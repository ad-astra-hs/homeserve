/// Configuration module for Homeserve.
/// Loads settings from homeserve.toml file.
import gleam/dict
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import simplifile
import tom
import wisp

// ---- Types ----

/// Main configuration structure for the application.
pub type Config {
  Config(
    server: ServerConfig,
    paths: PathsConfig,
    mnesia: MnesiaConfig,
    admin: AdminConfig,
    contact: ContactConfig,
    logging: LoggingConfig,
  )
}

/// Logging configuration.
pub type LoggingConfig {
  LoggingConfig(
    /// Log level: "debug", "info", "warning", "error"
    level: String,
  )
}

/// Contact information configuration.
pub type ContactConfig {
  ContactConfig(
    /// Email address for privacy concerns and general contact
    email: String,
  )
}

/// Admin panel configuration.
pub type AdminConfig {
  AdminConfig(
    /// Token for admin authentication (should be changed in production)
    token: String,
  )
}

/// Mnesia configuration.
pub type MnesiaConfig {
  MnesiaConfig(
    /// Optional data directory for Mnesia (uses Erlang default if not set)
    data_dir: Option(String),
  )
}

/// Server-related configuration.
pub type ServerConfig {
  ServerConfig(port: Int, host: String)
}

/// Path-related configuration.
pub type PathsConfig {
  PathsConfig(assets_directory: String, extra_directory: String)
}

/// Errors that can occur when loading configuration.
pub type ConfigError {
  FileNotFound(path: String)
  ParseError(message: String)
  MissingField(field: String)
  InvalidFieldType(field: String, expected: String)
}

// ---- Constants (defaults) ----

const default_config_path = "./homeserve.toml"

const default_port = 8000

const default_host = "0.0.0.0"

const default_assets_directory = "./priv/static/assets"

const default_extra_directory = "./priv/static/extra"

const default_admin_token = "changeme"

const default_contact_email = "admin@example.com"

const default_log_level = "info"

// ---- Public API ----

/// Loads configuration from the default config file path (`homeserve.toml`).
///
/// Attempts to load `homeserve.toml` from the current directory.
/// If the file doesn't exist or contains errors, falls back to default values.
/// Logs the configuration that was actually used (loaded or defaults).
///
/// # Returns
///
/// Complete application configuration
pub fn load() -> Config {
  load_from(default_config_path)
}

/// Loads configuration from a specific TOML file path.
///
/// Attempts to parse and validate the configuration file.
/// If the file doesn't exist or contains errors, falls back to default values.
/// Logs the configuration that was actually used (loaded or defaults).
///
/// # Parameters
///
/// - `path`: Path to the TOML configuration file
///
/// # Returns
///
/// Complete application configuration
pub fn load_from(path: String) -> Config {
  case load_from_file(path) {
    Ok(config) -> {
      wisp.log_info("Loaded configuration from " <> path)
      log_config(config)
      config
    }
    Error(FileNotFound(_)) -> {
      wisp.log_info("No config file found at " <> path <> ", using defaults")
      let config = default_config()
      log_config(config)
      config
    }
    Error(err) -> {
      wisp.log_warning(
        "Failed to load config from "
        <> path
        <> ": "
        <> config_error_to_string(err)
        <> ", using defaults",
      )
      let config = default_config()
      log_config(config)
      config
    }
  }
}

/// Returns the default configuration.
pub fn default_config() -> Config {
  Config(
    server: ServerConfig(port: default_port, host: default_host),
    paths: PathsConfig(
      assets_directory: default_assets_directory,
      extra_directory: default_extra_directory,
    ),
    mnesia: MnesiaConfig(data_dir: None),
    admin: AdminConfig(token: default_admin_token),
    contact: ContactConfig(email: default_contact_email),
    logging: LoggingConfig(level: default_log_level),
  )
}

// ---- Internal functions ----

fn load_from_file(path: String) -> Result(Config, ConfigError) {
  use content <- result.try(
    simplifile.read(path)
    |> result.map_error(fn(_) { FileNotFound(path) }),
  )

  use toml <- result.try(
    tom.parse(content)
    |> result.map_error(fn(err) {
      case err {
        tom.Unexpected(got, expected) ->
          ParseError("Unexpected '" <> got <> "', expected " <> expected)
        tom.KeyAlreadyInUse(key) ->
          ParseError("Duplicate key: " <> key_to_string(key))
      }
    }),
  )

  parse_config(toml)
}

/// Validation error for configuration values.
pub type ValidationError {
  InvalidPort(field: String, value: Int, min: Int, max: Int)
  InvalidNonEmptyString(field: String)
  InvalidEmail(field: String, value: String)
}

