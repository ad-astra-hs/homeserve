/// Panel Module
///
/// Main entry point for panel functionality. Provides high-level
/// rendering interface for webcomic panels stored in CouchDB.
import gleam/int
import gleam/option.{None, Some}
import wisp

import homeserve/base
import homeserve/config.{type Config}
import homeserve/couchdb
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

// ---- Public rendering API ----

/// Renders a panel page.
pub fn render_panel(
  panel_index: Int,
  quirked: Bool,
  animated: Bool,
  cfg: Config,
) -> base.Page {
  let panel_str = int.to_string(panel_index)
  let couch_config = couchdb.config_from_app_config(cfg)

  wisp.log_debug("Rendering panel " <> panel_str)

  case loader.load_panel(couch_config, panel_index) {
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
        loader.decode_meta(couch_config, panel_index + 1)
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
