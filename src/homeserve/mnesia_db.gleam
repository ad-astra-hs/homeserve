//// Mnesia Database Client
////
//// A lightweight Mnesia client for storing panels and volunteers.
//// Uses Erlang/BEAM's built-in distributed database.

import gleam/dynamic.{type Dynamic}
import gleam/erlang/atom.{type Atom}
import gleam/int
import gleam/option.{type Option, None}

import homeserve/config.{type MnesiaConfig}

/// Errors that can occur during Mnesia operations
pub type MnesiaError {
  ConnectionError(String)
  NotFound(String)
  Conflict(String)
  InvalidResponse(String)
  DatabaseError(String)
}

/// Converts an error to a human-readable string
pub fn error_to_string(err: MnesiaError) -> String {
  case err {
    ConnectionError(msg) -> "Connection: " <> msg
    NotFound(msg) -> "Not found: " <> msg
    Conflict(msg) -> "Conflict: " <> msg
    InvalidResponse(msg) -> "Invalid response: " <> msg
    DatabaseError(msg) -> "Database: " <> msg
  }
}

/// Creates a NotFound error
pub fn not_found_error(key: String) -> MnesiaError {
  NotFound("Document not found: " <> key)
}

/// Format connection info for logging
pub fn format_connection_string(_cfg: MnesiaConfig) -> String {
  "mnesia://local"
}

/// Default Mnesia configuration (uses Erlang's default Mnesia dir)
pub fn default_config() -> MnesiaConfig {
  config.MnesiaConfig(data_dir: None)
}

// ---- FFI Functions ----

/// Initialize Mnesia and create tables
@external(erlang, "mnesia_db_ffi", "initialize")
fn ffi_initialize(data_dir: Option(String)) -> Result(Nil, String)

/// Get a document by key from a table
/// Returns {ok, {some, Value}} | {ok, none} | {error, Msg}
@external(erlang, "mnesia_db_ffi", "get_doc")
fn ffi_get_doc(table: Atom, key: Dynamic) -> Result(Dynamic, String)

/// Put a document into a table
@external(erlang, "mnesia_db_ffi", "put_doc")
fn ffi_put_doc(table: Atom, key: Dynamic, value: Dynamic) -> Result(Nil, String)

/// Delete a document from a table
@external(erlang, "mnesia_db_ffi", "delete_doc")
fn ffi_delete_doc(table: Atom, key: Dynamic) -> Result(Nil, String)

/// Get all documents from a table
@external(erlang, "mnesia_db_ffi", "get_all_docs")
fn ffi_get_all_docs(table: Atom) -> Result(List(Dynamic), String)

/// Get table info (for health checks)
@external(erlang, "mnesia_db_ffi", "table_info")
fn ffi_table_info(table: Atom) -> Result(Int, String)

// ---- Public API ----

/// Ensure Mnesia is initialized and tables exist
pub fn ensure_database(config: MnesiaConfig) -> Result(Nil, MnesiaError) {
  case ffi_initialize(config.data_dir) {
    Ok(_) -> Ok(Nil)
    Error(msg) -> Error(ConnectionError(msg))
  }
}

/// Get a document by ID from a table
pub fn get_doc(table: String, key: String) -> Result(Dynamic, MnesiaError) {
  let table_atom = atom.create_from_string(table)
  let key_dynamic = dynamic.from(key)

  case ffi_get_doc(table_atom, key_dynamic) {
    Ok(value) -> Ok(value)
    Error(msg) -> {
      case msg {
        "not_found" -> Error(NotFound("Document not found: " <> key))
        _ -> Error(DatabaseError(msg))
      }
    }
  }
}

/// Get a document by integer key from a table
pub fn get_doc_by_int(table: String, key: Int) -> Result(Dynamic, MnesiaError) {
  let table_atom = atom.create_from_string(table)
  let key_dynamic = dynamic.from(key)

  case ffi_get_doc(table_atom, key_dynamic) {
    Ok(value) -> Ok(value)
    Error(msg) -> {
      case msg {
        "not_found" ->
          Error(NotFound("Document not found: " <> int.to_string(key)))
        _ -> Error(DatabaseError(msg))
      }
    }
  }
}

/// Save a document to a table
pub fn put_doc(
  table: String,
  key: String,
  value: Dynamic,
) -> Result(Nil, MnesiaError) {
  let table_atom = atom.create_from_string(table)

  case ffi_put_doc(table_atom, dynamic.from(key), value) {
    Ok(_) -> Ok(Nil)
    Error(msg) -> Error(DatabaseError(msg))
  }
}

/// Save a document with integer key
pub fn put_doc_by_int(
  table: String,
  key: Int,
  value: Dynamic,
) -> Result(Nil, MnesiaError) {
  let table_atom = atom.create_from_string(table)

  case ffi_put_doc(table_atom, dynamic.from(key), value) {
    Ok(_) -> Ok(Nil)
    Error(msg) -> Error(DatabaseError(msg))
  }
}

/// Delete a document from a table
pub fn delete_doc(table: String, key: String) -> Result(Nil, MnesiaError) {
  let table_atom = atom.create_from_string(table)

  case ffi_delete_doc(table_atom, dynamic.from(key)) {
    Ok(_) -> Ok(Nil)
    Error(msg) -> Error(DatabaseError(msg))
  }
}

/// Delete a document by integer key
pub fn delete_doc_by_int(table: String, key: Int) -> Result(Nil, MnesiaError) {
  let table_atom = atom.create_from_string(table)

  case ffi_delete_doc(table_atom, dynamic.from(key)) {
    Ok(_) -> Ok(Nil)
    Error(msg) -> Error(DatabaseError(msg))
  }
}

/// Get all documents from a table
pub fn get_all_docs(table: String) -> Result(List(Dynamic), MnesiaError) {
  let table_atom = atom.create_from_string(table)

  case ffi_get_all_docs(table_atom) {
    Ok(docs) -> Ok(docs)
    Error(msg) -> Error(DatabaseError(msg))
  }
}

/// Get table size (for health checks)
pub fn get_table_size(table: String) -> Result(Int, MnesiaError) {
  let table_atom = atom.create_from_string(table)

  case ffi_table_info(table_atom) {
    Ok(size) -> Ok(size)
    Error(msg) -> Error(DatabaseError(msg))
  }
}

/// Clears all data from a table
@external(erlang, "mnesia_db_ffi", "clear_table")
fn ffi_clear_table(table: Atom) -> Result(Nil, String)

/// Clears all data from a table
pub fn clear_table(table: String) -> Result(Nil, MnesiaError) {
  let table_atom = atom.create_from_string(table)

  case ffi_clear_table(table_atom) {
    Ok(_) -> Ok(Nil)
    Error(msg) -> Error(DatabaseError(msg))
  }
}

/// Table names as constants
pub const panel_table = "panel"

pub const volunteer_table = "volunteer"
