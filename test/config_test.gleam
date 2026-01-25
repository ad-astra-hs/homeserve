import gleam/string
import gleeunit/should

import homeserve/config

// ---- Default Config Tests ----

pub fn default_config_has_port_8000_test() {
  let cfg = config.default_config()

  cfg.server.port |> should.equal(8000)
}

pub fn default_config_has_host_all_interfaces_test() {
  let cfg = config.default_config()

  cfg.server.host |> should.equal("0.0.0.0")
}

pub fn default_config_has_60_minute_ttl_test() {
  let cfg = config.default_config()

  cfg.cache.ttl_minutes |> should.equal(60)
}

pub fn default_config_has_5_second_watch_interval_test() {
  let cfg = config.default_config()

  cfg.cache.watch_interval_seconds |> should.equal(5)
}

pub fn default_config_has_pages_directory_test() {
  let cfg = config.default_config()

  cfg.paths.pages_directory |> should.equal("./pages")
}

pub fn default_config_has_assets_directory_test() {
  let cfg = config.default_config()

  cfg.paths.assets_directory |> should.equal("./priv/static/assets")
}

// ---- Load Config Tests ----

pub fn load_returns_config_test() {
  // load() should always return a config (either from file or defaults)
  let cfg = config.load()

  // Should have valid values
  cfg.server.port |> should.not_equal(0)
  string.length(cfg.server.host) |> should.not_equal(0)
}

pub fn load_from_nonexistent_file_returns_defaults_test() {
  let cfg = config.load_from("./nonexistent_config_file_12345.toml")

  // Should fall back to defaults
  cfg.server.port |> should.equal(8000)
  cfg.server.host |> should.equal("0.0.0.0")
  cfg.cache.ttl_minutes |> should.equal(60)
}

// ---- Config from example homeserve.toml ----

pub fn load_from_example_toml_test() {
  let cfg = config.load_from("./homeserve.example.toml")

  // The example config has these values
  cfg.server.port |> should.equal(8000)
  cfg.server.host |> should.equal("0.0.0.0")
  cfg.cache.ttl_minutes |> should.equal(60)
  cfg.cache.watch_interval_seconds |> should.equal(5)
  cfg.paths.pages_directory |> should.equal("./pages")
  cfg.paths.assets_directory |> should.equal("./priv/static/assets")
}

// ---- Server Config Tests ----

pub fn server_config_port_is_positive_test() {
  let cfg = config.default_config()

  should.be_true(cfg.server.port > 0)
}

pub fn server_config_port_is_valid_range_test() {
  let cfg = config.default_config()

  // Port should be in valid range (1-65535)
  should.be_true(cfg.server.port >= 1 && cfg.server.port <= 65_535)
}

// ---- Cache Config Tests ----

pub fn cache_ttl_is_positive_test() {
  let cfg = config.default_config()

  should.be_true(cfg.cache.ttl_minutes > 0)
}

pub fn cache_watch_interval_is_positive_test() {
  let cfg = config.default_config()

  should.be_true(cfg.cache.watch_interval_seconds > 0)
}

// ---- Paths Config Tests ----

pub fn pages_directory_is_not_empty_test() {
  let cfg = config.default_config()

  string.length(cfg.paths.pages_directory) |> should.not_equal(0)
}

pub fn assets_directory_is_not_empty_test() {
  let cfg = config.default_config()

  string.length(cfg.paths.assets_directory) |> should.not_equal(0)
}
