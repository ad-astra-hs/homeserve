import gleam/erlang/process
import gleam/int
import gleam/string

import mist
import wisp
import wisp/wisp_mist

import homeserve/router
import homeserve_app

/// Application entry point that starts the homeserve web server.
pub fn main() {
  wisp.configure_logger()
  wisp.log_info("Starting homeserve server...")

  // Start the OTP application (handles config, db, cache warmup)
  let app_state = homeserve_app.start()
  let cfg = app_state.config

  let secret_key_base = wisp.random_string(64)

  let server_result =
    router.handle_request(_, cfg)
    |> wisp_mist.handler(secret_key_base)
    |> mist.new
    |> mist.port(cfg.server.port)
    |> mist.bind(cfg.server.host)
    |> mist.start_http

  case server_result {
    Error(err) -> {
      wisp.log_error("Failed to start HTTP server: " <> string.inspect(err))
    }
    Ok(_) -> {
      wisp.log_info(
        "Server started successfully on http://"
        <> cfg.server.host
        <> ":"
        <> int.to_string(cfg.server.port),
      )
      wisp.log_info("")
      wisp.log_info("Database: Mnesia (Erlang/BEAM built-in)")
      wisp.log_info("")

      // Wait for shutdown signal
      let selector = process.new_selector()
      process.select_forever(selector)

      // Graceful shutdown
      homeserve_app.stop(app_state)
    }
  }
}
