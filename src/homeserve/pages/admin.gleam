//// Admin Panel for Creating/Editing/Deleting Panels
////
//// Provides a web interface for managing panels stored in CouchDB.
//// Uses the admin/* modules for authentication, forms, and utilities.

import gleam/http
import gleam/int

import lustre/attribute
import lustre/element/html

import homeserve/base
import homeserve/config.{type Config}
import homeserve/couchdb
import homeserve/db
import homeserve/pages/admin/auth
import homeserve/pages/admin/forms
import homeserve/pages/admin/util
import homeserve/pages/panel/types
import wisp.{type Request, type Response}

// ---- Public API ----

/// Serve the admin page (GET)
pub fn serve_admin(req: Request, cfg: Config) -> Response {
  use <- wisp.require_method(req, http.Get)

  case auth.is_authenticated(req, cfg) {
    False -> auth.render_login_page()
    True -> {
      let token = auth.get_token_string(req)
      let csrf_token = auth.generate_csrf_token()
      let page =
        base.Page(
          head: [html.title([], "Admin - Create Panel | Homeserve")],
          css: [],
          body: [forms.render_create_form(token, csrf_token, cfg)],
        )

      // Set CSRF token cookie
      let resp = wisp.ok() |> wisp.html_body(base.render_page(page))
      wisp.set_cookie(resp, req, "csrf_token", csrf_token, wisp.PlainText, 3600)
    }
  }
}

