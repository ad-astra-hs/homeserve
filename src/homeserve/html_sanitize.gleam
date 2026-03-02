//// HTML Sanitization
////
//// Sanitizes HTML output to prevent XSS attacks.
//// This is a defense-in-depth measure for markdown output.

import gleam/list
import gleam/regexp
import gleam/string

/// Sanitizes HTML content to prevent XSS attacks.
/// Removes dangerous tags and attributes while preserving safe content.
pub fn sanitize(html: String) -> String {
  html
  |> remove_dangerous_tags
  |> sanitize_attributes
  |> escape_remaining_scripts
}

/// Remove dangerous tags that could execute JavaScript
fn remove_dangerous_tags(html: String) -> String {
  let dangerous_tags = [
    "script", "iframe", "object", "embed", "applet", "form", "input", "button",
    "textarea", "select", "option", "optgroup", "svg", "math", "link", "style",
    "meta", "base", "title", "video", "source",
  ]

  list.fold(dangerous_tags, html, fn(acc, tag) {
    let case_insensitive =
      regexp.Options(case_insensitive: True, multi_line: False)

    // For script tags, remove content between tags too
    case tag {
      "script" -> {
        // Remove script tags and everything between them
        let script_pattern = "<script[^>]*>.*?</script>"
        case
          regexp.compile(
            script_pattern,
            with: regexp.Options(case_insensitive: True, multi_line: True),
          )
        {
          Ok(re) -> regexp.replace(re, acc, "")
          Error(_) -> acc
        }
      }
      _ -> {
        // Remove opening tags with any attributes
        let pattern = "<" <> tag <> "[^>]*>"
        case regexp.compile(pattern, with: case_insensitive) {
          Ok(re) -> regexp.replace(re, acc, "")
          Error(_) -> acc
        }
        |> fn(acc2) {
          // Remove closing tags
          let close_pattern = "</" <> tag <> ">"
          case regexp.compile(close_pattern, with: case_insensitive) {
            Ok(re) -> regexp.replace(re, acc2, "")
            Error(_) -> acc2
          }
        }
      }
    }
  })
}

/// Remove dangerous attributes from all tags
fn sanitize_attributes(html: String) -> String {
  // Remove event handlers (on* attributes)
  let event_pattern = "\\s+on\\w+=[\"'][^\"']*[\"']"
  let case_insensitive =
    regexp.Options(case_insensitive: True, multi_line: False)
  case regexp.compile(event_pattern, with: case_insensitive) {
    Ok(re) -> regexp.replace(re, html, "")
    Error(_) -> html
  }
  |> fn(acc) {
    // Remove javascript: URLs
    let js_url_pattern = "(href|src|action)=[\"']javascript:[^\"']*[\"']"
    case regexp.compile(js_url_pattern, with: case_insensitive) {
      Ok(re) -> regexp.replace(re, acc, "")
      Error(_) -> acc
    }
  }
  |> fn(acc) {
    // Remove data: URLs (except for images)
    let data_url_pattern = "(href|src)=[\"']data:(?!image/)[^\"']*[\"']"
    case regexp.compile(data_url_pattern, with: case_insensitive) {
      Ok(re) -> regexp.replace(re, acc, "")
      Error(_) -> acc
    }
  }
  |> fn(acc) {
    // Remove vbscript: URLs
    let vb_url_pattern = "(href|src|action)=[\"']vbscript:[^\"']*[\"']"
    case regexp.compile(vb_url_pattern, with: case_insensitive) {
      Ok(re) -> regexp.replace(re, acc, "")
      Error(_) -> acc
    }
  }
}

/// Escape any remaining script references
fn escape_remaining_scripts(html: String) -> String {
  html
  |> string.replace("<script", "&lt;script")
  |> string.replace("</script", "&lt;/script")
  |> string.replace("javascript:", "[removed:")
  |> string.replace("vbscript:", "[removed:")
}
