//// Database Layer for Panels and Volunteers
////
//// High-level database operations for panels and volunteers using CouchDB.
//// Converts between CouchDB documents and Gleam types.

import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/int
import gleam/json.{type Json}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string

import homeserve/couchdb.{type CouchConfig, type CouchError}
import homeserve/pages/panel/types.{
  type Credits, type Media, type Meta, type Panel, type ParseError, Credits,
  Image, Media, Meta, Panel, Video,
}
import homeserve/volunteers.{type Volunteer, Volunteer}

/// Document ID prefix for panels
const panel_prefix = "panel:"

/// Document ID prefix for volunteers
const volunteer_prefix = "volunteer:"

/// Converts a panel index to document ID
fn index_to_id(index: Int) -> String {
  panel_prefix <> int.to_string(index)
}

/// Converts a volunteer name to document ID
fn volunteer_name_to_id(name: String) -> String {
  volunteer_prefix <> name
}

// ---- JSON Encoding ----

fn encode_media(media: Media) -> Json {
  json.object([
    #("kind", case media.kind {
      Image -> json.string("image")
      Video -> json.string("video")
    }),
    #("url", json.string(media.url)),
    #("alt", case media.alt {
      Some(alt) -> json.string(alt)
      None -> json.null()
    }),
    #("track", case media.track {
      Some(track) -> json.string(track)
      None -> json.null()
    }),
  ])
}

fn encode_credits(credits: Credits) -> Json {
  json.object([
    #("artists", json.array(credits.artists, json.string)),
    #("writers", json.array(credits.writers, json.string)),
    #("musicians", json.array(credits.musicians, json.string)),
    #("misc", json.array(credits.misc, json.string)),
  ])
}

fn encode_meta(meta: Meta) -> Json {
  json.object([
    #("index", json.int(meta.index)),
    #("title", json.string(meta.title)),
    #("media", encode_media(meta.media)),
    #("credits", encode_credits(meta.credits)),
    #("css", json.array(meta.css, json.string)),
    #("js", json.array(meta.js, json.string)),
    #("date", json.int(meta.date)),
    #("draft", json.bool(meta.draft)),
  ])
}

/// Encodes a complete panel to JSON
pub fn encode_panel(panel: Panel) -> Json {
  json.object([
    #("_id", json.string(index_to_id(panel.meta.index))),
    #("type", json.string("panel")),
    #("meta", encode_meta(panel.meta)),
    #("content", json.string(panel.content)),
  ])
}

/// Encodes metadata only (for efficient caching)
pub fn encode_meta_only(meta: Meta) -> Json {
  json.object([
    #("_id", json.string(index_to_id(meta.index))),
    #("type", json.string("panel_meta")),
    #("meta", encode_meta(meta)),
  ])
}

/// Encodes a volunteer to JSON
pub fn encode_volunteer(volunteer: Volunteer) -> Json {
  json.object([
    #("_id", json.string(volunteer_name_to_id(volunteer.name))),
    #("type", json.string("volunteer")),
    #("name", json.string(volunteer.name)),
    #("social_links", json.array(volunteer.social_links, json.string)),
    #("bio", json.string(volunteer.bio)),
  ])
}

// ---- JSON Decoding ----

fn decode_media(
  kind_str: String,
  dict: Dict(String, Dynamic),
) -> Result(Media, Nil) {
  use url_dyn <- result.try(dict.get(dict, "url"))
  use url <- result.try(
    decode.run(url_dyn, decode.string)
    |> result.map_error(fn(_) { Nil }),
  )

  let alt = case dict.get(dict, "alt") {
    Ok(dyn) -> {
      case decode.run(dyn, decode.string) {
        Ok(s) -> Some(s)
        Error(_) -> None
      }
    }
    Error(_) -> None
  }

  let track = case dict.get(dict, "track") {
    Ok(dyn) -> {
      case decode.run(dyn, decode.string) {
        Ok(s) -> Some(s)
        Error(_) -> None
      }
    }
    Error(_) -> None
  }

  let kind = case kind_str {
    "video" -> Video
    _ -> Image
  }

  Ok(Media(kind: kind, url: url, alt: alt, track: track))
}

fn decode_credits(dict: Dict(String, Dynamic)) -> Result(Credits, Nil) {
  use artists_dyn <- result.try(dict.get(dict, "artists"))
  let artists =
    decode.run(artists_dyn, decode.list(decode.string))
    |> result.unwrap([])

  use writers_dyn <- result.try(dict.get(dict, "writers"))
  let writers =
    decode.run(writers_dyn, decode.list(decode.string))
    |> result.unwrap([])

  use musicians_dyn <- result.try(dict.get(dict, "musicians"))
  let musicians =
    decode.run(musicians_dyn, decode.list(decode.string))
    |> result.unwrap([])

  use misc_dyn <- result.try(dict.get(dict, "misc"))
  let misc =
    decode.run(misc_dyn, decode.list(decode.string))
    |> result.unwrap([])

  Ok(Credits(
    artists: artists,
    writers: writers,
    musicians: musicians,
    misc: misc,
  ))
}

