//// Panel Cache with CouchDB
////
//// This module manages panel metadata caching with CouchDB change feed
//// integration for automatic cache invalidation.

import gleam/erlang
import gleam/erlang/process.{type Subject}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/otp/actor
import gleam/result
import wisp

import homeserve/config.{type Config}
import homeserve/couchdb
import homeserve/db
import homeserve/pages/panel.{type Meta}

// ---- Constants ----

const call_timeout_ms = 60_000

// 60 second timeout for CouchDB operations

// ---- Error Types ----

/// Cache operation errors
pub type CacheError {
  CacheTimeout
  CacheUnavailable
}

// ---- Cache Types ----

/// Messages that can be sent to the panel cache actor.
pub type CacheMessage {
  /// Request current list of panel metadata, with reply channel for response
  GetPanels(reply_to: Subject(Result(List(Meta), CacheError)))
  /// Force cache invalidation and reload from CouchDB
  InvalidateCache
  /// Gracefully shutdown the cache actor
  Shutdown
  /// Preload panels (used during startup)
  PreloadPanels(panels: List(Meta))
  /// Load panels from database (blocking operation)
  LoadPanels(reply_to: Subject(Result(List(Meta), CacheError)))
  /// Background reload without waiting for response
  ReloadInBackground
  /// Get cache health status
  GetHealth(reply_to: Subject(CacheHealth))
}

/// Health status of the cache
pub type CacheHealth {
  CacheHealth(
    /// Whether the cache has loaded panels successfully
    is_ready: Bool,
    /// Number of panels in cache
    panel_count: Int,
    /// When the cache was last loaded (Unix timestamp)
    last_loaded_at: Option(Int),
    /// Whether the cache is healthy
    is_healthy: Bool,
  )
}

type CacheState {
  CacheState(
    panels: List(Meta),
    loaded_at: Option(Int),
    cache_ttl_ms: Int,
    couch_config: couchdb.CouchConfig,
    last_seq: Option(String),
    max_cache_size: Int,
    self: Subject(CacheMessage),
  )
}

// ---- Watcher Types ----

/// Maximum backoff interval: 5 minutes
const max_backoff_ms = 300_000

/// Backoff multiplier on failure
const backoff_multiplier = 2

type WatcherMessage {
  CheckForChanges
  StopWatcher
}

type WatcherState {
  WatcherState(
    cache: Subject(CacheMessage),
    couch_config: couchdb.CouchConfig,
    last_seq: Option(String),
    self: Subject(WatcherMessage),
    watch_interval_ms: Int,
    /// Current backoff delay in milliseconds (for exponential backoff)
    current_backoff_ms: Int,
    /// Number of consecutive failures
    consecutive_failures: Int,
    /// Whether the watcher is currently healthy
    is_healthy: Bool,
  )
}

// ---- Public API ----

/// Starts the panel cache actor with CouchDB change feed monitoring.
pub fn start(cfg: Config) -> Result(Subject(CacheMessage), actor.StartError) {
  let cache_ttl_ms = cfg.cache.ttl_minutes * 60 * 1000
  let watch_interval_ms = cfg.cache.watch_interval_seconds * 1000

  let couch_config =
    couchdb.CouchConfig(
      host: cfg.couchdb.host,
      port: cfg.couchdb.port,
      database: cfg.couchdb.database,
      username: cfg.couchdb.username,
      password: cfg.couchdb.password,
    )

  wisp.log_info(
    "Starting panel cache with CouchDB at "
    <> couch_config.host
    <> ":"
    <> int.to_string(couch_config.port)
    <> "/"
    <> couch_config.database,
  )

  // Create self-reference for the actor
  let self_subject = process.new_subject()

  // Don't block on database init - we'll retry on first access
  // This prevents the server from hanging if CouchDB is not available
  let initial_state =
    CacheState(
      panels: [],
      loaded_at: None,
      cache_ttl_ms: cache_ttl_ms,
      couch_config: couch_config,
      last_seq: None,
      max_cache_size: cfg.cache.max_cache_size,
      self: self_subject,
    )

  use cache <- result.try(
    actor.start_spec(actor.Spec(
      init: fn() {
        let selector =
          process.new_selector()
          |> process.selecting(self_subject, fn(msg) { msg })
        actor.Ready(CacheState(..initial_state, self: self_subject), selector)
      },
      init_timeout: 5000,
      loop: handle_cache_message,
    )),
  )

  // Try to load panels initially (don't block on failure)
  wisp.log_info("Attempting initial panel load from CouchDB...")
  case db.get_all_meta(couch_config) {
    Ok(panels) -> {
      wisp.log_info(
        "Pre-loaded "
        <> int.to_string(list.length(panels))
        <> " panels from CouchDB",
      )
      process.send(cache, PreloadPanels(panels))
    }
    Error(err) -> {
      wisp.log_warning(
        "Initial panel load failed: " <> couchdb.error_to_string(err),
      )
      wisp.log_warning(
        "Panels will be loaded on first request (may cause delays)",
      )
    }
  }

  // Start the CouchDB change feed watcher
  start_watcher(cache, couch_config, watch_interval_ms)

  Ok(cache)
}

