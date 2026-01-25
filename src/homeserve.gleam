import gleam/int

import gleam/erlang/process

import mist
import wisp
import wisp/wisp_mist

import homeserve/config
import homeserve/panel_cache
import homeserve/router

/// Application entry point that starts the homeserve web server.
/// 
/// This function:
/// - Configures logging
/// - Loads application configuration
/// - Starts the panel cache actor
/// - Starts the HTTP server on configured port
/// 
/// The server will run until interrupted.
pub fn main() {
  wisp.configure_logger()

  wisp.log_info("Starting homeserve server...")

  // Load configuration
  let cfg = config.load()

  // Start the panel cache with config
  case panel_cache.start(cfg) {
    Error(err) -> {
      echo err
      wisp.log_error("Failed to start panel cache")
    }
    Ok(cache) -> {
      wisp.log_info("Panel cache started")

      let secret_key_base = wisp.random_string(64)

      let server_result =
        router.handle_request(_, cache, cfg)
        |> wisp_mist.handler(secret_key_base)
        |> mist.new
        |> mist.port(cfg.server.port)
        |> mist.bind(cfg.server.host)
        |> mist.start_http

      case server_result {
        Error(err) -> {
          echo err
          wisp.log_error("Failed to start HTTP server")
        }
        Ok(_) -> {
          wisp.log_info(
            "Server started successfully on http://"
            <> cfg.server.host
            <> ":"
            <> int.to_string(cfg.server.port),
          )
          process.sleep_forever()
        }
      }
    }
  }
}
