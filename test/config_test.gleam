import gleam/list
import gleam/option.{None}
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
}

// ---- Config from example homeserve.toml ----

pub fn load_from_example_toml_test() {
  let cfg = config.load_from("./homeserve.example.toml")

  // The example config has these values
  cfg.server.port |> should.equal(8000)
  cfg.server.host |> should.equal("0.0.0.0")
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

// ---- Paths Config Tests ----

pub fn assets_directory_is_not_empty_test() {
  let cfg = config.default_config()

  string.length(cfg.paths.assets_directory) |> should.not_equal(0)
}

// ---- Admin Config Tests ----

pub fn default_admin_token_is_set_test() {
  let cfg = config.default_config()

  string.length(cfg.admin.token) |> should.not_equal(0)
}

pub fn default_admin_token_is_changeme_test() {
  let cfg = config.default_config()

  cfg.admin.token |> should.equal("changeme")
}

// ---- Contact Config Tests ----

pub fn default_contact_email_is_set_test() {
  let cfg = config.default_config()

  string.length(cfg.contact.email) |> should.not_equal(0)
}

pub fn default_contact_email_is_example_test() {
  let cfg = config.default_config()

  cfg.contact.email |> should.equal("admin@example.com")
}

// ---- Logging Config Tests ----

pub fn default_log_level_is_info_test() {
  let cfg = config.default_config()

  cfg.logging.level |> should.equal("info")
}

pub fn load_from_example_toml_has_log_level_test() {
  let cfg = config.load_from("./homeserve.example.toml")

  cfg.logging.level |> should.equal("info")
}

pub fn load_from_example_toml_has_contact_email_test() {
  let cfg = config.load_from("./homeserve.example.toml")

  cfg.contact.email |> should.equal("admin@example.com")
}

// ---- Config Validation Tests ----

pub fn validate_config_default_is_valid_test() {
  let cfg = config.default_config()
  let errors = config.validate_config(cfg)

  // Default config should have no validation errors
  should.equal(errors, [])
}

pub fn validate_config_invalid_port_too_low_test() {
  let cfg =
    config.Config(
      server: config.ServerConfig(port: 0, host: "0.0.0.0"),
      paths: config.PathsConfig(
        assets_directory: "./priv/static/assets",
        extra_directory: "./priv/static/extra",
      ),
      mnesia: config.MnesiaConfig(data_dir: None),
      admin: config.AdminConfig(token: "test"),
      contact: config.ContactConfig(email: "test@example.com"),
      logging: config.LoggingConfig(level: "info"),
    )

  let errors = config.validate_config(cfg)

  // Should have port validation error
  let has_port_error =
    list.any(errors, fn(e) {
      case e {
        config.InvalidPort("server.port", 0, _, _) -> True
        _ -> False
      }
    })
  should.be_true(has_port_error)
}

pub fn validate_config_invalid_port_too_high_test() {
  let cfg =
    config.Config(
      server: config.ServerConfig(port: 100_000, host: "0.0.0.0"),
      paths: config.PathsConfig(
        assets_directory: "./priv/static/assets",
        extra_directory: "./priv/static/extra",
      ),
      mnesia: config.MnesiaConfig(data_dir: None),
      admin: config.AdminConfig(token: "test"),
      contact: config.ContactConfig(email: "test@example.com"),
      logging: config.LoggingConfig(level: "info"),
    )

  let errors = config.validate_config(cfg)

  let has_port_error =
    list.any(errors, fn(e) {
      case e {
        config.InvalidPort("server.port", 100_000, _, _) -> True
        _ -> False
      }
    })
  should.be_true(has_port_error)
}

pub fn validate_config_empty_host_test() {
  let cfg =
    config.Config(
      server: config.ServerConfig(port: 8000, host: ""),
      paths: config.PathsConfig(
        assets_directory: "./priv/static/assets",
        extra_directory: "./priv/static/extra",
      ),
      mnesia: config.MnesiaConfig(data_dir: None),
      admin: config.AdminConfig(token: "test"),
      contact: config.ContactConfig(email: "test@example.com"),
      logging: config.LoggingConfig(level: "info"),
    )

  let errors = config.validate_config(cfg)

  let has_host_error =
    list.any(errors, fn(e) {
      case e {
        config.InvalidNonEmptyString("server.host") -> True
        _ -> False
      }
    })
  should.be_true(has_host_error)
}

pub fn validate_config_empty_admin_token_test() {
  let cfg =
    config.Config(
      server: config.ServerConfig(port: 8000, host: "0.0.0.0"),
      paths: config.PathsConfig(
        assets_directory: "./priv/static/assets",
        extra_directory: "./priv/static/extra",
      ),
      mnesia: config.MnesiaConfig(data_dir: None),
      admin: config.AdminConfig(token: ""),
      contact: config.ContactConfig(email: "test@example.com"),
      logging: config.LoggingConfig(level: "info"),
    )

  let errors = config.validate_config(cfg)

  let has_token_error =
    list.any(errors, fn(e) {
      case e {
        config.InvalidNonEmptyString("admin.token") -> True
        _ -> False
      }
    })
  should.be_true(has_token_error)
}

pub fn validate_config_invalid_email_test() {
  let cfg =
    config.Config(
      server: config.ServerConfig(port: 8000, host: "0.0.0.0"),
      paths: config.PathsConfig(
        assets_directory: "./priv/static/assets",
        extra_directory: "./priv/static/extra",
      ),
      mnesia: config.MnesiaConfig(data_dir: None),
      admin: config.AdminConfig(token: "test"),
      contact: config.ContactConfig(email: "invalid-email"),
      logging: config.LoggingConfig(level: "info"),
    )

  let errors = config.validate_config(cfg)

  let has_email_error =
    list.any(errors, fn(e) {
      case e {
        config.InvalidEmail("contact.email", "invalid-email") -> True
        _ -> False
      }
    })
  should.be_true(has_email_error)
}

pub fn validate_config_valid_email_test() {
  let cfg =
    config.Config(
      server: config.ServerConfig(port: 8000, host: "0.0.0.0"),
      paths: config.PathsConfig(
        assets_directory: "./priv/static/assets",
        extra_directory: "./priv/static/extra",
      ),
      mnesia: config.MnesiaConfig(data_dir: None),
      admin: config.AdminConfig(token: "test"),
      contact: config.ContactConfig(email: "valid@example.com"),
      logging: config.LoggingConfig(level: "info"),
    )

  let errors = config.validate_config(cfg)

  // Should have no email errors
  let has_email_error =
    list.any(errors, fn(e) {
      case e {
        config.InvalidEmail(_, _) -> True
        _ -> False
      }
    })
  should.be_false(has_email_error)
}

// ---- Validation Error String Tests ----

pub fn validation_error_to_string_port_test() {
  let err = config.InvalidPort("server.port", 100_000, 1, 65_535)
  let msg = config.validation_error_to_string(err)

  should.be_true(string.contains(msg, "server.port"))
  should.be_true(string.contains(msg, "100000"))
}

pub fn validation_error_to_string_empty_string_test() {
  let err = config.InvalidNonEmptyString("server.host")
  let msg = config.validation_error_to_string(err)

  should.be_true(string.contains(msg, "server.host"))
  should.be_true(string.contains(msg, "cannot be empty"))
}

pub fn validation_error_to_string_email_test() {
  let err = config.InvalidEmail("contact.email", "bad-email")
  let msg = config.validation_error_to_string(err)

  should.be_true(string.contains(msg, "bad-email"))
  should.be_true(string.contains(msg, "not a valid email"))
}
