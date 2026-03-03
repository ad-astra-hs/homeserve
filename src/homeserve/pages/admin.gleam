//// Admin Panel for Creating/Editing/Deleting Panels
////
//// Provides a web interface for managing panels stored in Mnesia.
//// Uses the admin/* modules for authentication, forms, and utilities.

import gleam/http
import gleam/int
import gleam/list
import gleam/result
import gleam/string

import lustre/attribute
import lustre/element/html

import homeserve/base
import homeserve/config.{type Config}
import homeserve/db
import homeserve/logging
import homeserve/mnesia_db
import homeserve/pages/admin/auth
import homeserve/pages/admin/forms
import homeserve/pages/admin/util
import homeserve/pages/panel/types
import homeserve/pagination
import homeserve/rate_limit
import wisp.{type Request, type Response}

// ---- Constants ----

/// Number of panels to display per page in the list view
const panels_per_page = 10

// ---- Public API ----

/// Serve the admin page (GET)
/// Handle POST /admin/login — verifies token from form body, sets cookie, redirects.
pub fn handle_login(req: Request, cfg: Config) -> Response {
  use <- wisp.require_method(req, http.Post)
  use form <- wisp.require_form(req)

  let ip = get_client_ip(req)
  case rate_limit.check(ip) {
    rate_limit.RateLimited -> render_rate_limited_page()
    rate_limit.Allowed -> {
      case list.key_find(form.values, "token") {
        Error(_) -> auth.render_login_page()
        Ok(token) -> {
          case auth.verify_token(token, cfg.admin.token) {
            True -> {
              rate_limit.reset(ip)
              auth.set_token_cookie_and_redirect(req, token, "/admin")
            }
            False -> {
              rate_limit.record_failure(ip)
              logging.warning_ctx("AUTH", "Failed login attempt from " <> ip)
              auth.render_login_page()
            }
          }
        }
      }
    }
  }
}

pub fn serve_admin(req: Request, cfg: Config) -> Response {
  use <- wisp.require_method(req, http.Get)

  case auth.is_authenticated(req, cfg) {
    False -> auth.render_login_page()
    True -> {
      let csrf_token = auth.generate_csrf_token()
      let page =
        base.Page(
          head: [html.title([], "Admin - Create Panel | Homeserve")],
          css: [],
          body: [forms.render_create_form(csrf_token, cfg)],
        )

      // Set CSRF token cookie
      let resp = wisp.ok() |> wisp.html_body(base.render_page(page))
      auth.set_csrf_cookie(resp, req, csrf_token)
    }
  }
}

// ---- Private helpers ----

/// Extract the client IP from request headers.
/// Checks x-forwarded-for (proxy), then x-real-ip, falling back to "unknown".
fn get_client_ip(req: Request) -> String {
  case list.key_find(req.headers, "x-forwarded-for") {
    Ok(forwarded) ->
      forwarded
      |> string.split(",")
      |> list.first
      |> result.unwrap("unknown")
      |> string.trim
    Error(_) ->
      case list.key_find(req.headers, "x-real-ip") {
        Ok(ip) -> string.trim(ip)
        Error(_) -> "unknown"
      }
  }
}

/// Render a 429 Too Many Requests response for rate-limited login attempts.
fn render_rate_limited_page() -> Response {
  wisp.response(429)
  |> wisp.html_body(
    base.render_page(
      base.Page(
        head: [html.title([], "Too Many Requests | Homeserve")],
        css: [],
        body: [
          html.div([attribute.class("dead-center")], [
            html.h1([], [html.text("TOO MANY ATTEMPTS")]),
            html.p([], [
              html.text(
                "Too many failed login attempts. Please wait 5 minutes before trying again.",
              ),
            ]),
            html.a(
              [attribute.href("/admin"), attribute.class("btn btn-primary")],
              [html.text("Back to Login")],
            ),
          ]),
        ],
      ),
    ),
  )
}

