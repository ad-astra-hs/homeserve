/// Panel Loading from CouchDB
///
/// Loads panel data from CouchDB and converts markdown content to HTML.
import mork

import homeserve/couchdb
import homeserve/db
import homeserve/pages/panel/types.{type Panel, type ParseError}

/// Parses markdown content to HTML using the mork library.
fn parse_markdown(content: String) -> String {
  content
  |> mork.parse
  |> mork.to_html
}

// ---- Public API for loading panels ----

/// Loads and parses a panel from CouchDB by index.
pub fn load_panel(panel_index: Int) -> Result(Panel, ParseError) {
  db.load_panel(couchdb.default_config(), panel_index)
}

/// Decodes only the metadata for a panel from CouchDB by index.
pub fn decode_meta(panel_index: Int) -> Result(types.Meta, types.ParseError) {
  db.load_meta(couchdb.default_config(), panel_index)
}

/// Converts markdown content to HTML format for rendering.
pub fn parse_markdown_content(content: String) -> String {
  parse_markdown(content)
}
