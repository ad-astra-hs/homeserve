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

// ---- Constants ----

const section_bg = "#e0e0e0"

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
  html.div([attribute.class("about")], [
    html.h2([attribute.style("text-align", "center")], [
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
    |> list.sort(fn(a, b) { int.compare(b.date, a.date) })
    |> list.take(15)

  wisp.log_debug(
    "Displaying "
    <> int.to_string(list.length(recent_panels))
    <> " recent panels on home page",
  )

  html.div([attribute.class("panels")], [
    html.h2([], [html.text("Recent Pages")]),
    html.ul([], list.map(recent_panels, render_panel_link)),
  ])
}

fn render_panel_link(page: panel.Meta) {
  let date_str =
    datetime.from_unix_seconds(page.date)
    |> datetime.get_date()
    |> date.format(tempo.ISO8601Date)

  html.li([], [
    html.a([attribute.href("/read/" <> int.to_string(page.index))], [
      html.text("[" <> date_str <> "] " <> page.title),
    ]),
  ])
}

fn render_contributor_section(panels: List(panel.Meta)) {
  case get_random_contributor(panels) {
    None -> html.div([], [])
    Some(contributor) ->
      html.div([attribute.class("contributor")], [
        html.h2([attribute.style("text-align", "center")], [
          html.text("Featured Contributor"),
        ]),
        html.p([attribute.style("text-align", "center")], [
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

  let published_count =
    panels
    |> list.filter(fn(p) { !p.draft })
    |> list.length

  wisp.log_info(
    "Home page: "
    <> int.to_string(published_count)
    <> " published panels out of "
    <> int.to_string(list.length(panels))
    <> " total",
  )

  let head = [html.title([], "Ad Astra: Volo Kaj Malplena")]

  let css = [
    css.global(".content_right", [
      css.flex("1"),
      css.display("flex"),
      css.flex_direction("column"),
      css.width_("auto"),
      css.media(media.max_width(length.px(768)), [css.flex("auto")]),
    ]),
    css.global(".panels, .socials, .about, .contributor", [
      css.background(section_bg),
      css.margin(length.pt(10)),
      css.padding(length.pt(10)),
      css.media(media.max_width(length.px(768)), [
        css.min_height(length.percent(15)),
      ]),
    ]),
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
    css.global(".panels", [css.flex("1")]),
  ]

  let body = [
    html.div([attribute.class("content_left")], [
      render_about_section(),
      render_contributor_section(panels),
    ]),
    html.div([attribute.class("content_right")], [
      html.div(
        [attribute.class("socials")],
        list.map(social_links, render_social_link),
      ),
      render_recent_panels(panels),
    ]),
  ]

  base.Page(head:, css:, body:)
}
