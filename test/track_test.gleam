import gleeunit/should
import homeserve/pages/panel/renderer

// ---- Track URL Parsing Tests ----
//
// Tests for the track field URL parsing functionality.
// Uses the shared renderer utilities.

/// Extract filename from URL - wrapper for renderer function
fn extract_filename_from_url(url: String) -> String {
  renderer.extract_filename_from_url(url)
}

/// Extract display name from track URL - wrapper for renderer function
fn extract_track_display_name(track_url: String) -> String {
  renderer.extract_track_display_name(track_url)
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
// Test complete
