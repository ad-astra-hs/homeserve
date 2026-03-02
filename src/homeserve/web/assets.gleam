/// Asset Serving
///
/// Handles serving of static assets using wisp.serve_static with support for
/// accessibility features like GIF-to-PNG conversion for photosensitive users.
import gleam/http
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import simplifile
import wisp

import homeserve/config.{type Config}
import homeserve/security

/// Cache control max age for static assets (1 week in seconds)
const asset_cache_max_age_seconds = 604_800

/// Serves static assets with automatic MIME type detection and GIF conversion support.
/// 
/// This function checks for special accessibility handling (GIF to static PNG conversion)
/// before falling through to wisp.serve_static which handles MIME types automatically.
pub fn serve_assets(
  req: wisp.Request,
  path_segments: List(String),
  cfg: Config,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Get)

  // Reconstruct the path from segments
  let path = string.join(path_segments, "/")

  // Check for GIF conversion (accessibility feature for photosensitive users)
  let #(resolved_path, is_gif_conversion) = case
    string.ends_with(path, ".gif")
  {
    True -> {
      let animated = is_animation_requested(req)
      case animated {
        False -> {
          // Serve static PNG version for accessibility
          let base = string.drop_end(path, 4)
          #(base <> "_static.png", True)
        }
        True -> #(path, False)
      }
    }
    False -> #(path, False)
  }

  // Sanitize the filename for security
  case security.sanitize_filename(resolved_path) {
    None -> {
      wisp.log_warning(
        "Path traversal attempt blocked in assets: " <> resolved_path,
      )
      wisp.not_found()
    }
    Some(safe_filename) -> {
      // Build full path and verify it's within the assets directory
      let full_path = cfg.paths.assets_directory <> "/" <> safe_filename

      case security.is_path_within_base(full_path, cfg.paths.assets_directory) {
        False -> {
          wisp.log_warning("Path validation failed for asset: " <> full_path)
          wisp.not_found()
        }
        True -> {
          // Check if file exists (for GIF conversions, the PNG might not exist)
          case simplifile.is_file(full_path) {
            Ok(True) -> {
              // File exists - serve it with proper cache headers
              // For converted GIFs, we serve directly without going through serve_static
              // to maintain our cache-control header
              case is_gif_conversion {
                True -> serve_file_with_cache(full_path)
                False -> {
                  // Use wisp.serve_static for automatic MIME detection and other features
                  use <- wisp.serve_static(
                    req,
                    under: "/assets",
                    from: cfg.paths.assets_directory,
                  )
                  wisp.not_found()
                }
              }
            }
            Ok(False) -> {
              // File not found - try fallback to original path if it was a conversion
              case is_gif_conversion {
                True -> {
                  // Fall back to original GIF if static PNG doesn't exist
                  case security.sanitize_filename(path) {
                    None -> wisp.not_found()
                    Some(original_safe) -> {
                      let original_path =
                        cfg.paths.assets_directory <> "/" <> original_safe
                      case simplifile.is_file(original_path) {
                        Ok(True) -> {
                          use <- wisp.serve_static(
                            req,
                            under: "/assets",
                            from: cfg.paths.assets_directory,
                          )
                          wisp.not_found()
                        }
                        _ -> wisp.not_found()
                      }
                    }
                  }
                }
                False -> {
                  wisp.log_info("Asset not found: " <> full_path)
                  wisp.not_found()
                }
              }
            }
            Error(_) -> {
              wisp.log_error("Failed to check if asset exists: " <> full_path)
              wisp.not_found()
            }
          }
        }
      }
    }
  }
}

/// Serves a specific file with cache headers (used for converted GIFs)
fn serve_file_with_cache(path: String) -> wisp.Response {
  wisp.ok()
  |> wisp.set_header(
    "cache-control",
    "public, max-age=" <> int.to_string(asset_cache_max_age_seconds),
  )
  |> wisp.set_body(wisp.File(path))
}

fn is_animation_requested(req: wisp.Request) -> Bool {
  let query = wisp.get_query(req)
  case list.key_find(query, "animated") {
    Ok("False") -> False
    _ -> True
  }
}
