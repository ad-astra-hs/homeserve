/// Panel Loading from Mnesia
///
/// Loads panel data from Mnesia and converts markdown content to HTML.
import homeserve/db
import homeserve/pages/panel/types.{type Panel, type ParseError}
import mork

/// Loads and parses a panel from Mnesia by index.
pub fn load_panel(panel_index: Int) -> Result(Panel, ParseError) {
  db.load_panel(panel_index)
}

/// Converts markdown content to HTML format for rendering.
pub fn parse_markdown_content(content: String) -> String {
  content
  |> mork.parse
  |> mork.to_html
}
