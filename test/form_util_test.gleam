import gleeunit/should

import homeserve/pages/admin/util

// ---- Parse List Tests ----

pub fn parse_list_single_item_test() {
  util.parse_list("artist1")
  |> should.equal(["artist1"])
}

pub fn parse_list_multiple_items_test() {
  util.parse_list("artist1, artist2, artist3")
  |> should.equal(["artist1", "artist2", "artist3"])
}

pub fn parse_list_empty_string_test() {
  util.parse_list("")
  |> should.equal([])
}

pub fn parse_list_whitespace_test() {
  util.parse_list("  artist1  ,  artist2  ")
  |> should.equal(["artist1", "artist2"])
}

pub fn parse_list_empty_items_filtered_test() {
  util.parse_list("artist1,, , artist2")
  |> should.equal(["artist1", "artist2"])
}

// ---- Timestamp Tests ----

pub fn current_timestamp_returns_positive_test() {
  let ts = util.current_timestamp()
  should.be_true(ts > 0)
}

pub fn current_timestamp_is_reasonable_test() {
  let ts = util.current_timestamp()
  // Should be after year 2020 (approx 1609459200)
  // and before year 2100 (approx 4102444800)
  should.be_true(ts > 1_600_000_000)
  should.be_true(ts < 5_000_000_000)
}
