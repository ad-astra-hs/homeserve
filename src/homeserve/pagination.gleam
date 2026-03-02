//// Pagination Utilities
////
//// Shared pagination functions for listing pages across the application.

import gleam/int
import gleam/list

/// Default number of items per page
pub const default_items_per_page = 10

/// Parse page number from query parameters, defaulting to 1
pub fn parse_page_param(query_params: List(#(String, String))) -> Int {
  case list.key_find(query_params, "page") {
    Ok(page_str) -> {
      case int.base_parse(page_str, 10) {
        Ok(page) if page >= 1 -> page
        _ -> 1
      }
    }
    Error(_) -> 1
  }
}

/// Calculate total pages based on total items and items per page
pub fn calculate_total_pages(total_items: Int, per_page: Int) -> Int {
  case total_items {
    0 -> 1
    _ -> {
      let pages = { total_items + per_page - 1 } / per_page
      int.max(1, pages)
    }
  }
}

/// Get a specific page of items from a list
pub fn get_page(items: List(a), page: Int, per_page: Int) -> List(a) {
  let start_index = { page - 1 } * per_page
  items
  |> list.drop(start_index)
  |> list.take(per_page)
}

/// Calculate current page number clamped to valid range
pub fn clamp_page(page: Int, total_pages: Int) -> Int {
  int.clamp(page, 1, int.max(1, total_pages))
}
