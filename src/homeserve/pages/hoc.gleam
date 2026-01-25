import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order
import gleam/string
import gleam/uri
import tempo/datetime
import wisp

import tempo.{Custom}

import homeserve/base
import homeserve/pages/errors
import homeserve/pages/panel
import lustre/attribute
import lustre/element/html
import sketch/css
import sketch/css/length
import sketch/css/media

// ---- Constants ----

const section_bg = "#e0e0e0"

// ---- Types ----

type ContributionType {
  Art
  Writing
  Music
  Misc
}

type Contribution {
  Contribution(
    name: String,
    type_: ContributionType,
    panel_index: Int,
    date: Int,
  )
}

type Contributor {
  Contributor(
    name: String,
    contributed_to: List(Int),
    types_of_contributions: List(ContributionType),
    first_contribution_date: Int,
  )
}

type Hoc {
  Hoc(sections: List(#(ContributionType, List(String))))
}

// ---- ContributionType helpers ----

fn contribution_type_to_string(t: ContributionType) -> String {
  case t {
    Art -> "Artists"
    Writing -> "Writers"
    Music -> "Musicians"
    Misc -> "Misc."
  }
}

fn contribution_type_rank(t: ContributionType) -> Int {
  case t {
    Art -> 0
    Writing -> 1
    Music -> 2
    Misc -> 3
  }
}

fn compare_types(a: ContributionType, b: ContributionType) -> order.Order {
  int.compare(contribution_type_rank(a), contribution_type_rank(b))
}

// ---- Data extraction ----

fn unique_contributors(panels: List(panel.Meta)) -> Hoc {
  let get_unique = fn(extractor) {
    panels |> list.flat_map(extractor) |> list.unique
  }

  Hoc(sections: [
    #(Art, get_unique(fn(p) { p.credits.artists })),
    #(Writing, get_unique(fn(p) { p.credits.writers })),
    #(Music, get_unique(fn(p) { p.credits.musicians })),
    #(Misc, get_unique(fn(p) { p.credits.misc })),
  ])
}

fn get_all_contributions(panels: List(panel.Meta)) -> List(Contribution) {
  panels
  |> list.flat_map(fn(meta) {
    let c = meta.credits
    list.flatten([
      list.map(c.artists, fn(n) { Contribution(n, Art, meta.index, meta.date) }),
      list.map(c.writers, fn(n) {
        Contribution(n, Writing, meta.index, meta.date)
      }),
      list.map(c.musicians, fn(n) {
        Contribution(n, Music, meta.index, meta.date)
      }),
      list.map(c.misc, fn(n) { Contribution(n, Misc, meta.index, meta.date) }),
    ])
  })
}

fn get_contributor_info(
  target_name: String,
  panels: List(panel.Meta),
) -> Option(Contributor) {
  wisp.log_debug("Looking up contributor: " <> target_name)

  let contributions =
    panels
    |> get_all_contributions
    |> list.filter(fn(c) { c.name == target_name })

  case contributions {
    [] -> {
      wisp.log_info("Contributor not found: " <> target_name)
      None
    }
    _ -> {
      let unique_panels =
        contributions
        |> list.map(fn(c) { c.panel_index })
        |> list.unique
        |> list.sort(int.compare)

      let unique_types =
        contributions
        |> list.map(fn(c) { c.type_ })
        |> list.unique
        |> list.sort(compare_types)

      wisp.log_debug(
        "Found contributor "
        <> target_name
        <> " with "
        <> int.to_string(list.length(unique_panels))
        <> " contributions",
      )

      // Find the earliest contribution date
      let first_contribution_date = case
        contributions
        |> list.map(fn(c) { c.date })
        |> list.sort(int.compare)
      {
        [] -> 0
        [date, ..] -> date
      }

      Some(Contributor(
        name: target_name,
        contributed_to: unique_panels,
        types_of_contributions: unique_types,
        first_contribution_date: first_contribution_date,
      ))
    }
  }
}

// ---- Rendering helpers ----

fn render_section(title: String, contributors: List(String)) {
  html.div([attribute.class("section")], [
    html.h2([], [html.text(title)]),
    html.ul(
      [],
      list.map(contributors, fn(name) {
        html.li([], [
          html.a([attribute.href("/hoc/" <> uri.percent_encode(name))], [
            html.text(name),
          ]),
        ])
      }),
    ),
  ])
}

fn type_to_singular(t: ContributionType) -> String {
  case t {
    Art -> "Art"
    Writing -> "Writing"
    Music -> "Music"
    Misc -> "Misc."
  }
}

/// Converts Unix timestamp to a human-readable year string.
///
/// Simple implementation that extracts the year from timestamp.
/// In production, you might want to use a proper date library
/// for more detailed formatting.
///
/// # Parameters
///
/// - `timestamp`: Unix timestamp in seconds
///
/// # Returns
///
/// String in format "YYYY-MM-DD"
fn format_date(timestamp: Int) -> String {
  datetime.format(
    datetime.from_unix_milli(timestamp * 1000),
    Custom("YYYY-MM-DD"),
  )
}

// ---- Page builders ----

pub fn build_hoc(panels: List(panel.Meta)) -> base.Page {
  wisp.log_debug("Building Hall of Contributors page")

  let hoc = unique_contributors(panels)

  let total_contributors =
    hoc.sections
    |> list.flat_map(fn(s) { s.1 })
    |> list.unique
    |> list.length

  wisp.log_info(
    "Hall of Contributors: "
    <> int.to_string(total_contributors)
    <> " unique contributors across "
    <> int.to_string(list.length(panels))
    <> " panels",
  )

  let head = [html.title([], "The Hall of Contributors")]

  let css = [
    css.global(".section", [
      css.background(section_bg),
      css.flex("1"),
      css.height(length.percent(100)),
      css.margin(length.pt(10)),
      css.padding(length.pt_(2.5)),
    ]),
    css.global(".title", [
      css.width(length.percent(100)),
      css.text_align("center"),
    ]),
    css.global(".sections", [
      css.display("flex"),
      css.flex_direction("column"),
      css.min_height(length.vh(100)),
      css.height_("auto"),
    ]),
    css.global(".content", [css.min_height_("inherit")]),
  ]

  let body = [
    html.div([attribute.class("title")], [
      html.h1([], [html.text("The Hall of Contributors")]),
    ]),
    html.div(
      [attribute.class("sections")],
      list.map(hoc.sections, fn(section) {
        render_section(contribution_type_to_string(section.0), section.1)
      }),
    ),
  ]

  base.Page(head:, css:, body:)
}

pub fn build_contributor(
  contributor: String,
  panels: List(panel.Meta),
) -> base.Page {
  wisp.log_debug("Building contributor page for: " <> contributor)

  case get_contributor_info(contributor, panels) {
    None -> {
      wisp.log_warning(
        "Contributor page requested but not found: " <> contributor,
      )
      errors.build_error(404, "Contributor not found")
    }
    Some(stats) -> {
      wisp.log_debug(
        "Rendering contributor page for "
        <> contributor
        <> " with "
        <> int.to_string(list.length(stats.contributed_to))
        <> " panels",
      )

      let head = [html.title([], "Contributor: " <> contributor)]

      let css = [
        css.global(".contributor", [
          css.display("flex"),
          css.flex("1"),
          css.flex_direction("row"),
          css.padding(length.pt(10)),
          css.media(media.max_width(length.px(768)), [
            css.flex_direction("column"),
          ]),
        ]),
        css.global(".contributor_main", [
          css.display("flex"),
          css.flex("1"),
          css.flex_direction("column"),
          css.max_width(length.percent(50)),
          css.margin(length.pt(10)),
          css.padding(length.pt(10)),
          css.background(section_bg),
          css.media(media.max_width(length.px(768)), [
            css.max_width(length.percent(100)),
            css.height_("auto"),
          ]),
        ]),
        css.global(".contributor_side", [
          css.width(length.percent(50)),
          css.margin(length.pt(10)),
          css.padding(length.pt(10)),
          css.background(section_bg),
          css.media(media.max_width(length.px(768)), [
            css.width_("auto"),
            css.height_("auto"),
          ]),
        ]),
      ]

      let body = [
        html.div([attribute.class("contributor")], [
          html.div([attribute.class("contributor_main")], [
            html.h1([], [html.text(contributor)]),
            html.p([], [
              html.text(
                "Total Contributions: "
                <> int.to_string(list.length(stats.contributed_to)),
              ),
            ]),
            html.p([], [
              html.text(
                "Types of Contribution: "
                <> stats.types_of_contributions
                |> list.map(type_to_singular)
                |> string.join(", "),
              ),
            ]),
            html.p([], [
              html.text(
                "First Contribution: "
                <> format_date(stats.first_contribution_date),
              ),
            ]),
          ]),
          html.div([attribute.class("contributor_side")], [
            html.h2([], [html.text("Panels Contributed:")]),
            html.ul(
              [],
              list.filter_map(stats.contributed_to, fn(panel_index) {
                case panel.decode_meta(panel_index) {
                  Error(_) -> {
                    wisp.log_warning(
                      "Failed to decode panel meta for index "
                      <> int.to_string(panel_index)
                      <> " while building contributor page",
                    )
                    Error(Nil)
                  }
                  Ok(panel_meta) ->
                    Ok(
                      html.li([], [
                        html.a(
                          [
                            attribute.href(
                              "/read/" <> int.to_string(panel_index),
                            ),
                          ],
                          [html.text(panel_meta.title)],
                        ),
                      ]),
                    )
                }
              }),
            ),
          ]),
        ]),
      ]

      base.Page(head:, css:, body:)
    }
  }
}
