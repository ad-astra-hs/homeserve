import gleam/option.{None}
import gleam/string
import gleeunit/should

import homeserve/config
import homeserve/db
import homeserve/pages/panel/loader
import homeserve/pages/panel/types.{DatabaseError, FileNotFound}

// ---- Panel Loading Tests ----
//
// NOTE: These tests require Mnesia to be initialized.
// Mnesia will be initialized automatically when running tests.

pub fn load_panel_not_found_test() {
  // This test should return FileNotFound when Mnesia is running,
  // or DatabaseError when Mnesia is not available
  let result = loader.load_panel(999_999)

  result |> should.be_error

  // Explicit pattern match instead of let assert for better error handling
  case result {
    // Panel doesn't exist (Mnesia is running)
    Error(FileNotFound(_)) -> should.be_true(True)
    // Mnesia is not running - also acceptable for this test
    Error(DatabaseError(_)) -> should.be_true(True)
    // Any other result is unexpected
    _ -> should.fail()
  }
}

pub fn load_panel_meta_not_found_test() {
  let result = db.load_panel(999_999)
  result |> should.be_error
}

// ---- Regression test: integer-key lookup must return FileNotFound, not crash ----
//
// Before the Erlang FFI fix, `db.load_panel(int)` for a missing panel
// would crash with `badarg` inside `parse_error_to_string/1` because
// `mnesia_db_ffi.erl` returned "not_found" as an Erlang charlist (list of
// integers) instead of a binary.  The Gleam `<>` operator (binary_part)
// then threw badarg when it hit the charlist.
//
// This test walks the full path and calls `parse_error_to_string` on the
// result to confirm the string is a valid Gleam binary.

pub fn load_panel_nonexistent_int_is_file_not_found_test() {
  let _ = db.initialize(config.MnesiaConfig(data_dir: None))

  case db.load_panel(88_888) {
    Error(FileNotFound(msg)) -> {
      // parse_error_to_string does `<>` binary concatenation.
      // This would have crashed with badarg if msg were a charlist.
      let str = types.parse_error_to_string(FileNotFound(msg))
      should.be_true(string.contains(str, "88888"))
    }
    Error(other) -> {
      // Wrong error variant — regression has occurred.
      // Call parse_error_to_string anyway; a badarg panic here means
      // the charlist bug has resurfaced.
      let _ = types.parse_error_to_string(other)
      should.fail()
    }
    Ok(_) -> should.fail()
  }
}

// ---- Type Structure Tests (don't require Mnesia) ----

// Exhaustively verify that parse_error_to_string works for every variant.
// DatabaseError in particular was the crashing variant (charlist vs binary).
pub fn parse_error_to_string_all_variants_test() {
  types.parse_error_to_string(FileNotFound("panel:1"))
  |> should.equal("Panel not found: panel:1")

  types.parse_error_to_string(DatabaseError("oops"))
  |> should.equal("Database error: oops")

  types.parse_error_to_string(types.InvalidFrontmatter("bad json"))
  |> should.equal("Invalid metadata: bad json")

  types.parse_error_to_string(types.MissingField("title"))
  |> should.equal("Missing required field: title")

  types.parse_error_to_string(types.InvalidFieldType("date", "Int"))
  |> should.equal("Invalid type for field 'date', expected Int")
}

pub fn parse_error_to_string_works_test() {
  let err = FileNotFound("test_panel")
  let msg = types.parse_error_to_string(err)

  string.contains(msg, "test_panel") |> should.be_true
}
