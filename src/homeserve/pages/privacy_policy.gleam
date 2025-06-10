import lustre/attribute
import lustre/element/html
import sketch/css
import sketch/css/length

import homeserve/base

pub fn build_privacy_policy() -> base.Page {
  let head = [html.title([], "Privacy Policy")]
  let css = [
    css.global(".dead_center", [
      css.text_align("justify"),
      css.background("#e0e0e0"),
      css.padding(length.pt(10)),
      css.margin(length.pt(10)),
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
          "When you use the \"Quirks\" or \"Animations\" buttons, we store exactly two cookies, called \"quirked\", and \"animated\", each with a simple base64-encoded boolean value. These cookies are used only to remember your choices about rendering either character quirks or static images (as opposed to animated gifs).",
        ),
      ]),
      html.p([], [
        html.text(
          "These cookies are not used for tracking, analytics, or advertising. You can delete these cookies at any time via your browser settings. They are only set if you press the relevant buttons.",
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
