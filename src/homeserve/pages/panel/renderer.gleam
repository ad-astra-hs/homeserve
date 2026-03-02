//// Panel Rendering and UI Components
////
//// This module handles the rendering of panels into HTML/CSS,
//// including media rendering, credits, navigation, and styling.

import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleam/uri

import lustre/attribute
import lustre/element
import lustre/element/html
import sketch/css
import sketch/css/length
import sketch/css/media
import sketch/css/transform

import homeserve/base
import homeserve/html_sanitize
import homeserve/pages/panel/types.{
  type Credits, type Media, type Meta, Image, Video,
}

// ---- Credit section rendering ----

type CreditSection {
  CreditSection(label: String, names: List(String))
}

/// Renders the credits section with links to contributor pages.
pub fn render_credits(credits: Credits) {
  let sections = [
    CreditSection("Art", credits.artists),
    CreditSection("Writing", credits.writers),
    CreditSection("Music", credits.musicians),
    CreditSection("Misc. Help", credits.misc),
  ]

  html.span(
    [attribute.class("credits")],
    list.filter_map(sections, fn(section) {
      case list.is_empty(section.names) {
        True -> Error(Nil)
        False -> Ok(render_credit_section(section))
      }
    }),
  )
}

/// Renders a single credit section with links.
fn render_credit_section(section: CreditSection) {
  html.sup([], [
    html.text(section.label <> ": "),
    ..section.names
    |> list.map(fn(name) {
      html.a([attribute.href("/hoc/" <> uri.percent_encode(name))], [
        html.text(name),
      ])
    })
    |> list.intersperse(html.text(", "))
    |> list.append([html.text(". ")])
  ])
}

// ---- Media rendering ----

/// Renders the main media content (image or video) for a panel.
pub fn render_media(media: Media, animated: Bool) {
  let alt_attrs = case media.alt {
    Some(alt) -> [attribute.alt(alt), attribute.title(alt)]
    None -> [attribute.alt("")]
  }

  case media.kind {
    Image -> {
      let src = case animated {
        True -> media.url
        False -> media.url <> "?animated=False"
      }
      html.img(
        list.flatten([
          [attribute.src(src), attribute.class("panel-media")],
          alt_attrs,
        ]),
      )
    }
    Video -> {
      html.video(
        list.flatten([
          [
            attribute.controls(True),
            attribute.src(media.url),
            attribute.class("panel-media"),
          ],
          alt_attrs,
        ]),
        [],
      )
    }
  }
}

// ---- Audio player rendering ----

/// Extracts the filename from a URL or path.
/// For "https://example.com/music/song.mp3" or "/assets/music/song.mp3"
/// returns "song.mp3"
pub fn extract_filename_from_url(url: String) -> String {
  url
  |> string.split("/")
  |> list.last
  |> result.unwrap(url)
}

/// Extracts the display name from a track URL.
/// Takes the filename and strips the extension.
/// For "song.mp3" returns "song"
pub fn extract_track_display_name(track_url: String) -> String {
  let filename = extract_filename_from_url(track_url)

  // Split by "?" first to remove query params, then by "." for extension
  let without_query = case string.split(filename, "?") {
    [base, ..] -> base
    [] -> filename
  }

  // Split by "." and take everything before the last extension
  case string.split(without_query, ".") {
    [name] -> name
    parts -> {
      // Drop the last part (extension), join the rest
      let name_parts = list.take(parts, list.length(parts) - 1)
      string.join(name_parts, ".")
    }
  }
}

/// Renders audio player controls if a track is specified.
/// The track can be any URL (absolute or relative).
pub fn render_audio_player(track: Option(String)) {
  case track {
    None -> element.none()
    Some(track_url) -> {
      let display_name = extract_track_display_name(track_url)

      element.fragment([
        html.span([attribute.class("audio-controls")], [
          html.text("🕪 \"" <> display_name <> "\" "),
          html.button(
            [attribute.id("play_pause"), attribute.class("btn btn-secondary")],
            [
              html.text("Play"),
            ],
          ),
          html.text(" "),
          html.button(
            [attribute.class("btn btn-secondary"), attribute.id("volume_down")],
            [
              html.text("-"),
            ],
          ),
          html.span([attribute.id("volume")], [html.text("")]),
          html.button(
            [attribute.class("btn btn-secondary"), attribute.id("volume_up")],
            [
              html.text("+"),
            ],
          ),
        ]),
        html.audio(
          [
            attribute.class("music"),
            attribute.id("audio"),
            attribute.src(track_url),
            attribute.loop(True),
          ],
          [html.text("Audio is not supported in this browser")],
        ),
      ])
    }
  }
}

// ---- Navigation and controls ----

/// Renders the "next page" link if there is a next panel.
pub fn render_next_link(metadata: Meta, next_page_text: Option(String)) {
  case next_page_text {
    Some(next) ->
      html.a(
        [
          attribute.href("/read/" <> int.to_string(metadata.index + 1)),
          attribute.class("btn btn-primary next-link"),
        ],
        [html.text("> " <> next)],
      )
    None -> element.none()
  }
}

/// Renders a toggle button for settings like animations and quirks.
fn render_toggle_button(label: String, enabled: Bool, toggle_endpoint: String) {
  let symbol = case enabled {
    True -> "✓"
    False -> "✗"
  }

  html.button(
    [
      attribute.attribute(
        "onclick",
        "fetch('" <> toggle_endpoint <> "').then(()=>location.reload());",
      ),
      attribute.class("btn btn-secondary"),
    ],
    [html.text(label <> " " <> symbol)],
  )
}

