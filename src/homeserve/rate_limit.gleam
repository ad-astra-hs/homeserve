//// Admin Login Rate Limiter
////
//// ETS-backed brute-force protection for the admin authentication endpoint.
//// Tracks failed login attempts per IP address; blocks after 5 failures within
//// a 5-minute sliding window. Resets automatically on successful login.

import gleam/erlang/atom.{type Atom}

import homeserve/ets

// ---- Constants ----

/// 5-minute window in microseconds
const window_us = 300_000_000

/// Maximum failed attempts per window
const max_attempts = 5

// ---- ETS Table ----

fn rate_table() -> Atom {
  ets.table_name("homeserve_rate_limit")
}

// ---- Table Management ----

/// Initialise the ETS table. Call once at application startup.
pub fn init() -> Nil {
  ets.create_named_table(rate_table(), ets.public_set_options_concurrent())
}

@external(erlang, "erlang", "system_time")
fn system_time(unit: Atom) -> Int

fn now_us() -> Int {
  system_time(ets.atom("microsecond"))
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
  case ets.lookup(rate_table(), ip) {
    [] -> Allowed
    [#(_, count, window_start), ..] ->
      case now - window_start > window_us {
        True -> {
          // Window has expired — stale entry, treat as allowed
          ets.delete(rate_table(), ip)
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
  case ets.lookup(rate_table(), ip) {
    [] -> {
      ets.insert(rate_table(), #(ip, 1, now))
      Nil
    }
    [#(_, count, window_start), ..] ->
      case now - window_start > window_us {
        True -> {
          // Old window expired — start fresh
          ets.insert(rate_table(), #(ip, 1, now))
          Nil
        }
        False -> {
          ets.insert(rate_table(), #(ip, count + 1, window_start))
          Nil
        }
      }
  }
}

/// Reset the failure counter for an IP.
/// Call this when a login attempt succeeds.
pub fn reset(ip: String) -> Nil {
  init()
  ets.delete(rate_table(), ip)
  Nil
}