/// Handle panel creation (POST)
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
          util.render_error_page(
            "Invalid or missing CSRF token. Please refresh the page and try again.",
            [#("/admin?token=" <> token, "Back to Admin")],
            403,
          )
        }
        True -> {
          case int.base_parse(util.get_form_field(body, "index"), 10) {
            Error(_) -> {
              util.render_error_page(
                "Invalid panel index. Must be a number.",
                [
                  #("/admin?token=" <> token, "Back to Admin"),
                ],
                400,
              )
            }
            Ok(index) -> {
              case
                util.build_panel_from_form(
                  body,
                  index,
                  util.current_timestamp(),
                )
              {
                Error(errors) -> {
                  let error_msg = util.format_validation_errors(errors)
                  util.render_error_page(
                    "Validation failed: " <> error_msg,
                    [#("/admin?token=" <> token, "Back to Admin")],
                    400,
                  )
                }
                Ok(panel) -> {
                  case db.save_panel(couch_config, panel) {
                    Ok(_) -> {
                      util.render_success_page(
                        "Panel #"
                          <> int.to_string(index)
                          <> " created successfully!",
                        [
                          #("/admin?token=" <> token, "Back to Admin"),
                          #("/admin/list?token=" <> token, "View All Panels"),
                        ],
                        201,
                      )
                    }
                    Error(err) -> {
                      util.render_error_page(
                        "Failed to save panel: " <> couchdb.error_to_string(err),
                        [
                          #("/admin?token=" <> token, "Back to Admin"),
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
  }
}

/// Serve the panel list page
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
      case db.get_all_meta(couch_config) {
        Ok(panels) -> {
          let page =
            base.Page(
              head: [html.title([], "Admin - Panel List | Homeserve")],
              css: [],
              body: [forms.render_panel_list(token, panels)],
            )
          wisp.ok() |> wisp.html_body(base.render_page(page))
        }
        Error(err) -> {
          util.render_error_page(
            "Failed to load panels: " <> couchdb.error_to_string(err),
            [
              #("/admin?token=" <> token, "Back to Admin"),
            ],
            500,
          )
        }
      }
    }
  }
}

/// Serve the edit form for an existing panel
pub fn serve_edit(
  req: Request,
  couch_config: couchdb.CouchConfig,
  cfg: Config,
  panel_index: String,
) -> Response {
  use <- wisp.require_method(req, http.Get)

  case auth.is_authenticated(req, cfg) {
    False -> auth.render_login_page()
    True -> {
      let token = auth.get_token_string(req)
      case int.base_parse(panel_index, 10) {
        Error(_) -> {
          util.render_error_page(
            "Invalid panel index.",
            [
              #("/admin/list?token=" <> token, "Back to List"),
            ],
            400,
          )
        }
        Ok(index) -> {
          case db.load_panel(couch_config, index) {
            Ok(panel) -> {
              let csrf_token = auth.generate_csrf_token()
              let page =
                base.Page(
                  head: [html.title([], "Admin - Edit Panel | Homeserve")],
                  css: [],
                  body: [forms.render_edit_form(token, csrf_token, panel)],
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
            Error(types.FileNotFound(_)) -> {
              util.render_error_page(
                "Panel #" <> panel_index <> " not found.",
                [
                  #("/admin/list?token=" <> token, "Back to List"),
                ],
                404,
              )
            }
            Error(_) -> {
              util.render_error_page(
                "Failed to load panel #" <> panel_index,
                [
                  #("/admin/list?token=" <> token, "Back to List"),
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

/// Handle panel update (POST)
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
          util.render_error_page(
            "Invalid or missing CSRF token. Please refresh the page and try again.",
            [#("/admin/list?token=" <> token, "Back to List")],
            403,
          )
        }
        True -> {
          case int.base_parse(util.get_form_field(body, "index"), 10) {
            Error(_) -> {
              util.render_error_page(
                "Invalid panel index.",
                [
                  #("/admin/list?token=" <> token, "Back to List"),
                ],
                400,
              )
            }
            Ok(index) -> {
              let original_date = case db.load_panel(couch_config, index) {
                Ok(existing) -> existing.meta.date
                Error(_) -> util.current_timestamp()
              }
              case util.build_panel_from_form(body, index, original_date) {
                Error(errors) -> {
                  let error_msg = util.format_validation_errors(errors)
                  util.render_error_page(
                    "Validation failed: " <> error_msg,
                    [#("/admin/list?token=" <> token, "Back to List")],
                    400,
                  )
                }
                Ok(panel) -> {
                  case db.update_panel(couch_config, panel) {
                    Ok(_) -> {
                      util.render_success_page(
                        "Panel #"
                          <> int.to_string(index)
                          <> " updated successfully!",
                        [
                          #("/admin/list?token=" <> token, "Back to List"),
                          #("/read/" <> int.to_string(index), "View Panel"),
                        ],
                        200,
                      )
                    }
                    Error(couchdb.NotFound(_)) -> {
                      util.render_error_page(
                        "Panel #" <> int.to_string(index) <> " not found.",
                        [
                          #("/admin/list?token=" <> token, "Back to List"),
                        ],
                        404,
                      )
                    }
                    Error(err) -> {
                      util.render_error_page(
                        "Failed to update panel: "
                          <> couchdb.error_to_string(err),
                        [
                          #("/admin/list?token=" <> token, "Back to List"),
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
  }
}

/// Handle delete confirmation (GET)
pub fn handle_delete(
  req: Request,
  couch_config: couchdb.CouchConfig,
  cfg: Config,
  panel_index: String,
) -> Response {
  use <- wisp.require_method(req, http.Get)

  case auth.is_authenticated(req, cfg) {
    False -> auth.render_login_page()
    True -> {
      let token = auth.get_token_string(req)
      case int.base_parse(panel_index, 10) {
        Error(_) -> {
          util.render_error_page(
            "Invalid panel index.",
            [
              #("/admin/list?token=" <> token, "Back to List"),
            ],
            400,
          )
        }
        Ok(index) -> {
          case db.load_panel(couch_config, index) {
            Ok(panel) -> {
              let csrf_token = auth.generate_csrf_token()
              let page =
                base.Page(
                  head: [html.title([], "Admin - Delete Panel | Homeserve")],
                  css: [],
                  body: [
                    render_delete_confirmation(
                      token,
                      csrf_token,
                      panel_index,
                      panel,
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
            Error(types.FileNotFound(_)) -> {
              util.render_error_page(
                "Panel #" <> panel_index <> " not found.",
                [
                  #("/admin/list?token=" <> token, "Back to List"),
                ],
                404,
              )
            }
            Error(_) -> {
              util.render_error_page(
                "Failed to load panel #" <> panel_index,
                [
                  #("/admin/list?token=" <> token, "Back to List"),
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

/// Handle panel deletion (POST)
pub fn handle_delete_post(
  req: Request,
  couch_config: couchdb.CouchConfig,
  cfg: Config,
  panel_index: String,
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
          util.render_error_page(
            "Invalid or missing CSRF token. Please refresh the page and try again.",
            [#("/admin/list?token=" <> token, "Back to List")],
            403,
          )
        }
        True -> {
          case int.base_parse(panel_index, 10) {
            Error(_) -> {
              util.render_error_page(
                "Invalid panel index.",
                [
                  #("/admin/list?token=" <> token, "Back to List"),
                ],
                400,
              )
            }
            Ok(index) -> {
              case db.delete_panel(couch_config, index) {
                Ok(_) -> {
                  util.render_success_page(
                    "Panel #" <> panel_index <> " deleted successfully.",
                    [
                      #("/admin/list?token=" <> token, "Back to List"),
                    ],
                    200,
                  )
                }
                Error(couchdb.NotFound(_)) -> {
                  util.render_error_page(
                    "Panel #" <> panel_index <> " not found.",
                    [
                      #("/admin/list?token=" <> token, "Back to List"),
                    ],
                    404,
                  )
                }
                Error(err) -> {
                  util.render_error_page(
                    "Failed to delete panel: " <> couchdb.error_to_string(err),
                    [
                      #("/admin/list?token=" <> token, "Back to List"),
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

// ---- Helper Functions ----

fn render_delete_confirmation(
  token: String,
  csrf_token: String,
  panel_index: String,
  panel: types.Panel,
) {
  html.div([attribute.class("dead-center")], [
    html.h1([], [html.text("DELETE PANEL")]),
    html.p([], [
      html.text("Panel #" <> panel_index <> ": \"" <> panel.meta.title <> "\""),
    ]),
    html.p([attribute.class("status-draft")], [
      html.text("This action cannot be undone!"),
    ]),
    html.form(
      [
        attribute.method("POST"),
        attribute.action("/admin/delete/" <> panel_index <> "?token=" <> token),
      ],
      [
        html.input([
          attribute.type_("hidden"),
          attribute.name("csrf_token"),
          attribute.value(csrf_token),
        ]),
        html.div([attribute.class("flex-row")], [
          html.button(
            [attribute.type_("submit"), attribute.class("btn btn-danger")],
            [html.text("YES, DELETE")],
          ),
          html.a(
            [
              attribute.href("/admin/list?token=" <> token),
              attribute.class("btn btn-secondary"),
            ],
            [html.text("CANCEL")],
          ),
        ]),
      ],
    ),
  ])
}
