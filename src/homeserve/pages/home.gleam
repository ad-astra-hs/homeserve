import gleam/int
import gleam/list

import lustre/attribute
import lustre/element
import lustre/element/html
import tempo
import tempo/date
import tempo/datetime

import homeserve/pages/panel

pub fn build_home() -> #(List(_), List(_)) {
  #([html.title([], "Ad Astra: Volo Kaj Malplena")], [
    html.div([attribute.class("content_left")], [
      html.div([attribute.class("about")], [
        html.h2([attribute.style("text-align", "center")], [
          html.text("Ad Astra: Volo Kaj Malplena"),
        ]),
        html.p([], [
          html.text(
            "Ad Astra is a brand new multimedia adventure, bringing a new spin to ideas presented to us in Homestuck.",
          ),
        ]),
        html.p([], [
          html.text(
            "We are always on the lookout for talented Artists, Writers, Musicians, and Gleam/Python Developers (Even better if you've used Wisp/Lustre!).",
          ),
        ]),
        html.p([], [
          html.text(
            "Apply using the link above, and come hang out in our Discord!",
          ),
        ]),
      ]),
    ]),
    html.div([attribute.class("content_right")], [
      html.div([attribute.class("socials")], [html.text("Bluesjy, a b c,")]),
      html.div([attribute.class("panels")], [
        html.h2([], [html.text("Pages")]),
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
  ])
}
