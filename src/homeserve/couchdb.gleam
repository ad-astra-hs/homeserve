//// CouchDB HTTP Client
////
//// A lightweight HTTP client for CouchDB operations.
//// Uses the Gleam httpc library for HTTP requests.

import gleam/bit_array
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/httpc
import gleam/int
import gleam/json.{type Json}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import wisp

/// Configuration for CouchDB connection
pub type CouchConfig {
  CouchConfig(
    host: String,
    port: Int,
    database: String,
    username: Option(String),
    password: Option(String),
  )
}

/// Default CouchDB configuration
pub fn default_config() -> CouchConfig {
  CouchConfig(
    host: "127.0.0.1",
    port: 5984,
    database: "homeserve_panels",
    username: Some("admin"),
    password: Some("password"),
  )
}

/// Errors that can occur during CouchDB operations
pub type CouchError {
  ConnectionError(String)
  NotFound(String)
  Conflict(String)
  InvalidResponse(String)
  DatabaseError(String)
}

// ---- Utility Functions (merged from couchdb_util.gleam) ----

import homeserve/config.{type Config}

/// Builds a CouchConfig from the application Config.
pub fn config_from_app_config(cfg: Config) -> CouchConfig {
  CouchConfig(
    host: cfg.couchdb.host,
    port: cfg.couchdb.port,
    database: cfg.couchdb.database,
    username: cfg.couchdb.username,
    password: cfg.couchdb.password,
  )
}

/// Converts a CouchError to a human-readable string.
pub fn error_to_string(err: CouchError) -> String {
  case err {
    ConnectionError(msg) -> "Connection: " <> msg
    NotFound(msg) -> "Not found: " <> msg
    Conflict(msg) -> "Conflict: " <> msg
    InvalidResponse(msg) -> "Invalid response: " <> msg
    DatabaseError(msg) -> "Database: " <> msg
  }
}

/// Formats a CouchDB connection string for logging (without credentials).
pub fn format_connection_string(cfg: CouchConfig) -> String {
  cfg.host <> ":" <> int.to_string(cfg.port) <> "/" <> cfg.database
}

// ---- HTTP Helpers ----

