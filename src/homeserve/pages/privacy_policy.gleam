import lustre/attribute
import lustre/element/html
import sketch/css
import sketch/css/length
import sketch/css/transform

import homeserve/base

pub fn build_privacy_policy() -> base.Page {
  let head = [html.title([], "Privacy Policy")]
  let css = [
    css.global(".dead_center", [
      css.position("absolute"),
      css.width(length.percent(50)),
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
      html.h1([], [html.text("Privacy Policy")]),
      html.p([], [
        html.text(
          "We do not store or process any of your data. Our Webserver (Caddy) does not log your IP address or any other identifying information.",
        ),
      ]),
      html.p([], [
        html.text(
          "When you use the \"Toggle Quirks\" button, we store exactly one cookie, called \"quirked\" with a simple base64-encoded boolean value. This cookie is used only to remember your choice about rendering character quirks, and to control whether they are rendered.",
        ),
      ]),
      html.p([], [
        html.text(
          "This cookie is not used for tracking, analytics, or advertising. You can delete this cookie at any time via your browser settings. It is only set if you press the \"Toggle Quirks\" button.",
        ),
      ]),
      html.p([], [
        html.text(
          "You have the right to know what data we collect (none) and to contact us with any privacy concerns (also hopefully none).",
        ),
      ]),
      html.p([], [
        html.text(
          "If you have any concerns regarding your privacy, please email ",
        ),
        html.a([attribute.href("mailto:michal@adastra.wtf")], [
          html.text("michal@adastra.wtf"),
        ]),
        html.text(
          ". We strive to comply with all relevant privacy laws, including the GDPR and PECR.",
        ),
      ]),
    ]),
  ]

  base.Page(head:, css:, body:)
}
