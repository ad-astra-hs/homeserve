/// Security utilities for Homeserve
///
/// Provides path validation, sanitization, and other security helpers.
import gleam/bool
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleam/uri

/// Validates and sanitizes a file path to prevent path traversal attacks.
///
/// Returns the sanitized filename if valid, or None if the path contains
/// traversal attempts or other security issues.
///
/// # Security checks performed:
/// - URL decoding (%2e%2e, etc.)
/// - Path traversal sequences (.., /../, etc.)
/// - Null byte injection
/// - Absolute paths
/// - Double slashes
///
pub fn sanitize_filename(input: String) -> Option(String) {
  // Step 1: Reject null bytes
  use <- bool.guard(string.contains(input, "\u{0000}"), None)

  // Step 2: URL decode
  let decoded =
    uri.percent_decode(input)
    |> result.unwrap(input)

  // Step 3: Normalize path separators and normalize
  let normalized =
    decoded
    |> string.replace("\\", "/")
    |> normalize_path

  // Step 4: Extract just the filename (no directories)
  let filename = case string.last(normalized) {
    Ok("/") ->
      // Trailing slash - invalid for a file
      None
    _ -> {
      let parts = string.split(normalized, "/")
      case list.last(parts) {
        Ok(filename) if filename != "" -> Some(filename)
        _ -> None
      }
    }
  }

  // Step 5: Final validation
  case filename {
    None -> None
    Some(name) -> {
      use <- bool.guard(!is_safe_filename(name), None)
      Some(name)
    }
  }
}

/// Normalizes a path by removing redundant components
fn normalize_path(path: String) -> String {
  path
  |> remove_double_slashes
  |> remove_dot_segments
}

/// Removes double slashes from path
fn remove_double_slashes(path: String) -> String {
  case string.contains(path, "//") {
    True -> remove_double_slashes(string.replace(path, "//", "/"))
    False -> path
  }
}

/// Removes ./ and resolves ../ segments
fn remove_dot_segments(path: String) -> String {
  let parts = string.split(path, "/")
  let cleaned = remove_dot_segments_acc(parts, [])
  string.join(cleaned, "/")
}

fn remove_dot_segments_acc(
  parts: List(String),
  acc: List(String),
) -> List(String) {
  case parts {
    [] -> list.reverse(acc)
    [".", ..rest] -> remove_dot_segments_acc(rest, acc)
    ["..", ..rest] -> {
      // Go up one directory
      let new_acc = case acc {
        [] -> []
        [_, ..tail] -> tail
      }
      remove_dot_segments_acc(rest, new_acc)
    }
    ["", ..rest] -> {
      // Empty segment (leading slash)
      remove_dot_segments_acc(rest, acc)
    }
    [part, ..rest] -> remove_dot_segments_acc(rest, [part, ..acc])
  }
}

/// Checks if a filename is safe (no path traversal attempts)
fn is_safe_filename(filename: String) -> Bool {
  // Must not be empty
  use <- bool.guard(string.is_empty(filename), False)

  // Must not contain path separators after normalization
  use <- bool.guard(
    string.contains(filename, "/") || string.contains(filename, "\\"),
    False,
  )

  // Must not be . or ..
  use <- bool.guard(filename == "." || filename == "..", False)

  True
}

/// Validates that a resolved path is within an allowed base directory.
/// This is a defense-in-depth check after sanitization.
pub fn is_path_within_base(resolved_path: String, base_path: String) -> Bool {
  // Normalize both paths
  let normalized_base = string.replace(base_path, "\\", "/")
  let normalized_path = string.replace(resolved_path, "\\", "/")

  // Ensure base ends with / for prefix matching
  let base_with_slash = case string.ends_with(normalized_base, "/") {
    True -> normalized_base
    False -> normalized_base <> "/"
  }

  // Check if path starts with base
  string.starts_with(normalized_path, base_with_slash)
}

/// Validates that media URLs are safe.
/// Prevents javascript: URLs and other malicious schemes in media fields.
pub fn validate_media_url(url: String) -> Result(String, String) {
  let trimmed = string.trim(url)

  use <- bool.guard(
    string.is_empty(trimmed),
    Error("Media URL cannot be empty"),
  )

  let lower = string.lowercase(trimmed)

  // Check for dangerous protocols
  use <- bool.guard(
    string.starts_with(lower, "javascript:")
      || string.starts_with(lower, "data:")
      || string.starts_with(lower, "vbscript:"),
    Error("Invalid URL protocol"),
  )

  // Check for HTML/script injection
  use <- bool.guard(
    string.contains(trimmed, "<")
      || string.contains(trimmed, ">")
      || string.contains(trimmed, "\"")
      || string.contains(trimmed, "'"),
    Error("URL contains invalid characters"),
  )

  Ok(trimmed)
}
