// ---- Panel Module ----
//
// This is the main entry point for panel functionality.
// It re-exports the public API from submodules and provides
// the high-level rendering interface.

import gleam/int
import gleam/option.{None, Some}
import wisp

import homeserve/base
import homeserve/pages/errors
import homeserve/pages/panel/loader
import homeserve/pages/panel/renderer
import homeserve/pages/panel/types
import homeserve/quirks

// ---- Re-export types for public API ----

pub type Meta =
  types.Meta

pub type Panel =
  types.Panel

pub type ParseError =
  types.ParseError

// ---- Re-export loader functions ----

/// Loads and parses a panel file (.md) with YAML frontmatter.
/// Uses the default pages directory.
pub fn load_panel(panel_index: Int) -> Result(Panel, ParseError) {
  loader.load_panel(panel_index)
}

/// Loads and parses a panel file (.md) with YAML frontmatter from a specific directory.
pub fn load_panel_from(
  panel_index: Int,
  pages_directory: String,
) -> Result(Panel, ParseError) {
  loader.load_panel_from(panel_index, pages_directory)
}

/// Decodes only the metadata for a panel (for caching/listing purposes).
/// Uses the default pages directory.
pub fn decode_meta(panel_index: Int) -> Result(Meta, ParseError) {
  loader.decode_meta(panel_index)
}

/// Decodes only the metadata for a panel from a specific directory.
pub fn decode_meta_from(
  panel_index: Int,
  pages_directory: String,
) -> Result(Meta, ParseError) {
  loader.decode_meta_from(panel_index, pages_directory)
}

// ---- Public rendering API ----

/// Renders a panel using the default pages directory.
pub fn render_panel(
  panel_index: Int,
  quirked: Bool,
  animated: Bool,
) -> base.Page {
  render_panel_from(panel_index, quirked, animated, "./pages")
}

/// Renders a panel from a specific pages directory.
pub fn render_panel_from(
  panel_index: Int,
  quirked: Bool,
  animated: Bool,
  pages_directory: String,
) -> base.Page {
  let panel_str = int.to_string(panel_index)

  wisp.log_debug("Rendering panel " <> panel_str)

  case load_panel_from(panel_index, pages_directory) {
    Error(err) -> {
      let err_str = types.parse_error_to_string(err)
      case err {
        types.FileNotFound(_) -> {
          wisp.log_warning("Panel not found: " <> panel_str <> " - " <> err_str)
          errors.build_error(404, "Page not found")
        }
        _ -> {
          wisp.log_error(
            "Failed to load panel " <> panel_str <> ": " <> err_str,
          )
          errors.build_error(500, "Could not load panel")
        }
      }
    }
    Ok(panel) -> {
      wisp.log_debug("Successfully loaded panel " <> panel_str)

      let next_page_text = case
        decode_meta_from(panel_index + 1, pages_directory)
      {
        Ok(next) -> Some(next.title)
        Error(_) -> None
      }

      case quirks.parse_document(panel.content, quirked) {
        Ok(quirked_content) -> {
          let parsed_page = loader.parse_markdown_content(quirked_content)
          renderer.build_panel(
            panel.meta,
            parsed_page,
            next_page_text,
            quirked,
            animated,
          )
        }
        Error(err) -> {
          wisp.log_error(
            "Failed to parse quirks for panel "
            <> panel_str
            <> ": "
            <> err.error,
          )
          errors.build_error(500, "Failed to parse page content")
        }
      }
    }
  }
}