/// Gets the list of panels, using the cache if available and not expired.
/// Returns a Result to avoid crashes on timeout.
pub fn get_panels(
  cache: Subject(CacheMessage),
) -> Result(List(Meta), CacheError) {
  let reply_to = process.new_subject()
  process.send(cache, GetPanels(reply_to))

  case process.receive(reply_to, call_timeout_ms) {
    Ok(result) -> result
    Error(_) -> Error(CacheTimeout)
  }
}

/// Invalidates the cache, forcing a reload on next access.
pub fn invalidate(cache: Subject(CacheMessage)) -> Nil {
  process.send(cache, InvalidateCache)
}

/// Shuts down the cache actor.
pub fn shutdown(cache: Subject(CacheMessage)) -> Nil {
  process.send(cache, Shutdown)
}

/// Gets the health status of the cache.
pub fn get_health(cache: Subject(CacheMessage)) -> CacheHealth {
  let reply_to = process.new_subject()
  process.send(cache, GetHealth(reply_to))

  case process.receive(reply_to, call_timeout_ms) {
    Ok(health) -> health
    Error(_) ->
      CacheHealth(
        is_ready: False,
        panel_count: 0,
        last_loaded_at: None,
        is_healthy: False,
      )
  }
}

// ---- Cache Size Management ----

/// Limits the cache to the configured maximum size.
/// Keeps only the first max_size items (assumes panels are ordered by priority).
fn limit_cache_size(panels: List(Meta), max_size: Int) -> List(Meta) {
  let current_size = list.length(panels)
  case current_size > max_size {
    True -> {
      let excess = current_size - max_size
      wisp.log_info(
        "Cache size limit exceeded: "
        <> int.to_string(current_size)
        <> " > "
        <> int.to_string(max_size)
        <> ", truncating by "
        <> int.to_string(excess)
        <> " panels",
      )
      // Take only first max_size items
      list.take(panels, max_size)
    }
    False -> panels
  }
}

// ---- Cache Actor ----

