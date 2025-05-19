import lustre/attribute
import lustre/element
import lustre/element/html
import sketch
import sketch/css
import sketch/css/length
import sketch/css/media
import sketch/css/transform

fn stylesheet() -> String {
  let assert Ok(stylesheet) = sketch.stylesheet(sketch.Persistent)

  stylesheet
  |> apply_globals([
    css.global("body", [
      css.background("grey"),
      css.background_position("fit"),
      css.font_family("monospace"),
      css.font_size(length.pt(10)),
      css.margin(length.px(0)),
    ]),
    css.global(".center", [
      css.position("absolute"),
      css.left(length.percent(50)),
      css.transform([transform.translate_x(length.percent(-50))]),
      css.width(length.percent(75)),
      css.min_height(length.vb(100)),
      css.background("lightgrey"),
      css.media(media.max_width(length.px(768)), [
        css.left(length.percent(0)),
        css.transform([]),
        css.width(length.percent(100)),
        css.height(length.percent(100)),
      ]),
    ]),
    css.global(".topbar", [
      css.width(length.percent(100)),
      css.background("black"),
      css.color("white"),
    ]),
    css.global(".banner", [css.height(length.px(100))]),
    css.global(".banner img", [
      css.object_fit("cover"),
      css.height(length.px(100)),
      css.object_position("right top"),
      css.position("relative"),
    ]),
    css.global(".toplinks", [
      css.display("flex"),
      css.overflow_x("auto"),
      css.width(length.percent(100)),
      css.justify_content("space-evenly"),
      css.align_items("center"),
      css.padding(length.pt(2)),
    ]),
    css.global(".toplinks a", [css.color("white")]),
    css.global(".content", [
      css.display("flex"),
      css.flex_direction("row"),
      css.width(length.percent(100)),
      css.min_height(length.vh(80)),
      css.media(media.max_width(length.px(768)), [css.flex_direction("column")]),
      css.media(media.min_width(length.px(769)), []),
    ]),
    css.global(".footer", [css.background("black"), css.color("white")]),
    css.global(".bottom_info", [
      css.display("flex"),
      css.overflow_x("auto"),
      css.width(length.percent(100)),
      css.justify_content("space-evenly"),
      css.align_items("center"),
      css.padding(length.pt(2)),
    ]),
    css.global(".bottom_info, .toplinks", [css.height(length.px(22))]),
    // Homepage-specific
    css.global(".content_left", [
      css.flex("1"),
      css.display("flex"),
      css.media(media.max_width(length.px(768)), [css.flex("auto")]),
    ]),
    css.global(".content_right", [
      css.flex("1"),
      css.display("flex"),
      css.flex_direction("column"),
      css.media(media.max_width(length.px(768)), [css.flex("auto")]),
    ]),
    css.global(".panels, .socials, .about", [
      css.background("#e0e0e0"),
      css.flex("1"),
      css.margin(length.pt(10)),
      css.padding(length.pt_(2.5)),
      css.media(media.max_width(length.px(768)), [css.min_height(length.vh(15))]),
    ]),
    // Panel-specific
    css.global(".page_margins", [
      css.transform([transform.translate_x(length.percent(30))]),
      css.width(length.percent(65)),
      css.media(media.max_width(length.px(768)), [
        css.transform([]),
        css.width(length.percent(100)),
      ]),
    ]),
    css.global(".page_outer", [
      css.flex("1"),
      css.display("flex"),
      css.flex_direction("column"),
      css.background("white"),
    ]),
    css.global(".page_outer h2", [css.text_align("center")]),
    css.global(".page_outer img,video", [css.margin_bottom(length.pt(10))]),
    css.global(".page_inner", [
      css.text_align("center"),
      css.margin_bottom(length.rlh(1.0)),
    ]),
    css.global(".next", [css.font_size(length.pt(16)), css.margin(length.pt(5))]),
    css.global(".bottom_links", [
      css.display("flex"),
      css.margin(length.pt(5)),
      css.margin_top(length.pt(0)),
    ]),
    css.global(".credits", [
      css.color("gray"),
      css.margin(length.pt(5)),
      css.margin_bottom(length.pt(0)),
    ]),
    css.global(".bottom_links a:last-child", [css.margin_left_("auto")]),
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

pub fn render_page(head_elements: List(_), body_elements: List(_)) {
  html.html([attribute.lang("en")], [
    html.head([], [
      html.style([], stylesheet()),
      html.meta([
        attribute.name("viewport"),
        attribute.content("width=device-width, initial-scale=1.0"),
      ]),
      ..head_elements
    ]),
    html.body([], [
      html.div([attribute.class("center")], [
        html.div([attribute.class("topbar")], [
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
        html.div([attribute.class("content")], body_elements),
        html.div([attribute.class("footer")], [
          html.div([attribute.class("bottom_info")], [
            html.p([], [html.text("Made with <3 in Wisp!")]),
            html.a([], [
              html.text("Made real by our incredible team of Volunteers!"),
            ]),
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
