import homeserve/quirks

@external(erlang, "Elixir.BBCode", "to_html")
pub fn to_html(data: String) -> Result(String, String)

import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}

import lustre/attribute
import lustre/element
import lustre/element/html
import simplifile
import sketch/css
import sketch/css/length
import sketch/css/media
import sketch/css/transform

import homeserve/base
import homeserve/pages/errors

pub type Meta {
  Meta(
    index: Int,
    title: String,
    media: Media,
    credits: Credits,
    css: List(String),
    characters: List(String),
    date: Int,
    draft: Bool,
  )
}

pub type Credits {
  Credits(
    artists: List(String),
    writers: List(String),
    musicians: List(String),
    misc: List(String),
  )
}

pub type Media {
  Media(kind: String, url: String, alt: Option(String), track: Option(String))
}

pub fn decode_meta(panel: Int) -> Result(Meta, json.DecodeError) {
  let credits_decoder = {
    use artists <- decode.field("artists", decode.list(decode.string))
    use writers <- decode.field("writers", decode.list(decode.string))
    use musicians <- decode.field("musicians", decode.list(decode.string))
    use misc <- decode.field("misc", decode.list(decode.string))
    decode.success(Credits(artists:, writers:, musicians:, misc:))
  }

  let media_decoder = {
    use kind <- decode.field("kind", decode.string)
    use url <- decode.field("url", decode.string)
    use alt <- decode.optional_field(
      "alt",
      None,
      decode.optional(decode.string),
    )
    use track <- decode.optional_field(
      "track",
      None,
      decode.optional(decode.string),
    )
    decode.success(Media(kind:, url:, alt:, track:))
  }

  let meta_decoder = {
    use title <- decode.field("title", decode.string)
    use media <- decode.field("media", media_decoder)
    use credits <- decode.field("credits", credits_decoder)
    use css <- decode.field("css", decode.list(decode.string))
    use characters <- decode.field("characters", decode.list(decode.string))
    use date <- decode.field("date", decode.int)
    use draft <- decode.field("draft", decode.bool)
    decode.success(Meta(
      index: panel,
      title:,
      media:,
      credits:,
      css:,
      characters:,
      date:,
      draft:,
    ))
  }

  let path = "./pages/" <> int.to_string(panel) <> "/meta.json"

  case simplifile.read(path) {
    Ok(meta_file) -> {
      case json.parse(from: meta_file, using: meta_decoder) {
        Ok(meta) -> Ok(meta)
        Error(e) -> Error(e)
      }
    }
    Error(_) -> Error(json.UnexpectedSequence("Could not read file."))
  }
}

