//// Hall of Contributors
////
//// Lists all contributors to the project based on panel credits from Mnesia.

import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order
import gleam/string
import gleam/uri
import tempo.{Custom}
import tempo/datetime

import homeserve/base
import homeserve/db
import homeserve/pages/errors
import homeserve/pages/panel/types
import homeserve/pagination

import lustre/attribute
import lustre/element
import lustre/element/html
import sketch/css
import sketch/css/length

// ---- Constants ----

/// Number of panels to display per page on contributor pages
const panels_per_page = 10

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

fn type_to_label(t: ContributionType) -> String {
  case t {
    Art -> "ARTISTS"
    Writing -> "WRITERS"
    Music -> "MUSICIANS"
    Misc -> "MISC."
  }
}

fn type_to_singular(t: ContributionType) -> String {
  case t {
    Art -> "Art"
    Writing -> "Writing"
    Music -> "Music"
    Misc -> "Misc."
  }
}

// ---- Data extraction ----

fn unique_case_insensitive(names: List(String)) -> List(String) {
  let fold_fn = fn(acc: List(String), name: String) {
    let normalized = normalize_name(name)
    let already_exists =
      list.any(acc, fn(existing) { normalize_name(existing) == normalized })
    case already_exists {
      True -> acc
      False -> [name, ..acc]
    }
  }
  list.fold(names, [], fold_fn)
  |> list.reverse
}

fn unique_contributors(panels: List(types.Meta)) -> Hoc {
  let get_unique = fn(extractor) {
    panels
    |> list.flat_map(extractor)
    |> unique_case_insensitive
    |> list.sort(fn(a, b) {
      string.compare(normalize_name(a), normalize_name(b))
    })
  }

  Hoc(sections: [
    #(Art, get_unique(fn(p) { p.credits.artists })),
    #(Writing, get_unique(fn(p) { p.credits.writers })),
    #(Music, get_unique(fn(p) { p.credits.musicians })),
    #(Misc, get_unique(fn(p) { p.credits.misc })),
  ])
}

fn get_all_contributions(panels: List(types.Meta)) -> List(Contribution) {
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

fn normalize_name(name: String) -> String {
  string.trim(name) |> string.lowercase
}

fn get_contributor_info(
  target_name: String,
  panels: List(types.Meta),
) -> Option(Contributor) {
  let normalized_target = normalize_name(target_name)

  let contributions =
    panels
    |> get_all_contributions
    |> list.filter(fn(c) { normalize_name(c.name) == normalized_target })

  case contributions {
    [] -> None
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

      let first_contribution_date = case
        contributions
        |> list.map(fn(c) { c.date })
        |> list.sort(int.compare)
      {
        [] -> 0
        [date, ..] -> date
      }

      let original_name = case contributions {
        [first, ..] -> first.name
        [] -> target_name
      }

      Some(Contributor(
        name: original_name,
        contributed_to: unique_panels,
        types_of_contributions: unique_types,
        first_contribution_date: first_contribution_date,
      ))
    }
  }
}

fn get_section_contributors(
  hoc: Hoc,
  section_type: ContributionType,
) -> List(String) {
  case list.find(hoc.sections, fn(section) { section.0 == section_type }) {
    Ok(found_section) -> found_section.1
    Error(_) -> []
  }
}

fn format_date(timestamp: Int) -> String {
  datetime.format(
    datetime.from_unix_milli(timestamp * 1000),
    Custom("YYYY-MM-DD"),
  )
}

// ---- Rendering helpers ----

fn render_contributor_list(contributors: List(String)) {
  html.ul(
    [attribute.class("list-clean list-grid")],
    list.map(contributors, fn(name) {
      html.li([], [
        html.a([attribute.href("/hoc/" <> uri.percent_encode(name))], [
          html.text(name),
        ]),
      ])
    }),
  )
}

// ---- Page builders ----

