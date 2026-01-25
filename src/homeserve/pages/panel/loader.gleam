// ---- Panel File Loading and Public API ----
//
// This module handles loading panel files from disk and provides
// the main public API for accessing panel data.

import gleam/int
import gleam/result
import mork
import simplifile

import homeserve/pages/panel/parser
import homeserve/pages/panel/types.{type Panel, type ParseError}

/// Default directory containing panel files.
const default_pages_directory = "./pages"

/// Parses markdown content to HTML using the mork library.
fn parse_markdown(content: String) -> String {
  content
  |> mork.parse
  |> mork.to_html
}

// ---- Public API for loading panels ----

/// Loads and parses a panel file (.md) with YAML frontmatter.
/// Uses the default pages directory.
pub fn load_panel(panel_index: Int) -> Result(Panel, ParseError) {
  load_panel_from(panel_index, default_pages_directory)
}

/// Loads and parses a panel file (.md) with YAML frontmatter from a specific directory.
pub fn load_panel_from(
  panel_index: Int,
  pages_directory: String,
) -> Result(Panel, ParseError) {
  let path = pages_directory <> "/" <> int.to_string(panel_index) <> ".md"

  case simplifile.read(path) {
    Error(_) -> Error(types.FileNotFound(path))
    Ok(content) -> {
      use #(yaml, body) <- result.try(parser.split_frontmatter(content))
      use meta <- result.try(parser.decode_meta_from_yaml(yaml, panel_index))
      Ok(types.Panel(meta:, content: body))
    }
  }
}

/// Decodes only the metadata for a panel (for caching/listing purposes).
/// Uses the default pages directory.
pub fn decode_meta(panel_index: Int) -> Result(types.Meta, ParseError) {
  decode_meta_from(panel_index, default_pages_directory)
}

/// Decodes only the metadata for a panel from a specific directory.
pub fn decode_meta_from(
  panel_index: Int,
  pages_directory: String,
) -> Result(types.Meta, ParseError) {
  case load_panel_from(panel_index, pages_directory) {
    Ok(panel) -> Ok(panel.meta)
    Error(err) -> Error(err)
  }
}

/// Converts markdown content to HTML format for rendering.
pub fn parse_markdown_content(content: String) -> String {
  parse_markdown(content)
}
