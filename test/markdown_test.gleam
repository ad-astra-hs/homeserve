import gleam/string
import gleeunit/should
import mork

import homeserve/pages/panel

// ---- Basic Markdown Parsing Tests ----

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

// ---- Panel Content Markdown Tests ----

pub fn panel_content_renders_bold_test() {
  let assert Ok(p) = panel.load_panel(1)

  // Content has **> Enter Name.** which should render as <strong>
  let html = p.content |> mork.parse |> mork.to_html

  string.contains(html, "<strong>") |> should.be_true
}

pub fn panel_content_renders_paragraphs_test() {
  let assert Ok(p) = panel.load_panel(1)

  let html = p.content |> mork.parse |> mork.to_html

  string.contains(html, "<p>") |> should.be_true
}

pub fn panel_content_preserves_text_test() {
  let assert Ok(p) = panel.load_panel(1)

  let html = p.content |> mork.parse |> mork.to_html

  // The content should still contain the original text
  string.contains(html, "young troll") |> should.be_true
}

// ---- Multiple Paragraph Tests ----

pub fn multiple_paragraphs_test() {
  let md = "First paragraph.\n\nSecond paragraph."
  let html = md |> mork.parse |> mork.to_html

  // Should have two <p> tags
  let p_count =
    html
    |> string.split("<p>")
    |> fn(parts) {
      case parts {
        [] -> 0
        [_, ..rest] -> rest |> length
      }
    }

  p_count |> should.equal(2)
}

fn length(list: List(a)) -> Int {
  case list {
    [] -> 0
    [_, ..rest] -> 1 + length(rest)
  }
}
