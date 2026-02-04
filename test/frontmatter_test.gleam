import gleam/string
import gleeunit/should

import homeserve/pages/panel/types

// ---- Error Type Tests ----
//
// These tests verify the error handling types work correctly.
// Frontmatter parsing tests removed - the markdown format is no longer used.

pub fn file_not_found_error_test() {
  let err = types.FileNotFound("panel_123")
  let msg = types.parse_error_to_string(err)

  should.be_true(string.contains(msg, "panel_123"))
}

pub fn invalid_frontmatter_error_test() {
  let err = types.InvalidFrontmatter("missing title")
  let msg = types.parse_error_to_string(err)

  should.be_true(string.contains(msg, "missing title"))
}

pub fn missing_field_error_test() {
  let err = types.MissingField("title")
  let msg = types.parse_error_to_string(err)

  should.be_true(string.contains(msg, "title"))
}

pub fn invalid_field_type_error_test() {
  let err = types.InvalidFieldType("date", "int")
  let msg = types.parse_error_to_string(err)

  should.be_true(string.contains(msg, "date"))
  should.be_true(string.contains(msg, "int"))
}