pub fn build_hoc(panels: List(types.Meta)) -> base.Page {
  let hoc = unique_contributors(panels)

  let total_contributors =
    hoc.sections
    |> list.flat_map(fn(s) { s.1 })
    |> list.unique
    |> list.length

  let head = [html.title([], "Hall of Contributors")]

  let css = [
    css.global(".hoc-stats", [
      css.text_align("center"),
      css.margin_bottom(length.pt(20)),
    ]),
  ]

  let body = [
    html.div([attribute.class("page-container box-dark")], [
      html.h1([attribute.class("heading-bordered text-center")], [
        html.text("HALL OF CONTRIBUTORS"),
      ]),
      html.p([attribute.class("hoc-stats text-muted")], [
        html.text(int.to_string(total_contributors) <> " CONTRIBUTORS"),
      ]),
      html.div([attribute.class("box")], [
        html.h2([attribute.class("heading-bordered")], [
          html.text(type_to_label(Art)),
        ]),
        html.hr([]),
        render_contributor_list(get_section_contributors(hoc, Art)),
      ]),
      html.div([attribute.class("box")], [
        html.h2([attribute.class("heading-bordered")], [
          html.text(type_to_label(Writing)),
        ]),
        html.hr([]),
        render_contributor_list(get_section_contributors(hoc, Writing)),
      ]),
      html.div([attribute.class("box")], [
        html.h2([attribute.class("heading-bordered")], [
          html.text(type_to_label(Music)),
        ]),
        html.hr([]),
        render_contributor_list(get_section_contributors(hoc, Music)),
      ]),
      html.div([attribute.class("box")], [
        html.h2([attribute.class("heading-bordered")], [
          html.text(type_to_label(Misc)),
        ]),
        html.hr([]),
        render_contributor_list(get_section_contributors(hoc, Misc)),
      ]),
    ]),
  ]

  base.Page(head:, css:, body:)
}

