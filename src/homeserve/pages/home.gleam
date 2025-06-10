import gleam/json
import gleam/dynamic/decode
import gleam/result
import gleam/http/request
import gleam/int
import gleam/list
import gleam/httpc

import lustre/attribute
import lustre/element
import lustre/element/html
import sketch/css
import sketch/css/length
import sketch/css/media
import tempo
import tempo/date
import tempo/datetime

import homeserve/base
import homeserve/pages/panel

pub fn build_home() -> base.Page {
  let latest_tumblr_post = case {
    let assert Ok(base_req) = request.to("https://api.tumblr.com/v2/blog/volo-kaj-malplena.tumblr.com/posts?limit=1&api_key=b5CeV684WkccTD6QARZMzuGeZ0DYevUz45nG5Dc7ojNyMPHHjK")
    use resp <- result.try(httpc.send(base_req))
    Ok(resp)
  } {
    Ok(resp) -> resp.body
    Error(_) -> ""
  }
  |> echo

  let tumblr_decoder = {
    decode.at(["response", "posts", "0", "summary"], decode.string)
  }

  let _ = echo json.parse(latest_tumblr_post, tumblr_decoder)



  let head = [html.title([], "Ad Astra: Volo Kaj Malplena")]
  let css = [
    css.global(".content_right", [
      css.flex("1"),
      css.display("flex"),
      css.flex_direction("column"),
      css.width_("auto"),
      css.media(media.max_width(length.px(768)), [css.flex("auto")]),
    ]),
    css.global(".panels, .socials, .about", [
      css.background("#e0e0e0"),
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
      html.div([attribute.class("about")], [
        html.h2([attribute.style("text-align", "center")], [
          html.text("Ad Astra: Volo Kaj Malplena"),
        ]),
        html.p([], [
          html.text(
            "Ad Astra is a brand new multimedia adventure, bringing a new spin to ideas presented to us in ",
          ),
          html.a([attribute.href("https://homestuck.com")], [
            html.text("Homestuck"),
          ]),
          html.text("."),
        ]),
        html.p([], [
          html.text(
            "Our work spans a MSPFA-style Webcomic (which you can read ",
          ),
          html.a([attribute.href("/read")], [html.text("here")]),
          html.text(" and on "),
          html.a([attribute.href("https://mspfa.com/")], [html.text("MPSFA")]),
          html.text(
            "!), as well as a Ren'Py based Friendsim-style Visual Novel.",
          ),
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
        //html.p([], [
        //  html.text(
        //    "We tend to show up at the SAHCon Premieres with teasers of our work, here's an example from New Years' 2025!",
        //  ),
        //]),
        //element.unsafe_raw_html(
        //  "",
        //  "div",
        //  [],
        //  "<iframe width=100% height=auto src='https://www.youtube.com/embed/sy6oK2lBr5M?si=0XRz5tLX82wokJXN' title='YouTube video player' frameborder='0' allow='accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share' referrerpolicy='strict-origin-when-cross-origin' allowfullscreen></iframe>",
        //),
      ]),
      html.div([attribute.class("about")], [
        html.h2([], [html.text("News")]),
        html.p([], [html.text("Latest Tumblr Post will go here")])
      ]),
    ]),
    html.div([attribute.class("content_right")], [
      html.div([attribute.class("socials")], [
        html.a([attribute.href("https://bsky.app/profile/adastra.wtf")], [
          html.img([
            attribute.src("https://www.svgrepo.com/show/481667/butterfly-4.svg"),
            attribute.title("Bluesky"),
          ]),
        ]),
        html.a([attribute.href("https://tumblr.com/volo-kaj-malplena")], [
          html.img([
            attribute.src("https://www.svgrepo.com/show/513007/tumblr-181.svg"),
            attribute.title("Tumblr"),
          ]),
        ]),
        html.a([attribute.href("https://twitter.com/AdAstraTwt")], [
          html.img([
            attribute.src("https://www.svgrepo.com/show/513008/twitter-154.svg"),
            attribute.title("Twitter"),
          ]),
        ]),
        html.a([attribute.href("/discord")], [
          html.img([
            attribute.src("https://www.svgrepo.com/show/506463/discord.svg"),
            attribute.title("Discord"),
          ]),
        ]),
        html.a([attribute.href("https://adastramspfa.bandcamp.com")], [
          html.img([
            attribute.src("https://www.svgrepo.com/show/508768/bandcamp.svg"),
            attribute.title("Bandcamp"),
          ]),
        ]),
        html.a([attribute.href("https://codeberg.org/ad-astra")], [
          html.img([
            attribute.src("https://www.svgrepo.com/show/330179/codeberg.svg"),
            attribute.title("Codeberg"),
          ]),
        ]),
      ]),
      html.div([attribute.class("panels")], [
        html.h2([], [html.text("Recent Pages")]),
        html.ul(
          [],
          panel.panel_list()
            |> list.filter_map(fn(page) {
              case page.draft {
                True -> Error(element.none())
                False ->
                  Ok({
                    html.li([], [
                      html.a(
                        [attribute.href("/read/" <> int.to_string(page.index))],
                        [
                          html.text(
                            "["
                            <> datetime.from_unix_seconds(page.date)
                            |> datetime.get_date()
                            |> date.format(tempo.ISO8601Date)
                            <> "] "
                            <> page.title,
                          ),
                        ],
                      ),
                    ])
                  })
              }
            })
            |> list.reverse()
            |> list.take(15),
        ),
      ]),
    ]),
  ]

  base.Page(head:, css:, body:)
}