pub fn build_panel(
  metadata: Meta,
  parsed_page: String,
  next_page_text: Option(String),
) -> base.Page {
  let head =
    [
      [
        html.title([], "> " <> metadata.title),
        html.meta([
          attribute.name("viewport"),
          attribute.content("width=device-width, initial-scale=1.0"),
        ]),
        html.link([
          attribute.href(
            "/assets/misc/" <> int.to_string(metadata.index) <> ".css",
          ),
          attribute.rel("stylesheet"),
        ]),
        html.script([attribute.src("/assets/misc/default.js")], ""),
      ],
      list.map(metadata.css, fn(css) {
        html.link([
          attribute.href("/assets/misc/" <> css <> ".css"),
          attribute.rel("stylesheet"),
        ])
      }),
      list.map(metadata.characters, fn(js) {
        html.script([attribute.src("/assets/misc/" <> js <> ".js")], "")
      }),
      [
        html.script(
          [],
          "
      document.addEventListener(\"DOMContentLoaded\", () => {
        const detailsElements = document.querySelectorAll(\"details\");
        detailsElements.forEach(details => {
          details.open = true;
        });
      });",
        ),
      ],
    ]
    |> list.flatten
  let css = [
    css.global(".page_margins", [
      css.transform([transform.translate_x(length.percent(30))]),
      css.width(length.percent(65)),
      css.media(media.max_width(length.px(768)), [
        css.transform([]),
        css.width(length.percent(100)),
      ]),
    ]),
    css.global(".page_outer", [
      css.display("flex"),
      css.flex_direction("column"),
      css.background("white"),
    ]),
    css.global(".page_outer h2", [css.text_align("center")]),
    css.global(".page_outer img,video", [css.margin_bottom(length.pt(0))]),
    css.global(".page_inner", [
      css.text_align("center"),
      css.margin(length.pt(10)),
      css.margin_bottom(length.rlh(1.0)),
    ]),
    css.global(".next", [css.font_size(length.pt(16)), css.margin(length.pt(5))]),
    css.global(".bottom_links", [
      css.display("flex"),
      css.margin(length.pt(5)),
      css.align_items("center"),
    ]),
    css.global(".credits", [
      css.color("gray"),
      css.margin(length.pt(10)),
      css.margin_left(length.pt(5)),
      css.margin_bottom(length.pt(0)),
    ]),
    css.global(".credits a", [css.color("gray")]),
    css.global(".bottom_links a:last-child", [css.margin_left_("auto")]),
    css.global(".music", [
      css.border("1pt solid white"),
      css.background("black"),
      css.color("white"),
    ]),
    css.global(".quirk_toggle, .animation_toggle", [
      css.border("1pt solid grey"),
      css.background("#e9e9e9"),
    ]),
    css.global(".quirk_toggle:hover, .animation_toggle:hover", [
      css.border("1pt solid grey"),
      css.background("#c9c9c9"),
    ]),
    css.global(".audio_controls", [
      css.margin_top(length.pt(0)),
      css.padding(length.pt(3)),
      css.padding_right(length.pt(6)),
      css.padding_bottom(length.pt(0)),
      css.background("black"),
      css.color("white"),
      css.width_("fit-content"),
      css.margin_bottom(length.pt(10)),
    ]),
    css.global("#volume_down", [
      css.padding_left(length.pt(5)),
      css.padding_right(length.pt(5)),
    ]),
    css.global(".page_inner details", [
      css.border("1pt dotted grey"),
      css.text_align("left"),
      css.display("flex"),
      css.padding(length.pt(10)),
    ]),
    css.global(".page_inner summary", [
      css.margin_("0 auto"),
      css.width_("fit-content"),
      css.padding(length.pt(3)),
      css.border("1pt solid grey"),
      css.background("#e9e9e9"),
      css.margin_bottom(length.rlh(1.0)),
    ]),
    css.global(".page_inner summary:hover", [
      css.background("#c9c9c9"),
      css.cursor("default"),
    ]),
    css.global(".page_inner summary::marker", [css.content("\"\"")]),
  ]
  let body = [
    html.div([attribute.class("page_margins")], [
      html.div([attribute.class("page_outer")], [
        html.h2([], [html.text(metadata.title)]),
        case metadata.media.kind {
          "image" ->
            html.img(
              list.append(
                [attribute.src(metadata.media.url), attribute.class("panel")],
                case metadata.media.alt {
                  Some(alt) -> [attribute.alt(alt), attribute.title(alt)]
                  None -> []
                },
              ),
            )
          "video" ->
            html.video(
              list.append(
                [
                  attribute.controls(True),
                  attribute.src(metadata.media.url),
                  attribute.class("panel"),
                ],
                case metadata.media.alt {
                  Some(alt) -> [attribute.alt(alt), attribute.title(alt)]
                  None -> []
                },
              ),
              [],
            )
          _ -> element.none()
        },
        case metadata.media.track {
          Some(track) -> {
            element.fragment([
              html.span([attribute.class("audio_controls")], [
                html.text("🕪 \"" <> track <> "\" "),
                html.button(
                  [attribute.id("play_pause"), attribute.class("music")],
                  [html.text("Play")],
                ),
                html.text(" "),
                html.button(
                  [attribute.class("music"), attribute.id("volume_down")],
                  [html.text("-")],
                ),
                html.span([attribute.id("volume")], [html.text("")]),
                html.button(
                  [attribute.class("music"), attribute.id("volume_up")],
                  [html.text("+")],
                ),
              ]),
              html.audio(
                [
                  attribute.class("music"),
                  attribute.id("audio"),
                  attribute.src("/assets/" <> track),
                ],
                [html.text("Audio is not supported in this browser")],
              ),
              html.script(
                [],
                "const audio = document.getElementById('audio');
                 const btn = document.getElementById('play_pause');
                 const vol = document.getElementById('volume')
                 const vol_up = document.getElementById('volume_up')
                 const vol_down = document.getElementById('volume_down')

                 audio.volume = 0.3
                 vol.textContent = ' ' + audio.volume*100 + '%' + ' '

                 btn.addEventListener('click', function() {
                   if (audio.paused) {
                     audio.play();
                     btn.textContent = 'Pause';
                   } else {
                     audio.pause();
                     btn.textContent = 'Play';
                   }
                 });
                 vol_up.addEventListener('click', function() {
                   audio.volume += .05
                   vol.textContent = ' ' + Math.ceil(audio.volume*100) + '%' + ' '
                 });
                 vol_down.addEventListener('click', function() {
                   audio.volume -= .05
                   vol.textContent = ' ' + Math.ceil(audio.volume*100) + '%' + ' '
                 });
                 ",
              ),
            ])
          }
          None -> element.none()
        },
        element.unsafe_raw_html(
          "",
          "div",
          [attribute.class("page_inner")],
          parsed_page,
        ),
        html.br([]),
        html.br([]),
        case next_page_text {
          Some(next) -> {
            html.a(
              [
                attribute.href("/read/" <> int.to_string(metadata.index + 1)),
                attribute.class("next"),
              ],
              [html.text("> " <> next)],
            )
          }
          None -> {
            element.none()
          }
        },
        html.br([]),
        html.br([]),
        html.span([attribute.class("credits")], [
          html.sup([], [
            html.text("Art: "),
            ..{
              list.map(metadata.credits.artists, fn(artist) {
                html.a([attribute.href("/hoc/" <> artist)], [html.text(artist)])
              })
            }
            |> list.intersperse(html.text(", "))
            |> list.append([html.text(". ")])
          ]),
          html.sup([], [
            html.text("Writing: "),
            ..{
              list.map(metadata.credits.writers, fn(writer) {
                html.a([attribute.href("/hoc/" <> writer)], [html.text(writer)])
              })
            }
            |> list.intersperse(html.text(", "))
            |> list.append([html.text(". ")])
          ]),
          case list.length(metadata.credits.musicians) {
            0 -> element.none()
            _ ->
              html.sup([], [
                html.text("Music: "),
                ..{
                  list.map(metadata.credits.musicians, fn(musician) {
                    html.a([attribute.href("/hoc/" <> musician)], [
                      html.text(musician),
                    ])
                  })
                }
                |> list.intersperse(html.text(", "))
                |> list.append([html.text(". ")])
              ])
          },
          case list.length(metadata.credits.misc) {
            0 -> element.none()
            _ ->
              html.sup([], [
                html.text("Misc. Help: "),
                ..{
                  list.map(metadata.credits.misc, fn(misc) {
                    html.a([attribute.href("/hoc/" <> misc)], [html.text(misc)])
                  })
                }
                |> list.intersperse(html.text(", "))
                |> list.append([html.text(". ")])
              ])
          },
        ]),
        html.br([]),
        html.span([attribute.class("bottom_links")], [
          html.button(
            [
              attribute.attribute(
                "onclick",
                "fetch('/read/toggle_quirks').then(()=>location.reload());",
              ),
              attribute.class("quirk_toggle"),
            ],
            [html.text("Toggle Quirks")],
          ),
          html.wbr([attribute.style("margin", "5pt")]),
          //TODO: Implement this and put it somewhere better that doesn't interfere with mobile layout
          //html.button(
          //  [
          //    attribute.attribute("onclick", ""),
          //    attribute.class("animation_toggle"),
          //  ],
          //  [html.text("Toggle Animations")],
          //),
          //html.wbr([attribute.style("margin", "5pt")]),
          html.a([attribute.href("/read/1")], [html.text("Start Over")]),
          html.wbr([attribute.style("margin", "5pt")]),
          html.a(
            [attribute.href("/read/" <> int.to_string(metadata.index - 1))],
            [html.text("Go Back")],
          ),
          html.a([attribute.href("/")], [html.text("Home")]),
        ]),
      ]),
    ]),
  ]
  base.Page(head:, css:, body:)
}

pub fn render_panel(panel: Int, quirked_cookie: String) {
  case simplifile.read("./pages/" <> int.to_string(panel) <> "/page.txt") {
    Ok(got_page) -> {
      let assert Ok(metadata) = decode_meta(panel)

      let next_page_text = case decode_meta(panel + 1) {
        Ok(next_metadata) -> {
          let next_metadata: Meta = next_metadata
          Some(next_metadata.title)
        }
        _ -> None
      }

      let quirked = case quirked_cookie {
        "false" -> False
        _ -> True
      }

      let assert Ok(parsed_page) =
        to_html(quirks.parse_document(got_page, quirked))

      build_panel(metadata, parsed_page, next_page_text)
    }
    _ -> {
      errors.build_404()
    }
  }
}

pub fn panel_list() -> List(Meta) {
  let assert Ok(pages) = simplifile.read_directory("./pages")

  list.filter_map(pages, fn(page) { int.base_parse(page, 10) })
  |> list.filter_map(fn(page) { decode_meta(page) })
}
