//// Pagination Utilities
////
//// Shared pagination functions and components for listing pages across the application.

import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}

import lustre/attribute
import lustre/element
import lustre/element/html

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

/// Renders pagination controls with customizable URL generation
///
/// # Parameters
/// - `current_page`: The current page number (1-indexed)
/// - `total_pages`: Total number of pages
/// - `prev_url`: Function that generates the URL for the previous page
/// - `next_url`: Function that generates the URL for the next page  
/// - `total_items`: Optional total item count to display (e.g., "Page 1 of 5 (42 panels)")
///
/// # Returns
/// Lustre element with pagination controls, or empty element if only 1 page
pub fn render_pagination(
  current_page: Int,
  total_pages: Int,
  prev_url: fn(Int) -> String,
  next_url: fn(Int) -> String,
  total_items: Option(Int),
) {
  case total_pages <= 1 {
    True -> element.none()
    False -> {
      let prev_button = case current_page > 1 {
        True ->
          html.a(
            [
              attribute.href(prev_url(current_page - 1)),
              attribute.class("btn btn-secondary"),
            ],
            [html.text("← Previous")],
          )
        False ->
          html.span([attribute.class("btn btn-disabled")], [
            html.text("← Previous"),
          ])
      }

      let next_button = case current_page < total_pages {
        True ->
          html.a(
            [
              attribute.href(next_url(current_page + 1)),
              attribute.class("btn btn-secondary"),
            ],
            [html.text("Next →")],
          )
        False ->
          html.span([attribute.class("btn btn-disabled")], [
            html.text("Next →"),
          ])
      }

      let page_info_text = case total_items {
        Some(items) ->
          "Page "
          <> int.to_string(current_page)
          <> " of "
          <> int.to_string(total_pages)
          <> " ("
          <> int.to_string(items)
          <> " panels)"
        None ->
          "Page "
          <> int.to_string(current_page)
          <> " of "
          <> int.to_string(total_pages)
      }

      let page_info =
        html.span([attribute.class("pagination-info")], [
          html.text(page_info_text),
        ])

      html.div([attribute.class("pagination-controls")], [
        prev_button,
        page_info,
        next_button,
      ])
    }
  }
}
