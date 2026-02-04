import gleam/erlang/process
import gleam/int

import mist
import wisp
import wisp/wisp_mist

import homeserve/config
import homeserve/panel_cache
import homeserve/router

/// Application entry point that starts the homeserve web server.
pub fn main() {
  wisp.configure_logger()
  wisp.log_info("Starting homeserve server...")

  // Load configuration
  let cfg = config.load()

  // Note: gleam_httpc requires inets to be started automatically by the runtime.
  // CouchDB should be started before this application to ensure panels can be loaded.

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
          wisp.log_info("")
          wisp.log_info("IMPORTANT: Make sure CouchDB is running!")
          wisp.log_info(
            "  docker run -d -p 5984:5984 -e COUCHDB_USER=admin -e COUCHDB_PASSWORD=password couchdb:latest",
          )
          wisp.log_info("")
          process.sleep_forever()
        }
      }
    }
  }
}
