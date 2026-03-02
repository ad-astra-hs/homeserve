//// Types
//// Constants
//// Navigation
//// Shared CSS Classes
////
//// These classes provide consistent styling across all pages.
//// Edit these to change the look and feel of the entire site.
//// Stylesheet
//// Page rendering

import gleam/list

import homeserve/logging
import lustre/attribute
import lustre/element
import lustre/element/html
import lustre/vdom/vnode
import sketch
import sketch/css
import sketch/css/length
import sketch/css/media
import sketch/css/transform

pub type Page {
  Page(
    head: List(vnode.Element(String)),
    css: List(css.Global),
    body: List(vnode.Element(String)),
  )
}

const top_banner_image = "/assets/top_banner.png"

const bottom_banner_image = "/assets/bottom_banner.png"

const charm_image = "/assets/symbolic.svg"

type NavLink {
  NavLink(href: String, text: String)
}

const top_links = [
  NavLink("/", "Home"),
  NavLink("/read", "Read"),
  NavLink("/play", "Play"),
]

const bottom_links = [
  NavLink("https://codeberg.org/ad-astra/homeserve", "Source Code"),
  NavLink("/hoc", "Volunteers"),
  NavLink("/privacy", "Privacy Policy"),
]

fn render_nav_links(links: List(NavLink)) -> List(vnode.Element(String)) {
  let charm =
    html.img([
      attribute.src(charm_image),
      attribute.class("charm"),
      attribute.alt(""),
    ])

  links
  |> list.flat_map(fn(link) {
    [
      charm,
      html.a([attribute.href(link.href)], [html.text(link.text)]),
    ]
  })
  |> list.append([charm])
}

