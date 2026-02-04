// ---- Panel Types and Error Definitions ----
//
// This module contains all type definitions for panel metadata,
// media types, credits, and parsing errors.

import gleam/option.{type Option}

/// Metadata for a webcomic panel, stored in CouchDB.
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
    /// Optional audio track URL (can be absolute URL or relative path)
    track: Option(String),
  )
}

/// Complete panel data including metadata and markdown content.
pub type Panel {
  Panel(
    /// Panel metadata from CouchDB
    meta: Meta,
    /// Markdown body content
    content: String,
  )
}

/// Errors that can occur during panel parsing and loading.
pub type ParseError {
  /// Panel not found in database
  FileNotFound(path: String)
  /// Metadata format is invalid
  InvalidFrontmatter(message: String)
  /// Required field missing from metadata
  MissingField(field: String)
  /// Field has wrong type
  InvalidFieldType(field: String, expected: String)
  /// Database connection or query error
  DatabaseError(message: String)
}

/// Converts ParseError to human-readable string for logging.
pub fn parse_error_to_string(err: ParseError) -> String {
  case err {
    FileNotFound(path) -> "Panel not found: " <> path
    InvalidFrontmatter(msg) -> "Invalid metadata: " <> msg
    MissingField(field) -> "Missing required field: " <> field
    InvalidFieldType(field, expected) ->
      "Invalid type for field '" <> field <> "', expected " <> expected
    DatabaseError(msg) -> "Database error: " <> msg
  }
}
