//// Homeserve OTP Application
////
//// Provides proper OTP application behaviour with graceful shutdown handling.

import gleam/erlang/process
import gleam/int
import gleam/list
import gleam/option.{None}

import homeserve/cache
import homeserve/config
import homeserve/db
import homeserve/logging
import homeserve/mnesia_db
import homeserve/rate_limit

/// Application state
pub type AppState {
  AppState(config: config.Config)
}

/// Start the homeserve application
pub fn start() {
  // Load configuration
  let cfg = config.load()

  // Initialise ETS-backed services
  cache.init()
  logging.init()
  rate_limit.init()

  // Initialize logging with config level
  init_logging(cfg)

  // Initialize database
  logging.info("Initializing Mnesia database...", None)
  case db.initialize(cfg.mnesia) {
    Ok(_) -> {
      logging.info("Mnesia database initialized successfully", None)
      // Warm up cache
      warmup_cache()
    }
    Error(err) -> {
      logging.error("Failed to initialize Mnesia database", None)
      logging.error(mnesia_db.error_to_string(err), None)
    }
  }

  // Set up graceful shutdown handler
  setup_shutdown_handler(cfg)

  AppState(config: cfg)
}

/// Initialize logging from config
fn init_logging(cfg: config.Config) {
  let log_level = case cfg.logging.level {
    "debug" -> logging.Debug
    "warning" -> logging.Warning
    "error" -> logging.Error
    _ -> logging.Info
  }
  logging.set_log_level(log_level)
}

/// Warm up the cache with existing panels
fn warmup_cache() -> Nil {
  logging.info("Warming up cache...", None)
  case db.get_all_meta() {
    Ok(metas) -> {
      cache.warmup_meta_list(metas)
      logging.info(
        "Cached "
          <> int.to_string(list.length(metas))
          <> " panel metadata entries",
        None,
      )
      // Also load recent panels (last 10) into panel cache
      let recent_metas = list.take(list.reverse(metas), 10)
      list.each(recent_metas, fn(meta) {
        case db.load_panel(meta.index) {
          Ok(panel) -> cache.put(meta.index, panel)
          Error(_) -> Nil
        }
      })
      logging.info(
        "Warmed up cache with "
          <> int.to_string(list.length(recent_metas))
          <> " recent panels",
        None,
      )
    }
    Error(err) -> {
      logging.warning(
        "Cache warmup skipped: " <> mnesia_db.error_to_string(err),
        None,
      )
    }
  }
}

/// Set up graceful shutdown handler
fn setup_shutdown_handler(_cfg: config.Config) -> Nil {
  // Trap exit signals for graceful shutdown
  process.trap_exits(True)

  // The shutdown handler will be triggered when the application stops
  logging.info("Graceful shutdown handler registered", None)
  Nil
}

/// Stop the application gracefully
pub fn stop(_state: AppState) {
  logging.info("Shutting down homeserve gracefully...", None)

  // Clear cache
  logging.info("Clearing cache...", None)
  cache.clear()

  // Any other cleanup needed
  logging.info("Shutdown complete", None)

  Nil
}