fn shared_css() -> List(css.Global) {
  [
    // ---- Layout Containers ----
    // Standard page container - wraps main content
    css.global(".page-container", [
      css.flex("1"),
      css.padding(length.pt(10)),
      css.margin(length.pt(10)),
    ]),

    // Content wrapper for centered/sized content
    css.global(".content-wrapper", [
      css.width(length.percent(100)),
      css.max_width(length.pt(750)),
      css.margin_("auto"),
    ]),

    // Dead center - for 404 pages, login forms, etc.
    css.global(".dead-center", [
      css.position("absolute"),
      css.top(length.percent(50)),
      css.left(length.percent(50)),
      css.transform([
        transform.translate_x(length.percent(-50)),
        transform.translate_y(length.percent(-50)),
      ]),
      css.text_align("center"),
      css.background("#e0e0e0"),
      css.padding(length.pt(20)),
    ]),

    // ---- Box Styles ----
    // Standard box - light gray background
    css.global(".box", [
      css.background("#e0e0e0"),
      css.padding(length.pt(10)),
      css.margin(length.pt(10)),
    ]),

    // Darker box - for outer containers
    css.global(".box-dark", [
      css.background("lightgrey"),
      css.padding(length.pt(10)),
    ]),

    // Inner box - for nesting inside other boxes
    css.global(".box-inner", [
      css.background("#efefef"),
      css.padding(length.pt(10)),
    ]),

    // ---- Buttons ----
    // Base button style
    css.global(".btn", [
      css.display("inline-block"),
      css.padding(length.pt(2)),
      css.padding_left(length.pt(5)),
      css.padding_right(length.pt(5)),
      css.text_decoration("none"),
      css.font_family("monospace"),
      css.font_size(length.pt(10)),
      css.cursor("pointer"),
      css.border("1px solid #777"),
    ]),

    // Primary button - bold text style
    css.global(".btn-primary", [
      css.font_weight("bold"),
    ]),

    // Secondary button - normal style with hover
    css.global(".btn-secondary:hover", [
      css.text_decoration("underline"),
    ]),

    // Danger button - red text for destructive actions
    css.global(".btn-danger", [
      css.color("#cc0000"),
      css.font_weight("bold"),
    ]),

    // ---- Form Elements ----
    // Text inputs, selects, textareas
    css.global(".input", [
      css.font_family("monospace"),
      css.font_size(length.pt(10)),
      css.width(length.percent(100)),
      css.padding_("5px 0 5px 0"),
    ]),

    // Form group - label + input wrapper
    css.global(".form-group", [
      css.margin_bottom(length.pt(10)),
    ]),
    css.global(".form-group label", [
      css.display("block"),
      css.margin_bottom(length.px(5)),
      css.font_weight("bold"),
    ]),

    // Form row - for side-by-side inputs
    css.global(".form-row", [
      css.display("flex"),
      css.gap(length.px(20)),
      css.margin_bottom(length.px(10)),
      css.media(media.max_width(length.px(768)), [
        css.flex_direction("column"),
        css.gap(length.px(5)),
      ]),
    ]),
    css.global(".form-row .form-group", [
      css.flex("1"),
    ]),

    // ---- Tables ----
    // Standard table
    css.global(".table", [
      css.width(length.percent(100)),
      css.border_collapse("collapse"),
      css.margin_top(length.pt(10)),
    ]),
    css.global(".table th, .table td", [
      css.padding(length.px(8)),
      css.border("1px solid #777"),
      css.text_align("left"),
    ]),
    css.global(".table th", [
      css.background("#000"),
      css.color("#fff"),
      css.font_weight("bold"),
    ]),
    css.global(".table tr:nth-child(even)", [
      css.background("#e0e0e0"),
    ]),

    // ---- Lists ----
    // Clean list - no bullets, no padding
    css.global(".list-clean", [
      css.margin(length.px(0)),
      css.padding_left(length.px(0)),
      css.list_style("none"),
    ]),

    // List with dividers between items
    css.global(".list-divided li", [
      css.padding(length.px(5)),
    ]),

    // Grid list - items in a grid
    css.global(".list-grid", [
      css.display("grid"),
      css.grid_template_columns("repeat(auto-fill, minmax(200px, 1fr))"),
      css.gap(length.px(5)),
    ]),
    css.global(".list-grid li", [
      css.padding(length.px(5)),
    ]),

    // ---- Typography ----
    // Heading style
    css.global(".heading-bordered", [
      css.margin_top(length.px(0)),
      css.margin_bottom(length.pt(10)),
    ]),

    // Centered text
    css.global(".text-center", [
      css.text_align("center"),
    ]),

    // Muted text
    css.global(".text-muted", [
      css.color("#666"),
    ]),

    // ---- Navigation ----
    // Navigation bar
    css.global(".nav-bar", [
      css.display("flex"),
      css.justify_content("space-between"),
      css.align_items("center"),
      css.gap(length.pt(5)),
      css.margin_bottom(length.pt(10)),
    ]),

    // Navigation links
    css.global(".nav-links", [
      css.display("flex"),
      css.gap(length.px(10)),
    ]),

    // ---- Status/Labels ----
    css.global(".status-draft", [
      css.font_weight("bold"),
    ]),
    css.global(".status-published", [
      css.font_weight("bold"),
    ]),

    // ---- Utility ----
    // Scrollable container
    css.global(".scrollable", [
      css.max_height(length.px(300)),
      css.overflow_y("auto"),
    ]),

    // Flex row
    css.global(".flex-row", [
      css.display("flex"),
      css.gap(length.px(10)),
    ]),

    // Flex column
    css.global(".flex-col", [
      css.display("flex"),
      css.flex_direction("column"),
      css.gap(length.px(10)),
    ]),

    // Grid 2 columns
    css.global(".grid-2", [
      css.display("grid"),
      css.grid_template_columns("1fr 1fr"),
      css.gap(length.pt(10)),
      css.media(media.max_width(length.px(768)), [
        css.grid_template_columns("1fr"),
      ]),
    ]),

    // ---- Pagination ----
    // Pagination controls container
    css.global(".pagination-controls", [
      css.display("flex"),
      css.justify_content("center"),
      css.align_items("center"),
      css.gap(length.px(15)),
      css.margin_top(length.pt(15)),
      css.padding_top(length.pt(10)),
      css.border_top("1px solid #bbb"),
    ]),

    // Pagination info text
    css.global(".pagination-info", [
      css.color("#666"),
      css.font_size(length.pt(10)),
      css.font_weight("bold"),
    ]),

    // Disabled button state
    css.global(".btn-disabled", [
      css.opacity(0.5),
      css.cursor("not-allowed"),
      css.color("#999"),
    ]),
  ]
}

