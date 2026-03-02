//// Database Layer for Panels and Volunteers
////
//// High-level database operations for panels and volunteers using Mnesia.
//// Converts between Mnesia records and Gleam types.

import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/int
import gleam/json.{type Json}
import gleam/list
import gleam/option.{None, Some}
import gleam/result

import homeserve/cache
import homeserve/config.{type MnesiaConfig}
import homeserve/mnesia_db.{type MnesiaError, panel_table, volunteer_table}
import homeserve/pages/panel/types.{
  type Credits, type Media, type Meta, type Panel, type ParseError, Credits,
  Image, Media, Meta, Panel, Video,
}
import homeserve/volunteers.{type Volunteer, Volunteer}

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
    #("type", json.string("panel")),
    #("meta", encode_meta(panel.meta)),
    #("content", json.string(panel.content)),
  ])
}

/// Encodes metadata only (for efficient caching)
pub fn encode_meta_only(meta: Meta) -> Json {
  json.object([
    #("type", json.string("panel_meta")),
    #("meta", encode_meta(meta)),
  ])
}

/// Encodes a volunteer to JSON
pub fn encode_volunteer(volunteer: Volunteer) -> Json {
  json.object([
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

// ---- Error Conversion ----

fn mnesia_error_to_parse_error(err: MnesiaError) -> ParseError {
  case err {
    mnesia_db.NotFound(msg) -> types.FileNotFound(msg)
    mnesia_db.ConnectionError(msg) | mnesia_db.DatabaseError(msg) ->
      types.DatabaseError(msg)
    mnesia_db.Conflict(msg) | mnesia_db.InvalidResponse(msg) ->
      types.InvalidFrontmatter(msg)
  }
}

// ---- Panel Public API ----

/// Loads a panel by index from cache or Mnesia
pub fn load_panel(index: Int) -> Result(Panel, ParseError) {
  // Check cache first
  case cache.get(index) {
    Some(panel) -> Ok(panel)
    None -> {
      // Cache miss - load from Mnesia
      case mnesia_db.get_doc_by_int(panel_table, index) {
        Ok(dynamic_val) -> {
          let dict_decoder = decode.dict(decode.string, decode.dynamic)
          case decode.run(dynamic_val, dict_decoder) {
            Ok(dict) -> {
              case decode_panel(dict) {
                Ok(panel) -> {
                  // Store in cache for future reads
                  cache.put(index, panel)
                  Ok(panel)
                }
                Error(_) ->
                  Error(types.InvalidFrontmatter(
                    "Failed to decode panel document",
                  ))
              }
            }
            Error(_) ->
              Error(types.InvalidFrontmatter("Failed to decode document"))
          }
        }
        Error(mnesia_db.NotFound(_)) ->
          Error(types.FileNotFound("panel:" <> int.to_string(index)))
        Error(err) -> Error(mnesia_error_to_parse_error(err))
      }
    }
  }
}

/// Saves a panel to Mnesia and clears cache
pub fn save_panel(panel: Panel) -> Result(Nil, MnesiaError) {
  let key = panel.meta.index
  let json_doc = encode_panel(panel)
  let json_string = json.to_string(json_doc)

  // Parse JSON to get a dynamic value for storage
  case json.parse(json_string, using: decode.dynamic) {
    Ok(dynamic_val) -> {
      case mnesia_db.put_doc_by_int(panel_table, key, dynamic_val) {
        Ok(_) -> {
          // Clear cache on write to ensure consistency
          cache.clear()
          Ok(Nil)
        }
        Error(err) -> Error(err)
      }
    }
    Error(_) -> Error(mnesia_db.InvalidResponse("Failed to encode panel"))
  }
}

/// Gets all panel metadata (for listing/caching)
pub fn get_all_meta() -> Result(List(Meta), MnesiaError) {
  // Check cache first
  case cache.get_meta_list() {
    Some(metas) -> Ok(metas)
    None -> {
      // Cache miss - load from Mnesia
      use docs <- result.try(mnesia_db.get_all_docs(panel_table))

      let metas =
        list.filter_map(docs, fn(doc) {
          let dict_decoder = decode.dict(decode.string, decode.dynamic)
          case decode.run(doc, dict_decoder) {
            Ok(dict) -> {
              case decode_panel(dict) {
                Ok(p) -> Ok(p.meta)
                Error(_) -> Error(Nil)
              }
            }
            Error(_) -> Error(Nil)
          }
        })

      // Store in cache
      cache.put_meta_list(metas)
      Ok(metas)
    }
  }
}

/// Ensures the database exists (initializes Mnesia)
pub fn initialize(config: MnesiaConfig) -> Result(Nil, MnesiaError) {
  mnesia_db.ensure_database(config)
}

/// Updates an existing panel in Mnesia
/// Note: Mnesia doesn't need explicit update - put_doc handles it
pub fn update_panel(panel: Panel) -> Result(Nil, MnesiaError) {
  // First check if the panel exists
  case load_panel(panel.meta.index) {
    Ok(_) -> save_panel(panel)
    Error(types.FileNotFound(_)) ->
      Error(mnesia_db.NotFound("Panel does not exist"))
    Error(_) ->
      Error(mnesia_db.DatabaseError("Failed to check panel existence"))
  }
}

/// Deletes a panel from Mnesia and clears cache
pub fn delete_panel(index: Int) -> Result(Nil, MnesiaError) {
  case mnesia_db.delete_doc_by_int(panel_table, index) {
    Ok(_) -> {
      // Clear cache on delete to ensure consistency
      cache.clear()
      Ok(Nil)
    }
    Error(err) -> Error(err)
  }
}

// ---- Volunteer Public API ----

/// Loads a volunteer by name from Mnesia
pub fn load_volunteer(
  name: String,
) -> Result(Volunteer, volunteers.VolunteerError) {
  case mnesia_db.get_doc(volunteer_table, name) {
    Ok(dynamic_val) -> {
      let dict_decoder = decode.dict(decode.string, decode.dynamic)
      case decode.run(dynamic_val, dict_decoder) {
        Ok(dict) -> {
          case decode_volunteer(dict) {
            Ok(volunteer) -> Ok(volunteer)
            Error(_) ->
              Error(volunteers.ParseError("Failed to decode volunteer document"))
          }
        }
        Error(_) -> Error(volunteers.ParseError("Failed to decode document"))
      }
    }
    Error(_err) -> {
      // Any error (including NotFound) means the volunteer doesn't exist
      Error(volunteers.FileNotFound(name))
    }
  }
}

/// Saves a volunteer to Mnesia
pub fn save_volunteer(volunteer: Volunteer) -> Result(Nil, MnesiaError) {
  let key = volunteer.name
  let json_doc = encode_volunteer(volunteer)
  let json_string = json.to_string(json_doc)

  case json.parse(json_string, using: decode.dynamic) {
    Ok(dynamic_val) -> mnesia_db.put_doc(volunteer_table, key, dynamic_val)
    Error(_) -> Error(mnesia_db.InvalidResponse("Failed to encode volunteer"))
  }
}

/// Gets all volunteers from Mnesia
pub fn get_all_volunteers() -> Result(List(Volunteer), MnesiaError) {
  use docs <- result.try(mnesia_db.get_all_docs(volunteer_table))

  let volunteers_list =
    list.filter_map(docs, fn(doc) {
      let dict_decoder = decode.dict(decode.string, decode.dynamic)
      case decode.run(doc, dict_decoder) {
        Ok(dict) -> {
          case decode_volunteer(dict) {
            Ok(v) -> Ok(v)
            Error(_) -> Error(Nil)
          }
        }
        Error(_) -> Error(Nil)
      }
    })

  Ok(volunteers_list)
}

/// Updates an existing volunteer in Mnesia
pub fn update_volunteer(volunteer: Volunteer) -> Result(Nil, MnesiaError) {
  // First check if the volunteer exists
  case load_volunteer(volunteer.name) {
    Ok(_) -> save_volunteer(volunteer)
    Error(volunteers.FileNotFound(_)) ->
      Error(mnesia_db.NotFound("Volunteer does not exist"))
    Error(_) ->
      Error(mnesia_db.DatabaseError("Failed to check volunteer existence"))
  }
}

/// Deletes a volunteer from Mnesia
pub fn delete_volunteer(name: String) -> Result(Nil, MnesiaError) {
  mnesia_db.delete_doc(volunteer_table, name)
}

/// Clears all data from both panels and volunteers tables
/// Useful for testing
pub fn clear_all_data() -> Result(Nil, MnesiaError) {
  // Clear panels table
  case mnesia_db.clear_table(panel_table) {
    Error(err) -> Error(err)
    Ok(_) -> {
      // Clear volunteers table
      case mnesia_db.clear_table(volunteer_table) {
        Error(err) -> Error(err)
        Ok(_) -> {
          // Also clear cache to ensure consistency
          cache.clear()
          Ok(Nil)
        }
      }
    }
  }
}