fn decode_meta(dict: Dict(String, Dynamic)) -> Result(Meta, Nil) {
  use index_dyn <- result.try(dict.get(dict, "index"))
  use index <- result.try(
    decode.run(index_dyn, decode.int)
    |> result.map_error(fn(_) { Nil }),
  )

  use title_dyn <- result.try(dict.get(dict, "title"))
  use title <- result.try(
    decode.run(title_dyn, decode.string)
    |> result.map_error(fn(_) { Nil }),
  )

  use media_dyn <- result.try(dict.get(dict, "media"))
  use media_dict <- result.try(
    decode.run(media_dyn, decode.dict(decode.string, decode.dynamic))
    |> result.map_error(fn(_) { Nil }),
  )

  use kind_str_dyn <- result.try(dict.get(media_dict, "kind"))
  use kind_str <- result.try(
    decode.run(kind_str_dyn, decode.string)
    |> result.map_error(fn(_) { Nil }),
  )

  use media <- result.try(decode_media(kind_str, media_dict))

  use credits_dyn <- result.try(dict.get(dict, "credits"))
  use credits_dict <- result.try(
    decode.run(credits_dyn, decode.dict(decode.string, decode.dynamic))
    |> result.map_error(fn(_) { Nil }),
  )

  use credits <- result.try(decode_credits(credits_dict))

  let css =
    dict.get(dict, "css")
    |> result.unwrap(dynamic.from([]))
    |> decode.run(decode.list(decode.string))
    |> result.unwrap([])

  let js =
    dict.get(dict, "js")
    |> result.unwrap(dynamic.from([]))
    |> decode.run(decode.list(decode.string))
    |> result.unwrap([])

  use date_dyn <- result.try(dict.get(dict, "date"))
  use date <- result.try(
    decode.run(date_dyn, decode.int)
    |> result.map_error(fn(_) { Nil }),
  )

  let draft =
    dict.get(dict, "draft")
    |> result.unwrap(dynamic.from(False))
    |> decode.run(decode.bool)
    |> result.unwrap(False)

  Ok(Meta(
    index: index,
    title: title,
    media: media,
    credits: credits,
    css: css,
    js: js,
    date: date,
    draft: draft,
  ))
}

fn decode_panel(dict: Dict(String, Dynamic)) -> Result(Panel, Nil) {
  use meta_dyn <- result.try(dict.get(dict, "meta"))
  use meta_dict <- result.try(
    decode.run(meta_dyn, decode.dict(decode.string, decode.dynamic))
    |> result.map_error(fn(_) { Nil }),
  )

  use meta <- result.try(decode_meta(meta_dict))

  use content_dyn <- result.try(dict.get(dict, "content"))
  use content <- result.try(
    decode.run(content_dyn, decode.string)
    |> result.map_error(fn(_) { Nil }),
  )

  Ok(Panel(meta: meta, content: content))
}

fn decode_volunteer(dict: Dict(String, Dynamic)) -> Result(Volunteer, Nil) {
  use name_dyn <- result.try(dict.get(dict, "name"))
  use name <- result.try(
    decode.run(name_dyn, decode.string)
    |> result.map_error(fn(_) { Nil }),
  )

  let social_links =
    dict.get(dict, "social_links")
    |> result.unwrap(dynamic.from([]))
    |> decode.run(decode.list(decode.string))
    |> result.unwrap([])

  let bio =
    dict.get(dict, "bio")
    |> result.unwrap(dynamic.from(""))
    |> decode.run(decode.string)
    |> result.unwrap("")

  Ok(Volunteer(name: name, social_links: social_links, bio: bio))
}

// ---- Internal Helpers ----

/// Extracts the revision string from a document dictionary.
/// Returns None if the revision field is missing or invalid.
fn extract_revision(dict: Dict(String, Dynamic)) -> Option(String) {
  case dict.get(dict, "_rev") {
    Ok(rev_dyn) ->
      decode.run(rev_dyn, decode.string)
      |> option.from_result
    Error(_) -> None
  }
}

/// Fetches an existing document and extracts its revision.
/// Returns None if the document doesn't exist or has no revision.
fn get_existing_revision(config: CouchConfig, doc_id: String) -> Option(String) {
  case couchdb.get_doc(config, doc_id) {
    Ok(existing) -> extract_revision(existing)
    Error(_) -> None
  }
}

