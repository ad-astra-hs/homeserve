import gleam/option
import gleam/string
import gleeunit/should

import homeserve/pages/panel
import homeserve/pages/panel/types.{FileNotFound, Image}

// ---- Valid Frontmatter Tests ----

pub fn frontmatter_parses_title_test() {
  let assert Ok(p) = panel.load_panel(1)

  p.meta.title |> should.equal("Enter Name")
}

pub fn frontmatter_parses_date_test() {
  let assert Ok(p) = panel.load_panel(1)

  p.meta.date |> should.equal(1_704_067_200)
}

pub fn frontmatter_parses_draft_false_test() {
  let assert Ok(p) = panel.load_panel(1)

  p.meta.draft |> should.equal(False)
}

pub fn frontmatter_parses_media_kind_test() {
  let assert Ok(p) = panel.load_panel(1)

  p.meta.media.kind |> should.equal(Image)
}

pub fn frontmatter_parses_media_url_test() {
  let assert Ok(p) = panel.load_panel(1)

  p.meta.media.url |> should.equal("/assets/panel1.png")
}

pub fn frontmatter_parses_media_alt_test() {
  let assert Ok(p) = panel.load_panel(1)

  p.meta.media.alt
  |> should.equal(option.Some(
    "A mysterious figure stands before a glowing terminal",
  ))
}

pub fn frontmatter_parses_media_track_null_test() {
  let assert Ok(p) = panel.load_panel(1)

  p.meta.media.track |> should.equal(option.None)
}

pub fn frontmatter_parses_artists_list_test() {
  let assert Ok(p) = panel.load_panel(1)

  p.meta.credits.artists |> should.equal(["Alice Artist"])
}

pub fn frontmatter_parses_writers_list_test() {
  let assert Ok(p) = panel.load_panel(2)

  p.meta.credits.writers |> should.equal(["Bob Writer", "Charlie Editor"])
}

pub fn frontmatter_parses_empty_musicians_test() {
  let assert Ok(p) = panel.load_panel(1)

  p.meta.credits.musicians |> should.equal([])
}

pub fn frontmatter_parses_misc_list_test() {
  let assert Ok(p) = panel.load_panel(2)

  p.meta.credits.misc |> should.equal(["Dave Helper"])
}

pub fn frontmatter_parses_empty_css_test() {
  let assert Ok(p) = panel.load_panel(1)

  p.meta.css |> should.equal([])
}

pub fn frontmatter_parses_empty_js_test() {
  let assert Ok(p) = panel.load_panel(1)

  p.meta.js |> should.equal([])
}

// ---- Index Derivation Tests ----

pub fn panel_index_derived_from_filename_1_test() {
  let assert Ok(p) = panel.load_panel(1)

  p.meta.index |> should.equal(1)
}

pub fn panel_index_derived_from_filename_2_test() {
  let assert Ok(p) = panel.load_panel(2)

  p.meta.index |> should.equal(2)
}

// ---- Content Separation Tests ----

pub fn content_separated_from_frontmatter_test() {
  let assert Ok(p) = panel.load_panel(1)

  // Content should not contain YAML markers at the start
  string.starts_with(p.content, "---") |> should.be_false
}

pub fn content_does_not_contain_yaml_fields_test() {
  let assert Ok(p) = panel.load_panel(1)

  // Content should not contain YAML field names
  string.contains(p.content, "title:") |> should.be_false
  string.contains(p.content, "media:") |> should.be_false
  string.contains(p.content, "credits:") |> should.be_false
}

pub fn content_starts_with_markdown_test() {
  let assert Ok(p) = panel.load_panel(1)

  // Content should start with the actual markdown content (after trimming)
  let trimmed = string.trim(p.content)
  string.starts_with(trimmed, "**>") |> should.be_true
}

// ---- Error Cases ----

pub fn nonexistent_panel_returns_file_not_found_test() {
  let result = panel.load_panel(9999)

  result |> should.be_error

  let assert Error(err) = result
  case err {
    FileNotFound(_) -> should.be_true(True)
    _ -> should.fail()
  }
}
