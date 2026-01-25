import gleam/erlang
import gleam/erlang/process.{type Subject}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/otp/actor
import gleam/result
import gleam/string
import simplifile
import wisp

import homeserve/config.{type Config}
import homeserve/pages/panel.{type Meta}

// ---- Constants ----

const call_timeout_ms = 5000

// ---- Cache Types ----

/// Messages that can be sent to the panel cache actor.
/// 
/// The cache actor manages panel metadata with TTL-based expiration
/// and file system watching for automatic invalidation.
pub type CacheMessage {
  /// Request current list of panel metadata, with reply channel for response
  GetPanels(reply_to: Subject(List(Meta)))
  /// Force cache invalidation and reload from file system
  InvalidateCache
  /// Gracefully shutdown the cache actor
  Shutdown
}

type CacheState {
  CacheState(
    panels: List(Meta),
    loaded_at: Option(Int),
    cache_ttl_ms: Int,
    pages_directory: String,
  )
}

// ---- Watcher Types ----

type WatcherMessage {
  CheckForChanges
  StopWatcher
}

type WatcherState {
  WatcherState(
    cache: Subject(CacheMessage),
    last_snapshot: List(FileSnapshot),
    self: Subject(WatcherMessage),
    pages_directory: String,
    watch_interval_ms: Int,
  )
}

type FileSnapshot {
  FileSnapshot(path: String, modified: Int)
}

// ---- Public API ----

/// Starts the panel cache actor with file watching and TTL-based expiration.
/// 
/// This creates an actor that manages panel metadata caching with the following features:
/// - TTL-based cache expiration (configurable minutes)
/// - File system watching for automatic cache invalidation
/// - Concurrent access through message passing
/// - Graceful shutdown support
/// 
/// # Parameters
/// 
/// - `cfg`: Application configuration containing cache settings
/// 
/// # Returns
/// 
/// Subject for sending messages to the cache actor, or StartError if actor fails to start
pub fn start(cfg: Config) -> Result(Subject(CacheMessage), actor.StartError) {
  let cache_ttl_ms = cfg.cache.ttl_minutes * 60 * 1000
  let watch_interval_ms = cfg.cache.watch_interval_seconds * 1000
  let pages_directory = cfg.paths.pages_directory

  wisp.log_info(
    "Starting panel cache actor with "
    <> int.to_string(cfg.cache.ttl_minutes)
    <> " minute TTL and file watching every "
    <> int.to_string(cfg.cache.watch_interval_seconds)
    <> " seconds",
  )

  // Start the cache actor
  let initial_state =
    CacheState(
      panels: [],
      loaded_at: None,
      cache_ttl_ms: cache_ttl_ms,
      pages_directory: pages_directory,
    )

  use cache <- result.try(actor.start(initial_state, handle_cache_message))

  // Start the file watcher
  start_watcher(cache, pages_directory, watch_interval_ms)

  Ok(cache)
}

/// Gets the list of panels, using the cache if available and not expired.
pub fn get_panels(cache: Subject(CacheMessage)) -> List(Meta) {
  actor.call(cache, GetPanels, call_timeout_ms)
}

/// Invalidates the cache, forcing a reload on next access.
pub fn invalidate(cache: Subject(CacheMessage)) -> Nil {
  process.send(cache, InvalidateCache)
}

/// Shuts down the cache actor.
pub fn shutdown(cache: Subject(CacheMessage)) -> Nil {
  process.send(cache, Shutdown)
}

// ---- Cache Actor ----

fn handle_cache_message(
  message: CacheMessage,
  state: CacheState,
) -> actor.Next(CacheMessage, CacheState) {
  case message {
    GetPanels(reply_to) -> {
      let now = current_time_ms()
      let is_valid = case state.loaded_at {
        None -> False
        Some(loaded_at) -> now - loaded_at < state.cache_ttl_ms
      }

      let #(panels, new_state) = case is_valid {
        True -> {
          wisp.log_debug(
            "Returning cached panel list ("
            <> int.to_string(list.length(state.panels))
            <> " panels, "
            <> int.to_string(time_remaining_minutes(
              state.loaded_at,
              now,
              state.cache_ttl_ms,
            ))
            <> " minutes until expiry)",
          )
          #(state.panels, state)
        }
        False -> {
          case state.loaded_at {
            None -> wisp.log_info("Loading panel list from disk (cache empty)")
            Some(_) ->
              wisp.log_info("Loading panel list from disk (cache expired)")
          }
          let panels = load_panels_from_disk(state.pages_directory)
          wisp.log_info(
            "Cached "
            <> int.to_string(list.length(panels))
            <> " panels (TTL: "
            <> int.to_string(state.cache_ttl_ms / 60_000)
            <> " minutes)",
          )
          #(panels, CacheState(..state, panels: panels, loaded_at: Some(now)))
        }
      }
      process.send(reply_to, panels)
      actor.continue(new_state)
    }

    InvalidateCache -> {
      wisp.log_info("Panel cache invalidated")
      actor.continue(CacheState(..state, panels: [], loaded_at: None))
    }

    Shutdown -> {
      wisp.log_info("Panel cache shutting down")
      actor.Stop(process.Normal)
    }
  }
}

// ---- File Watcher ----

