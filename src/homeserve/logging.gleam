//// Logging Utilities
////
//// Provides structured logging helpers for consistent log messages
//// across the application. Supports Debug and Info level logging.
//// Log level can be configured at runtime via config file.

import gleam/dynamic.{type Dynamic}
import gleam/erlang
import gleam/erlang/atom.{type Atom}
import gleam/int
import gleam/option.{type Option, None, Some}
import wisp

// ---- ETS Table Bindings ----

@external(erlang, "ets", "new")
fn ets_new(name: Atom, options: List(Dynamic)) -> Atom

@external(erlang, "ets", "lookup")
fn ets_lookup_level(table: Atom, key: Atom) -> List(#(Atom, String))

@external(erlang, "ets", "insert")
fn ets_insert_level(table: Atom, record: #(Atom, String)) -> Bool

// ---- Table Management ----

fn log_table() -> Atom {
  atom.create_from_string("homeserve_config")
}

fn log_level_key() -> Atom {
  atom.create_from_string("log_level")
}

/// Initialise the ETS table. Call once at application startup.
pub fn init() -> Nil {
  let _ =
    erlang.rescue(fn() {
      ets_new(log_table(), [
        dynamic.from(atom.create_from_string("set")),
        dynamic.from(atom.create_from_string("public")),
        dynamic.from(atom.create_from_string("named_table")),
        dynamic.from(#(atom.create_from_string("read_concurrency"), True)),
      ])
    })
  Nil
}

// ---- Log Level Configuration ----

/// Log levels for controlling output verbosity
pub type LogLevel {
  Debug
  Info
  Warning
  Error
}

/// Sets the minimum log level at runtime
pub fn set_log_level(level: LogLevel) -> Nil {
  init()
  ets_insert_level(log_table(), #(log_level_key(), log_level_to_string(level)))
  wisp.log_info("Log level changed to: " <> log_level_to_string(level))
  Nil
}

/// Gets the current minimum log level
pub fn get_log_level() -> LogLevel {
  init()
  case ets_lookup_level(log_table(), log_level_key()) {
    [#(_, level)] -> string_to_log_level(level)
    _ -> Info
  }
}

/// Compares log levels to determine if a message should be logged
fn should_log(level: LogLevel) -> Bool {
  log_level_to_int(level) >= log_level_to_int(get_log_level())
}

fn log_level_to_int(level: LogLevel) -> Int {
  case level {
    Debug -> 0
    Info -> 1
    Warning -> 2
    Error -> 3
  }
}

fn log_level_to_string(level: LogLevel) -> String {
  case level {
    Debug -> "debug"
    Info -> "info"
    Warning -> "warning"
    Error -> "error"
  }
}

fn string_to_log_level(level: String) -> LogLevel {
  case level {
    "debug" -> Debug
    "warning" -> Warning
    "error" -> Error
    _ -> Info
  }
}

// ---- Core Logging Functions ----

/// Logs a debug message with optional context
pub fn debug(message: String, context: Option(String)) {
  case should_log(Debug) {
    True -> {
      let full_message = format_message(message, context)
      wisp.log_debug(full_message)
    }
    False -> Nil
  }
}

/// Logs an info message with optional context
pub fn info(message: String, context: Option(String)) {
  case should_log(Info) {
    True -> {
      let full_message = format_message(message, context)
      wisp.log_info(full_message)
    }
    False -> Nil
  }
}

/// Logs a warning message with optional context
pub fn warning(message: String, context: Option(String)) {
  case should_log(Warning) {
    True -> {
      let full_message = format_message(message, context)
      wisp.log_warning(full_message)
    }
    False -> Nil
  }
}

/// Logs an error message with optional context
pub fn error(message: String, context: Option(String)) {
  case should_log(Error) {
    True -> {
      let full_message = format_message(message, context)
      wisp.log_error(full_message)
    }
    False -> Nil
  }
}

// ---- Formatted Message Builder ----

fn format_message(message: String, context: Option(String)) -> String {
  case context {
    None -> message
    Some(ctx) -> "[" <> ctx <> "] " <> message
  }
}

// ---- Convenience Functions with Context ----

/// Debug log with component context
pub fn debug_ctx(component: String, message: String) {
  debug(message, Some(component))
}

/// Info log with component context
pub fn info_ctx(component: String, message: String) {
  info(message, Some(component))
}

/// Warning log with component context
pub fn warning_ctx(component: String, message: String) {
  warning(message, Some(component))
}

/// Error log with component context
pub fn error_ctx(component: String, message: String) {
  error(message, Some(component))
}

// ---- Request Logging ----

/// Logs an incoming HTTP request
pub fn log_request(method: String, path: String, remote_ip: Option(String)) {
  let ip_str = case remote_ip {
    None -> "unknown"
    Some(ip) -> ip
  }
  info(method <> " " <> path <> " from " <> ip_str, Some("HTTP"))
}

/// Logs authentication events
pub fn log_auth(event: String, user_info: String) {
  case event {
    "login_success" -> info("Login successful: " <> user_info, Some("AUTH"))
    "login_failure" -> warning("Login failed: " <> user_info, Some("AUTH"))
    "logout" -> info("Logout: " <> user_info, Some("AUTH"))
    _ -> info(event <> ": " <> user_info, Some("AUTH"))
  }
}

/// Logs admin panel actions
pub fn log_admin(action: String, details: String) {
  info(action <> ": " <> details, Some("ADMIN"))
}

/// Logs panel operations
pub fn log_panel(operation: String, panel_id: Int) {
  info(operation <> ": #" <> int.to_string(panel_id), Some("PANEL"))
}

/// Logs volunteer operations
pub fn log_volunteer(operation: String, volunteer_name: String) {
  info(operation <> ": " <> volunteer_name, Some("VOLUNTEER"))
}
