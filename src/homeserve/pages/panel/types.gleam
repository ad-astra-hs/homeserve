// ---- Panel Types and Error Definitions ----
//
// This module contains all type definitions for panel metadata,
// media types, credits, and parsing errors.

import glaml.{type SelectorError, type YamlError}
import gleam/option.{type Option}

/// Metadata for a webcomic panel, extracted from YAML frontmatter.
pub type Meta {
  Meta(
    /// Sequential index of the panel in the story
    index: Int,
    /// Panel title displayed to readers
    title: String,
    /// Associated media (image or video)
    media: Media,
    /// Credits for contributors
    credits: Credits,
    /// Additional CSS files to include
    css: List(String),
    /// Additional JavaScript files to include
    js: List(String),
    /// Publication timestamp (Unix epoch)
    date: Int,
    /// Whether this panel is a draft (not publicly visible)
    draft: Bool,
  )
}

/// Credits for contributors to a panel.
pub type Credits {
  Credits(
    /// Visual artists and illustrators
    artists: List(String),
    /// Writers and story contributors
    writers: List(String),
    /// Music and sound contributors
    musicians: List(String),
    /// Miscellaneous contributors
    misc: List(String),
  )
}

/// Supported media types for panel content.
pub type MediaKind {
  Image
  Video
}

/// Media file associated with a panel.
pub type Media {
  Media(
    /// Type of media (image or video)
    kind: MediaKind,
    /// URL to the media file
    url: String,
    /// Alt text for accessibility
    alt: Option(String),
    /// Optional audio track file name
    track: Option(String),
  )
}

/// Complete panel data including metadata and markdown content.
pub type Panel {
  Panel(
    /// Extracted metadata from frontmatter
    meta: Meta,
    /// Markdown body content
    content: String,
  )
}

/// Errors that can occur during panel parsing and loading.
pub type ParseError {
  /// Panel file not found at specified path
  FileNotFound(path: String)
  /// Frontmatter format is invalid or missing
  InvalidFrontmatter(message: String)
  /// YAML parsing failed
  YamlParseError(error: YamlError)
  /// YAML field selection/query failed
  YamlSelectionError(error: SelectorError)
  /// Required field missing from frontmatter
  MissingField(field: String)
  /// Field has wrong type
  InvalidFieldType(field: String, expected: String)
}

/// Converts ParseError to human-readable string for logging.
pub fn parse_error_to_string(err: ParseError) -> String {
  case err {
    FileNotFound(path) -> "File not found: " <> path
    InvalidFrontmatter(msg) -> "Invalid frontmatter: " <> msg
    YamlParseError(_) -> "YAML parsing error"
    YamlSelectionError(_) -> "YAML field selection error"
    MissingField(field) -> "Missing required field: " <> field
    InvalidFieldType(field, expected) ->
      "Invalid type for field '" <> field <> "', expected " <> expected
  }
}
