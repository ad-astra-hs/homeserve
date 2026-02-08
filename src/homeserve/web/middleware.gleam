/// Web Middleware
///
/// Provides the HTTP middleware pipeline for request processing.
import wisp

/// Middleware pipeline for all requests.
/// 
/// Applies the following middleware in order:
/// 1. Method override (for form-based method switching)
/// 2. Request logging
/// 3. Crash rescue (catch panics and return 500)
/// 4. HEAD request handling (convert to GET, discard body)
///
pub fn middleware(
  req: wisp.Request,
  handle_request: fn(wisp.Request) -> wisp.Response,
) -> wisp.Response {
  let req = wisp.method_override(req)
  use <- wisp.log_request(req)
  use <- wisp.rescue_crashes
  use req <- wisp.handle_head(req)
  handle_request(req)
}