/// Build contributor page with optional pagination.
/// Returns the HTTP status code alongside the page.
pub fn build_contributor(
  contributor: String,
  panels: List(types.Meta),
  current_page: Int,
) -> #(Int, base.Page) {
  let volunteer_info = case db.load_volunteer(contributor) {
    Ok(volunteer) -> Some(volunteer)
    Error(_) -> None
  }

  case get_contributor_info(contributor, panels) {
    None -> #(404, errors.build_error(404, "Contributor not found"))
    Some(stats) -> {
      let head = [html.title([], "Contributor: " <> contributor)]

      let css = [
        css.global(".contributor-header", [
          css.margin_bottom(length.pt(15)),
          css.padding_bottom(length.pt(10)),
        ]),
        css.global(".contributor-stats", [
          css.display("flex"),
          css.gap(length.px(20)),
          css.flex_wrap("wrap"),
        ]),
        css.global(".volunteer-info", [
          css.margin_top(length.pt(15)),
          css.padding_top(length.pt(10)),
        ]),
        css.global(".pagination-controls", [
          css.display("flex"),
          css.justify_content("center"),
          css.align_items("center"),
          css.gap(length.px(15)),
          css.margin_top(length.pt(15)),
          css.padding_top(length.pt(10)),
          css.border_top("1px solid #444"),
        ]),
        css.global(".pagination-info", [
          css.color("#888"),
          css.font_size(length.pt(12)),
        ]),
      ]

      let volunteer_section = case volunteer_info {
        Some(volunteer) -> [
          html.div([attribute.class("volunteer-info")], [
            html.h3([attribute.class("heading-bordered")], [
              html.text("VOLUNTEER INFO"),
            ]),
            html.p([], [html.text(volunteer.bio)]),
            case volunteer.social_links {
              [] -> element.none()
              links ->
                html.ul(
                  [attribute.class("list-clean")],
                  list.map(links, fn(link) {
                    html.li([], [
                      html.a([attribute.href(link)], [html.text(link)]),
                    ])
                  }),
                )
            },
          ]),
        ]
        None -> []
      }

      // Calculate pagination
      let total_panels = list.length(stats.contributed_to)
      let total_pages =
        pagination.calculate_total_pages(total_panels, panels_per_page)
      let clamped_page = pagination.clamp_page(current_page, total_pages)

      // Get paginated panels
      let paginated_panels =
        pagination.get_page(stats.contributed_to, clamped_page, panels_per_page)

      let pagination_controls =
        render_contributor_pagination(
          contributor,
          clamped_page,
          total_pages,
          total_panels,
        )

      let panels_list_html =
        html.div([attribute.class("box-inner")], [
          html.h2([attribute.class("heading-bordered")], [
            html.text("PANELS (" <> int.to_string(total_panels) <> ")"),
          ]),
          html.ul(
            [attribute.class("list-clean list-divided scrollable")],
            list.filter_map(paginated_panels, fn(panel_index) {
              case db.load_panel(panel_index) {
                Error(_) -> Error(Nil)
                Ok(panel) ->
                  Ok(
                    html.li([], [
                      html.a(
                        [
                          attribute.href("/read/" <> int.to_string(panel_index)),
                        ],
                        [
                          html.text(
                            "#"
                            <> int.to_string(panel_index)
                            <> " "
                            <> panel.meta.title,
                          ),
                        ],
                      ),
                    ]),
                  )
              }
            }),
          ),
          pagination_controls,
        ])

      let body = [
        html.div([attribute.class("page-container box")], [
          html.div([attribute.class("contributor-header")], [
            html.h1([], [html.text(contributor)]),
            html.div([attribute.class("contributor-stats text-muted")], [
              html.span([], [
                html.text(
                  "CONTRIBUTIONS: "
                  <> int.to_string(list.length(stats.contributed_to)),
                ),
              ]),
              html.span([], [
                html.text(
                  "TYPES: "
                  <> string.join(
                    list.map(stats.types_of_contributions, type_to_singular),
                    ", ",
                  ),
                ),
              ]),
              html.span([], [
                html.text(
                  "SINCE: " <> format_date(stats.first_contribution_date),
                ),
              ]),
            ]),
          ]),
          html.div([attribute.class("grid-2")], [
            html.div([attribute.class("box-inner")], [
              html.h2([attribute.class("heading-bordered")], [html.text("INFO")]),
              html.p([], [
                html.text(
                  "Total panels contributed to: "
                  <> int.to_string(list.length(stats.contributed_to)),
                ),
              ]),
              html.p([], [
                html.text(
                  "First contribution: "
                  <> format_date(stats.first_contribution_date),
                ),
              ]),
              ..volunteer_section
            ]),
            panels_list_html,
          ]),
        ]),
      ]

      #(200, base.Page(head:, css:, body:))
    }
  }
}

/// Render pagination controls for contributor page
fn render_contributor_pagination(
  contributor: String,
  current_page: Int,
  total_pages: Int,
  total_items: Int,
) {
  case total_pages <= 1 {
    True -> element.none()
    False -> {
      let prev_button = case current_page > 1 {
        True ->
          html.a(
            [
              attribute.href(
                "/hoc/"
                <> uri.percent_encode(contributor)
                <> "?page="
                <> int.to_string(current_page - 1),
              ),
              attribute.class("btn btn-secondary"),
            ],
            [html.text("← Previous")],
          )
        False ->
          html.span([attribute.class("btn btn-disabled")], [
            html.text("← Previous"),
          ])
      }

      let next_button = case current_page < total_pages {
        True ->
          html.a(
            [
              attribute.href(
                "/hoc/"
                <> uri.percent_encode(contributor)
                <> "?page="
                <> int.to_string(current_page + 1),
              ),
              attribute.class("btn btn-secondary"),
            ],
            [html.text("Next →")],
          )
        False ->
          html.span([attribute.class("btn btn-disabled")], [
            html.text("Next →"),
          ])
      }

      let page_info =
        html.span([attribute.class("pagination-info")], [
          html.text(
            "Page "
            <> int.to_string(current_page)
            <> " of "
            <> int.to_string(total_pages)
            <> " ("
            <> int.to_string(total_items)
            <> " panels)",
          ),
        ])

      html.div([attribute.class("pagination-controls")], [
        prev_button,
        page_info,
        next_button,
      ])
    }
  }
}
