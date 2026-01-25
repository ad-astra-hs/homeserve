import lustre/attribute
import lustre/element/html
import sketch/css
import sketch/css/length

import homeserve/base

/// Builds the privacy policy page with current, comprehensive privacy information.
/// 
/// The policy covers data collection (none), cookie usage (functional only),
/// user rights, legal compliance, and contact information.
/// 
/// # Returns
/// 
/// Complete privacy policy page with modern styling
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
        html.text("Last updated: January 2026"),
      ]),
      html.h2([], [html.text("Data Collection")]),
      html.p([], [
        html.text(
          "We do not collect, store, or process any personal data. Our web server does not log IP addresses or other identifying information.",
        ),
      ]),
      html.h2([], [html.text("Cookies")]),
      html.p([], [
        html.text("We use two optional functional cookies:"),
      ]),
      html.ul([], [
        html.li([], [
          html.text("quirked: Remembers character quirk preferences"),
        ]),
        html.li([], [html.text("animated: Remembers animation settings")]),
      ]),
      html.p([], [
        html.text(
          "These cookies contain only boolean values and are set only when you click the respective toggle buttons. They are not used for tracking, analytics, or advertising.",
        ),
      ]),
      html.h2([], [html.text("Your Rights")]),
      html.ul([], [
        html.li([], [
          html.text("Access: You know exactly what data we collect (none)"),
        ]),
        html.li([], [
          html.text("Control: Cookies are optional and can be deleted anytime"),
        ]),
        html.li([], [html.text("Contact: Reach us with privacy questions")]),
      ]),
      html.h2([], [html.text("Legal Compliance")]),
      html.p([], [
        html.text(
          "We comply with applicable privacy laws including GDPR and PECR. Our minimal data collection approach naturally respects privacy by design.",
        ),
      ]),
      html.h2([], [html.text("Contact")]),
      html.p([], [
        html.text("For privacy concerns: "),
        html.a([attribute.href("mailto:michal@adastra.wtf")], [
          html.text("michal@adastra.wtf"),
        ]),
      ]),
      html.p([], [
        html.text(
          "This policy may be updated as needed. Changes will be reflected here.",
        ),
      ]),
    ]),
  ]

  base.Page(head:, css:, body:)
}
