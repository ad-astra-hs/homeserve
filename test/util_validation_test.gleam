// Test input validation in admin utilities

import gleam/list
import gleam/option.{None, Some}
import gleam/string
import gleeunit
import gleeunit/should

import homeserve/pages/admin/util
import homeserve/pages/panel/types.{Image, Video}
import wisp

pub fn main() {
  gleeunit.main()
}

// ---- Title Validation Tests ----

pub fn validate_title_empty_test() {
  let form_data = wisp.FormData(values: [#("title", "")], files: [])

  case util.build_panel_from_form(form_data, 1, 1000) {
    Error(errors) -> {
      list.any(errors, fn(e) {
        case e {
          util.MissingRequiredField("title") -> True
          _ -> False
        }
      })
      |> should.be_true
    }
    Ok(_) -> should.fail()
  }
}

pub fn validate_title_whitespace_only_test() {
  let form_data = wisp.FormData(values: [#("title", "   ")], files: [])

  case util.build_panel_from_form(form_data, 1, 1000) {
    Error(errors) -> {
      list.any(errors, fn(e) {
        case e {
          util.MissingRequiredField("title") -> True
          _ -> False
        }
      })
      |> should.be_true
    }
    Ok(_) -> should.fail()
  }
}

pub fn validate_title_null_bytes_test() {
  let form_data =
    wisp.FormData(values: [#("title", "Test\u{0000}Title")], files: [])

  case util.build_panel_from_form(form_data, 1, 1000) {
    Error(errors) -> {
      list.any(errors, fn(e) {
        case e {
          util.InvalidCharacters("title") -> True
          _ -> False
        }
      })
      |> should.be_true
    }
    Ok(_) -> should.fail()
  }
}

pub fn validate_title_valid_test() {
  let form_data =
    wisp.FormData(
      values: [
        #("title", "Valid Title"),
        #("media_url", "/assets/image.jpg"),
        #("content", "Some content"),
      ],
      files: [],
    )

  case util.build_panel_from_form(form_data, 1, 1000) {
    Ok(panel) -> {
      panel.meta.title |> should.equal("Valid Title")
    }
    Error(_) -> should.fail()
  }
}

// ---- URL Validation Tests ----

pub fn validate_media_url_javascript_test() {
  let form_data =
    wisp.FormData(
      values: [
        #("title", "Test"),
        #("media_url", "javascript:alert('xss')"),
        #("content", "Content"),
      ],
      files: [],
    )

  case util.build_panel_from_form(form_data, 1, 1000) {
    Error(errors) -> {
      list.any(errors, fn(e) {
        case e {
          util.InvalidUrl("media_url") -> True
          _ -> False
        }
      })
      |> should.be_true
    }
    Ok(_) -> should.fail()
  }
}

pub fn validate_media_url_valid_test() {
  let form_data =
    wisp.FormData(
      values: [
        #("title", "Test"),
        #("media_url", "/assets/image.jpg"),
        #("content", "Content"),
      ],
      files: [],
    )

  case util.build_panel_from_form(form_data, 1, 1000) {
    Ok(panel) -> {
      panel.meta.media.url |> should.equal("/assets/image.jpg")
    }
    Error(_) -> should.fail()
  }
}

// ---- Content Validation Tests ----

pub fn validate_content_null_bytes_test() {
  let form_data =
    wisp.FormData(
      values: [
        #("title", "Test"),
        #("media_url", "/assets/image.jpg"),
        #("content", "Content\u{0000}WithNull"),
      ],
      files: [],
    )

  case util.build_panel_from_form(form_data, 1, 1000) {
    Error(errors) -> {
      list.any(errors, fn(e) {
        case e {
          util.InvalidCharacters("content") -> True
          _ -> False
        }
      })
      |> should.be_true
    }
    Ok(_) -> should.fail()
  }
}

// ---- Form Validation Tests ----

pub fn build_panel_complete_test() {
  let form_data =
    wisp.FormData(
      values: [
        #("title", "Test Panel"),
        #("media_kind", "image"),
        #("media_url", "/assets/test.jpg"),
        #("media_alt", "Alt text"),
        #("media_track", ""),
        #("content", "This is test content"),
        #("artists", "Artist1, Artist2"),
        #("writers", "Writer1"),
        #("musicians", ""),
        #("misc", ""),
        #("css", ""),
        #("js", ""),
        #("draft", "false"),
      ],
      files: [],
    )

  case util.build_panel_from_form(form_data, 42, 1_234_567_890) {
    Ok(panel) -> {
      panel.meta.index |> should.equal(42)
      panel.meta.title |> should.equal("Test Panel")
      panel.meta.media.kind |> should.equal(Image)
      panel.meta.media.url |> should.equal("/assets/test.jpg")
      panel.meta.media.alt |> should.equal(Some("Alt text"))
      panel.meta.media.track |> should.equal(None)
      panel.meta.credits.artists |> should.equal(["Artist1", "Artist2"])
      panel.meta.credits.writers |> should.equal(["Writer1"])
      panel.meta.credits.musicians |> should.equal([])
      panel.meta.css |> should.equal([])
      panel.meta.js |> should.equal([])
      panel.meta.draft |> should.be_false
      panel.meta.date |> should.equal(1_234_567_890)
      panel.content |> should.equal("This is test content")
    }
    Error(errors) -> {
      let _ = util.format_validation_errors(errors)
      should.fail()
    }
  }
}

pub fn build_panel_video_test() {
  let form_data =
    wisp.FormData(
      values: [
        #("title", "Video Panel"),
        #("media_kind", "video"),
        #("media_url", "/assets/video.mp4"),
        #("media_alt", ""),
        #("media_track", "/assets/captions.vtt"),
        #("content", "Video content"),
      ],
      files: [],
    )

  case util.build_panel_from_form(form_data, 1, 1000) {
    Ok(panel) -> {
      panel.meta.media.kind |> should.equal(Video)
      panel.meta.media.track |> should.equal(Some("/assets/captions.vtt"))
    }
    Error(_) -> should.fail()
  }
}

pub fn build_panel_validation_errors_test() {
  // Multiple validation errors
  let form_data =
    wisp.FormData(
      values: [
        #("title", ""),
        #("media_url", "javascript:alert('xss')"),
        #("content", "Content\u{0000}"),
      ],
      files: [],
    )

  case util.build_panel_from_form(form_data, 1, 1000) {
    Error(errors) -> {
      errors |> list.length |> should.equal(3)
    }
    Ok(_) -> should.fail()
  }
}

// ---- Error Formatting Tests ----

pub fn format_validation_errors_test() {
  let errors = [
    util.MissingRequiredField("title"),
    util.InvalidUrl("media_url"),
    util.InvalidCharacters("content"),
    util.FieldTooLong("title", 200),
  ]

  let formatted = util.format_validation_errors(errors)

  string.contains(formatted, "title is required") |> should.be_true
  string.contains(formatted, "media_url contains an invalid URL")
  |> should.be_true
  string.contains(formatted, "content contains invalid characters")
  |> should.be_true
  string.contains(formatted, "title is too long") |> should.be_true
}
