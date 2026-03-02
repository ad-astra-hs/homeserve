//// Admin Handler Tests
////
//// Tests for admin page handlers (authentication, CRUD operations).

import gleam/option.{None}
import gleam/string
import gleeunit/should

import homeserve/config
import homeserve/pages/admin/auth

// ---- Test Configuration ----

fn test_config() -> config.Config {
  config.Config(
    server: config.ServerConfig(port: 8000, host: "0.0.0.0"),
    paths: config.PathsConfig(assets_directory: "./priv/static/assets"),
    mnesia: config.MnesiaConfig(data_dir: None),
    admin: config.AdminConfig(token: "test-token-123"),
    contact: config.ContactConfig(email: "test@example.com"),
    logging: config.LoggingConfig(level: "info"),
  )
}

// ---- Token Verification ----

pub fn token_verification_valid_test() {
  let cfg = test_config()
  should.be_true(auth.verify_token("test-token-123", cfg.admin.token))
}

pub fn token_verification_invalid_test() {
  let cfg = test_config()
  should.be_false(auth.verify_token("wrong-token", cfg.admin.token))
}

pub fn token_hashing_test() {
  let hashed = auth.hash_token("my-secret-token")
  // Verify it produces a sha256 hash
  case hashed {
    "sha256:" <> _ -> should.be_true(True)
    _ -> should.fail()
  }
  // Verify the original token can be verified against the hash
  should.be_true(auth.verify_token("my-secret-token", hashed))
}

pub fn token_hashing_different_tokens_test() {
  let hash1 = auth.hash_token("token1")
  let hash2 = auth.hash_token("token2")
  // Should produce different hashes
  should.be_true(hash1 != hash2)
}

pub fn token_verification_plaintext_vs_hash_test() {
  let cfg =
    config.Config(
      server: config.ServerConfig(port: 8000, host: "0.0.0.0"),
      paths: config.PathsConfig(assets_directory: "./priv/static/assets"),
      mnesia: config.MnesiaConfig(data_dir: None),
      admin: config.AdminConfig(token: "simple-plaintext-token"),
      contact: config.ContactConfig(email: "test@example.com"),
      logging: config.LoggingConfig(level: "info"),
    )
  // Should work with plaintext token
  should.be_true(auth.verify_token("simple-plaintext-token", cfg.admin.token))
  should.be_false(auth.verify_token("wrong-token", cfg.admin.token))
}

// ---- CSRF Token Tests ----

pub fn csrf_token_generation_test() {
  let token1 = auth.generate_csrf_token()
  let token2 = auth.generate_csrf_token()
  // Should generate non-empty tokens
  should.be_true(token1 != "")
  should.be_true(token2 != "")
  // Should generate different tokens
  should.be_true(token1 != token2)
}

pub fn csrf_token_length_test() {
  let token = auth.generate_csrf_token()
  // Should be 32 characters (as defined in auth.gleam)
  should.equal(32, string.length(token))
}

// ---- Default Config Token ----

pub fn default_config_token_test() {
  let default_cfg = config.default_config()
  // Default token should be "changeme"
  should.equal("changeme", default_cfg.admin.token)
}