fn start_watcher(
  cache: Subject(CacheMessage),
  pages_directory: String,
  watch_interval_ms: Int,
) -> Nil {
  let initial_snapshot = get_directory_snapshot(pages_directory)

  // Create a subject for the watcher to send messages to itself
  let self_subject = process.new_subject()

  let watcher_state =
    WatcherState(
      cache: cache,
      last_snapshot: initial_snapshot,
      self: self_subject,
      pages_directory: pages_directory,
      watch_interval_ms: watch_interval_ms,
    )

  case
    actor.start_spec(actor.Spec(
      init: fn() {
        // Set up the selector to receive messages from the self subject
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
        "File watcher started, monitoring "
        <> pages_directory
        <> " every "
        <> int.to_string(watch_interval_ms / 1000)
        <> " seconds",
      )
      Nil
    }
    Error(_) -> {
      wisp.log_warning(
        "Failed to start file watcher, cache will still work but won't auto-invalidate on file changes",
      )
      Nil
    }
  }
}

fn handle_watcher_message(
  message: WatcherMessage,
  state: WatcherState,
) -> actor.Next(WatcherMessage, WatcherState) {
  case message {
    CheckForChanges -> {
      let current_snapshot = get_directory_snapshot(state.pages_directory)
      let changes = detect_changes(state.last_snapshot, current_snapshot)

      let new_state = case changes {
        [] -> state
        _ -> {
          // Log what changed
          list.each(changes, fn(change) {
            wisp.log_info("File change detected: " <> change)
          })

          // Invalidate the cache
          process.send(state.cache, InvalidateCache)

          // Update snapshot
          WatcherState(..state, last_snapshot: current_snapshot)
        }
      }

      // Schedule next check using the stored self subject
      process.send_after(state.self, state.watch_interval_ms, CheckForChanges)

      actor.continue(new_state)
    }

    StopWatcher -> {
      wisp.log_info("File watcher stopping")
      actor.Stop(process.Normal)
    }
  }
}

// ---- File Snapshot Functions ----

fn get_directory_snapshot(pages_directory: String) -> List(FileSnapshot) {
  get_all_files(pages_directory)
  |> list.filter_map(fn(path) {
    case get_file_modified_time(path) {
      Ok(modified) -> Ok(FileSnapshot(path: path, modified: modified))
      Error(_) -> Error(Nil)
    }
  })
  |> list.sort(fn(a, b) { string.compare(a.path, b.path) })
}

fn get_all_files(directory: String) -> List(String) {
  case simplifile.read_directory(directory) {
    Error(_) -> []
    Ok(entries) -> {
      list.flat_map(entries, fn(entry) {
        let path = directory <> "/" <> entry
        case simplifile.is_directory(path) {
          Ok(True) -> get_all_files(path)
          _ -> [path]
        }
      })
    }
  }
}

fn get_file_modified_time(path: String) -> Result(Int, Nil) {
  case simplifile.file_info(path) {
    Ok(info) -> Ok(info.mtime_seconds)
    Error(_) -> Error(Nil)
  }
}

fn detect_changes(
  old_snapshot: List(FileSnapshot),
  new_snapshot: List(FileSnapshot),
) -> List(String) {
  let old_paths = list.map(old_snapshot, fn(f) { f.path })
  let new_paths = list.map(new_snapshot, fn(f) { f.path })

  // Find added files
  let added =
    new_paths
    |> list.filter(fn(p) { !list.contains(old_paths, p) })

  // Find removed files
  let removed =
    old_paths
    |> list.filter(fn(p) { !list.contains(new_paths, p) })

  // Find modified files
  let modified =
    new_snapshot
    |> list.filter_map(fn(new_file) {
      case list.find(old_snapshot, fn(old) { old.path == new_file.path }) {
        Ok(old_file) if old_file.modified != new_file.modified ->
          Ok(new_file.path)
        _ -> Error(Nil)
      }
    })

  list.flatten([added, removed, modified])
}

// ---- Helper Functions ----

fn load_panels_from_disk(pages_directory: String) -> List(Meta) {
  case simplifile.read_directory(pages_directory) {
    Error(err) -> {
      wisp.log_error(
        "Failed to read pages directory: " <> simplifile.describe_error(err),
      )
      []
    }
    Ok(files) -> {
      let panels =
        files
        // Filter for .md files and extract the panel number from filename
        |> list.filter(fn(file) { string.ends_with(file, ".md") })
        |> list.filter_map(fn(file) {
          // Remove .md extension and parse as int
          file
          |> string.drop_end(3)
          |> int.base_parse(10)
        })
        |> list.filter_map(fn(index) {
          case panel.decode_meta_from(index, pages_directory) {
            Ok(meta) -> Ok(meta)
            Error(_) -> Error(Nil)
          }
        })

      wisp.log_debug(
        "Loaded " <> int.to_string(list.length(panels)) <> " panels from disk",
      )
      panels
    }
  }
}

fn current_time_ms() -> Int {
  erlang.system_time(erlang.Millisecond)
}

fn time_remaining_minutes(loaded_at: Option(Int), now: Int, ttl_ms: Int) -> Int {
  case loaded_at {
    None -> 0
    Some(loaded) -> {
      let elapsed = now - loaded
      let remaining = ttl_ms - elapsed
      remaining / 60_000
    }
  }
}
