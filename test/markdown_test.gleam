import gleam/string
import gleeunit/should
import mork

// ---- Markdown Parsing Tests ----
//
// These tests verify the mork markdown library works correctly.

pub fn bold_text_test() {
  let html = "**Bold text**" |> mork.parse |> mork.to_html

  string.contains(html, "<strong>Bold text</strong>") |> should.be_true
}

pub fn italic_text_test() {
  let html = "*Italic text*" |> mork.parse |> mork.to_html

  string.contains(html, "<em>Italic text</em>") |> should.be_true
}

pub fn paragraph_wrapping_test() {
  let html = "Some text" |> mork.parse |> mork.to_html

  string.contains(html, "<p>") |> should.be_true
}

pub fn heading_test() {
  let html = "# Heading 1" |> mork.parse |> mork.to_html

  string.contains(html, "<h1>") |> should.be_true
}

pub fn link_test() {
  let html = "[Link text](https://example.com)" |> mork.parse |> mork.to_html

  string.contains(html, "<a href=\"https://example.com\">Link text</a>")
  |> should.be_true
}

pub fn code_inline_test() {
  let html = "`inline code`" |> mork.parse |> mork.to_html

  string.contains(html, "<code>inline code</code>") |> should.be_true
}

pub fn multiple_paragraphs_test() {
  let md = "First paragraph.\n\nSecond paragraph."
  let html = md |> mork.parse |> mork.to_html

  // Should have at least two <p> tags
  let p_count = count_substring_occurrences(html, "<p>")
  should.be_true(p_count >= 2)
}

// Helper function
fn count_substring_occurrences(haystack: String, needle: String) -> Int {
  case string.split(haystack, needle) {
    [] -> 0
    parts -> list_length(parts) - 1
  }
}

fn list_length(list: List(a)) -> Int {
  case list {
    [] -> 0
    [_, ..rest] -> 1 + list_length(rest)
  }
}