fn handle_cache_message(
  message: CacheMessage,
  state: CacheState,
) -> actor.Next(CacheMessage, CacheState) {
  case message {
    GetPanels(reply_to) -> {
      let now = current_time_ms()
      let is_expired = case state.loaded_at {
        None -> True
        Some(loaded_at) -> now - loaded_at >= state.cache_ttl_ms
      }

      let is_reload_in_progress = case state.loaded_at {
        None -> False
        // If loaded_at is within last 5 seconds, assume reload is in progress
        Some(loaded_at) -> now - loaded_at < 5000
      }

      case is_expired, is_reload_in_progress {
        // Cache valid - return immediately
        False, _ -> {
          wisp.log_debug(
            "Returning cached panel list ("
            <> int.to_string(list.length(state.panels))
            <> " panels)",
          )
          process.send(reply_to, Ok(state.panels))
          actor.continue(state)
        }

        // Expired but reload already in progress - return stale data
        True, True -> {
          wisp.log_debug(
            "Cache reload in progress, returning stale data ("
            <> int.to_string(list.length(state.panels))
            <> " panels)",
          )
          process.send(reply_to, Ok(state.panels))
          actor.continue(state)
        }

        // Expired and no reload in progress - trigger background reload
        True, False -> {
          wisp.log_info(
            "Cache expired, returning "
            <> case list.is_empty(state.panels) {
              True -> "empty list"
              False ->
                "stale data ("
                <> int.to_string(list.length(state.panels))
                <> " panels)"
            }
            <> ", triggering background reload...",
          )
          process.send(reply_to, Ok(state.panels))

          // Trigger background reload
          process.send(state.self, ReloadInBackground)

          // Update loaded_at to prevent multiple simultaneous reloads
          actor.continue(
            CacheState(
              ..state,
              loaded_at: Some(current_time_ms()),
              max_cache_size: state.max_cache_size,
            ),
          )
        }
      }
    }

    InvalidateCache -> {
      wisp.log_info("Panel cache invalidated")
      actor.continue(
        CacheState(
          ..state,
          panels: [],
          loaded_at: None,
          max_cache_size: state.max_cache_size,
        ),
      )
    }

    Shutdown -> {
      wisp.log_info("Panel cache shutting down")
      actor.Stop(process.Normal)
    }

    PreloadPanels(panels) -> {
      let limited_panels = limit_cache_size(panels, state.max_cache_size)
      wisp.log_info(
        "Preloaded "
        <> int.to_string(list.length(limited_panels))
        <> " panels into cache"
        <> case list.length(limited_panels) < list.length(panels) {
          True -> " (limited from " <> int.to_string(list.length(panels)) <> ")"
          False -> ""
        },
      )
      let now = current_time_ms()
      actor.continue(
        CacheState(
          ..state,
          panels: limited_panels,
          loaded_at: Some(now),
          max_cache_size: state.max_cache_size,
        ),
      )
    }

    LoadPanels(reply_to) -> {
      wisp.log_info("Loading panels from database...")
      case db.get_all_meta(state.couch_config) {
        Ok(panels) -> {
          let limited_panels = limit_cache_size(panels, state.max_cache_size)
          let now = current_time_ms()
          process.send(reply_to, Ok(limited_panels))
          actor.continue(
            CacheState(
              ..state,
              panels: limited_panels,
              loaded_at: Some(now),
              max_cache_size: state.max_cache_size,
            ),
          )
        }
        Error(err) -> {
          wisp.log_warning(
            "Failed to load panels from database: "
            <> couchdb.error_to_string(err),
          )
          process.send(reply_to, Error(CacheUnavailable))
          actor.continue(state)
        }
      }
    }

    ReloadInBackground -> {
      wisp.log_info("Background reload of panels from database...")
      case db.get_all_meta(state.couch_config) {
        Ok(panels) -> {
          let limited_panels = limit_cache_size(panels, state.max_cache_size)
          let now = current_time_ms()
          wisp.log_info(
            "Background reload complete: "
            <> int.to_string(list.length(limited_panels))
            <> " panels loaded",
          )
          actor.continue(
            CacheState(
              ..state,
              panels: limited_panels,
              loaded_at: Some(now),
              max_cache_size: state.max_cache_size,
            ),
          )
        }
        Error(err) -> {
          wisp.log_warning(
            "Background reload failed: " <> couchdb.error_to_string(err),
          )
          // Clear loaded_at to allow retry on next request
          actor.continue(CacheState(..state, loaded_at: None))
        }
      }
    }

    GetHealth(reply_to) -> {
      let panel_count = list.length(state.panels)
      let is_ready = !list.is_empty(state.panels)
      let is_healthy = case state.loaded_at {
        None -> False
        Some(loaded_at) ->
          current_time_ms() - loaded_at < state.cache_ttl_ms * 2
      }
      process.send(
        reply_to,
        CacheHealth(
          is_ready: is_ready,
          panel_count: panel_count,
          last_loaded_at: state.loaded_at,
          is_healthy: is_healthy,
        ),
      )
      actor.continue(state)
    }
  }
}

// ---- Change Feed Watcher ----

