//// ETS Utilities
////
//// Shared utilities for working with Erlang Term Storage (ETS) tables.
//// Provides common initialization patterns and helper functions.

import gleam/dynamic.{type Dynamic}
import gleam/erlang
import gleam/erlang/atom.{type Atom}

// ---- FFI Bindings ----

@external(erlang, "ets", "new")
fn ets_new_external(name: Atom, options: List(Dynamic)) -> Atom

@external(erlang, "ets", "lookup")
pub fn lookup(table: Atom, key: a) -> List(b)

@external(erlang, "ets", "insert")
pub fn insert(table: Atom, record: a) -> Bool

@external(erlang, "ets", "delete")
pub fn delete(table: Atom, key: a) -> Bool

// ---- Table Options ----

/// Creates ETS table options for a public set table with read concurrency
pub fn public_set_options() -> List(Dynamic) {
  [
    dynamic.from(atom.create_from_string("set")),
    dynamic.from(atom.create_from_string("public")),
    dynamic.from(atom.create_from_string("named_table")),
    dynamic.from(#(atom.create_from_string("read_concurrency"), True)),
  ]
}

/// Creates ETS table options for a public set table with read and write concurrency
pub fn public_set_options_concurrent() -> List(Dynamic) {
  [
    dynamic.from(atom.create_from_string("set")),
    dynamic.from(atom.create_from_string("public")),
    dynamic.from(atom.create_from_string("named_table")),
    dynamic.from(#(atom.create_from_string("read_concurrency"), True)),
    dynamic.from(#(atom.create_from_string("write_concurrency"), True)),
  ]
}

// ---- Table Initialization ----

/// Creates a named ETS table if it doesn't already exist.
/// Uses erlang.rescue to handle the case where the table already exists,
/// making this function idempotent and safe to call multiple times.
///
/// # Parameters
/// - `name`: The atom name for the table
/// - `options`: ETS table options (use `public_set_options()` or `public_set_options_concurrent()`)
///
/// # Returns
/// Nil (table creation is side-effect only)
pub fn create_named_table(name: Atom, options: List(Dynamic)) -> Nil {
  let _ = erlang.rescue(fn() { ets_new_external(name, options) })
  Nil
}

/// Helper to create a table name atom from a string
pub fn table_name(name: String) -> Atom {
  atom.create_from_string(name)
}

/// Helper to create an atom from a string
pub fn atom(name: String) -> Atom {
  atom.create_from_string(name)
}
