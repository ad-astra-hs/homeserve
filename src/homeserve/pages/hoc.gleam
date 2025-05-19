import gleam/int
import gleam/list
import gleam/order
import gleam/string
import sketch/css/media
import tempo
import tempo/date

import homeserve/pages/panel
import lustre/attribute
import lustre/element/html
import sketch/css
import sketch/css/length

import homeserve/base

type Contributor {
  Contributor(
    name: String,
    contributed_to: List(Int),
    types_of_contributions: List(ContributionType),
    first_contribution: tempo.Date,
  )
}

type ContributionType {
  Art
  Writing
  Music
  Misc
}

fn to_string(contribution_type: ContributionType) -> String {
  case contribution_type {
    Art -> "Art"
    Writing -> "Writing"
    Music -> "Music"
    Misc -> "Misc."
  }
}

type Hoc {
  Hoc(
    artists: List(String),
    writers: List(String),
    musicians: List(String),
    misc: List(String),
  )
}

fn unique_contributors(panels: List(panel.Meta)) -> Hoc {
  let artists =
    panels
    |> list.flat_map(fn(panel) { panel.credits.artists })
    |> list.unique

  let writers =
    panels
    |> list.flat_map(fn(panel) { panel.credits.writers })
    |> list.unique

  let musicians =
    panels
    |> list.flat_map(fn(panel) { panel.credits.musicians })
    |> list.unique

  let misc =
    panels
    |> list.flat_map(fn(panel) { panel.credits.misc })
    |> list.unique

  Hoc(artists:, writers:, musicians:, misc:)
}

fn get_contributor_info(target_name: String) -> Contributor {
  let panels = panel.panel_list()
  let contributions =
    panels
    |> list.flat_map(fn(meta) {
      let panel.Credits(artists, writers, musicians, misc) = meta.credits

      artists
      |> list.map(fn(a) { #(a, Art, meta.index) })
      |> list.append(writers |> list.map(fn(w) { #(w, Writing, meta.index) }))
      |> list.append(musicians |> list.map(fn(m) { #(m, Music, meta.index) }))
      |> list.append(misc |> list.map(fn(m) { #(m, Misc, meta.index) }))
    })

  let matching =
    contributions
    |> list.filter(fn(contribution) {
      let #(name, _type, _index) = contribution
      name == target_name
    })

  let unique_types =
    matching
    |> list.map(fn(contribution) {
      let #(_name, type_, _index) = contribution
      type_
    })
    |> list.unique
    |> list.sort(compare_types)

  let unique_panels =
    matching
    |> list.map(fn(contribution) {
      let #(_name, _type, index) = contribution
      index
    })
    |> list.unique
    |> list.sort(order.reverse(int.compare))

  Contributor(
    name: target_name,
    contributed_to: unique_panels,
    types_of_contributions: unique_types,
    first_contribution: date.current_local(),
  )
}

fn compare_types(a: ContributionType, b: ContributionType) -> order.Order {
  case a, b {
    Art, Art -> order.Eq
    Art, _ -> order.Lt
    Writing, Writing -> order.Eq
    Writing, _ -> order.Lt
    Music, Music -> order.Eq
    Music, _ ->
      case b {
        Misc -> order.Lt
        _ -> order.Gt
      }
    Misc, Misc -> order.Eq
    Misc, _ -> order.Gt
  }
}

pub fn build_hoc() -> base.Page {
  let hoc = unique_contributors(panel.panel_list())

  let head = [html.title([], "The Hall of Contributors")]
  let css = [
    css.global(".section", [
      css.background("#e0e0e0"),
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
    html.div([attribute.class("sections")], [
      html.div([attribute.class("section")], [
        html.h2([], [html.text("Artists")]),
        html.ul([], {
          hoc.artists
          |> list.map(fn(contributor) {
            html.li([], [
              html.a([attribute.href("/hoc/" <> contributor)], [
                html.text(contributor),
              ]),
            ])
          })
        }),
      ]),
      html.div([attribute.class("section")], [
        html.h2([], [html.text("Writers")]),
        html.ul([], {
          hoc.writers
          |> list.map(fn(contributor) {
            html.li([], [
              html.a([attribute.href("/hoc/" <> contributor)], [
                html.text(contributor),
              ]),
            ])
          })
        }),
      ]),
      html.div([attribute.class("section")], [
        html.h2([], [html.text("Musicians")]),
        html.ul([], {
          hoc.musicians
          |> list.map(fn(contributor) {
            html.li([], [
              html.a([attribute.href("/hoc/" <> contributor)], [
                html.text(contributor),
              ]),
            ])
          })
        }),
      ]),
      html.div([attribute.class("section")], [
        html.h2([], [html.text("Misc.")]),
        html.ul([], {
          hoc.misc
          |> list.map(fn(contributor) {
            html.li([], [
              html.a([attribute.href("/hoc/" <> contributor)], [
                html.text(contributor),
              ]),
            ])
          })
        }),
      ]),
    ]),
  ]

  base.Page(head:, css:, body:)
}

pub fn build_contributor(contributor: String) -> base.Page {
  let stats = get_contributor_info(contributor)

  let head = [html.title([], "Contributor: " <> contributor)]
  let css = [
    css.global(".contributor", [
      css.display("flex"),
      css.flex("1"),
      css.flex_direction("row"),
      css.padding(length.pt(10)),
      css.media(media.max_width(length.px(768)), [css.flex_direction("column")]),
    ]),
    css.global(".contributor_main", [
      css.display("flex"),
      css.flex("1"),
      css.flex_direction("column"),
      css.max_width(length.percent(50)),
      css.margin(length.pt(10)),
      css.padding(length.pt(10)),
      css.background("#e0e0e0"),
      css.media(media.max_width(length.px(768)), [
        css.max_width(length.percent(100)),
        css.height_("auto"),
      ]),
    ]),
    css.global(".contributor_side", [
      css.width(length.percent(50)),
      css.margin(length.pt(10)),
      css.padding(length.pt(10)),
      css.background("#e0e0e0"),
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
            <> stats.contributed_to |> list.length |> int.to_string,
          ),
        ]),
        html.p([], [
          html.text(
            "Types of Contribution: "
            <> stats.types_of_contributions
            |> list.map(fn(contribution) { to_string(contribution) })
            |> string.join(", "),
          ),
        ]),
        html.p([], [
          html.text(
            "First Contribution: "
            <> stats.first_contribution |> date.format(tempo.ISO8601Date),
          ),
        ]),
      ]),
      html.div([attribute.class("contributor_side")], [
        html.h2([], [html.text("Panels Contributed:")]),
        html.ul(
          [],
          stats.contributed_to
            |> list.map(fn(panel) {
              let assert Ok(panel_) = panel.decode_meta(panel)
              html.li([], [
                html.a([attribute.href("/read/" <> int.to_string(panel))], [
                  html.text(panel_.title),
                ]),
              ])
            }),
        ),
      ]),
    ]),
  ]

  base.Page(head:, css:, body:)
}