/// Converts ValidationError to human-readable string.
pub fn validation_error_to_string(err: ValidationError) -> String {
  case err {
    InvalidPort(field, value, min, max) ->
      field
      <> " must be between "
      <> int.to_string(min)
      <> " and "
      <> int.to_string(max)
      <> ", got "
      <> int.to_string(value)
    InvalidNonEmptyString(field) -> field <> " cannot be empty"
    InvalidEmail(field, value) ->
      "'" <> value <> "' is not a valid email address for " <> field
  }
}

/// Validates a configuration and returns list of validation errors.
/// Returns empty list if configuration is valid.
pub fn validate_config(config: Config) -> List(ValidationError) {
  let errors = []

  // Validate server config
  let errors = case is_valid_port(config.server.port) {
    True -> errors
    False -> [
      InvalidPort("server.port", config.server.port, 1, 65_535),
      ..errors
    ]
  }

  let errors = case string.is_empty(config.server.host) {
    True -> [InvalidNonEmptyString("server.host"), ..errors]
    False -> errors
  }

  // Validate paths config
  let errors = case string.is_empty(config.paths.assets_directory) {
    True -> [InvalidNonEmptyString("paths.assets_directory"), ..errors]
    False -> errors
  }

  let errors = case string.is_empty(config.paths.extra_directory) {
    True -> [InvalidNonEmptyString("paths.extra_directory"), ..errors]
    False -> errors
  }

  // Validate admin config
  let errors = case string.is_empty(config.admin.token) {
    True -> [InvalidNonEmptyString("admin.token"), ..errors]
    False -> errors
  }

  // Validate contact config (basic email validation)
  let errors = case is_valid_email(config.contact.email) {
    True -> errors
    False -> [InvalidEmail("contact.email", config.contact.email), ..errors]
  }

  list.reverse(errors)
}

fn is_valid_port(port: Int) -> Bool {
  port >= 1 && port <= 65_535
}

fn is_valid_email(email: String) -> Bool {
  // Basic email validation - must contain @ and have non-empty local and domain parts
  case string.split(email, "@") {
    [local, domain] -> {
      !string.is_empty(local)
      && !string.is_empty(domain)
      && string.contains(domain, ".")
    }
    _ -> False
  }
}

fn parse_config(
  toml: dict.Dict(String, tom.Toml),
) -> Result(Config, ConfigError) {
  let defaults = default_config()

  // Parse server config
  let server_port =
    tom.get_int(toml, ["server", "port"])
    |> result.unwrap(defaults.server.port)
  let server_host =
    tom.get_string(toml, ["server", "host"])
    |> result.unwrap(defaults.server.host)

  // Parse paths config
  let assets_dir =
    tom.get_string(toml, ["paths", "assets_directory"])
    |> result.unwrap(defaults.paths.assets_directory)
  let extra_dir =
    tom.get_string(toml, ["paths", "extra_directory"])
    |> result.unwrap(defaults.paths.extra_directory)

  // Parse mnesia config (optional)
  let mnesia_data_dir = case tom.get_string(toml, ["mnesia", "data_dir"]) {
    Ok(dir) if dir != "" -> Some(dir)
    _ -> None
  }

  // Parse admin config
  let admin_token =
    tom.get_string(toml, ["admin", "token"])
    |> result.unwrap(default_admin_token)

  // Parse contact config
  let contact_email =
    tom.get_string(toml, ["contact", "email"])
    |> result.unwrap(default_contact_email)

  // Parse logging config
  let log_level =
    tom.get_string(toml, ["logging", "level"])
    |> result.unwrap(default_log_level)

  let config =
    Config(
      server: ServerConfig(port: server_port, host: server_host),
      paths: PathsConfig(
        assets_directory: assets_dir,
        extra_directory: extra_dir,
      ),
      mnesia: MnesiaConfig(data_dir: mnesia_data_dir),
      admin: AdminConfig(token: admin_token),
      contact: ContactConfig(email: contact_email),
      logging: LoggingConfig(level: log_level),
    )

  // Validate the parsed configuration
  case validate_config(config) {
    [] -> Ok(config)
    errors -> {
      let error_msgs =
        list.map(errors, validation_error_to_string)
        |> string.join("; ")
      Error(ParseError("Configuration validation failed: " <> error_msgs))
    }
  }
}

fn key_to_string(key: List(String)) -> String {
  case key {
    [] -> ""
    [single] -> single
    [first, ..rest] -> first <> "." <> key_to_string(rest)
  }
}

fn config_error_to_string(err: ConfigError) -> String {
  case err {
    FileNotFound(path) -> "File not found: " <> path
    ParseError(msg) -> "Parse error: " <> msg
    MissingField(field) -> "Missing required field: " <> field
    InvalidFieldType(field, expected) ->
      "Invalid type for '" <> field <> "', expected " <> expected
  }
}

fn log_config(config: Config) -> Nil {
  wisp.log_debug(
    "Config: server="
    <> config.server.host
    <> ":"
    <> int.to_string(config.server.port)
    <> ", mnesia=local",
  )
}
