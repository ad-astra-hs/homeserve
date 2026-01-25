import gleam/list
import gleam/result
import gleam/string
import wisp

pub fn middleware(
  req: wisp.Request,
  handle_request: fn(wisp.Request) -> wisp.Response,
) -> wisp.Response {
  let req = wisp.method_override(req)
  use <- wisp.log_request(req)
  use <- wisp.rescue_crashes
  use req <- wisp.handle_head(req)

  handle_request(req)
}

pub fn file_with_mime(res: wisp.Response, path: String) -> wisp.Response {
  let mime_type =
    path
    |> get_file_extension
    |> extension_to_mime

  res
  |> wisp.set_header("content-type", mime_type)
  |> wisp.set_body(wisp.File(path))
}

pub fn get_file_extension(filename: String) -> String {
  filename
  |> string.split(".")
  |> list.last
  |> result.unwrap("")
}

pub fn extension_to_mime(extension: String) -> String {
  case extension {
    "svg" -> "image/svg+xml"
    "png" -> "image/png"
    "jpg" | "jpeg" -> "image/jpeg"
    "gif" -> "image/gif"
    "webp" -> "image/webp"
    "mp3" -> "audio/mpeg"
    "mp4" -> "video/mp4"
    "webm" -> "video/webm"
    "js" -> "text/javascript"
    "css" -> "text/css"
    "ico" -> "image/x-icon"
    _ -> "application/octet-stream"
  }
}