/// Requires an existing document and returns it with its revision.
/// Returns an error if the document doesn't exist or has no valid revision.
fn require_existing_doc(
  config: CouchConfig,
  doc_id: String,
) -> Result(#(Dict(String, Dynamic), String), CouchError) {
  case couchdb.get_doc(config, doc_id) {
    Ok(existing) -> {
      case extract_revision(existing) {
        Some(rev) -> Ok(#(existing, rev))
        None -> Error(couchdb.InvalidResponse("Missing or invalid _rev field"))
      }
    }
    Error(couchdb.NotFound(_)) ->
      Error(couchdb.NotFound("Document does not exist"))
    Error(err) -> Error(err)
  }
}

// ---- Panel Public API ----

/// Loads a panel by index from CouchDB
pub fn load_panel(config: CouchConfig, index: Int) -> Result(Panel, ParseError) {
  let doc_id = index_to_id(index)

  case couchdb.get_doc(config, doc_id) {
    Ok(dict) -> {
      case decode_panel(dict) {
        Ok(panel) -> Ok(panel)
        Error(_) ->
          Error(types.InvalidFrontmatter("Failed to decode panel document"))
      }
    }
    Error(couchdb.NotFound(_)) -> {
      Error(types.FileNotFound(doc_id))
    }
    Error(couchdb.ConnectionError(msg)) -> {
      Error(types.DatabaseError(msg))
    }
    Error(err) -> {
      Error(types.InvalidFrontmatter(couchdb.error_to_string(err)))
    }
  }
}

/// Loads only metadata for a panel
pub fn load_meta(config: CouchConfig, index: Int) -> Result(Meta, ParseError) {
  let doc_id = index_to_id(index)

  case couchdb.get_doc(config, doc_id) {
    Ok(dict) -> {
      case dict.get(dict, "meta") {
        Ok(meta_dyn) -> {
          case
            decode.run(meta_dyn, decode.dict(decode.string, decode.dynamic))
          {
            Ok(meta_dict) -> {
              case decode_meta(meta_dict) {
                Ok(meta) -> Ok(meta)
                Error(_) ->
                  Error(types.InvalidFrontmatter("Failed to decode meta"))
              }
            }
            Error(_) -> Error(types.InvalidFrontmatter("Invalid meta format"))
          }
        }
        Error(_) -> Error(types.MissingField("meta"))
      }
    }
    Error(couchdb.NotFound(_)) -> Error(types.FileNotFound(doc_id))
    Error(couchdb.ConnectionError(msg)) -> Error(types.DatabaseError(msg))
    Error(err) -> Error(types.InvalidFrontmatter(couchdb.error_to_string(err)))
  }
}

/// Saves a panel to CouchDB
/// If the panel already exists, updates it with the existing revision.
pub fn save_panel(
  config: CouchConfig,
  panel: Panel,
) -> Result(String, CouchError) {
  let doc_id = index_to_id(panel.meta.index)
  let doc = encode_panel(panel)
  let rev = get_existing_revision(config, doc_id)

  couchdb.put_doc(config, doc_id, doc, rev)
}

/// Gets all panel metadata (for listing/caching)
pub fn get_all_meta(config: CouchConfig) -> Result(List(Meta), CouchError) {
  use docs <- result.try(couchdb.get_all_docs(config))

  let metas =
    list.filter_map(docs, fn(doc) {
      // Skip design documents
      case dict.get(doc, "_id") {
        Ok(id_dyn) -> {
          case decode.run(id_dyn, decode.string) {
            Ok(id) -> {
              case
                string.starts_with(id, "_")
                || string.starts_with(id, "panel:") == False
              {
                True -> Error(Nil)
                False -> {
                  case decode_panel(doc) {
                    Ok(p) -> Ok(p.meta)
                    Error(_) -> Error(Nil)
                  }
                }
              }
            }
            Error(_) -> Error(Nil)
          }
        }
        Error(_) -> Error(Nil)
      }
    })

  Ok(metas)
}

/// Bulk saves multiple panels to CouchDB
pub fn bulk_save_panels(
  config: CouchConfig,
  panels: List(Panel),
) -> Result(List(String), CouchError) {
  let docs = list.map(panels, encode_panel)
  couchdb.bulk_docs(config, docs)
}

/// Gets changes since a sequence number
pub fn get_changes(
  config: CouchConfig,
  since: Option(String),
) -> Result(#(String, List(Meta)), CouchError) {
  use #(last_seq, changes) <- result.try(couchdb.get_changes(config, since))

  let metas =
    list.filter_map(changes, fn(doc) {
      case decode_panel(doc) {
        Ok(p) -> Ok(p.meta)
        Error(_) -> Error(Nil)
      }
    })

  Ok(#(last_seq, metas))
}

/// Ensures the database exists
pub fn initialize(config: CouchConfig) -> Result(Nil, CouchError) {
  couchdb.ensure_database(config)
}

/// Updates an existing panel in CouchDB
/// Requires the panel to already exist (will fail if not found)
pub fn update_panel(
  config: CouchConfig,
  panel: Panel,
) -> Result(String, CouchError) {
  let doc_id = index_to_id(panel.meta.index)
  use #(_, rev) <- result.try(require_existing_doc(config, doc_id))

  let doc = encode_panel(panel)
  couchdb.put_doc(config, doc_id, doc, Some(rev))
}

/// Deletes a panel from CouchDB
pub fn delete_panel(config: CouchConfig, index: Int) -> Result(Nil, CouchError) {
  let doc_id = index_to_id(index)
  use #(_, rev) <- result.try(require_existing_doc(config, doc_id))

  couchdb.delete_doc(config, doc_id, rev)
}

// ---- Volunteer Public API ----

/// Loads a volunteer by name from CouchDB
pub fn load_volunteer(
  config: CouchConfig,
  name: String,
) -> Result(Volunteer, volunteers.VolunteerError) {
  let doc_id = volunteer_name_to_id(name)

  case couchdb.get_doc(config, doc_id) {
    Ok(dict) -> {
      case decode_volunteer(dict) {
        Ok(volunteer) -> Ok(volunteer)
        Error(_) ->
          Error(volunteers.ParseError("Failed to decode volunteer document"))
      }
    }
    Error(couchdb.NotFound(_)) -> {
      Error(volunteers.FileNotFound(doc_id))
    }
    Error(couchdb.ConnectionError(msg)) -> {
      Error(volunteers.ParseError("Database connection error: " <> msg))
    }
    Error(err) -> {
      Error(volunteers.ParseError(couchdb.error_to_string(err)))
    }
  }
}

/// Saves a volunteer to CouchDB
/// If the volunteer already exists, updates it with the existing revision.
pub fn save_volunteer(
  config: CouchConfig,
  volunteer: Volunteer,
) -> Result(String, CouchError) {
  let doc_id = volunteer_name_to_id(volunteer.name)
  let doc = encode_volunteer(volunteer)
  let rev = get_existing_revision(config, doc_id)

  couchdb.put_doc(config, doc_id, doc, rev)
}

/// Gets all volunteers from CouchDB
pub fn get_all_volunteers(
  config: CouchConfig,
) -> Result(List(Volunteer), CouchError) {
  use docs <- result.try(couchdb.get_all_docs(config))

  let volunteers =
    list.filter_map(docs, fn(doc) {
      // Skip design documents and non-volunteer docs
      case dict.get(doc, "_id") {
        Ok(id_dyn) -> {
          case decode.run(id_dyn, decode.string) {
            Ok(id) -> {
              case
                string.starts_with(id, "_")
                || string.starts_with(id, "volunteer:") == False
              {
                True -> Error(Nil)
                False -> {
                  case decode_volunteer(doc) {
                    Ok(v) -> Ok(v)
                    Error(_) -> Error(Nil)
                  }
                }
              }
            }
            Error(_) -> Error(Nil)
          }
        }
        Error(_) -> Error(Nil)
      }
    })

  Ok(volunteers)
}

/// Updates an existing volunteer in CouchDB
/// Requires the volunteer to already exist (will fail if not found)
pub fn update_volunteer(
  config: CouchConfig,
  volunteer: Volunteer,
) -> Result(String, CouchError) {
  let doc_id = volunteer_name_to_id(volunteer.name)
  use #(_, rev) <- result.try(require_existing_doc(config, doc_id))

  let doc = encode_volunteer(volunteer)
  couchdb.put_doc(config, doc_id, doc, Some(rev))
}

/// Deletes a volunteer from CouchDB
pub fn delete_volunteer(
  config: CouchConfig,
  name: String,
) -> Result(Nil, CouchError) {
  let doc_id = volunteer_name_to_id(name)
  use #(_, rev) <- result.try(require_existing_doc(config, doc_id))

  couchdb.delete_doc(config, doc_id, rev)
}

/// Gets volunteer changes since a sequence number
pub fn get_volunteer_changes(
  config: CouchConfig,
  since: Option(String),
) -> Result(#(String, List(Volunteer)), CouchError) {
  use #(last_seq, changes) <- result.try(couchdb.get_changes(config, since))

  let volunteers =
    list.filter_map(changes, fn(doc) {
      case decode_volunteer(doc) {
        Ok(v) -> Ok(v)
        Error(_) -> Error(Nil)
      }
    })

  Ok(#(last_seq, volunteers))
}
