//// Admin Panel for Managing Volunteers
////
//// Provides a web interface for managing volunteers stored in CouchDB.
//// Uses the admin/* modules for authentication, forms, and utilities.
//// Public API
//// Helper Functions

import gleam/http
import gleam/list
import gleam/result
import gleam/string
import gleam/uri

import lustre/attribute
import lustre/element/html

import homeserve/base
import homeserve/config.{type Config}
import homeserve/couchdb
import homeserve/db
import homeserve/pages/admin/auth
import homeserve/pages/admin/forms
import homeserve/pages/admin/util
import homeserve/volunteers.{type Volunteer, Volunteer}
import wisp.{type Request, type Response}

/// Serve the volunteer admin page (GET)
pub fn serve_volunteer_admin(req: Request, cfg: Config) -> Response {
  use <- wisp.require_method(req, http.Get)

  case auth.is_authenticated(req, cfg) {
    False -> auth.render_login_page()
    True -> {
      let token = auth.get_token_string(req)
      let csrf_token = auth.generate_csrf_token()
      let page =
        base.Page(
          head: [html.title([], "Admin - Volunteers | Homeserve")],
          css: [],
          body: [forms.render_volunteer_create_form(token, csrf_token)],
        )

      // Set CSRF token cookie
      let resp = wisp.ok() |> wisp.html_body(base.render_page(page))
      wisp.set_cookie(resp, req, "csrf_token", csrf_token, wisp.PlainText, 3600)
    }
  }
}

/// Handle volunteer creation (POST)
pub fn handle_create(
  req: Request,
  couch_config: couchdb.CouchConfig,
  cfg: Config,
) -> Response {
  use <- wisp.require_method(req, http.Post)

  case auth.is_authenticated(req, cfg) {
    False -> auth.render_login_page()
    True -> {
      use body <- wisp.require_form(req)
      let token = auth.get_token_string(req)

      // Validate CSRF token
      let csrf_token = util.get_form_field(body, "csrf_token")
      case auth.validate_csrf_token(req, csrf_token) {
        False -> {
          render_error_page(
            "Invalid or missing CSRF token. Please refresh the page and try again.",
            [#("/admin/volunteers?token=" <> token, "Back to Volunteers")],
            403,
          )
        }
        True -> {
          case build_volunteer_from_form(body) {
            Error(errors) -> {
              let error_msg = format_validation_errors(errors)
              render_error_page(
                "Validation failed: " <> error_msg,
                [#("/admin/volunteers?token=" <> token, "Back to Volunteers")],
                400,
              )
            }
            Ok(volunteer) -> {
              case db.save_volunteer(couch_config, volunteer) {
                Ok(_) -> {
                  render_success_page(
                    "Volunteer \""
                      <> volunteer.name
                      <> "\" created successfully!",
                    [
                      #(
                        "/admin/volunteers?token=" <> token,
                        "Back to Volunteers",
                      ),
                      #(
                        "/admin/volunteers/list?token=" <> token,
                        "View All Volunteers",
                      ),
                    ],
                    201,
                  )
                }
                Error(err) -> {
                  render_error_page(
                    "Failed to save volunteer: " <> couchdb.error_to_string(err),
                    [
                      #(
                        "/admin/volunteers?token=" <> token,
                        "Back to Volunteers",
                      ),
                    ],
                    500,
                  )
                }
              }
            }
          }
        }
      }
    }
  }
}

