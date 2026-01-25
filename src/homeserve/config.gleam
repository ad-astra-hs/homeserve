/// Configuration module for Homeserve.
/// Loads settings from homeserve.toml file.
import gleam/dict
import gleam/int
import gleam/result
import simplifile
import tom
import wisp

// ---- Types ----

/// Main configuration structure for the application.
pub type Config {
  Config(server: ServerConfig, cache: CacheConfig, paths: PathsConfig)
}

/// Server-related configuration.
pub type ServerConfig {
  ServerConfig(port: Int, host: String)
}

/// Cache-related configuration.
pub type CacheConfig {
  CacheConfig(ttl_minutes: Int, watch_interval_seconds: Int)
}

/// Path-related configuration.
pub type PathsConfig {
  PathsConfig(
    pages_directory: String,
    assets_directory: String,
    extra_directory: String,
  )
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

const default_pages_directory = "./pages"

const default_assets_directory = "./priv/static/assets"

const default_extra_directory = "./priv/static/extra"

// ---- Public API ----

/// Loads configuration from the default path (homeserve.toml).
/// Loads configuration from the default config file path.
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
    ),
    paths: PathsConfig(
      pages_directory: default_pages_directory,
      assets_directory: default_assets_directory,
      extra_directory: default_extra_directory,
    ),
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

  // Parse paths config
  let pages_dir =
    get_string_or_default(
      toml,
      ["paths", "pages_directory"],
      defaults.paths.pages_directory,
    )
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

  Ok(Config(
    server: ServerConfig(port: server_port, host: server_host),
    cache: CacheConfig(
      ttl_minutes: cache_ttl,
      watch_interval_seconds: watch_interval,
    ),
    paths: PathsConfig(
      pages_directory: pages_dir,
      assets_directory: assets_dir,
      extra_directory: extra_dir,
    ),
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
    <> ", pages="
    <> config.paths.pages_directory
    <> ", assets="
    <> config.paths.assets_directory,
  )
}
