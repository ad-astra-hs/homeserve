//// Pagination Tests
////
//// Tests for the shared pagination utilities.

import gleeunit/should

import homeserve/pagination

// ---- parse_page_param ----

pub fn parse_page_param_valid_test() {
  pagination.parse_page_param([#("page", "3")])
  |> should.equal(3)
}

pub fn parse_page_param_first_page_test() {
  pagination.parse_page_param([#("page", "1")])
  |> should.equal(1)
}

pub fn parse_page_param_missing_key_test() {
  pagination.parse_page_param([])
  |> should.equal(1)
}

pub fn parse_page_param_zero_defaults_to_one_test() {
  pagination.parse_page_param([#("page", "0")])
  |> should.equal(1)
}

pub fn parse_page_param_negative_defaults_to_one_test() {
  pagination.parse_page_param([#("page", "-5")])
  |> should.equal(1)
}

pub fn parse_page_param_non_numeric_defaults_to_one_test() {
  pagination.parse_page_param([#("page", "abc")])
  |> should.equal(1)
}

pub fn parse_page_param_large_page_test() {
  pagination.parse_page_param([#("page", "9999")])
  |> should.equal(9999)
}

pub fn parse_page_param_ignores_other_keys_test() {
  pagination.parse_page_param([#("foo", "5"), #("page", "7")])
  |> should.equal(7)
}

// ---- calculate_total_pages ----

pub fn calculate_total_pages_zero_items_test() {
  // Zero items should still return at least 1 page
  pagination.calculate_total_pages(0, 10)
  |> should.equal(1)
}

pub fn calculate_total_pages_one_item_test() {
  pagination.calculate_total_pages(1, 10)
  |> should.equal(1)
}

pub fn calculate_total_pages_exact_multiple_test() {
  pagination.calculate_total_pages(20, 10)
  |> should.equal(2)
}

pub fn calculate_total_pages_partial_last_page_test() {
  pagination.calculate_total_pages(21, 10)
  |> should.equal(3)
}

pub fn calculate_total_pages_per_page_one_test() {
  pagination.calculate_total_pages(5, 1)
  |> should.equal(5)
}

pub fn calculate_total_pages_large_count_test() {
  pagination.calculate_total_pages(100, 10)
  |> should.equal(10)
}

pub fn calculate_total_pages_less_than_per_page_test() {
  pagination.calculate_total_pages(3, 10)
  |> should.equal(1)
}

// ---- get_page ----

pub fn get_page_first_page_test() {
  let items = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
  pagination.get_page(items, 1, 5)
  |> should.equal([1, 2, 3, 4, 5])
}

pub fn get_page_second_page_test() {
  let items = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
  pagination.get_page(items, 2, 5)
  |> should.equal([6, 7, 8, 9, 10])
}

pub fn get_page_last_partial_page_test() {
  let items = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
  pagination.get_page(items, 3, 5)
  |> should.equal([11])
}

pub fn get_page_beyond_end_test() {
  let items = [1, 2, 3]
  pagination.get_page(items, 5, 10)
  |> should.equal([])
}

pub fn get_page_empty_list_test() {
  pagination.get_page([], 1, 10)
  |> should.equal([])
}

pub fn get_page_per_page_one_test() {
  let items = ["a", "b", "c"]
  pagination.get_page(items, 2, 1)
  |> should.equal(["b"])
}

// ---- clamp_page ----

pub fn clamp_page_within_range_test() {
  pagination.clamp_page(3, 5)
  |> should.equal(3)
}

pub fn clamp_page_below_one_test() {
  pagination.clamp_page(0, 5)
  |> should.equal(1)
}

pub fn clamp_page_above_max_test() {
  pagination.clamp_page(10, 5)
  |> should.equal(5)
}

pub fn clamp_page_exactly_one_test() {
  pagination.clamp_page(1, 1)
  |> should.equal(1)
}

pub fn clamp_page_exactly_max_test() {
  pagination.clamp_page(5, 5)
  |> should.equal(5)
}

pub fn clamp_page_total_one_any_page_test() {
  // When there's only 1 page, any input clamps to 1
  pagination.clamp_page(99, 1)
  |> should.equal(1)
}
