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
/// 5. Security headers (CSP, X-Frame-Options, etc.)
///
pub fn middleware(
  req: wisp.Request,
  handle_request: fn(wisp.Request) -> wisp.Response,
) -> wisp.Response {
  let req = wisp.method_override(req)
  use <- wisp.log_request(req)
  use <- wisp.rescue_crashes
  use req <- wisp.handle_head(req)
  let response = handle_request(req)
  add_security_headers(response)
}

/// Add security headers to all responses
fn add_security_headers(response: wisp.Response) -> wisp.Response {
  response
  // Content Security Policy - strict but allows inline styles for Lustre
  |> wisp.set_header(
    "content-security-policy",
    "default-src 'self'; "
      <> "script-src 'self' 'unsafe-inline'; "
      <> "style-src 'self' 'unsafe-inline'; "
      <> "img-src 'self' data: blob:; "
      <> "media-src 'self'; "
      <> "connect-src 'self'; "
      <> "frame-ancestors 'self'; "
      <> "base-uri 'self'; "
      <> "form-action 'self'",
  )
  // Prevent clickjacking
  |> wisp.set_header("x-frame-options", "SAMEORIGIN")
  // Prevent MIME type sniffing
  |> wisp.set_header("x-content-type-options", "nosniff")
  // XSS protection for older browsers
  |> wisp.set_header("x-xss-protection", "1; mode=block")
  // Referrer policy
  |> wisp.set_header("referrer-policy", "strict-origin-when-cross-origin")
  // Permissions policy
  |> wisp.set_header(
    "permissions-policy",
    "accelerometer=(), camera=(), geolocation=(), gyroscope=(), magnetometer=(), microphone=(), payment=(), usb=()",
  )
}
