import lustre/attribute
import lustre/element/html
import sketch/css
import sketch/css/length
import sketch/css/transform

import homeserve/base

pub fn build_404() -> base.Page {
  let head = [html.title([], "Error 404")]
  let css = [
    css.global(".dead_center", [
      css.position("absolute"),
      css.top(length.percent(50)),
      css.left(length.percent(50)),
      css.transform([
        transform.translate_x(length.percent(-50)),
        transform.translate_y(length.percent(-50)),
      ]),
      css.text_align("justify"),
      css.background("#e0e0e0"),
      css.padding(length.pt(10)),
    ]),
  ]
  let body = [
    html.div([attribute.class("dead_center")], [
      html.h1([], [html.text("Error 404: Not Found")]),
      html.h3([], [
        html.text("You are in a maze of twisty little passages, all alike. "),
        html.text("Unfortunately for you, this one has lead you nowhere."),
      ]),
      html.h2([], [html.a([attribute.href("/")], [html.text("> Return")])]),
    ]),
  ]

  base.Page(head:, css:, body:)
}
