/// Admin Utilities
///
/// Form parsing, input validation, and panel building utilities.
import gleam/erlang
import gleam/list
import gleam/option.{None, Some}
import gleam/string

import homeserve/pages/panel/types.{
  type Panel, Credits, Image, Media, Meta, Panel as PanelConstructor, Video,
}
import homeserve/security
import wisp.{type FormData}

/// Maximum lengths for form fields
const max_title_length = 200

const max_content_length = 50_000

const max_url_length = 1000

const max_contributor_name_length = 100

const max_css_js_filename_length = 100

/// Validation result type
pub type ValidationError {
  FieldTooLong(field: String, max: Int)
  InvalidUrl(field: String)
  InvalidCharacters(field: String)
  MissingRequiredField(field: String)
}

/// Get current Unix timestamp in seconds.
pub fn current_timestamp() -> Int {
  erlang.system_time(erlang.Second)
}

/// Get form field value or empty string
pub fn get_form_field(body: FormData, name: String) -> String {
  case list.key_find(body.values, name) {
    Ok(value) -> value
    Error(_) -> ""
  }
}

/// Parse comma-separated list with validation
pub fn parse_list(value: String) -> List(String) {
  value
  |> string.split(",")
  |> list.map(string.trim)
  |> list.filter(fn(s) { s != "" })
}

/// Parse boolean checkbox
pub fn parse_bool(body: FormData, name: String) -> Bool {
  case list.key_find(body.values, name) {
    Ok("true") -> True
    _ -> False
  }
}

/// Validates a title field
fn validate_title(title: String) -> Result(String, ValidationError) {
  let trimmed = string.trim(title)
  case string.is_empty(trimmed) {
    True -> Error(MissingRequiredField("title"))
    False -> {
      case string.length(trimmed) > max_title_length {
        True -> Error(FieldTooLong("title", max_title_length))
        False -> {
          // Check for null bytes
          case string.contains(trimmed, "\u{0000}") {
            True -> Error(InvalidCharacters("title"))
            False -> Ok(trimmed)
          }
        }
      }
    }
  }
}

/// Validates content field
fn validate_content(content: String) -> Result(String, ValidationError) {
  case string.length(content) > max_content_length {
    True -> Error(FieldTooLong("content", max_content_length))
    False -> {
      // Check for null bytes
      case string.contains(content, "\u{0000}") {
        True -> Error(InvalidCharacters("content"))
        False -> Ok(content)
      }
    }
  }
}

/// Validates URL field
fn validate_url(
  url: String,
  field_name: String,
) -> Result(String, ValidationError) {
  let trimmed = string.trim(url)
  case string.is_empty(trimmed) {
    True -> Error(MissingRequiredField(field_name))
    False -> {
      case string.length(trimmed) > max_url_length {
        True -> Error(FieldTooLong(field_name, max_url_length))
        False -> {
          // Use security module validation
          case security.validate_media_url(trimmed) {
            Ok(valid_url) -> Ok(valid_url)
            Error(_) -> Error(InvalidUrl(field_name))
          }
        }
      }
    }
  }
}

/// Validates optional URL field (can be empty)
fn validate_optional_url(
  url: String,
  field_name: String,
) -> Result(String, ValidationError) {
  let trimmed = string.trim(url)
  case string.is_empty(trimmed) {
    True -> Ok("")
    False -> validate_url(url, field_name)
  }
}

/// Validates contributor names
fn validate_contributor_names(names: List(String)) -> List(String) {
  names
  |> list.filter(fn(name) {
    let trimmed = string.trim(name)
    !string.is_empty(trimmed)
    && string.length(trimmed) <= max_contributor_name_length
    && !string.contains(trimmed, "\u{0000}")
  })
}

/// Validates CSS/JS filenames
fn validate_filename(filename: String) -> Bool {
  let trimmed = string.trim(filename)
  !string.is_empty(trimmed)
  && string.length(trimmed) <= max_css_js_filename_length
  && !string.contains(trimmed, "\u{0000}")
  && !string.contains(trimmed, "/")
  && !string.contains(trimmed, "\\")
  && !string.contains(trimmed, "..")
}

/// Validates a list of CSS/JS filenames
fn validate_filenames(filenames: List(String)) -> List(String) {
  filenames
  |> list.filter(validate_filename)
}

/// Build Panel from form data with validation
pub fn build_panel_from_form(
  body: FormData,
  index: Int,
  date: Int,
) -> Result(Panel, List(ValidationError)) {
  // Validate required fields
  let title_result = validate_title(get_form_field(body, "title"))
  let media_url_result =
    validate_url(get_form_field(body, "media_url"), "media_url")
  let content_result = validate_content(get_form_field(body, "content"))

  // Validate optional fields
  let media_alt_result =
    validate_optional_url(get_form_field(body, "media_alt"), "media_alt")
  let media_track_result =
    validate_optional_url(get_form_field(body, "media_track"), "media_track")

  // Collect all errors
  let errors =
    collect_errors([
      #("title", title_result),
      #("media_url", media_url_result),
      #("content", content_result),
      #("media_alt", media_alt_result),
      #("media_track", media_track_result),
    ])

  case errors {
    [] -> {
      // All validations passed, build the panel
      let assert Ok(title) = title_result
      let assert Ok(media_url) = media_url_result
      let assert Ok(content_raw) = content_result
      let assert Ok(media_alt) = media_alt_result
      let assert Ok(media_track) = media_track_result

      // Content is stored as-is (panel authors are trusted)
      let content = content_raw

      let media_kind_str = get_form_field(body, "media_kind")
      let media_kind = case media_kind_str {
        "video" -> Video
        _ -> Image
      }

      let media =
        Media(
          kind: media_kind,
          url: media_url,
          alt: case media_alt {
            "" -> None
            alt -> Some(alt)
          },
          track: case media_track {
            "" -> None
            track -> Some(track)
          },
        )

      let artists =
        validate_contributor_names(parse_list(get_form_field(body, "artists")))
      let writers =
        validate_contributor_names(parse_list(get_form_field(body, "writers")))
      let musicians =
        validate_contributor_names(
          parse_list(get_form_field(body, "musicians")),
        )
      let misc =
        validate_contributor_names(parse_list(get_form_field(body, "misc")))
      let css = validate_filenames(parse_list(get_form_field(body, "css")))
      let js = validate_filenames(parse_list(get_form_field(body, "js")))
      let draft = parse_bool(body, "draft")

      let credits = Credits(artists:, writers:, musicians:, misc:)
      let meta =
        Meta(index:, title:, media:, credits:, css:, js:, date:, draft:)

      Ok(PanelConstructor(meta:, content:))
    }
    errs -> Error(errs)
  }
}

/// Helper to collect validation errors
type ValidationResult =
  Result(String, ValidationError)

fn collect_errors(
  results: List(#(String, ValidationResult)),
) -> List(ValidationError) {
  results
  |> list.filter_map(fn(pair) {
    case pair.1 {
      Error(err) -> Ok(err)
      Ok(_) -> Error(Nil)
    }
  })
}

/// Format validation errors for display
pub fn format_validation_errors(errors: List(ValidationError)) -> String {
  errors
  |> list.map(fn(err) {
    case err {
      FieldTooLong(field, max) ->
        field <> " is too long (max " <> string.inspect(max) <> " characters)"
      InvalidUrl(field) -> field <> " contains an invalid URL"
      InvalidCharacters(field) -> field <> " contains invalid characters"
      MissingRequiredField(field) -> field <> " is required"
    }
  })
  |> string.join("; ")
}
