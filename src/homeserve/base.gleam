import gleam/list

import lustre/attribute
import lustre/element
import lustre/element/html
import lustre/vdom/vnode
import sketch
import sketch/css
import sketch/css/length
import sketch/css/media
import sketch/css/transform
import wisp

// ---- Types ----

pub type Page {
  Page(
    head: List(vnode.Element(String)),
    css: List(css.Global),
    body: List(vnode.Element(String)),
  )
}

// ---- Constants ----

const top_banner_image = "/assets/top_banner.png"

const bottom_banner_image = "/assets/bottom_banner.png"

const charm_image = "/assets/symbolic.svg"

// ---- Navigation ----

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

// ---- Stylesheet ----

fn stylesheet(globals: List(css.Global)) -> String {
  case sketch.stylesheet(sketch.Persistent) {
    Error(_) -> {
      wisp.log_error("Failed to create sketch stylesheet")
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
          css.min_height_("100%"),
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

      stylesheet
      |> apply_globals(list.append(base_globals, globals))
    }
  }
}

fn apply_globals(
  stylesheet: sketch.StyleSheet,
  globals: List(css.Global),
) -> String {
  case globals {
    [] -> sketch.render(stylesheet)
    [global, ..rest] -> apply_globals(sketch.global(stylesheet, global), rest)
  }
}

// ---- Page rendering ----

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
  wisp.log_debug("Rendering page")

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
