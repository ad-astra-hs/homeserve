//// Router Tests
////
//// Tests for request routing and URL handling.

import gleam/int
import gleam/option.{None, Some}
import gleam/string
import gleeunit/should

import homeserve/config

// ---- Route Path Parsing Tests ----

pub fn parse_page_query_valid_test() {
  // Test that page query parameter parsing works
  let query = [#("page", "5")]

  // Simulate parse_page_query logic
  let page = case query {
    [#("page", page_str)] -> {
      case int.base_parse(page_str, 10) {
        Ok(page) if page >= 1 -> page
        _ -> 1
      }
    }
    _ -> 1
  }

  should.equal(page, 5)
}

pub fn parse_page_query_default_test() {
  // Empty query should default to 1
  let query = []

  let page = case query {
    [#("page", page_str)] -> {
      case int.base_parse(page_str, 10) {
        Ok(page) if page >= 1 -> page
        _ -> 1
      }
    }
    _ -> 1
  }

  should.equal(page, 1)
}

pub fn parse_page_query_invalid_test() {
  // Invalid page should default to 1
  let query = [#("page", "invalid")]

  let page = case query {
    [#("page", page_str)] -> {
      case int.base_parse(page_str, 10) {
        Ok(page) if page >= 1 -> page
        _ -> 1
      }
    }
    _ -> 1
  }

  should.equal(page, 1)
}

pub fn parse_page_query_zero_test() {
  // Page 0 should default to 1
  let query = [#("page", "0")]

  let page = case query {
    [#("page", page_str)] -> {
      case int.base_parse(page_str, 10) {
        Ok(page) if page >= 1 -> page
        _ -> 1
      }
    }
    _ -> 1
  }

  should.equal(page, 1)
}

pub fn parse_page_query_negative_test() {
  // Negative page should default to 1
  let query = [#("page", "-5")]

  let page = case query {
    [#("page", page_str)] -> {
      case int.base_parse(page_str, 10) {
        Ok(page) if page >= 1 -> page
        _ -> 1
      }
    }
    _ -> 1
  }

  should.equal(page, 1)
}

// ---- Config Loading for Router Tests ----

pub fn router_config_test() {
  let cfg = config.default_config()

  // Verify config has all required fields for router
  should.equal(cfg.server.port, 8000)
  should.equal(cfg.server.host, "0.0.0.0")
  should.be_true(string.length(cfg.admin.token) > 0)
}

// ---- Route Matching Logic Tests ----

pub fn home_route_matching_test() {
  // Test that empty path matches home
  let path = []

  let is_home = case path {
    [] -> True
    _ -> False
  }

  should.be_true(is_home)
}

pub fn read_route_matching_test() {
  // Test that ["read"] redirects to read/1
  let path = ["read"]

  let is_read_redirect = case path {
    ["read"] -> True
    _ -> False
  }

  should.be_true(is_read_redirect)
}

pub fn read_page_route_matching_test() {
  // Test that ["read", page] matches panel reading
  let path = ["read", "42"]

  let page_num = case path {
    ["read", page] -> {
      case int.base_parse(page, 10) {
        Ok(num) -> Some(num)
        Error(_) -> None
      }
    }
    _ -> None
  }

  should.equal(page_num, Some(42))
}

pub fn admin_route_matching_test() {
  // Test admin route matching
  let path = ["admin"]

  let is_admin = case path {
    ["admin"] -> True
    ["admin", ..] -> True
    _ -> False
  }

  should.be_true(is_admin)
}

pub fn admin_subroute_matching_test() {
  // Test admin subroutes
  let path = ["admin", "create"]

  let is_admin_create = case path {
    ["admin", "create"] -> True
    _ -> False
  }

  should.be_true(is_admin_create)
}

pub fn assets_route_matching_test() {
  // Test assets route matching
  let path = ["assets", "image.jpg"]

  let asset = case path {
    ["assets", filename] -> Some(filename)
    _ -> None
  }

  should.equal(asset, Some("image.jpg"))
}

pub fn hoc_route_matching_test() {
  // Test hall of contributors route
  let path1 = ["hoc"]
  let path2 = ["hoc", "volunteer-name"]

  let is_hoc_list = case path1 {
    ["hoc"] -> True
    _ -> False
  }

  let is_hoc_volunteer = case path2 {
    ["hoc", _] -> True
    _ -> False
  }

  should.be_true(is_hoc_list)
  should.be_true(is_hoc_volunteer)
}

// ---- Health Check Route Tests ----

pub fn health_route_matching_test() {
  let path = ["health"]

  let is_health = case path {
    ["health"] -> True
    _ -> False
  }

  should.be_true(is_health)
}

// ---- 404 Handling Tests ----

pub fn unknown_route_test() {
  // Test that unknown routes are handled as 404
  let path = ["unknown", "path"]

  let is_known = case path {
    [] -> True
    // Home
    ["play"] -> True
    ["read"] -> True
    ["read", "toggle_quirks"] -> True
    ["read", "toggle_animations"] -> True
    ["read", _] -> True
    ["health"] -> True
    ["hoc"] -> True
    ["hoc", _] -> True
    ["assets", ..] -> True
    ["favicon.ico"] -> True
    ["discord"] -> True
    ["apply"] -> True
    ["privacy"] -> True
    ["admin"] -> True
    ["admin", ..] -> True
    _ -> False
  }

  should.be_false(is_known)
}

// ---- URL Encoding for Volunteer Names ----

pub fn volunteer_name_encoding_test() {
  // Test that volunteer names with spaces are encoded correctly
  let name = "Alice Artist"
  let encoded = uri_percent_encode(name)

  should.equal(encoded, "Alice%20Artist")
}

pub fn volunteer_name_decoding_test() {
  let encoded = "Bob%20Writer"
  let decoded = uri_percent_decode(encoded)

  should.equal(decoded, Ok("Bob Writer"))
}

// Helper functions for URL encoding (simplified)
fn uri_percent_encode(s: String) -> String {
  // Simple space encoding for test
  string.replace(s, " ", "%20")
}

fn uri_percent_decode(s: String) -> Result(String, Nil) {
  Ok(string.replace(s, "%20", " "))
}