fn auth_header(config: CouchConfig) -> List(#(String, String)) {
  case config.username, config.password {
    Some(user), Some(pass) -> {
      let credentials =
        bit_array.from_string(user <> ":" <> pass)
        |> bit_array.base64_encode(True)
      // Security: Don't log credentials at all, just log that auth is configured
      wisp.log_debug("CouchDB auth configured for user: " <> user)
      [#("Authorization", "Basic " <> credentials)]
    }
    _, _ -> {
      wisp.log_debug("CouchDB: No auth configured")
      []
    }
  }
}

fn handle_response(
  resp: response.Response(String),
) -> Result(Dynamic, CouchError) {
  case resp.status {
    200 | 201 -> {
      case json.decode(resp.body, fn(d) { Ok(d) }) {
        Ok(value) -> Ok(value)
        Error(_) -> Error(InvalidResponse("Failed to parse JSON response"))
      }
    }
    404 -> Error(NotFound("Document not found"))
    409 -> Error(Conflict("Document conflict - revision mismatch"))
    _ ->
      Error(DatabaseError(
        "HTTP " <> int.to_string(resp.status) <> ": " <> resp.body,
      ))
  }
}

fn make_request(
  config: CouchConfig,
  method: http.Method,
  path: String,
  body: Option(String),
) -> Result(response.Response(String), CouchError) {
  // Debug: Log what we're trying to connect to
  let url =
    "http://" <> config.host <> ":" <> int.to_string(config.port) <> path
  wisp.log_debug("CouchDB request: " <> url)

  // IMPORTANT: request.new() defaults to HTTPS, we need HTTP for CouchDB
  let req =
    request.new()
    |> request.set_method(method)
    |> request.set_scheme(http.Http)
    |> request.set_host(config.host)
    |> request.set_port(config.port)
    |> request.set_path(path)
    |> request.set_header("Accept", "application/json")
    |> request.set_header("Content-Type", "application/json")

  // Add auth headers
  let auth_headers = auth_header(config)
  wisp.log_debug(
    "Auth headers count: " <> int.to_string(list.length(auth_headers)),
  )
  let req = case auth_headers {
    [] -> req
    [#(key, value)] -> {
      // Security: Don't log authorization header values
      let log_value = case key {
        "Authorization" -> "[REDACTED]"
        _ -> string.slice(value, 0, 20) <> "..."
      }
      wisp.log_debug("Adding header: " <> key <> "=" <> log_value)
      request.set_header(req, key, value)
    }
    [first, ..rest] -> {
      let req = request.set_header(req, first.0, first.1)
      list.fold(rest, req, fn(r, h) { request.set_header(r, h.0, h.1) })
    }
  }

  // Add body if present
  let req = case body {
    Some(b) -> request.set_body(req, b)
    None -> req
  }

  // Try to send the request and handle errors gracefully
  // NOTE: gleam_httpc may crash on certain errors (Shutdown, etc.) instead of returning Error
  // This is a known limitation - ensure CouchDB is running before starting the app
  case httpc.send(req) {
    Ok(resp) -> Ok(resp)
    Error(httpc.FailedToConnect(_, _)) ->
      Error(ConnectionError(
        "Failed to connect to CouchDB - is it running on "
        <> config.host
        <> ":"
        <> int.to_string(config.port)
        <> "?",
      ))
    Error(httpc.InvalidUtf8Response) ->
      Error(ConnectionError("Invalid response from CouchDB"))
  }
}

// ---- Database Operations ----

/// Ensures the database exists, creating it if necessary
pub fn ensure_database(config: CouchConfig) -> Result(Nil, CouchError) {
  let path = "/" <> config.database

  case make_request(config, http.Put, path, Some("")) {
    Error(err) -> Error(err)
    Ok(resp) -> {
      case resp.status {
        201 -> Ok(Nil)
        // Created
        412 -> Ok(Nil)
        // Already exists
        _ -> Error(DatabaseError("Failed to create database: " <> resp.body))
      }
    }
  }
}

/// Gets a document by ID
pub fn get_doc(
  config: CouchConfig,
  doc_id: String,
) -> Result(Dict(String, Dynamic), CouchError) {
  let path = "/" <> config.database <> "/" <> doc_id

  case make_request(config, http.Get, path, None) {
    Error(err) -> Error(err)
    Ok(resp) -> {
      case handle_response(resp) {
        Ok(dynamic) -> {
          let dict_decoder = decode.dict(decode.string, decode.dynamic)
          case decode.run(dynamic, dict_decoder) {
            Ok(dict) -> Ok(dict)
            Error(_) -> Error(InvalidResponse("Expected JSON object"))
          }
        }
        Error(err) -> Error(err)
      }
    }
  }
}

/// Creates or updates a document
pub fn put_doc(
  config: CouchConfig,
  doc_id: String,
  doc: Json,
  rev: Option(String),
) -> Result(String, CouchError) {
  let body = json.to_string(doc)

  let path = case rev {
    Some(r) -> "/" <> config.database <> "/" <> doc_id <> "?rev=" <> r
    None -> "/" <> config.database <> "/" <> doc_id
  }

  case make_request(config, http.Put, path, Some(body)) {
    Error(err) -> Error(err)
    Ok(resp) -> {
      case handle_response(resp) {
        Ok(dynamic) -> {
          let rev_decoder =
            decode.field("rev", decode.string, fn(rev) { decode.success(rev) })
          case decode.run(dynamic, rev_decoder) {
            Ok(new_rev) -> Ok(new_rev)
            Error(_) -> Error(InvalidResponse("Missing rev in response"))
          }
        }
        Error(err) -> Error(err)
      }
    }
  }
}

/// Deletes a document
pub fn delete_doc(
  config: CouchConfig,
  doc_id: String,
  rev: String,
) -> Result(Nil, CouchError) {
  let path = "/" <> config.database <> "/" <> doc_id <> "?rev=" <> rev

  case make_request(config, http.Delete, path, None) {
    Error(err) -> Error(err)
    Ok(resp) -> {
      case resp.status {
        200 -> Ok(Nil)
        404 -> Error(NotFound("Document not found"))
        409 -> Error(Conflict("Revision mismatch"))
        _ -> Error(DatabaseError("Failed to delete: " <> resp.body))
      }
    }
  }
}

/// Queries all documents using _all_docs
pub fn get_all_docs(
  config: CouchConfig,
) -> Result(List(Dict(String, Dynamic)), CouchError) {
  let path = "/" <> config.database <> "/_all_docs?include_docs=true"

  case make_request(config, http.Get, path, None) {
    Error(err) -> Error(err)
    Ok(resp) -> {
      case handle_response(resp) {
        Ok(dynamic) -> {
          let rows_decoder =
            decode.field("rows", decode.list(decode.dynamic), fn(rows) {
              decode.success(rows)
            })
          case decode.run(dynamic, rows_decoder) {
            Ok(rows) -> {
              let docs =
                list.filter_map(rows, fn(row) {
                  let doc_decoder =
                    decode.field(
                      "doc",
                      decode.dict(decode.string, decode.dynamic),
                      fn(doc) { decode.success(doc) },
                    )
                  case decode.run(row, doc_decoder) {
                    Ok(doc) -> Ok(doc)
                    Error(_) -> Error(Nil)
                  }
                })
              Ok(docs)
            }
            Error(_) -> Error(InvalidResponse("Invalid rows format"))
          }
        }
        Error(err) -> Error(err)
      }
    }
  }
}

/// Bulk creates or updates multiple documents
pub fn bulk_docs(
  config: CouchConfig,
  docs: List(Json),
) -> Result(List(String), CouchError) {
  let body =
    json.to_string(
      json.object([
        #("docs", json.array(docs, fn(x) { x })),
      ]),
    )

  let path = "/" <> config.database <> "/_bulk_docs"

  case make_request(config, http.Post, path, Some(body)) {
    Error(err) -> Error(err)
    Ok(resp) -> {
      case handle_response(resp) {
        Ok(dynamic) -> {
          let list_decoder = decode.list(decode.dynamic)
          case decode.run(dynamic, list_decoder) {
            Ok(results) -> {
              let revs =
                list.map(results, fn(result) {
                  let rev_decoder =
                    decode.field("rev", decode.string, fn(rev) {
                      decode.success(rev)
                    })
                  case decode.run(result, rev_decoder) {
                    Ok(rev) -> rev
                    Error(_) -> "unknown"
                  }
                })
              Ok(revs)
            }
            Error(_) -> Error(InvalidResponse("Invalid bulk response format"))
          }
        }
        Error(err) -> Error(err)
      }
    }
  }
}

/// Bulk deletes multiple documents
pub fn bulk_delete(
  config: CouchConfig,
  doc_revs: List(#(String, String)),
) -> Result(List(String), CouchError) {
  let docs =
    list.map(doc_revs, fn(pair) {
      let #(doc_id, rev) = pair
      json.object([
        #("_id", json.string(doc_id)),
        #("_rev", json.string(rev)),
        #("_deleted", json.bool(True)),
      ])
    })

  let body =
    json.to_string(
      json.object([
        #("docs", json.array(docs, fn(x) { x })),
      ]),
    )

  let path = "/" <> config.database <> "/_bulk_docs"

  case make_request(config, http.Post, path, Some(body)) {
    Error(err) -> Error(err)
    Ok(resp) -> {
      case handle_response(resp) {
        Ok(dynamic) -> {
          let list_decoder = decode.list(decode.dynamic)
          case decode.run(dynamic, list_decoder) {
            Ok(results) -> {
              let deleted_revs =
                list.map(results, fn(result) {
                  let rev_decoder =
                    decode.field("rev", decode.string, fn(rev) {
                      decode.success(rev)
                    })
                  case decode.run(result, rev_decoder) {
                    Ok(rev) -> rev
                    Error(_) -> "unknown"
                  }
                })
              Ok(deleted_revs)
            }
            Error(_) ->
              Error(InvalidResponse("Invalid bulk delete response format"))
          }
        }
        Error(err) -> Error(err)
      }
    }
  }
}

/// Gets changes feed since a given sequence
pub fn get_changes(
  config: CouchConfig,
  since: Option(String),
) -> Result(#(String, List(Dict(String, Dynamic))), CouchError) {
  let feed_param = case since {
    Some(seq) -> "?since=" <> seq <> "&include_docs=true"
    None -> "?include_docs=true"
  }
  let path = "/" <> config.database <> "/_changes" <> feed_param

  case make_request(config, http.Get, path, None) {
    Error(err) -> Error(err)
    Ok(resp) -> {
      case handle_response(resp) {
        Ok(dynamic) -> {
          use last_seq <- result.try(
            decode.run(
              dynamic,
              decode.field("last_seq", decode.string, fn(seq) {
                decode.success(seq)
              }),
            )
            |> result.map_error(fn(_) { InvalidResponse("Missing last_seq") }),
          )

          use results <- result.try(
            decode.run(
              dynamic,
              decode.field("results", decode.list(decode.dynamic), fn(res) {
                decode.success(res)
              }),
            )
            |> result.map_error(fn(_) { InvalidResponse("Missing results") }),
          )

          let changes =
            list.filter_map(results, fn(row) {
              let doc_decoder =
                decode.field(
                  "doc",
                  decode.dict(decode.string, decode.dynamic),
                  fn(doc) { decode.success(doc) },
                )
              case decode.run(row, doc_decoder) {
                Ok(doc) -> Ok(doc)
                Error(_) -> Error(Nil)
              }
            })

          Ok(#(last_seq, changes))
        }
        Error(err) -> Error(err)
      }
    }
  }
}