fn start_watcher(
  cache: Subject(CacheMessage),
  couch_config: couchdb.CouchConfig,
  watch_interval_ms: Int,
) -> Nil {
  let self_subject = process.new_subject()

  let watcher_state =
    WatcherState(
      cache: cache,
      couch_config: couch_config,
      last_seq: None,
      self: self_subject,
      watch_interval_ms: watch_interval_ms,
      current_backoff_ms: watch_interval_ms,
      consecutive_failures: 0,
      is_healthy: True,
    )

  case
    actor.start_spec(actor.Spec(
      init: fn() {
        let selector =
          process.new_selector()
          |> process.selecting(self_subject, fn(msg) { msg })

        // Schedule the first check
        process.send_after(self_subject, watch_interval_ms, CheckForChanges)

        actor.Ready(watcher_state, selector)
      },
      init_timeout: 5000,
      loop: handle_watcher_message,
    ))
  {
    Ok(_) -> {
      wisp.log_info(
        "CouchDB change feed watcher started, checking every "
        <> int.to_string(watch_interval_ms / 1000)
        <> " seconds",
      )
      Nil
    }
    Error(_) -> {
      wisp.log_warning(
        "Failed to start change feed watcher, cache will use TTL only",
      )
      Nil
    }
  }
}

/// Calculate the next backoff delay with exponential backoff
fn calculate_backoff(current_backoff: Int, _base_interval: Int) -> Int {
  let next_backoff = current_backoff * backoff_multiplier
  case next_backoff > max_backoff_ms {
    True -> max_backoff_ms
    False -> next_backoff
  }
}

fn handle_watcher_message(
  message: WatcherMessage,
  state: WatcherState,
) -> actor.Next(WatcherMessage, WatcherState) {
  case message {
    CheckForChanges -> {
      // Poll for changes from CouchDB
      case db.get_changes(state.couch_config, state.last_seq) {
        Error(err) -> {
          let new_failures = state.consecutive_failures + 1
          let new_backoff =
            calculate_backoff(state.current_backoff_ms, state.watch_interval_ms)

          wisp.log_warning(
            "Change feed poll failed (attempt "
            <> int.to_string(new_failures)
            <> "): "
            <> couchdb.error_to_string(err),
          )
          wisp.log_info(
            "Retrying in " <> int.to_string(new_backoff / 1000) <> " seconds",
          )

          // Schedule next check with backoff
          process.send_after(state.self, new_backoff, CheckForChanges)

          actor.continue(
            WatcherState(
              ..state,
              current_backoff_ms: new_backoff,
              consecutive_failures: new_failures,
              is_healthy: False,
            ),
          )
        }
        Ok(#(new_seq, changes)) -> {
          // Reset backoff on success
          let was_unhealthy = !state.is_healthy
          let new_state = case list.is_empty(changes) {
            True ->
              WatcherState(
                ..state,
                current_backoff_ms: state.watch_interval_ms,
                consecutive_failures: 0,
                is_healthy: True,
              )
            False -> {
              // Log changes
              list.each(changes, fn(meta) {
                wisp.log_info(
                  "Panel change detected: #"
                  <> int.to_string(meta.index)
                  <> " - "
                  <> meta.title,
                )
              })

              // Invalidate cache to force reload
              process.send(state.cache, InvalidateCache)

              WatcherState(
                ..state,
                last_seq: Some(new_seq),
                current_backoff_ms: state.watch_interval_ms,
                consecutive_failures: 0,
                is_healthy: True,
              )
            }
          }

          case was_unhealthy {
            True -> wisp.log_info("Change feed connection restored")
            False -> Nil
          }

          // Schedule next check at normal interval
          process.send_after(
            state.self,
            state.watch_interval_ms,
            CheckForChanges,
          )
          actor.continue(new_state)
        }
      }
    }

    StopWatcher -> {
      wisp.log_info("Change feed watcher stopping")
      actor.Stop(process.Normal)
    }
  }
}

// ---- Helper Functions ----

fn current_time_ms() -> Int {
  erlang.system_time(erlang.Millisecond)
}
