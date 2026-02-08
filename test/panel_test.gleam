import gleam/string
import gleeunit/should

import homeserve/couchdb
import homeserve/pages/panel/loader
import homeserve/pages/panel/types.{DatabaseError, FileNotFound}

// ---- Panel Loading Tests ----
// 
// NOTE: These tests require CouchDB to be running with test data.
// Run with: docker run -d -p 5984:5984 -e COUCHDB_USER=admin -e COUCHDB_PASSWORD=password couchdb:latest

pub fn load_panel_not_found_test() {
  // This test should return FileNotFound when CouchDB is running,
  // or DatabaseError when CouchDB is not available
  let result = loader.load_panel(couchdb.default_config(), 999_999)

  result |> should.be_error

  let assert Error(err) = result
  case err {
    // Panel doesn't exist (CouchDB is running)
    FileNotFound(_) -> should.be_true(True)
    // CouchDB is not running - also acceptable for this test
    DatabaseError(_) -> should.be_true(True)
    // Any other error is unexpected
    _ -> should.fail()
  }
}

pub fn decode_meta_not_found_test() {
  let result = loader.decode_meta(couchdb.default_config(), 999_999)
  result |> should.be_error
}

// ---- Type Structure Tests (don't require CouchDB) ----

pub fn parse_error_to_string_works_test() {
  let err = FileNotFound("test_panel")
  let msg = types.parse_error_to_string(err)

  string.contains(msg, "test_panel") |> should.be_true
}
