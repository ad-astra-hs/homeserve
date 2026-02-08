//// General Utilities
////
//// Small, general-purpose utility functions that don't belong in a specific domain.

import gleam/erlang

/// Returns the current Unix timestamp in milliseconds.
pub fn current_time_ms() -> Int {
  erlang.system_time(erlang.Millisecond)
}

/// Returns the current Unix timestamp in seconds.
pub fn current_time_seconds() -> Int {
  erlang.system_time(erlang.Second)
}
