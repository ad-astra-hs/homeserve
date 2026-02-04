/// Configuration module for Homeserve.
/// Loads settings from homeserve.toml file.
import gleam/dict
import gleam/int
import gleam/option.{type Option, Some}
import gleam/result
import simplifile
import tom
import wisp

// ---- Types ----

/// Main configuration structure for the application.
pub type Config {
  Config(
    server: ServerConfig,
    cache: CacheConfig,
    paths: PathsConfig,
    couchdb: CouchdbConfig,
    admin: AdminConfig,
    contact: ContactConfig,
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

/// CouchDB configuration.
pub type CouchdbConfig {
  CouchdbConfig(
    host: String,
    port: Int,
    database: String,
    username: Option(String),
    password: Option(String),
  )
}

/// Server-related configuration.
pub type ServerConfig {
  ServerConfig(port: Int, host: String)
}

/// Cache-related configuration.
pub type CacheConfig {
  CacheConfig(
    ttl_minutes: Int,
    watch_interval_seconds: Int,
    max_cache_size: Int,
  )
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

const default_cache_ttl_minutes = 60

const default_watch_interval_seconds = 5

const default_max_cache_size = 1000

const default_assets_directory = "./priv/static/assets"

const default_extra_directory = "./priv/static/extra"

const default_couchdb_host = "127.0.0.1"

const default_couchdb_port = 5984

const default_couchdb_database = "homeserve_panels"

const default_couchdb_username = "admin"

const default_couchdb_password = "password"

const default_admin_token = "changeme"

const default_contact_email = "admin@example.com"

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
    cache: CacheConfig(
      ttl_minutes: default_cache_ttl_minutes,
      watch_interval_seconds: default_watch_interval_seconds,
      max_cache_size: default_max_cache_size,
    ),
    paths: PathsConfig(
      assets_directory: default_assets_directory,
      extra_directory: default_extra_directory,
    ),
    couchdb: CouchdbConfig(
      host: default_couchdb_host,
      port: default_couchdb_port,
      database: default_couchdb_database,
      username: Some(default_couchdb_username),
      password: Some(default_couchdb_password),
    ),
    admin: AdminConfig(token: default_admin_token),
    contact: ContactConfig(email: default_contact_email),
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

fn parse_config(
  toml: dict.Dict(String, tom.Toml),
) -> Result(Config, ConfigError) {
  let defaults = default_config()

  // Parse server config
  let server_port =
    get_int_or_default(toml, ["server", "port"], defaults.server.port)
  let server_host =
    get_string_or_default(toml, ["server", "host"], defaults.server.host)

  // Parse cache config
  let cache_ttl =
    get_int_or_default(
      toml,
      ["cache", "ttl_minutes"],
      defaults.cache.ttl_minutes,
    )
  let watch_interval =
    get_int_or_default(
      toml,
      ["cache", "watch_interval_seconds"],
      defaults.cache.watch_interval_seconds,
    )
  let max_cache_size =
    get_int_or_default(
      toml,
      ["cache", "max_cache_size"],
      defaults.cache.max_cache_size,
    )

  // Parse paths config
  let assets_dir =
    get_string_or_default(
      toml,
      ["paths", "assets_directory"],
      defaults.paths.assets_directory,
    )
  let extra_dir =
    get_string_or_default(
      toml,
      ["paths", "extra_directory"],
      defaults.paths.extra_directory,
    )

  // Parse couchdb config
  let couchdb_host =
    get_string_or_default(toml, ["couchdb", "host"], defaults.couchdb.host)
  let couchdb_port =
    get_int_or_default(toml, ["couchdb", "port"], defaults.couchdb.port)
  let couchdb_database =
    get_string_or_default(
      toml,
      ["couchdb", "database"],
      defaults.couchdb.database,
    )
  let couchdb_username =
    get_string_or_default(
      toml,
      ["couchdb", "username"],
      default_couchdb_username,
    )
  let couchdb_password =
    get_string_or_default(
      toml,
      ["couchdb", "password"],
      default_couchdb_password,
    )

  // Parse admin config
  let admin_token =
    get_string_or_default(toml, ["admin", "token"], default_admin_token)

  // Parse contact config
  let contact_email =
    get_string_or_default(toml, ["contact", "email"], default_contact_email)

  Ok(Config(
    server: ServerConfig(port: server_port, host: server_host),
    cache: CacheConfig(
      ttl_minutes: cache_ttl,
      watch_interval_seconds: watch_interval,
      max_cache_size: max_cache_size,
    ),
    paths: PathsConfig(assets_directory: assets_dir, extra_directory: extra_dir),
    couchdb: CouchdbConfig(
      host: couchdb_host,
      port: couchdb_port,
      database: couchdb_database,
      username: Some(couchdb_username),
      password: Some(couchdb_password),
    ),
    admin: AdminConfig(token: admin_token),
    contact: ContactConfig(email: contact_email),
  ))
}

fn get_int_or_default(
  toml: dict.Dict(String, tom.Toml),
  key: List(String),
  default: Int,
) -> Int {
  tom.get_int(toml, key)
  |> result.unwrap(default)
}

fn get_string_or_default(
  toml: dict.Dict(String, tom.Toml),
  key: List(String),
  default: String,
) -> String {
  tom.get_string(toml, key)
  |> result.unwrap(default)
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
    <> ", cache_ttl="
    <> int.to_string(config.cache.ttl_minutes)
    <> "min"
    <> ", watch_interval="
    <> int.to_string(config.cache.watch_interval_seconds)
    <> "s"
    <> ", couchdb="
    <> config.couchdb.host
    <> ":"
    <> int.to_string(config.couchdb.port)
    <> "/"
    <> config.couchdb.database,
  )
}
