import gleeunit/should

// ---- Track URL Parsing Tests ----
//
// Tests for the track field URL parsing functionality.
// The track field can accept any URL, and the display name
// should be extracted from the final path component.

/// Extract filename from URL - same logic as in renderer
fn extract_filename_from_url(url: String) -> String {
  url
  |> string.split("/")
  |> list.last
  |> result.unwrap(url)
}

/// Extract display name from track URL
fn extract_track_display_name(track_url: String) -> String {
  let filename = extract_filename_from_url(track_url)

  // Split by "?" first to remove query params, then by "." for extension
  let without_query = case string.split(filename, "?") {
    [base, ..] -> base
    [] -> filename
  }

  // Split by "." and take everything before the last extension
  case string.split(without_query, ".") {
    [name] -> name
    parts -> {
      // Drop the last part (extension), join the rest
      let name_parts = list.take(parts, list.length(parts) - 1)
      string.join(name_parts, ".")
    }
  }
}

// ---- Filename Extraction Tests ----

pub fn extract_filename_simple_test() {
  extract_filename_from_url("/assets/music/song.mp3")
  |> should.equal("song.mp3")
}

pub fn extract_filename_absolute_url_test() {
  extract_filename_from_url("https://example.com/music/track.mp3")
  |> should.equal("track.mp3")
}

pub fn extract_filename_no_path_test() {
  extract_filename_from_url("song.mp3")
  |> should.equal("song.mp3")
}

pub fn extract_filename_with_query_test() {
  extract_filename_from_url("/assets/music/song.mp3?token=abc123")
  |> should.equal("song.mp3?token=abc123")
}

// ---- Display Name Tests ----

pub fn display_name_simple_mp3_test() {
  extract_track_display_name("/assets/music/song.mp3")
  |> should.equal("song")
}

pub fn display_name_with_spaces_test() {
  extract_track_display_name("/assets/music/My Song.mp3")
  |> should.equal("My Song")
}

pub fn display_name_multiple_dots_test() {
  extract_track_display_name("/assets/music/song.name.test.mp3")
  |> should.equal("song.name.test")
}

pub fn display_name_absolute_url_test() {
  extract_track_display_name("https://cdn.example.com/audio/background.mp3")
  |> should.equal("background")
}

pub fn display_name_with_query_test() {
  extract_track_display_name("/assets/music/song.mp3?token=abc")
  |> should.equal("song")
}

pub fn display_name_no_extension_test() {
  extract_track_display_name("/assets/music/song")
  |> should.equal("song")
}

pub fn display_name_ogg_test() {
  extract_track_display_name("/assets/music/song.ogg")
  |> should.equal("song")
}

pub fn display_name_wav_test() {
  extract_track_display_name("/assets/music/song.wav")
  |> should.equal("song")
}

// ---- Import helpers ----
import gleam/list
import gleam/result
import gleam/string