/// Serve the volunteer list page
pub fn serve_list(
  req: Request,
  couch_config: couchdb.CouchConfig,
  cfg: Config,
) -> Response {
  use <- wisp.require_method(req, http.Get)

  case auth.is_authenticated(req, cfg) {
    False -> auth.render_login_page()
    True -> {
      let token = auth.get_token_string(req)
      case db.get_all_volunteers(couch_config) {
        Ok(volunteers) -> {
          let page =
            base.Page(
              head: [html.title([], "Admin - Volunteer List | Homeserve")],
              css: [],
              body: [forms.render_volunteer_list(token, volunteers)],
            )
          wisp.ok() |> wisp.html_body(base.render_page(page))
        }
        Error(err) -> {
          render_error_page(
            "Failed to load volunteers: " <> couchdb.error_to_string(err),
            [#("/admin/volunteers?token=" <> token, "Back to Volunteers")],
            500,
          )
        }
      }
    }
  }
}

/// Serve the edit form for an existing volunteer
pub fn serve_edit(
  req: Request,
  couch_config: couchdb.CouchConfig,
  cfg: Config,
  volunteer_name: String,
) -> Response {
  use <- wisp.require_method(req, http.Get)

  case auth.is_authenticated(req, cfg) {
    False -> auth.render_login_page()
    True -> {
      let token = auth.get_token_string(req)
      let decoded_name =
        uri.percent_decode(volunteer_name) |> result.unwrap(volunteer_name)

      case db.load_volunteer(couch_config, decoded_name) {
        Ok(volunteer) -> {
          let csrf_token = auth.generate_csrf_token()
          let page =
            base.Page(
              head: [html.title([], "Admin - Edit Volunteer | Homeserve")],
              css: [],
              body: [
                forms.render_volunteer_edit_form(token, csrf_token, volunteer),
              ],
            )
          let resp = wisp.ok() |> wisp.html_body(base.render_page(page))
          wisp.set_cookie(
            resp,
            req,
            "csrf_token",
            csrf_token,
            wisp.PlainText,
            3600,
          )
        }
        Error(volunteers.FileNotFound(_)) -> {
          render_error_page(
            "Volunteer \"" <> decoded_name <> "\" not found.",
            [#("/admin/volunteers/list?token=" <> token, "Back to List")],
            404,
          )
        }
        Error(_) -> {
          render_error_page(
            "Failed to load volunteer \"" <> decoded_name <> "\"",
            [#("/admin/volunteers/list?token=" <> token, "Back to List")],
            500,
          )
        }
      }
    }
  }
}

/// Handle volunteer update (POST)
pub fn handle_update(
  req: Request,
  couch_config: couchdb.CouchConfig,
  cfg: Config,
) -> Response {
  use <- wisp.require_method(req, http.Post)

  case auth.is_authenticated(req, cfg) {
    False -> auth.render_login_page()
    True -> {
      use body <- wisp.require_form(req)
      let token = auth.get_token_string(req)

      // Validate CSRF token
      let csrf_token = util.get_form_field(body, "csrf_token")
      case auth.validate_csrf_token(req, csrf_token) {
        False -> {
          render_error_page(
            "Invalid or missing CSRF token. Please refresh the page and try again.",
            [#("/admin/volunteers/list?token=" <> token, "Back to List")],
            403,
          )
        }
        True -> {
          let original_name = util.get_form_field(body, "original_name")
          case build_volunteer_from_form(body) {
            Error(errors) -> {
              let error_msg = format_validation_errors(errors)
              render_error_page(
                "Validation failed: " <> error_msg,
                [#("/admin/volunteers/list?token=" <> token, "Back to List")],
                400,
              )
            }
            Ok(volunteer) -> {
              // If name changed, delete the old one and create new
              let name_changed = original_name != volunteer.name

              let result = case name_changed {
                True -> {
                  // Delete old and save new
                  case db.delete_volunteer(couch_config, original_name) {
                    Ok(_) -> db.save_volunteer(couch_config, volunteer)
                    Error(couchdb.NotFound(_)) ->
                      db.save_volunteer(couch_config, volunteer)
                    Error(err) -> Error(err)
                  }
                }
                False -> {
                  // Just update
                  db.update_volunteer(couch_config, volunteer)
                }
              }

              case result {
                Ok(_) -> {
                  render_success_page(
                    "Volunteer \""
                      <> volunteer.name
                      <> "\" updated successfully!",
                    [
                      #(
                        "/admin/volunteers/list?token=" <> token,
                        "Back to List",
                      ),
                      #(
                        "/hoc/" <> uri.percent_encode(volunteer.name),
                        "View Profile",
                      ),
                    ],
                    200,
                  )
                }
                Error(couchdb.NotFound(_)) -> {
                  render_error_page(
                    "Volunteer \"" <> volunteer.name <> "\" not found.",
                    [
                      #(
                        "/admin/volunteers/list?token=" <> token,
                        "Back to List",
                      ),
                    ],
                    404,
                  )
                }
                Error(err) -> {
                  render_error_page(
                    "Failed to update volunteer: "
                      <> couchdb.error_to_string(err),
                    [
                      #(
                        "/admin/volunteers/list?token=" <> token,
                        "Back to List",
                      ),
                    ],
                    500,
                  )
                }
              }
            }
          }
        }
      }
    }
  }
}

/// Handle delete confirmation (GET)
pub fn handle_delete(
  req: Request,
  couch_config: couchdb.CouchConfig,
  cfg: Config,
  volunteer_name: String,
) -> Response {
  use <- wisp.require_method(req, http.Get)

  case auth.is_authenticated(req, cfg) {
    False -> auth.render_login_page()
    True -> {
      let token = auth.get_token_string(req)
      let decoded_name =
        uri.percent_decode(volunteer_name) |> result.unwrap(volunteer_name)

      // Check if volunteer exists
      case db.load_volunteer(couch_config, decoded_name) {
        Ok(_) -> {
          let csrf_token = auth.generate_csrf_token()
          let page =
            base.Page(
              head: [html.title([], "Admin - Delete Volunteer | Homeserve")],
              css: [],
              body: [
                forms.render_volunteer_delete_confirmation(
                  token,
                  csrf_token,
                  decoded_name,
                ),
              ],
            )
          let resp = wisp.ok() |> wisp.html_body(base.render_page(page))
          wisp.set_cookie(
            resp,
            req,
            "csrf_token",
            csrf_token,
            wisp.PlainText,
            3600,
          )
        }
        Error(volunteers.FileNotFound(_)) -> {
          render_error_page(
            "Volunteer \"" <> decoded_name <> "\" not found.",
            [#("/admin/volunteers/list?token=" <> token, "Back to List")],
            404,
          )
        }
        Error(_) -> {
          render_error_page(
            "Failed to load volunteer \"" <> decoded_name <> "\"",
            [#("/admin/volunteers/list?token=" <> token, "Back to List")],
            500,
          )
        }
      }
    }
  }
}

/// Handle volunteer deletion (POST)
pub fn handle_delete_post(
  req: Request,
  couch_config: couchdb.CouchConfig,
  cfg: Config,
  volunteer_name: String,
) -> Response {
  use <- wisp.require_method(req, http.Post)

  case auth.is_authenticated(req, cfg) {
    False -> auth.render_login_page()
    True -> {
      use body <- wisp.require_form(req)
      let token = auth.get_token_string(req)
      let decoded_name =
        uri.percent_decode(volunteer_name) |> result.unwrap(volunteer_name)

      // Validate CSRF token
      let csrf_token = util.get_form_field(body, "csrf_token")
      case auth.validate_csrf_token(req, csrf_token) {
        False -> {
          render_error_page(
            "Invalid or missing CSRF token. Please refresh the page and try again.",
            [#("/admin/volunteers/list?token=" <> token, "Back to List")],
            403,
          )
        }
        True -> {
          case db.delete_volunteer(couch_config, decoded_name) {
            Ok(_) -> {
              render_success_page(
                "Volunteer \"" <> decoded_name <> "\" deleted successfully.",
                [#("/admin/volunteers/list?token=" <> token, "Back to List")],
                200,
              )
            }
            Error(couchdb.NotFound(_)) -> {
              render_error_page(
                "Volunteer \"" <> decoded_name <> "\" not found.",
                [#("/admin/volunteers/list?token=" <> token, "Back to List")],
                404,
              )
            }
            Error(err) -> {
              render_error_page(
                "Failed to delete volunteer: " <> couchdb.error_to_string(err),
                [#("/admin/volunteers/list?token=" <> token, "Back to List")],
                500,
              )
            }
          }
        }
      }
    }
  }
}

/// Validation result type
pub type ValidationError {
  FieldTooLong(field: String, max: Int)
  InvalidCharacters(field: String)
  MissingRequiredField(field: String)
}

/// Maximum lengths for form fields
const max_name_length = 100

const max_bio_length = 2000

const max_url_length = 1000

/// Get form field value or empty string
fn get_form_field(body: wisp.FormData, name: String) -> String {
  case list.key_find(body.values, name) {
    Ok(value) -> value
    Error(_) -> ""
  }
}

/// Parse comma-separated list
fn parse_list(value: String) -> List(String) {
  value
  |> string.split(",")
  |> list.map(string.trim)
  |> list.filter(fn(s) { s != "" })
}

/// Validates a name field
fn validate_name(name: String) -> Result(String, ValidationError) {
  let trimmed = string.trim(name)
  case string.is_empty(trimmed) {
    True -> Error(MissingRequiredField("name"))
    False -> {
      case string.length(trimmed) > max_name_length {
        True -> Error(FieldTooLong("name", max_name_length))
        False -> {
          case string.contains(trimmed, "\u{0000}") {
            True -> Error(InvalidCharacters("name"))
            False -> Ok(trimmed)
          }
        }
      }
    }
  }
}

/// Validates bio field
fn validate_bio(bio: String) -> Result(String, ValidationError) {
  case string.length(bio) > max_bio_length {
    True -> Error(FieldTooLong("bio", max_bio_length))
    False -> {
      case string.contains(bio, "\u{0000}") {
        True -> Error(InvalidCharacters("bio"))
        False -> Ok(bio)
      }
    }
  }
}

/// Validates URL list
fn validate_social_links(links: List(String)) -> List(String) {
  links
  |> list.filter(fn(link) {
    let trimmed = string.trim(link)
    !string.is_empty(trimmed)
    && string.length(trimmed) <= max_url_length
    && !string.contains(trimmed, "\u{0000}")
  })
}

/// Build Volunteer from form data with validation
fn build_volunteer_from_form(
  body: wisp.FormData,
) -> Result(Volunteer, List(ValidationError)) {
  // Validate required fields
  let name_result = validate_name(get_form_field(body, "name"))
  let bio_result = validate_bio(get_form_field(body, "bio"))

  // Collect all errors
  let errors = case name_result {
    Error(err) -> [err]
    Ok(_) -> []
  }
  let errors = case bio_result {
    Error(err) -> [err, ..errors]
    Ok(_) -> errors
  }

  case errors {
    [] -> {
      // All validations passed, build the volunteer
      let assert Ok(name) = name_result
      let assert Ok(bio) = bio_result

      let social_links =
        validate_social_links(parse_list(get_form_field(body, "social_links")))

      Ok(Volunteer(name:, social_links:, bio:))
    }
    errs -> Error(errs)
  }
}

/// Format validation errors for display
fn format_validation_errors(errors: List(ValidationError)) -> String {
  errors
  |> list.map(fn(err) {
    case err {
      FieldTooLong(field, max) ->
        field <> " is too long (max " <> string.inspect(max) <> " characters)"
      InvalidCharacters(field) -> field <> " contains invalid characters"
      MissingRequiredField(field) -> field <> " is required"
    }
  })
  |> string.join("; ")
}

fn render_error_page(
  message: String,
  links: List(#(String, String)),
  status: Int,
) -> Response {
  let link_elements =
    list.map(links, fn(link) {
      let #(url, text) = link
      html.h2([], [
        html.a([attribute.href(url), attribute.class("btn btn-primary")], [
          html.text("> " <> text),
        ]),
      ])
    })

  let page =
    base.Page(head: [html.title([], "Error | Homeserve")], css: [], body: [
      html.div([attribute.class("dead-center")], [
        html.h1([], [html.text("ERROR")]),
        html.p([], [html.text(message)]),
        ..link_elements
      ]),
    ])
  wisp.response(status) |> wisp.html_body(base.render_page(page))
}

fn render_success_page(
  message: String,
  links: List(#(String, String)),
  status: Int,
) -> Response {
  let link_elements =
    list.map(links, fn(link) {
      let #(url, text) = link
      html.h2([], [
        html.a([attribute.href(url), attribute.class("btn btn-primary")], [
          html.text("> " <> text),
        ]),
      ])
    })

  let page =
    base.Page(head: [html.title([], "Success | Homeserve")], css: [], body: [
      html.div([attribute.class("dead-center")], [
        html.h1([], [html.text("SUCCESS")]),
        html.p([], [html.text(message)]),
        ..link_elements
      ]),
    ])
  wisp.response(status) |> wisp.html_body(base.render_page(page))
}
