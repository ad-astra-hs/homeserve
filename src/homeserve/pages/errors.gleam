/// Error Page Builders
///
/// Generates error pages (404, 500, etc.) with consistent styling.
import gleam/int

import lustre/attribute
import lustre/element/html
import sketch/css
import sketch/css/length
import sketch/css/transform
import wisp

import homeserve/base

pub fn build_error(code: Int, message: String) -> base.Page {
  let code_str = int.to_string(code)

  // Log based on error severity
  case code {
    code if code >= 500 ->
      wisp.log_error("Server error " <> code_str <> ": " <> message)
    code if code >= 400 ->
      wisp.log_warning("Client error " <> code_str <> ": " <> message)
    _ -> wisp.log_info("Error page " <> code_str <> ": " <> message)
  }

  let head = [html.title([], "Error " <> code_str)]
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
      html.h1([], [html.text("Error " <> code_str)]),
      html.p([], [html.text(message)]),
      html.h3([], [
        html.text("You are in a maze of twisty little passages, all alike. "),
        html.text("Unfortunately for you, this one has lead you nowhere."),
      ]),
      html.h2([], [html.a([attribute.href("/")], [html.text("> Return")])]),
    ]),
  ]

  base.Page(head:, css:, body:)
}

pub fn build_404() -> base.Page {
  build_error(404, "Page not found")
}

pub fn build_500(message: String) -> base.Page {
  build_error(500, message)
}
