//// Admin Login Rate Limiter
////
//// ETS-backed brute-force protection for the admin authentication endpoint.
//// Tracks failed login attempts per IP address; blocks after 5 failures within
//// a 5-minute sliding window. Resets automatically on successful login.

import gleam/dynamic.{type Dynamic}
import gleam/erlang
import gleam/erlang/atom.{type Atom}

// ---- Constants ----

/// 5-minute window in microseconds
const window_us = 300_000_000

/// Maximum failed attempts per window
const max_attempts = 5

// ---- ETS Bindings ----

@external(erlang, "ets", "new")
fn ets_new(name: Atom, options: List(Dynamic)) -> Atom

@external(erlang, "ets", "lookup")
fn ets_lookup_rate(table: Atom, key: String) -> List(#(String, Int, Int))

@external(erlang, "ets", "insert")
fn ets_insert_rate(table: Atom, record: #(String, Int, Int)) -> Bool

@external(erlang, "ets", "delete")
fn ets_delete_key(table: Atom, key: String) -> Bool

@external(erlang, "erlang", "system_time")
fn system_time(unit: Atom) -> Int

// ---- Table Management ----

fn rate_table() -> Atom {
  atom.create_from_string("homeserve_rate_limit")
}

/// Initialise the ETS table. Call once at application startup.
pub fn init() -> Nil {
  let _ =
    erlang.rescue(fn() {
      ets_new(rate_table(), [
        dynamic.from(atom.create_from_string("set")),
        dynamic.from(atom.create_from_string("public")),
        dynamic.from(atom.create_from_string("named_table")),
        dynamic.from(#(atom.create_from_string("read_concurrency"), True)),
        dynamic.from(#(atom.create_from_string("write_concurrency"), True)),
      ])
    })
  Nil
}

fn now_us() -> Int {
  system_time(atom.create_from_string("microsecond"))
}

// ---- Public API ----

/// Result of a rate-limit check.
pub type RateLimitResult {
  /// The request is within limits and may proceed.
  Allowed
  /// Too many failures — the caller should return HTTP 429.
  RateLimited
}

/// Check whether the given IP address is currently rate-limited.
pub fn check(ip: String) -> RateLimitResult {
  init()
  let now = now_us()
  case ets_lookup_rate(rate_table(), ip) {
    [] -> Allowed
    [#(_, count, window_start), ..] ->
      case now - window_start > window_us {
        True -> {
          // Window has expired — stale entry, treat as allowed
          ets_delete_key(rate_table(), ip)
          Allowed
        }
        False ->
          case count >= max_attempts {
            True -> RateLimited
            False -> Allowed
          }
      }
  }
}

/// Record a failed authentication attempt for an IP.
/// Call this whenever a login attempt is rejected.
pub fn record_failure(ip: String) -> Nil {
  init()
  let now = now_us()
  case ets_lookup_rate(rate_table(), ip) {
    [] -> {
      ets_insert_rate(rate_table(), #(ip, 1, now))
      Nil
    }
    [#(_, count, window_start), ..] ->
      case now - window_start > window_us {
        True -> {
          // Old window expired — start fresh
          ets_insert_rate(rate_table(), #(ip, 1, now))
          Nil
        }
        False -> {
          ets_insert_rate(rate_table(), #(ip, count + 1, window_start))
          Nil
        }
      }
  }
}

/// Reset the failure counter for an IP.
/// Call this when a login attempt succeeds.
pub fn reset(ip: String) -> Nil {
  init()
  ets_delete_key(rate_table(), ip)
  Nil
}
