/// Admin Authentication
///
/// Handles token-based authentication with SHA-256 password hashing.
/// Tokens in config can be either:
/// - SHA-256 hashed (recommended for production): "sha256:<salt>:<hash>"
/// - Plaintext (for development only): "my-token"
import gleam/bit_array
import gleam/crypto.{Sha256}
import gleam/option.{type Option, None, Some}
import gleam/string

import lustre/attribute
import lustre/element/html

import homeserve/base
import homeserve/config.{type Config}
import wisp.{type Request, type Response}

// ---- Constants ----

/// Cookie TTL for admin authentication (24 hours in seconds)
const admin_token_ttl_seconds = 86_400

/// Cookie TTL for CSRF tokens (1 hour in seconds)
const csrf_token_ttl_seconds = 3600

/// Check if the provided token matches the stored token.
/// Supports both SHA-256 hashed tokens and plaintext tokens.
pub fn verify_token(provided: String, stored: String) -> Bool {
  // Check if stored token looks like a SHA-256 hash
  case string.starts_with(stored, "sha256:") {
    True -> {
      // Stored value is a SHA-256 hash, verify using crypto
      case string.split(stored, ":") {
        ["sha256", salt, hash] -> {
          // Recompute hash with the same salt
          let computed = hash_with_salt(provided, salt)
          crypto.secure_compare(
            bit_array.from_string(computed),
            bit_array.from_string(hash),
          )
        }
        _ -> False
      }
    }
    False -> {
      // Check for legacy bcrypt format (for backward compatibility)
      case string.starts_with(stored, "$2") {
        True -> {
          // Legacy bcrypt hash - return False as we can't verify without bcrypt
          // Users should re-generate their token using the new system
          False
        }
        False -> {
          // Stored value is plaintext (legacy/development mode)
          provided == stored
        }
      }
    }
  }
}

/// Hash a plaintext token for storage in config.
/// Use this to generate hashed tokens for production.
pub fn hash_token(token: String) -> String {
  let salt = generate_salt()
  let hash = hash_with_salt(token, salt)
  "sha256:" <> salt <> ":" <> hash
}

/// Generate a random salt using 16 crypto bytes, base64-encoded
fn generate_salt() -> String {
  crypto.strong_random_bytes(16)
  |> bit_array.base64_encode(False)
}

/// Hash a token with a specific salt using SHA-256
fn hash_with_salt(token: String, salt: String) -> String {
  // Combine salt and token, then hash
  let combined = salt <> token
  crypto.hash(Sha256, bit_array.from_string(combined))
  |> bit_array.base64_encode(False)
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
  case wisp.get_cookie(req, "admin_token", wisp.Signed) {
    Ok(token) -> Some(token)
    _ -> None
  }
}

/// Set the auth token as a signed cookie and redirect to clean URL
pub fn set_token_cookie_and_redirect(
  req: Request,
  token: String,
  redirect_path: String,
) -> Response {
  wisp.redirect(redirect_path)
  |> wisp.set_cookie(
    req,
    "admin_token",
    token,
    wisp.Signed,
    admin_token_ttl_seconds,
  )
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

/// Validates the CSRF token from form against the cookie
pub fn validate_csrf_token(req: Request, form_token: String) -> Bool {
  case wisp.get_cookie(req, "csrf_token", wisp.Signed) {
    Ok(cookie_token) -> cookie_token == form_token
    Error(_) -> False
  }
}

/// Sets the CSRF token as a signed cookie on the response.
pub fn set_csrf_cookie(
  resp: Response,
  req: Request,
  csrf_token: String,
) -> Response {
  wisp.set_cookie(
    resp,
    req,
    "csrf_token",
    csrf_token,
    wisp.Signed,
    csrf_token_ttl_seconds,
  )
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
            html.form(
              [attribute.method("POST"), attribute.action("/admin/login")],
              [
                html.div([attribute.class("form-group")], [
                  html.label([attribute.for("token")], [
                    html.text("Access Token"),
                  ]),
                  html.input([
                    attribute.type_("password"),
                    attribute.id("token"),
                    attribute.name("token"),
                    attribute.required(True),
                    attribute.class("input"),
                  ]),
                ]),
                html.button(
                  [
                    attribute.type_("submit"),
                    attribute.class("btn btn-primary"),
                  ],
                  [html.text("LOGIN")],
                ),
              ],
            ),
          ]),
        ],
      ),
    ),
  )
}