/// Handle panel creation (POST)
pub fn handle_create(req: Request, cfg: Config) -> Response {
  use <- wisp.require_method(req, http.Post)

  case auth.is_authenticated(req, cfg) {
    False -> auth.render_login_page()
    True -> {
      use body <- wisp.require_form(req)

      // Validate CSRF token
      let csrf_token = util.get_form_field(body, "csrf_token")
      case auth.validate_csrf_token(req, csrf_token) {
        False -> {
          util.render_error_page(
            "Invalid or missing CSRF token. Please refresh the page and try again.",
            [#("/admin", "Back to Admin")],
            403,
          )
        }
        True -> {
          case int.base_parse(util.get_form_field(body, "index"), 10) {
            Error(_) -> {
              util.render_error_page(
                "Invalid panel index. Must be a number.",
                [
                  #("/admin", "Back to Admin"),
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
                    [#("/admin", "Back to Admin")],
                    400,
                  )
                }
                Ok(panel) -> {
                  case db.save_panel(panel) {
                    Ok(_) -> {
                      logging.log_panel("created", index)
                      util.render_success_page(
                        "Panel #"
                          <> int.to_string(index)
                          <> " created successfully!",
                        [
                          #("/admin", "Back to Admin"),
                          #("/admin/list", "View All Panels"),
                        ],
                        201,
                      )
                    }
                    Error(err) -> {
                      logging.error_ctx(
                        "ADMIN",
                        "Failed to create panel #"
                          <> int.to_string(index)
                          <> ": "
                          <> mnesia_db.error_to_string(err),
                      )
                      util.render_error_page(
                        "Failed to save panel: "
                          <> mnesia_db.error_to_string(err),
                        [
                          #("/admin", "Back to Admin"),
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

/// Serve the panel list page with pagination
pub fn serve_list(req: Request, cfg: Config) -> Response {
  use <- wisp.require_method(req, http.Get)

  case auth.is_authenticated(req, cfg) {
    False -> auth.render_login_page()
    True -> {
      // Parse pagination parameters
      let query_params = wisp.get_query(req)
      let page = pagination.parse_page_param(query_params)

      case db.get_all_meta() {
        Ok(all_panels) -> {
          let sorted_panels =
            all_panels
            |> sort_panels_by_index

          let total_panels = list.length(sorted_panels)
          let total_pages =
            pagination.calculate_total_pages(total_panels, panels_per_page)
          let current_page = pagination.clamp_page(page, total_pages)

          // Get paginated subset
          let paginated_panels =
            pagination.get_page(sorted_panels, current_page, panels_per_page)

          let page =
            base.Page(
              head: [html.title([], "Admin - Panel List | Homeserve")],
              css: [],
              body: [
                forms.render_panel_list(
                  paginated_panels,
                  current_page,
                  total_pages,
                  total_panels,
                ),
              ],
            )
          wisp.ok() |> wisp.html_body(base.render_page(page))
        }
        Error(err) -> {
          logging.error_ctx(
            "ADMIN",
            "Failed to load panels: " <> mnesia_db.error_to_string(err),
          )
          util.render_error_page(
            "Failed to load panels: " <> mnesia_db.error_to_string(err),
            [
              #("/admin", "Back to Admin"),
            ],
            500,
          )
        }
      }
    }
  }
}

/// Serve the edit form for an existing panel
pub fn serve_edit(req: Request, cfg: Config, panel_index: String) -> Response {
  use <- wisp.require_method(req, http.Get)

  case auth.is_authenticated(req, cfg) {
    False -> auth.render_login_page()
    True -> {
      case int.base_parse(panel_index, 10) {
        Error(_) -> {
          util.render_error_page(
            "Invalid panel index.",
            [
              #("/admin/list", "Back to List"),
            ],
            400,
          )
        }
        Ok(index) -> {
          case db.load_panel(index) {
            Ok(panel) -> {
              let csrf_token = auth.generate_csrf_token()
              let page =
                base.Page(
                  head: [html.title([], "Admin - Edit Panel | Homeserve")],
                  css: [],
                  body: [forms.render_edit_form(csrf_token, panel)],
                )
              let resp = wisp.ok() |> wisp.html_body(base.render_page(page))
              auth.set_csrf_cookie(resp, req, csrf_token)
            }
            Error(types.FileNotFound(_)) -> {
              util.render_error_page(
                "Panel not found.",
                [
                  #("/admin/list", "Back to List"),
                ],
                404,
              )
            }
            Error(_) -> {
              logging.error_ctx(
                "ADMIN",
                "Failed to load panel #" <> panel_index,
              )
              util.render_error_page(
                "Unable to load panel. Please try again later.",
                [
                  #("/admin/list", "Back to List"),
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

// ---- Helper Functions ----

fn render_delete_confirmation(
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
        attribute.action("/admin/delete/" <> panel_index),
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
              attribute.href("/admin/list"),
              attribute.class("btn btn-secondary"),
            ],
            [html.text("CANCEL")],
          ),
        ]),
      ],
    ),
  ])
}

/// Sort panels by index
fn sort_panels_by_index(panels: List(types.Meta)) -> List(types.Meta) {
  list.sort(panels, fn(a, b) { int.compare(a.index, b.index) })
}

/// Handle panel update (POST)
pub fn handle_update(req: Request, cfg: Config) -> Response {
  use <- wisp.require_method(req, http.Post)

  case auth.is_authenticated(req, cfg) {
    False -> auth.render_login_page()
    True -> {
      use body <- wisp.require_form(req)

      // Validate CSRF token
      let csrf_token = util.get_form_field(body, "csrf_token")
      case auth.validate_csrf_token(req, csrf_token) {
        False -> {
          util.render_error_page(
            "Invalid or missing CSRF token. Please refresh the page and try again.",
            [#("/admin/list", "Back to List")],
            403,
          )
        }
        True -> {
          case int.base_parse(util.get_form_field(body, "index"), 10) {
            Error(_) -> {
              util.render_error_page(
                "Invalid panel index.",
                [
                  #("/admin/list", "Back to List"),
                ],
                400,
              )
            }
            Ok(index) -> {
              let original_date = case db.load_panel(index) {
                Ok(existing) -> existing.meta.date
                Error(_) -> util.current_timestamp()
              }
              case util.build_panel_from_form(body, index, original_date) {
                Error(errors) -> {
                  let error_msg = util.format_validation_errors(errors)
                  util.render_error_page(
                    "Validation failed: " <> error_msg,
                    [#("/admin/list", "Back to List")],
                    400,
                  )
                }
                Ok(panel) -> {
                  case db.update_panel(panel) {
                    Ok(_) -> {
                      logging.log_panel("updated", index)
                      util.render_success_page(
                        "Panel #"
                          <> int.to_string(index)
                          <> " updated successfully!",
                        [
                          #("/admin/list", "Back to List"),
                          #("/read/" <> int.to_string(index), "View Panel"),
                        ],
                        200,
                      )
                    }
                    Error(mnesia_db.NotFound(_)) -> {
                      util.render_error_page(
                        "Panel #" <> int.to_string(index) <> " not found.",
                        [
                          #("/admin/list", "Back to List"),
                        ],
                        404,
                      )
                    }
                    Error(err) -> {
                      logging.error_ctx(
                        "ADMIN",
                        "Failed to update panel #"
                          <> int.to_string(index)
                          <> ": "
                          <> mnesia_db.error_to_string(err),
                      )
                      util.render_error_page(
                        "Failed to update panel: "
                          <> mnesia_db.error_to_string(err),
                        [
                          #("/admin/list", "Back to List"),
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
pub fn handle_delete(req: Request, cfg: Config, panel_index: String) -> Response {
  use <- wisp.require_method(req, http.Get)

  case auth.is_authenticated(req, cfg) {
    False -> auth.render_login_page()
    True -> {
      case int.base_parse(panel_index, 10) {
        Error(_) -> {
          util.render_error_page(
            "Invalid panel index.",
            [
              #("/admin/list", "Back to List"),
            ],
            400,
          )
        }
        Ok(index) -> {
          case db.load_panel(index) {
            Ok(panel) -> {
              let csrf_token = auth.generate_csrf_token()
              let page =
                base.Page(
                  head: [html.title([], "Admin - Delete Panel | Homeserve")],
                  css: [],
                  body: [
                    render_delete_confirmation(csrf_token, panel_index, panel),
                  ],
                )
              let resp = wisp.ok() |> wisp.html_body(base.render_page(page))
              auth.set_csrf_cookie(resp, req, csrf_token)
            }
            Error(types.FileNotFound(_)) -> {
              util.render_error_page(
                "Panel not found.",
                [
                  #("/admin/list", "Back to List"),
                ],
                404,
              )
            }
            Error(_) -> {
              logging.error_ctx(
                "ADMIN",
                "Failed to load panel #" <> panel_index,
              )
              util.render_error_page(
                "Unable to load panel. Please try again later.",
                [
                  #("/admin/list", "Back to List"),
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
  cfg: Config,
  panel_index: String,
) -> Response {
  use <- wisp.require_method(req, http.Post)

  case auth.is_authenticated(req, cfg) {
    False -> auth.render_login_page()
    True -> {
      use body <- wisp.require_form(req)

      // Validate CSRF token
      let csrf_token = util.get_form_field(body, "csrf_token")
      case auth.validate_csrf_token(req, csrf_token) {
        False -> {
          util.render_error_page(
            "Invalid or missing CSRF token. Please refresh the page and try again.",
            [#("/admin/list", "Back to List")],
            403,
          )
        }
        True -> {
          case int.base_parse(panel_index, 10) {
            Error(_) -> {
              util.render_error_page(
                "Invalid panel index.",
                [
                  #("/admin/list", "Back to List"),
                ],
                400,
              )
            }
            Ok(index) -> {
              case db.delete_panel(index) {
                Ok(_) -> {
                  logging.log_panel("deleted", index)
                  util.render_success_page(
                    "Panel #" <> panel_index <> " deleted successfully.",
                    [#("/admin/list", "Back to List")],
                    200,
                  )
                }
                Error(mnesia_db.NotFound(_)) -> {
                  util.render_error_page(
                    "Panel #" <> panel_index <> " not found.",
                    [#("/admin/list", "Back to List")],
                    404,
                  )
                }
                Error(err) -> {
                  logging.error_ctx(
                    "ADMIN",
                    "Failed to delete panel #"
                      <> panel_index
                      <> ": "
                      <> mnesia_db.error_to_string(err),
                  )
                  util.render_error_page(
                    "Failed to delete panel: " <> mnesia_db.error_to_string(err),
                    [#("/admin/list", "Back to List")],
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
