//// Rate Limiter Tests
////
//// Tests for the ETS-backed brute-force protection on admin login.
////
//// Each test uses a unique IP suffix to avoid cross-contamination between
//// tests sharing the same ETS table.

import gleeunit/should

import homeserve/rate_limit

// ---- Basic allow/block behaviour ----

pub fn rate_limit_allows_fresh_ip_test() {
  // A brand-new IP with no recorded failures should be allowed
  rate_limit.check("10.0.0.fresh1")
  |> should.equal(rate_limit.Allowed)
}

pub fn rate_limit_allows_after_reset_test() {
  let ip = "10.0.0.reset1"
  // Record failures up to the limit
  rate_limit.record_failure(ip)
  rate_limit.record_failure(ip)
  rate_limit.record_failure(ip)
  rate_limit.record_failure(ip)
  rate_limit.record_failure(ip)

  // Should be rate limited now
  rate_limit.check(ip) |> should.equal(rate_limit.RateLimited)

  // Reset and check again
  rate_limit.reset(ip)
  rate_limit.check(ip) |> should.equal(rate_limit.Allowed)
}

// ---- Counting failures ----

pub fn rate_limit_allows_below_threshold_test() {
  let ip = "10.0.0.below1"
  // 4 failures — one below the limit of 5
  rate_limit.record_failure(ip)
  rate_limit.record_failure(ip)
  rate_limit.record_failure(ip)
  rate_limit.record_failure(ip)

  rate_limit.check(ip) |> should.equal(rate_limit.Allowed)

  // Cleanup
  rate_limit.reset(ip)
}

pub fn rate_limit_blocks_at_threshold_test() {
  let ip = "10.0.0.block1"
  // Exactly 5 failures should trigger the block
  rate_limit.record_failure(ip)
  rate_limit.record_failure(ip)
  rate_limit.record_failure(ip)
  rate_limit.record_failure(ip)
  rate_limit.record_failure(ip)

  rate_limit.check(ip) |> should.equal(rate_limit.RateLimited)

  // Cleanup
  rate_limit.reset(ip)
}

pub fn rate_limit_blocks_above_threshold_test() {
  let ip = "10.0.0.above1"
  // More than 5 failures — still rate limited
  rate_limit.record_failure(ip)
  rate_limit.record_failure(ip)
  rate_limit.record_failure(ip)
  rate_limit.record_failure(ip)
  rate_limit.record_failure(ip)
  rate_limit.record_failure(ip)

  rate_limit.check(ip) |> should.equal(rate_limit.RateLimited)

  // Cleanup
  rate_limit.reset(ip)
}

// ---- IP isolation ----

pub fn rate_limit_ips_are_independent_test() {
  let ip_a = "10.0.0.isola"
  let ip_b = "10.0.0.isolb"

  // Block ip_a
  rate_limit.record_failure(ip_a)
  rate_limit.record_failure(ip_a)
  rate_limit.record_failure(ip_a)
  rate_limit.record_failure(ip_a)
  rate_limit.record_failure(ip_a)

  // ip_b should be unaffected
  rate_limit.check(ip_a) |> should.equal(rate_limit.RateLimited)
  rate_limit.check(ip_b) |> should.equal(rate_limit.Allowed)

  // Cleanup
  rate_limit.reset(ip_a)
}

// ---- Reset idempotency ----

pub fn rate_limit_reset_on_clean_ip_is_safe_test() {
  // Resetting an IP with no recorded failures should not crash
  rate_limit.reset("10.0.0.clean1")
  rate_limit.check("10.0.0.clean1") |> should.equal(rate_limit.Allowed)
}

pub fn rate_limit_double_reset_is_safe_test() {
  let ip = "10.0.0.dbl1"
  rate_limit.record_failure(ip)
  rate_limit.reset(ip)
  rate_limit.reset(ip)
  // Should still be allowed after double-reset
  rate_limit.check(ip) |> should.equal(rate_limit.Allowed)
}
