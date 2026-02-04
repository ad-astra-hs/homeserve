import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/uri

import lustre/attribute
import lustre/element/html
import sketch/css
import sketch/css/length
import sketch/css/media
import tempo
import tempo/date
import tempo/datetime
import wisp

import homeserve/base
import homeserve/pages/panel

// ---- Social links ----

type SocialLink {
  SocialLink(name: String, url: String, icon: String)
}

const social_links = [
  SocialLink(
    "Bluesky",
    "https://bsky.app/profile/adastra.wtf",
    "https://www.svgrepo.com/show/481667/butterfly-4.svg",
  ),
  SocialLink(
    "Tumblr",
    "https://tumblr.com/volo-kaj-malplena",
    "https://www.svgrepo.com/show/513007/tumblr-181.svg",
  ),
  SocialLink(
    "Twitter",
    "https://twitter.com/AdAstraTwt",
    "https://www.svgrepo.com/show/513008/twitter-154.svg",
  ),
  SocialLink(
    "Discord",
    "/discord",
    "https://www.svgrepo.com/show/506463/discord.svg",
  ),
  SocialLink(
    "Bandcamp",
    "https://adastramspfa.bandcamp.com",
    "https://www.svgrepo.com/show/508768/bandcamp.svg",
  ),
  SocialLink(
    "Codeberg",
    "https://codeberg.org/ad-astra",
    "https://www.svgrepo.com/show/330179/codeberg.svg",
  ),
]

fn render_social_link(link: SocialLink) {
  html.a([attribute.href(link.url)], [
    html.img([
      attribute.src(link.icon),
      attribute.title(link.name),
      attribute.alt(link.name),
    ]),
  ])
}

// ---- Page sections ----

fn render_about_section() {
  html.div([attribute.class("box")], [
    html.h2([attribute.class("heading-bordered text-center")], [
      html.text("Ad Astra: Volo Kaj Malplena"),
    ]),
    html.p([], [
      html.text(
        "Ad Astra is a brand new multimedia adventure, bringing a new spin on ideas presented to us in ",
      ),
      html.a([attribute.href("https://homestuck.com")], [html.text("Homestuck")]),
      html.text("."),
    ]),
    html.p([], [
      html.text("Our work spans a MSPFA-style Webcomic (which you can read "),
      html.a([attribute.href("/read")], [html.text("here")]),
      html.text(" and on "),
      html.a([attribute.href("https://mspfa.com/")], [html.text("MSPFA")]),
      html.text("!), as well as a Ren'Py based Friendsim-style Visual Novel."),
    ]),
    html.p([], [
      html.text(
        "We are always on the lookout for talented Artists, Writers, Musicians, and Gleam/Python Developers (Even better if you've used Wisp/Lustre!).",
      ),
    ]),
    html.p([], [
      html.text(
        "If you're looking to get involved, feel free to join our Discord, where you'll hear first whenever we open applications in the future.",
      ),
    ]),
    html.p([], [
      html.text(
        "Ad Astra Team is committed to open-source development and welcomes contributions from the community. This website is open source and welcomes improvements, criticism, and feedback.",
      ),
    ]),
  ])
}

fn render_recent_panels(panels: List(panel.Meta)) {
  let recent_panels =
    panels
    |> list.filter(fn(page) { !page.draft })
    |> list.filter(fn(page) { page.index != 0 })
    |> list.sort(fn(a, b) { int.compare(b.date, a.date) })
    |> list.take(15)

  html.div([attribute.class("box flex-1")], [
    html.h2([attribute.class("heading-bordered")], [html.text("Recent Pages")]),
    html.ul(
      [attribute.class("list-clean list-divided scrollable")],
      list.map(recent_panels, render_panel_link),
    ),
  ])
}

fn render_panel_link(page: panel.Meta) {
  let date_str =
    datetime.from_unix_seconds(page.date)
    |> datetime.get_date()
    |> date.format(tempo.ISO8601Date)
  html.li([], [
    html.a([attribute.href("/read/" <> int.to_string(page.index))], [
      html.text("[" <> date_str <> "] > " <> page.title),
    ]),
  ])
}

fn render_contributor_section(panels: List(panel.Meta)) {
  case get_random_contributor(panels) {
    None -> html.div([], [])
    Some(contributor) ->
      html.div([attribute.class("box")], [
        html.h2([attribute.class("heading-bordered text-center")], [
          html.text("Featured Contributor"),
        ]),
        html.p([attribute.class("text-center")], [
          html.text("Check out the work of "),
          html.a([attribute.href("/hoc/" <> uri.percent_encode(contributor))], [
            html.text(contributor),
          ]),
          html.text("!"),
        ]),
      ])
  }
}

fn get_random_contributor(panels: List(panel.Meta)) -> option.Option(String) {
  let all_contributors =
    panels
    |> list.flat_map(fn(panel) {
      list.flatten([
        panel.credits.artists,
        panel.credits.writers,
        panel.credits.musicians,
        panel.credits.misc,
      ])
    })
    |> list.unique

  case all_contributors {
    [] -> None
    [single] -> Some(single)
    _ -> {
      let random_index = int.random(list.length(all_contributors) - 1)
      case list.drop(all_contributors, random_index) {
        [] -> None
        [contributor, ..] -> Some(contributor)
      }
    }
  }
}

// ---- Page builder ----

pub fn build_home(panels: List(panel.Meta)) -> base.Page {
  wisp.log_debug("Building home page")

  let head = [html.title([], "Ad Astra: Volo Kaj Malplena")]

  let css = [
    // Left/right content layout
    css.global(".content_left", [
      css.flex("2"),
      css.display("flex"),
      css.flex_direction("column"),
    ]),
    css.global(".content_right", [
      css.flex("1"),
      css.display("flex"),
      css.flex_direction("column"),
    ]),
    // Socials grid layout
    css.global(".socials", [
      css.display("grid"),
      css.place_items("center"),
      css.grid_template_rows("repeat(2,100px)"),
      css.grid_template_columns("repeat(3,100px)"),
      css.media(media.max_width(length.px(768)), [css.place_items("center end")]),
    ]),
    css.global(".socials img", [
      css.width(length.px(32)),
      css.height(length.px(32)),
    ]),
    // Evil monkey image
    css.global(".evil_monkey img", [
      css.width(length.percent(100)),
      css.height_("auto"),
    ]),
    // Flex utility
    css.global(".flex-1", [css.flex("1")]),
  ]

  let body = [
    html.div([attribute.class("content_left")], [
      render_about_section(),
      render_contributor_section(panels),
      html.div([attribute.class("box evil_monkey")], [
        html.img([attribute.src("/assets/evil_monkey.png")]),
      ]),
    ]),
    html.div([attribute.class("content_right")], [
      html.div(
        [attribute.class("box socials")],
        list.map(social_links, render_social_link),
      ),
      render_recent_panels(panels),
    ]),
  ]

  base.Page(head:, css:, body:)
}
