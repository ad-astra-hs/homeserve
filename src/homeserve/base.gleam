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

fn stylesheet(globals: List(css.Global)) -> String {
  let assert Ok(stylesheet) = sketch.stylesheet(sketch.Persistent)

  stylesheet
  |> apply_globals([
    css.global("body", [
      css.background("grey"),
      css.font_family("monospace"),
      css.font_size(length.pt(10)),
      css.margin(length.px(0)),
    ]),
    css.global(".center", [
      css.position("absolute"),
      css.left(length.percent(50)),
      css.transform([transform.translate_x(length.percent(-50))]),
      css.width(length.pt(750)),
      css.min_height(length.pt(600)),
      css.height_("auto"),
      css.display("flex"),
      css.flex_direction("column"),
      css.background("lightgrey"),
      css.media(media.max_width(length.px(768)), [
        css.position("unset"),
        css.left(length.percent(0)),
        css.transform([]),
        css.width(length.percent(100)),
        css.height(length.percent(100)),
      ]),
    ]),
    css.global(".header", [
      css.width(length.percent(100)),
      css.background("black"),
      css.color("white"),
      css.margin_bottom_("auto"),
    ]),
    css.global(".banner", [css.height(length.px(100))]),
    css.global(".banner img", [
      css.object_fit("cover"),
      css.height(length.px(100)),
      css.object_position("right top"),
      css.position("relative"),
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
      css.media(media.max_width(length.px(768)), [css.flex_direction("column")]),
    ]),
    css.global(".footer", [css.background("black"), css.margin_top_("auto")]),
    ..globals
  ])
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

pub fn render_page(page: Page) {
  html.html([attribute.lang("en")], [
    html.head([], [
      html.style([], stylesheet(page.css)),
      html.meta([
        attribute.name("viewport"),
        attribute.content("width=device-width, initial-scale=1.0"),
      ]),
      ..page.head
    ]),
    html.body([], [
      html.div([attribute.class("center")], [
        html.div([attribute.class("header")], [
          html.div([attribute.class("banner")], [
            html.img([
              attribute.src("/assets/background.png"),
              attribute.style("width", "100%"),
            ]),
            html.img([
              attribute.src("/assets/logo.png"),
              attribute.style("top", "-102.5px"),
            ]),
          ]),
          html.span([attribute.class("toplinks")], [
            html.a([attribute.href("/")], [html.text("Home")]),
            html.a([attribute.href("/read")], [html.text("Read")]),
            html.a([attribute.href("/play")], [html.text("Play")]),
            html.a([attribute.href("/apply")], [html.text("Apply")]),
          ]),
        ]),
        html.div([attribute.class("content")], page.body),
        html.div([attribute.class("footer")], [
          html.div([attribute.class("bottomlinks")], [
            html.a([attribute.href("https://codeberg.org/ad-astra/homeserve")], [
              html.text("Source Code"),
            ]),
            html.a([attribute.href("/hoc")], [html.text("Volunteers")]),
            html.a([attribute.href("/privacy")], [html.text("Privacy Policy")]),
          ]),
          html.div([attribute.class("banner")], [
            html.img([
              attribute.src("/assets/background.png"),
              attribute.style("width", "100%"),
            ]),
          ]),
        ]),
      ]),
    ]),
  ])
  |> element.to_document_string_tree
}
