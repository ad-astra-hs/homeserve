import gleam/dynamic
import gleam/dynamic/decode
import gleam/erlang/atom
import simplifile

@external(erlang, "Elixir.Mogrify", "open")
pub fn open(path: String) -> dynamic.Dynamic

@external(erlang, "Elixir.Mogrify", "custom")
pub fn custom(image: dynamic.Dynamic, custom: String) -> dynamic.Dynamic

@external(erlang, "Elixir.Mogrify", "format")
pub fn format(image: dynamic.Dynamic, format: String) -> dynamic.Dynamic

@external(erlang, "Elixir.Mogrify", "save")
pub fn save(
  image: dynamic.Dynamic,
  options: List(#(atom.Atom, dynamic.Dynamic)),
) -> dynamic.Dynamic

import gleam/float
import gleam/http.{Get}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import homeserve/pages/privacy_policy

import wisp.{type Request, type Response}

import homeserve/base
import homeserve/pages/errors
import homeserve/pages/hoc
import homeserve/pages/home
import homeserve/pages/panel
import homeserve/web

pub fn handle_request(req: Request) -> Response {
  use req <- web.middleware(req)

  case wisp.path_segments(req) {
    [] -> serve_home(req)

    // Game
    ["play"] ->
      wisp.redirect("https://gitlab.com/ad-astra-hs/friendsim/build-system")

    // Webcomic
    ["read"] | ["read", "0"] -> wisp.redirect("/read/1")
    ["read", "toggle_quirks"] -> toggle_a11y(req, "quirked")
    ["read", "toggle_animations"] -> toggle_a11y(req, "animated")
    ["read", page] -> {
      case int.base_parse(page, 10) {
        Ok(page) -> {
          serve_panel(req, page)
        }
        _ -> serve_404(req)
      }
    }
    ["hoc"] -> serve_hoc(req, None)
    ["hoc", volunteer] -> serve_hoc(req, Some(volunteer))

    // Media assets (music, panels, etc.)
    ["assets", asset] -> {
      serve_asset(req, asset)
    }

    // Misc. assets (custom CSS, JS quirks, etc.)
    ["assets", "misc", extra] -> {
      serve_extra(req, extra)
    }
    ["favicon.ico"] -> {
      serve_asset(req, "logo.png")
    }

    // Any misc. redirects
    ["discord"] -> wisp.redirect("https://discord.gg/TjMT9gsVPT")
    ["apply"] -> wisp.redirect("https://forms.gle/4Fz62i4bJ5Z63ZkYA")

    // Privacy Policy
    ["privacy"] -> serve_privacy_policy(req)
    _ -> serve_404(req)
  }
}

fn serve_home(req) -> Response {
  use <- wisp.require_method(req, Get)

  wisp.ok()
  |> wisp.html_body(base.render_page(home.build_home()))
}

fn serve_panel(req: Request, which: Int) -> Response {
  use <- wisp.require_method(req, Get)

  let quirked = case wisp.get_cookie(req, "quirked", wisp.PlainText) {
    Ok(cookie) -> cookie
    _ -> "true"
  }
  let animated = case wisp.get_cookie(req, "animated", wisp.PlainText) {
    Ok(cookie) -> cookie
    _ -> "true"
  }

  wisp.ok()
  |> wisp.html_body(
    base.render_page(panel.render_panel(which, quirked, animated)),
  )
}

fn serve_hoc(req: Request, volunteer: Option(String)) -> Response {
  use <- wisp.require_method(req, Get)

  let page = case volunteer {
    Some(volunteer) -> hoc.build_contributor(volunteer)
    None -> hoc.build_hoc()
  }

  wisp.ok()
  |> wisp.html_body(base.render_page(page))
}

fn serve_404(req: Request) -> Response {
  use <- wisp.require_method(req, Get)

  wisp.response(404)
  |> wisp.html_body(base.render_page(errors.build_404()))
}

fn serve_privacy_policy(req) -> Response {
  use <- wisp.require_method(req, Get)

  wisp.ok()
  |> wisp.html_body(base.render_page(privacy_policy.build_privacy_policy()))
}

fn serve_asset(req: Request, asset: String) -> Response {
  use <- wisp.require_method(req, Get)

  let query = wisp.get_query(req)
  echo query

  let animated = case list.key_find(query, "animated") {
    Ok(anim) if anim == "False" -> {
      False
    }
    _ -> True
  }

  let assert #(_, Ok(extension)) = case string.split(asset, ".") {
    [single] -> #("", Ok(single))
    parts -> #("", list.last(parts))
  }

  let extension = case extension {
    "svg" -> "image/svg+xml"
    "mp3" -> "audio/mpeg"
    "mp4" -> "video/mpeg"
    _ -> "image/" <> extension
  }

  let #(body, extension) = case extension, animated {
    "image/gif", False -> {
      case simplifile.is_file("priv/converted/" <> asset <> "_static.jpg") {
        Ok(False) -> {
          let image =
            open("priv/static/assets/" <> asset)
            |> custom("coalesce")
            |> format("jpg")
            |> save([])

          let decoder = {
            use image <- decode.field(
              atom.create_from_string("path"),
              decode.string,
            )
            decode.success(image)
          }

          case decode.run(image, decoder) {
            Ok(path) -> {
              let path = string.replace(path, ".jpg", "-0.jpg")
              let assert Ok(_) =
                simplifile.copy(
                  path,
                  "priv/converted/" <> asset <> "_static.jpg",
                )

              #(wisp.File(path), "image/jpeg")
            }
            Error(_) -> {
              #(wisp.File("priv/static/assets/" <> asset), "image/gif")
            }
          }
        }
        _ -> #(
          wisp.File("priv/converted/" <> asset <> "_static.jpg"),
          "image/jpg",
        )
      }
    }
    _, _ -> #(wisp.File("priv/static/assets/" <> asset), extension)
  }

  echo body

  wisp.ok()
  |> wisp.set_header("content-type", extension)
  |> wisp.set_header("cache-control", "public, max-age=604800")
  |> wisp.set_body(body)
}

fn serve_extra(req: Request, extra: String) -> Response {
  use <- wisp.require_method(req, Get)

  wisp.ok()
  |> wisp.set_body(wisp.File("priv/static/extra/" <> extra))
}

fn toggle_a11y(req: Request, a11y_option: String) -> Response {
  use <- wisp.require_method(req, Get)

  let value = case wisp.get_cookie(req, a11y_option, wisp.PlainText) {
    Ok(perchance) ->
      case perchance {
        "true" -> "false"
        _ -> "true"
      }
    Error(_) -> "false"
  }

  wisp.no_content()
  |> wisp.set_cookie(
    req,
    a11y_option,
    value,
    wisp.PlainText,
    float.round(3.156e7),
  )
}
