/// Panel Loading from CouchDB
///
/// Loads panel data from CouchDB and converts markdown content to HTML.
import mork

import homeserve/couchdb
import homeserve/db
import homeserve/pages/panel/types.{type Panel, type ParseError}

/// Loads and parses a panel from CouchDB by index.
pub fn load_panel(
  config: couchdb.CouchConfig,
  panel_index: Int,
) -> Result(Panel, ParseError) {
  db.load_panel(config, panel_index)
}

/// Decodes only the metadata for a panel from CouchDB by index.
pub fn decode_meta(
  config: couchdb.CouchConfig,
  panel_index: Int,
) -> Result(types.Meta, types.ParseError) {
  db.load_meta(config, panel_index)
}

/// Converts markdown content to HTML format for rendering.
pub fn parse_markdown_content(content: String) -> String {
  content
  |> mork.parse
  |> mork.to_html
}
