import lustre/attribute
import lustre/element/html
import sketch/css
import sketch/css/length

import homeserve/base

/// Builds the privacy policy page.
///
/// Covers: data collection (minimal), cookie usage (functional only),
/// user rights, and contact information.
pub fn build_privacy_policy(contact_email: String) -> base.Page {
  let head = [html.title([], "Privacy Policy")]
  let css = [
    css.global(".policy-box", [
      css.text_align("justify"),
      css.background("#e0e0e0"),
      css.padding(length.pt(10)),
      css.margin(length.pt(10)),
    ]),
  ]
  let body = [
    html.div([attribute.class("policy-box")], [
      html.h1([], [html.text("Privacy Policy")]),
      html.p([], [
        html.text("Last updated: February 2026"),
      ]),
      html.h2([], [html.text("Data Collection")]),
      html.p([], [
        html.text("This server collects minimal data necessary for operation:"),
      ]),
      html.ul([], [
        html.li([], [
          html.text("No IP addresses are logged or stored"),
        ]),
        html.li([], [
          html.text("No analytics or tracking cookies are used"),
        ]),
      ]),
      html.h2([], [html.text("Cookies")]),
      html.p([], [
        html.text("We use functional cookies only:"),
      ]),
      html.ul([], [
        html.li([], [
          html.text("quirked: Your character quirk preference (on/off)"),
        ]),
        html.li([], [
          html.text("animated: Your animation preference (on/off)"),
        ]),
        html.li([], [
          html.text(
            "csrf_token: Security token for admin forms (only when using admin panel)",
          ),
        ]),
      ]),
      html.p([], [
        html.text(
          "These cookies contain no personal data and are not used for tracking or advertising. "
          <> "They expire after one year or when you delete them.",
        ),
      ]),
      html.h2([], [html.text("Your Rights")]),
      html.ul([], [
        html.li([], [
          html.text(
            "Transparency: This policy clearly states what data is handled",
          ),
        ]),
        html.li([], [
          html.text(
            "Control: Delete cookies anytime through your browser settings",
          ),
        ]),
        html.li([], [
          html.text("Questions: Contact us with any privacy concerns"),
        ]),
      ]),
      html.h2([], [html.text("Contact")]),
      html.p([], [
        html.text("For privacy questions: "),
        html.a([attribute.href("mailto:" <> contact_email)], [
          html.text(contact_email),
        ]),
      ]),
      html.p([], [
        html.text(
          "This policy may be updated periodically. Changes will be posted here.",
        ),
      ]),
    ]),
  ]

  base.Page(head:, css:, body:)
}
