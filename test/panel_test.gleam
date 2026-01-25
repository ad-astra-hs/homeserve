import gleam/option
import gleam/string
import gleeunit/should

import homeserve/pages/panel
import homeserve/pages/panel/types.{FileNotFound}

// ---- Panel Loading Tests ----

pub fn load_panel_1_test() {
  let result = panel.load_panel(1)

  result |> should.be_ok

  let assert Ok(p) = result
  p.meta.title |> should.equal("Enter Name")
  p.meta.index |> should.equal(1)
  p.meta.draft |> should.equal(False)
  p.meta.media.url |> should.equal("/assets/panel1.png")
  p.meta.media.alt
  |> should.equal(option.Some(
    "A mysterious figure stands before a glowing terminal",
  ))
}

pub fn load_panel_2_test() {
  let result = panel.load_panel(2)

  result |> should.be_ok

  let assert Ok(p) = result
  p.meta.title |> should.equal("Examine Room")
  p.meta.index |> should.equal(2)
  p.meta.credits.writers |> should.equal(["Bob Writer", "Charlie Editor"])
  p.meta.credits.misc |> should.equal(["Dave Helper"])
}

pub fn load_nonexistent_panel_test() {
  let result = panel.load_panel(999)

  result |> should.be_error

  let assert Error(err) = result
  case err {
    FileNotFound(_) -> should.be_true(True)
    _ -> should.fail()
  }
}

// ---- Metadata Decoding Tests ----

pub fn decode_meta_1_test() {
  let result = panel.decode_meta(1)

  result |> should.be_ok

  let assert Ok(meta) = result
  meta.title |> should.equal("Enter Name")
}

pub fn decode_meta_2_test() {
  let result = panel.decode_meta(2)

  result |> should.be_ok

  let assert Ok(meta) = result
  meta.title |> should.equal("Examine Room")
  meta.credits.writers |> should.equal(["Bob Writer", "Charlie Editor"])
}

pub fn decode_meta_nonexistent_test() {
  let result = panel.decode_meta(999)

  result |> should.be_error
}

// ---- Content Tests ----

pub fn panel_content_not_empty_test() {
  let assert Ok(p) = panel.load_panel(1)

  string.length(p.content) |> should.not_equal(0)
}

pub fn panel_content_has_expected_text_test() {
  let assert Ok(p) = panel.load_panel(1)

  string.contains(p.content, "Enter Name") |> should.be_true
}

// ---- Credits Tests ----

pub fn panel_1_has_artists_test() {
  let assert Ok(p) = panel.load_panel(1)

  p.meta.credits.artists |> should.equal(["Alice Artist"])
}

pub fn panel_1_has_writers_test() {
  let assert Ok(p) = panel.load_panel(1)

  p.meta.credits.writers |> should.equal(["Bob Writer"])
}

pub fn panel_1_has_no_musicians_test() {
  let assert Ok(p) = panel.load_panel(1)

  p.meta.credits.musicians |> should.equal([])
}
