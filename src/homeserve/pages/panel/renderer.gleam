// ---- Panel Rendering and UI Components ----
//
// This module handles the rendering of panels into HTML/CSS,
// including media rendering, credits, navigation, and styling.

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
          [attribute.src(src), attribute.class("panel")],
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
            attribute.class("panel"),
          ],
          alt_attrs,
        ]),
        [],
      )
    }
  }
}

// ---- Audio player rendering ----

/// Renders audio player controls if a track is specified.
pub fn render_audio_player(track: Option(String)) {
  case track {
    None -> element.none()
    Some(track_name) ->
      element.fragment([
        html.span([attribute.class("audio_controls")], [
          html.text(
            "🕪 \""
            <> track_name
            |> string.split(".")
            |> list.first
            |> result.unwrap("Unknown Track")
            <> "\" ",
          ),
          html.button([attribute.id("play_pause"), attribute.class("music")], [
            html.text("Play"),
          ]),
          html.text(" "),
          html.button([attribute.class("music"), attribute.id("volume_down")], [
            html.text("-"),
          ]),
          html.span([attribute.id("volume")], [html.text("")]),
          html.button([attribute.class("music"), attribute.id("volume_up")], [
            html.text("+"),
          ]),
        ]),
        html.audio(
          [
            attribute.class("music"),
            attribute.id("audio"),
            attribute.src("/assets/" <> track_name),
            attribute.loop(True),
          ],
          [html.text("Audio is not supported in this browser")],
        ),
      ])
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
          attribute.class("next"),
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
      attribute.class("toggle_button"),
    ],
    [html.text(label <> " " <> symbol)],
  )
}

/// Renders the bottom navigation links and toggle buttons.
pub fn render_bottom_links(metadata: Meta, quirked: Bool, animated: Bool) {
  html.span([attribute.class("bottom_links")], [
    render_toggle_button("Quirks", quirked, "/read/toggle_quirks"),
    render_toggle_button("Animations", animated, "/read/toggle_animations"),
    html.a([attribute.href("/read/1")], [html.text("Start Over")]),
    case metadata.index > 1 {
      True ->
        html.a([attribute.href("/read/" <> int.to_string(metadata.index - 1))], [
          html.text("Go Back"),
        ])
      False ->
        html.a([attribute.href("/read/" <> int.to_string(metadata.index))], [
          html.text("Go Back"),
        ])
    },
    html.a([attribute.href("/")], [html.text("Home")]),
  ])
}

// ---- CSS generation ----

/// Generates CSS rules for panel pages.
pub fn build_css() -> List(css.Global) {
  [
    css.global(".page_margins", [
      css.transform([transform.translate_x(length.percent(30))]),
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
      css.background("white"),
    ]),
    css.global(".page_outer h2", [css.text_align("center")]),
    css.global(".page_outer img, .page_outer video", [
      css.margin_bottom(length.pt(0)),
    ]),
    css.global(".page_inner", [
      css.text_align("center"),
      css.margin(length.pt(10)),
      css.margin_bottom(length.rlh(1.0)),
      css.height_("100%"),
    ]),
    css.global(".next", [
      css.font_size(length.pt(16)),
      css.margin(length.pt(5)),
      css.display("block"),
      css.margin_top(length.pt(20)),
      css.margin_bottom(length.pt(20)),
    ]),
    css.global(".bottom_links", [
      css.display("flex"),
      css.margin(length.pt(5)),
      css.align_items("center"),
      css.gap(length.pt(5)),
    ]),
    css.global(".credits", [
      css.color("gray"),
      css.margin(length.pt(10)),
      css.margin_left(length.pt(5)),
      css.margin_bottom(length.pt(0)),
    ]),
    css.global(".credits a", [css.color("gray")]),
    css.global(".bottom_links a:last-child", [css.margin_left_("auto")]),
    css.global(".music", [
      css.border("1pt solid white"),
      css.background("black"),
      css.color("white"),
    ]),
    css.global(".toggle_button", [
      css.border("1pt solid grey"),
      css.background("#e9e9e9"),
    ]),
    css.global(".toggle_button:hover", [
      css.border("1pt solid grey"),
      css.background("#c9c9c9"),
    ]),
    css.global(".audio_controls", [
      css.margin_top(length.pt(0)),
      css.padding(length.pt(3)),
      css.padding_right(length.pt(6)),
      css.background("black"),
      css.color("white"),
      css.width_("fit-content"),
      css.margin_bottom(length.pt(10)),
    ]),
    css.global("#volume_down", [
      css.padding_left(length.pt(5)),
      css.padding_right(length.pt(5)),
    ]),
    css.global(".page_inner details", [
      css.border("1pt dotted grey"),
      css.text_align("left"),
      css.display("flex"),
      css.padding(length.pt(10)),
    ]),
    css.global(".page_inner summary", [
      css.margin_("0 auto"),
      css.width_("fit-content"),
      css.padding(length.pt(3)),
      css.border("1pt solid grey"),
      css.background("#e9e9e9"),
      css.margin_bottom(length.rlh(1.0)),
    ]),
    css.global(".page_inner summary:hover", [
      css.background("#c9c9c9"),
      css.cursor("default"),
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

  let body = [
    html.div([attribute.class("page_margins")], [
      html.div([attribute.class("page_outer")], [
        html.h2([], [html.text(metadata.title)]),
        render_media(metadata.media, animated),
        render_audio_player(metadata.media.track),
        element.unsafe_raw_html(
          "",
          "div",
          [attribute.class("page_inner")],
          parsed_page,
        ),
        render_next_link(metadata, next_page_text),
        render_credits(metadata.credits),
        render_bottom_links(metadata, quirked, animated),
      ]),
    ]),
  ]

  base.Page(head:, css:, body:)
}
