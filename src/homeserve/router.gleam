import gleam/http.{Get}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

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

  wisp.ok()
  |> wisp.html_body(base.render_page(panel.render_panel(which)))
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

fn serve_asset(req: Request, asset: String) -> Response {
  use <- wisp.require_method(req, Get)

  let assert #(_, Ok(extension)) = case string.split(asset, ".") {
    [single] -> #("", Ok(single))
    parts -> #("", list.last(parts))
  }

  let extension = case extension {
    "svg" -> "svg+xml"
    _ -> extension
  }

  wisp.ok()
  |> wisp.set_header("content-type", "image/" <> extension)
  |> wisp.set_header("cache-control", "public, max-age=604800")
  |> wisp.set_body(wisp.File("priv/static/assets/" <> asset))
}

fn serve_extra(req: Request, extra: String) -> Response {
  use <- wisp.require_method(req, Get)

  wisp.ok()
  |> wisp.set_body(wisp.File("priv/static/extra/" <> extra))
}
