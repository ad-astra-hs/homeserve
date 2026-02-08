/// Cookie Handling
///
/// Provides utilities for working with cookies including
/// accessibility toggles for quirks and animations.
import gleam/bool
import wisp

/// One year in seconds
const cookie_max_age_seconds = 31_536_000

/// Cookie name for quirks toggle
const quirks_cookie_name = "quirked"

/// Cookie name for animations toggle  
const animations_cookie_name = "animated"

/// Gets a boolean value from a cookie.
/// Returns the default value if the cookie is not present or invalid.
pub fn get_bool_cookie(req: wisp.Request, name: String, default: Bool) -> Bool {
  case wisp.get_cookie(req, name, wisp.PlainText) {
    Ok("False") -> False
    Ok("True") -> True
    _ -> default
  }
}

/// Sets a boolean cookie value.
pub fn set_bool_cookie(
  res: wisp.Response,
  req: wisp.Request,
  name: String,
  value: Bool,
) -> wisp.Response {
  wisp.set_cookie(
    res,
    req,
    name,
    bool.to_string(value),
    wisp.PlainText,
    cookie_max_age_seconds,
  )
}

/// Gets the quirks mode setting from cookies.
pub fn get_quirks(req: wisp.Request) -> Bool {
  get_bool_cookie(req, quirks_cookie_name, True)
}

/// Gets the animation setting from cookies.
pub fn get_animations(req: wisp.Request) -> Bool {
  get_bool_cookie(req, animations_cookie_name, True)
}
