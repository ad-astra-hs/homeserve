/// Asset Serving
///
/// Handles serving of static assets with proper MIME types and caching.
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import simplifile
import wisp

import homeserve/config.{type Config}
import homeserve/security

/// Cache control max age for static assets (1 week in seconds)
const asset_cache_max_age_seconds = 604_800

/// Serves an asset file with proper MIME type and caching headers.
/// 
/// Validates the filename for security and ensures the resolved path
/// is within the allowed assets directory.
pub fn serve_asset(
  req: wisp.Request,
  asset: String,
  cfg: Config,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Get)

  // Security: sanitize and validate path
  case security.sanitize_filename(asset) {
    None -> {
      wisp.log_warning("Path traversal attempt blocked in assets: " <> asset)
      wisp.not_found()
    }
    Some(safe_filename) -> {
      serve_asset_unchecked(req, safe_filename, cfg)
    }
  }
}

/// Serves an extra asset from the extra directory.
pub fn serve_extra(
  req: wisp.Request,
  extra: String,
  cfg: Config,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Get)

  // Security: sanitize and validate path
  case security.sanitize_filename(extra) {
    None -> {
      wisp.log_warning(
        "Path traversal attempt blocked in extra assets: " <> extra,
      )
      wisp.not_found()
    }
    Some(safe_filename) -> {
      let full_path =
        [cfg.paths.extra_directory, safe_filename]
        |> string.join("/")

      // Defense in depth: verify path is within allowed directory
      case security.is_path_within_base(full_path, cfg.paths.extra_directory) {
        False -> {
          wisp.log_warning("Path validation failed for extra: " <> full_path)
          wisp.not_found()
        }
        True -> serve_file_if_exists(full_path)
      }
    }
  }
}

fn serve_asset_unchecked(
  req: wisp.Request,
  asset: String,
  cfg: Config,
) -> wisp.Response {
  let is_gif = string.ends_with(asset, ".gif")
  let animated = is_animation_requested(req)

  let path = case is_gif, animated {
    True, False -> {
      let base = string.drop_end(asset, 4)
      base <> "_static.png"
    }
    _, _ -> asset
  }

  let full_path = [cfg.paths.assets_directory, path] |> string.join("/")

  // Defense in depth: verify the resolved path is within the assets directory
  case security.is_path_within_base(full_path, cfg.paths.assets_directory) {
    False -> {
      wisp.log_warning("Path validation failed for asset: " <> full_path)
      wisp.not_found()
    }
    True -> {
      case simplifile.is_file(full_path) {
        Ok(True) -> {
          wisp.ok()
          |> wisp.set_header(
            "cache-control",
            "public, max-age=" <> int.to_string(asset_cache_max_age_seconds),
          )
          |> file_with_mime(full_path)
        }
        Ok(False) -> {
          wisp.log_info("Asset not found: " <> full_path)
          wisp.not_found()
        }
        Error(_) -> {
          wisp.log_error("Failed to check if asset exists: " <> full_path)
          wisp.not_found()
        }
      }
    }
  }
}

fn serve_file_if_exists(full_path: String) -> wisp.Response {
  case simplifile.is_file(full_path) {
    Ok(True) -> {
      wisp.ok()
      |> file_with_mime(full_path)
    }
    Ok(False) -> {
      wisp.log_info("Extra asset not found: " <> full_path)
      wisp.not_found()
    }
    Error(_) -> {
      wisp.log_error("Failed to check if extra asset exists: " <> full_path)
      wisp.not_found()
    }
  }
}

fn is_animation_requested(req: wisp.Request) -> Bool {
  let query = wisp.get_query(req)
  case list.key_find(query, "animated") {
    Ok("False") -> False
    _ -> True
  }
}

/// Sets file response with appropriate MIME type
fn file_with_mime(res: wisp.Response, path: String) -> wisp.Response {
  let mime_type =
    path
    |> get_file_extension
    |> extension_to_mime
  res
  |> wisp.set_header("content-type", mime_type)
  |> wisp.set_body(wisp.File(path))
}

/// Extracts the file extension from a filename
fn get_file_extension(filename: String) -> String {
  filename
  |> string.split(".")
  |> list.last
  |> result.unwrap("")
}

/// Map of file extensions to MIME types
fn extension_to_mime(extension: String) -> String {
  case extension {
    // Audio
    "mp3" -> "audio/mpeg"
    "ogg" -> "audio/ogg"
    "wav" -> "audio/wav"
    "flac" -> "audio/flac"
    // Video
    "mp4" -> "video/mp4"
    "webm" -> "video/webm"
    // Image
    "svg" -> "image/svg+xml"
    "png" -> "image/png"
    "jpg" | "jpeg" -> "image/jpeg"
    "gif" -> "image/gif"
    "webp" -> "image/webp"
    // Web
    "js" | "mjs" -> "text/javascript"
    "css" -> "text/css"
    "html" | "htm" -> "text/html"
    "txt" -> "text/plain"
    "json" -> "application/json"
    // Fonts
    "woff" -> "font/woff"
    "woff2" -> "font/woff2"
    // Default
    _ -> "application/octet-stream"
  }
}

// Required import for http.Get
import gleam/http
