/// Admin Authentication
///
/// Handles token-based authentication with bcrypt password hashing.
/// Tokens in config can be either:
/// - Bcrypt hashed (recommended for production): "$2b$10$..."
/// - Plaintext (for development only): "my-token"
import beecrypt
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

import lustre/attribute
import lustre/element/html

import homeserve/base
import homeserve/config.{type Config}
import wisp.{type Request, type Response}

/// Check if the provided token matches the stored token.
/// Supports both bcrypt hashed tokens and plaintext tokens.
pub fn verify_token(provided: String, stored: String) -> Bool {
  // Check if stored token looks like a bcrypt hash
  case string.starts_with(stored, "$2") {
    True -> {
      // Stored value is a bcrypt hash, verify using bcrypt
      beecrypt.verify(provided, stored)
    }
    False -> {
      // Stored value is plaintext (legacy/development mode)
      provided == stored
    }
  }
}

/// Hash a plaintext token for storage in config.
/// Use this to generate hashed tokens for production.
pub fn hash_token(token: String) -> String {
  beecrypt.hash(token)
}

/// Check if request has valid authentication
pub fn is_authenticated(req: Request, cfg: Config) -> Bool {
  case get_token(req) {
    Some(token) -> verify_token(token, cfg.admin.token)
    None -> False
  }
}

/// Extract token from request (cookie or query param)
pub fn get_token(req: Request) -> Option(String) {
  case wisp.get_cookie(req, "admin_token", wisp.PlainText) {
    Ok(token) -> Some(token)
    _ -> {
      let query = wisp.get_query(req)
      case list.key_find(query, "token") {
        Ok(token) -> Some(token)
        _ -> None
      }
    }
  }
}

/// Get token string or empty
pub fn get_token_string(req: Request) -> String {
  case get_token(req) {
    Some(t) -> t
    None -> ""
  }
}

/// Generates a new CSRF token for form protection
/// Uses cryptographically secure random string from wisp
pub fn generate_csrf_token() -> String {
  wisp.random_string(32)
}

/// Sets the CSRF token cookie and returns the token
pub fn set_csrf_cookie(req: Request, res: Response) -> #(Response, String) {
  let token = generate_csrf_token()
  let res_with_cookie =
    wisp.set_cookie(
      res,
      req,
      "csrf_token",
      token,
      wisp.PlainText,
      3600,
      // 1 hour expiry
    )
  #(res_with_cookie, token)
}

/// Validates the CSRF token from form against the cookie
pub fn validate_csrf_token(req: Request, form_token: String) -> Bool {
  case wisp.get_cookie(req, "csrf_token", wisp.PlainText) {
    Ok(cookie_token) -> cookie_token == form_token
    Error(_) -> False
  }
}

/// Render the login page response
pub fn render_login_page() -> Response {
  wisp.response(401)
  |> wisp.html_body(
    base.render_page(
      base.Page(
        head: [html.title([], "Admin Login | Homeserve")],
        css: [],
        body: [
          html.div([attribute.class("dead-center")], [
            html.h1([], [html.text("ADMIN LOGIN")]),
            html.form([attribute.method("GET"), attribute.action("/admin")], [
              html.div([attribute.class("form-group")], [
                html.label([attribute.for("token")], [html.text("Access Token")]),
                html.input([
                  attribute.type_("password"),
                  attribute.id("token"),
                  attribute.name("token"),
                  attribute.required(True),
                  attribute.class("input"),
                ]),
              ]),
              html.button(
                [attribute.type_("submit"), attribute.class("btn btn-primary")],
                [html.text("LOGIN")],
              ),
            ]),
          ]),
        ],
      ),
    ),
  )
}
