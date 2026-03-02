//// In-Memory Panel Cache
////
//// Shared ETS-based cache for decoded Panel types and metadata.
//// Cache is cleared on any panel write (create/update/delete).
//// Uses ETS for cross-process sharing.

import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/erlang
import gleam/erlang/atom.{type Atom}
import gleam/list
import gleam/option.{type Option, None, Some}

import homeserve/pages/panel/types.{type Meta, type Panel}

// ---- ETS Table Names ----

fn cache_table() -> Atom {
  atom.create_from_string("homeserve_cache")
}

fn meta_table() -> Atom {
  atom.create_from_string("homeserve_meta_cache")
}

fn panel_cache_key() -> Atom {
  atom.create_from_string("panel_cache")
}

fn meta_list_key() -> Atom {
  atom.create_from_string("meta_list")
}

// ---- ETS Bindings ----

@external(erlang, "ets", "new")
fn ets_new(name: Atom, options: List(Dynamic)) -> Atom

@external(erlang, "ets", "lookup")
fn ets_lookup_cache(table: Atom, key: Atom) -> List(#(Atom, Dict(Int, Panel)))

@external(erlang, "ets", "lookup")
fn ets_lookup_meta(table: Atom, key: Atom) -> List(#(Atom, List(Meta)))

@external(erlang, "ets", "insert")
fn ets_insert_cache(table: Atom, record: #(Atom, Dict(Int, Panel))) -> Bool

@external(erlang, "ets", "insert")
fn ets_insert_meta(table: Atom, record: #(Atom, List(Meta))) -> Bool

@external(erlang, "ets", "delete")
fn ets_delete_key(table: Atom, key: a) -> Bool

// ---- Table Management ----

/// Initialise the ETS tables. Call once at application startup.
pub fn init() -> Nil {
  ensure_table(cache_table())
  ensure_table(meta_table())
}

fn ensure_table(name: Atom) -> Nil {
  // ets:new throws badarg if the named table already exists.
  // Using rescue makes this idempotent and race-condition-safe:
  // concurrent calls are fine — the second one just gets an ignored error.
  let _ =
    erlang.rescue(fn() {
      ets_new(name, [
        dynamic.from(atom.create_from_string("set")),
        dynamic.from(atom.create_from_string("public")),
        dynamic.from(atom.create_from_string("named_table")),
        dynamic.from(#(atom.create_from_string("read_concurrency"), True)),
        dynamic.from(#(atom.create_from_string("write_concurrency"), True)),
      ])
    })
  Nil
}

// ---- Panel Cache ----

/// Get a panel from the cache.
pub fn get(index: Int) -> Option(Panel) {
  init()
  case get_panel_cache_dict() {
    None -> None
    Some(cache) -> dict.get(cache, index) |> option.from_result
  }
}

/// Store a panel in the cache.
pub fn put(index: Int, panel: Panel) -> Nil {
  init()
  let cache = case get_panel_cache_dict() {
    None -> dict.new()
    Some(existing) -> existing
  }
  let new_cache = dict.insert(cache, index, panel)
  set_panel_cache_dict(new_cache)
}

fn get_panel_cache_dict() -> Option(Dict(Int, Panel)) {
  case ets_lookup_cache(cache_table(), panel_cache_key()) {
    [#(_, cache)] ->
      case dict.size(cache) {
        0 -> None
        _ -> Some(cache)
      }
    _ -> None
  }
}

fn set_panel_cache_dict(cache: Dict(Int, Panel)) -> Nil {
  ets_insert_cache(cache_table(), #(panel_cache_key(), cache))
  Nil
}

// ---- Meta List Cache ----

/// Get cached metadata list.
pub fn get_meta_list() -> Option(List(Meta)) {
  init()
  case ets_lookup_meta(meta_table(), meta_list_key()) {
    [#(_, [])] -> None
    [#(_, metas)] -> Some(metas)
    _ -> None
  }
}

/// Store metadata list in cache.
pub fn put_meta_list(metas: List(Meta)) -> Nil {
  init()
  ets_insert_meta(meta_table(), #(meta_list_key(), metas))
  Nil
}

// ---- Cache Management ----

/// Clear the entire cache (call after any panel write).
pub fn clear() -> Nil {
  init()
  ets_delete_key(cache_table(), panel_cache_key())
  ets_delete_key(meta_table(), meta_list_key())
  Nil
}

/// Pre-populate cache with panels (used for warmup).
pub fn warmup_panels(panels: List(Panel)) -> Nil {
  init()
  let cache =
    panels
    |> list.fold(dict.new(), fn(acc, panel) {
      dict.insert(acc, panel.meta.index, panel)
    })
  set_panel_cache_dict(cache)
}

/// Pre-populate metadata cache (used for warmup).
pub fn warmup_meta_list(metas: List(Meta)) -> Nil {
  put_meta_list(metas)
}