fn stylesheet(globals: List(css.Global)) -> String {
  case sketch.stylesheet(sketch.Ephemeral) {
    Error(_) -> {
      logging.error_ctx("BASE", "Failed to create sketch stylesheet")
      ""
    }
    Ok(stylesheet) -> {
      let base_globals = [
        css.global("body", [
          css.background_image("url('/assets/background.png');"),
          css.font_family("monospace"),
          css.font_size(length.pt(10)),
          css.margin(length.px(0)),
          css.height(length.percent(100)),
          css.min_height(length.vh(100)),
        ]),
        css.global(".center", [
          css.position("absolute"),
          css.left(length.percent(50)),
          css.transform([transform.translate_x(length.percent(-50))]),
          css.width(length.pt(750)),
          css.min_height(length.vh(100)),
          css.display("flex"),
          css.flex_direction("column"),
          css.background("lightgrey"),
          css.top(length.px(0)),
          css.media(media.max_width(length.px(768)), [
            css.position("unset"),
            css.left(length.percent(0)),
            css.transform([]),
            css.width(length.percent(100)),
            css.top(length.px(0)),
          ]),
        ]),
        css.global(".header", [
          css.width(length.percent(100)),
          css.background("black"),
          css.color("white"),
          css.margin_bottom_("auto"),
        ]),
        css.global(".banner", [
          css.height(length.px(100)),
          css.max_width(length.px(1000)),
          css.background_size("cover"),
          css.background_position("center"),
        ]),
        css.global(".top-banner", [
          css.background_image("url('" <> top_banner_image <> "')"),
        ]),
        css.global(".bottom-banner", [
          css.background_image("url('" <> bottom_banner_image <> "')"),
        ]),
        css.global(".toplinks, .bottomlinks", [
          css.display("flex"),
          css.overflow_x("auto"),
          css.width(length.percent(100)),
          css.justify_content("space-evenly"),
          css.align_items("center"),
          css.padding(length.pt(2)),
        ]),
        css.global(".toplinks a, .bottomlinks a", [css.color("white")]),
        css.global(".content", [
          css.display("flex"),
          css.flex_direction("row"),
          css.flex("1"),
          css.media(media.max_width(length.px(768)), [
            css.flex_direction("column"),
          ]),
        ]),
        css.global(".footer", [css.background("black"), css.margin_top_("auto")]),
        css.global(".charm", [
          css.width(length.px(10)),
          css.media(media.max_width(length.px(768)), [css.width(length.px(0))]),
        ]),
      ]

      let all_globals = list.flatten([base_globals, shared_css(), globals])

      stylesheet
      |> apply_globals(all_globals)
    }
  }
}

fn apply_globals(
  stylesheet: sketch.StyleSheet,
  globals: List(css.Global),
) -> String {
  globals
  |> list.fold(stylesheet, sketch.global)
  |> sketch.render
}

fn render_header() -> vnode.Element(String) {
  html.div([attribute.class("header")], [
    html.div([attribute.class("banner top-banner")], []),
    html.span([attribute.class("toplinks")], render_nav_links(top_links)),
  ])
}

fn render_footer() -> vnode.Element(String) {
  html.div([attribute.class("footer")], [
    html.div([attribute.class("bottomlinks")], render_nav_links(bottom_links)),
    html.div([attribute.class("banner bottom-banner")], []),
  ])
}

pub fn render_page(page: Page) {
  logging.debug_ctx("BASE", "Rendering page")

  html.html([attribute.lang("en")], [
    html.head([], [
      html.style([], stylesheet(page.css)),
      html.meta([
        attribute.name("viewport"),
        attribute.content("width=device-width, initial-scale=1.0"),
      ]),
      html.link([attribute.rel("icon"), attribute.href("/assets/logo.png")]),
      ..page.head
    ]),
    html.body([], [
      html.div([attribute.class("center")], [
        render_header(),
        html.div([attribute.class("content")], page.body),
        render_footer(),
      ]),
    ]),
  ])
  |> element.to_document_string_tree
}