/// Renders the bottom navigation links and toggle buttons.
pub fn render_bottom_links(metadata: Meta, quirked: Bool, animated: Bool) {
  html.span([attribute.class("nav-links")], [
    render_toggle_button("Quirks", quirked, "/read/toggle_quirks"),
    render_toggle_button("Animations", animated, "/read/toggle_animations"),
    html.a([attribute.href("/read/1")], [
      html.text("Start Over"),
    ]),
    case metadata.index > 1 {
      True ->
        html.a(
          [
            attribute.href("/read/" <> int.to_string(metadata.index - 1)),
          ],
          [
            html.text("Go Back"),
          ],
        )
      False ->
        html.a(
          [
            attribute.href("/read/" <> int.to_string(metadata.index)),
          ],
          [
            html.text("Go Back"),
          ],
        )
    },
    html.a(
      [
        attribute.href("/"),
        attribute.style("margin-left", "auto"),
      ],
      [html.text("Home")],
    ),
  ])
}

// ---- CSS generation ----

/// Generates CSS rules for panel pages.
pub fn build_css() -> List(css.Global) {
  [
    // Page structure
    css.global(".page_margins", [
      css.transform([transform.translate_x(length.percent(27))]),
      css.width(length.percent(65)),
      css.media(media.max_width(length.px(768)), [
        css.transform([]),
        css.width(length.percent(100)),
      ]),
    ]),
    css.global(".page_outer", [
      css.display("flex"),
      css.flex_direction("column"),
      css.height_("100%"),
      css.important(css.padding(length.pt(0))),
      css.important(css.margin(length.pt(0))),
    ]),
    css.global(".page_outer h2", [css.text_align("center")]),
    css.global(".page_outer img, .page_outer video", [
      css.margin_bottom(length.pt(0)),
    ]),
    // Panel media
    css.global(".panel-media", []),
    // Page content
    css.global(".page_inner", [
      css.text_align("center"),
      css.margin(length.pt(10)),
      css.margin_bottom(length.rlh(1.0)),
      css.height_("100%"),
    ]),
    // Next link
    css.global(".next-link", [
      css.important(css.font_size(length.pt(16))),
      css.margin(length.pt(5)),
      css.display("inline-block"),
      css.margin_top(length.pt(20)),
      css.margin_bottom(length.pt(20)),
      css.important(css.border("none")),
      css.important(css.text_decoration("underline")),
    ]),
    // Audio controls
    css.global(".audio-controls", [
      css.display("inline-block"),
      css.padding(length.pt(3)),
      css.margin_bottom(length.pt(10)),
      css.width_("max-content"),
      css.background("black"),
      css.color("white"),
    ]),
    css.global(".audio-controls button", [
      css.background("black"),
      css.color("white"),
      css.border("1px solid white"),
    ]),
    // Credits
    css.global(".credits", [
      css.font_size(length.pt(9)),
      css.color("grey"),
      css.margin(length.pt(10)),
      css.margin_bottom(length.pt(0)),
    ]),
    css.global(".credits a", [
      css.color("grey"),
    ]),
    css.global(".credits a:hover", [
      css.text_decoration("underline"),
    ]),
    // Navigation links wrapper
    css.global(".nav-links", [
      css.display("flex"),
      css.margin(length.pt(5)),
      css.align_items("center"),
      css.gap(length.pt(5)),
      css.flex_wrap("wrap"),
    ]),
    // Page inner details/summary
    css.global(".page_inner details", [
      css.text_align("left"),
      css.display("flex"),
      css.padding(length.pt(10)),
    ]),
    css.global(".page_inner summary", [
      css.margin_("0 auto"),
      css.width_("fit-content"),
      css.padding(length.pt(3)),
      css.margin_bottom(length.rlh(1.0)),
    ]),
    css.global(".page_inner summary::marker", [css.content("\"\"")]),
  ]
}

// ---- Head elements ----

/// Generates HTML head elements for a panel page.
pub fn build_head(metadata: Meta) {
  list.flatten([
    [
      html.title([], "> " <> metadata.title),
      html.link([
        attribute.href(
          "/assets/misc/" <> int.to_string(metadata.index) <> ".css",
        ),
        attribute.rel("stylesheet"),
      ]),
      html.script([attribute.src("/assets/misc/default.js")], ""),
      html.script([attribute.src("/assets/misc/details_open.js")], ""),
    ],
    list.map(metadata.css, fn(name) {
      html.link([
        attribute.href("/assets/misc/" <> name <> ".css"),
        attribute.rel("stylesheet"),
      ])
    }),
    list.map(metadata.js, fn(name) {
      html.script([attribute.src("/assets/misc/" <> name <> ".js")], "")
    }),
    case metadata.media.track {
      Some(_) -> [
        html.script([attribute.src("/assets/misc/audio_player.js")], ""),
      ]
      None -> []
    },
  ])
}

// ---- Page builder ----

/// Assembles a complete page from metadata and content.
pub fn build_panel(
  metadata: Meta,
  parsed_page: String,
  next_page_text: Option(String),
  quirked: Bool,
  animated: Bool,
) -> base.Page {
  let head = build_head(metadata)
  let css = build_css()

  // Sanitize HTML to prevent XSS
  let sanitized_content = html_sanitize.sanitize(parsed_page)

  let body = [
    html.div([attribute.class("page_margins")], [
      html.div([attribute.class("page_outer box")], [
        html.h2([], [html.text(metadata.title)]),
        render_media(metadata.media, animated),
        render_audio_player(metadata.media.track),
        element.unsafe_raw_html(
          "",
          "div",
          [attribute.class("page_inner box")],
          sanitized_content,
        ),
        render_next_link(metadata, next_page_text),
        render_credits(metadata.credits),
        render_bottom_links(metadata, quirked, animated),
      ]),
    ]),
  ]

  base.Page(head:, css:, body:)
}
