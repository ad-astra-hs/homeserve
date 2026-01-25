// ---- Panel Frontmatter and YAML Parsing ----
//
// This module handles parsing of YAML frontmatter from markdown files
// and extraction of metadata into typed structures.

import glaml.{type Node, NodeBool, NodeInt, NodeNil, NodeSeq, NodeStr}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string

import homeserve/pages/panel/types.{
  type MediaKind, type ParseError, Image, Video,
}

// ---- Frontmatter parsing ----

/// Splits a file into YAML frontmatter and body content.
/// Expects format:
/// ---
/// yaml content
/// ---
/// body content
pub fn split_frontmatter(
  content: String,
) -> Result(#(String, String), ParseError) {
  let trimmed = string.trim_start(content)

  case string.starts_with(trimmed, "---") {
    False -> Error(types.InvalidFrontmatter("File must start with '---'"))
    True -> {
      let after_first = string.drop_start(trimmed, 3)
      case string.split_once(after_first, "\n---") {
        Error(_) -> Error(types.InvalidFrontmatter("Missing closing '---'"))
        Ok(#(yaml, body)) -> {
          // Remove leading newline from body if present
          let body = case string.starts_with(body, "\n") {
            True -> string.drop_start(body, 1)
            False -> body
          }
          Ok(#(string.trim(yaml), body))
        }
      }
    }
  }
}

// ---- YAML field extraction helpers ----

/// Extracts a string value from YAML node at the given path.
fn get_string(node: Node, path: String) -> Result(String, ParseError) {
  case glaml.select_sugar(node, path) {
    Error(err) -> Error(types.YamlSelectionError(err))
    Ok(NodeStr(value)) -> Ok(value)
    Ok(NodeNil) -> Error(types.MissingField(path))
    Ok(_) -> Error(types.InvalidFieldType(path, "string"))
  }
}

/// Extracts an integer value from YAML node at the given path.
fn get_int(node: Node, path: String) -> Result(Int, ParseError) {
  case glaml.select_sugar(node, path) {
    Error(err) -> Error(types.YamlSelectionError(err))
    Ok(NodeInt(value)) -> Ok(value)
    Ok(NodeNil) -> Error(types.MissingField(path))
    Ok(_) -> Error(types.InvalidFieldType(path, "int"))
  }
}

/// Extracts a boolean value from YAML node at the given path.
fn get_bool(node: Node, path: String) -> Result(Bool, ParseError) {
  case glaml.select_sugar(node, path) {
    Error(err) -> Error(types.YamlSelectionError(err))
    Ok(NodeBool(value)) -> Ok(value)
    Ok(NodeNil) -> Error(types.MissingField(path))
    Ok(_) -> Error(types.InvalidFieldType(path, "bool"))
  }
}

/// Extracts an optional string value from YAML node at the given path.
fn get_optional_string(
  node: Node,
  path: String,
) -> Result(Option(String), ParseError) {
  case glaml.select_sugar(node, path) {
    Error(_) -> Ok(None)
    Ok(NodeNil) -> Ok(None)
    Ok(NodeStr(value)) -> Ok(Some(value))
    Ok(_) -> Error(types.InvalidFieldType(path, "string or null"))
  }
}

/// Extracts a list of strings from YAML node at the given path.
fn get_string_list(node: Node, path: String) -> Result(List(String), ParseError) {
  case glaml.select_sugar(node, path) {
    Error(_) -> Ok([])
    Ok(NodeNil) -> Ok([])
    Ok(NodeSeq(items)) -> {
      items
      |> list.try_map(fn(item) {
        case item {
          NodeStr(s) -> Ok(s)
          _ -> Error(types.InvalidFieldType(path, "list of strings"))
        }
      })
    }
    Ok(_) -> Error(types.InvalidFieldType(path, "list"))
  }
}

/// Extracts media kind (image/video) from YAML node at the given path.
fn get_media_kind(node: Node, path: String) -> Result(MediaKind, ParseError) {
  case get_string(node, path) {
    Error(err) -> Error(err)
    Ok("image") -> Ok(Image)
    Ok("video") -> Ok(Video)
    Ok(other) ->
      Error(types.InvalidFieldType(
        path,
        "media kind (image/video), got: " <> other,
      ))
  }
}

// ---- Meta decoding from YAML ----

/// Decodes panel metadata from YAML content string.
pub fn decode_meta_from_yaml(
  yaml_content: String,
  panel_index: Int,
) -> Result(types.Meta, ParseError) {
  case glaml.parse_string(yaml_content) {
    Error(err) -> Error(types.YamlParseError(err))
    Ok([]) -> Error(types.InvalidFrontmatter("Empty YAML document"))
    Ok([doc, ..]) -> {
      let root = glaml.document_root(doc)
      decode_meta_from_node(root, panel_index)
    }
  }
}

/// Decodes panel metadata from a parsed YAML node.
fn decode_meta_from_node(
  node: Node,
  panel_index: Int,
) -> Result(types.Meta, ParseError) {
  // Required fields
  use title <- result.try(get_string(node, "title"))
  use date <- result.try(get_int(node, "date"))
  use draft <- result.try(get_bool(node, "draft"))

  // Media (required)
  use media_kind <- result.try(get_media_kind(node, "media.kind"))
  use media_url <- result.try(get_string(node, "media.url"))
  use media_alt <- result.try(get_optional_string(node, "media.alt"))
  use media_track <- result.try(get_optional_string(node, "media.track"))

  let media =
    types.Media(
      kind: media_kind,
      url: media_url,
      alt: media_alt,
      track: media_track,
    )

  // Credits (all optional, default to empty lists)
  use artists <- result.try(get_string_list(node, "credits.artists"))
  use writers <- result.try(get_string_list(node, "credits.writers"))
  use musicians <- result.try(get_string_list(node, "credits.musicians"))
  use misc <- result.try(get_string_list(node, "credits.misc"))

  let credits = types.Credits(artists:, writers:, musicians:, misc:)

  // Optional lists
  use css <- result.try(get_string_list(node, "css"))
  use js <- result.try(get_string_list(node, "js"))

  Ok(types.Meta(
    index: panel_index,
    title:,
    media:,
    credits:,
    css:,
    js:,
    date:,
    draft:,
  ))
}
