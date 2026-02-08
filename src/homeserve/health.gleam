/// Health Check Module
///
/// Provides comprehensive health checks for Homeserve and its dependencies.
/// The health endpoint verifies CouchDB connectivity and overall application readiness.
import gleam/http
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import homeserve/utils

import homeserve/config.{type Config}
import homeserve/couchdb
import wisp.{type Request, type Response}

/// Overall health status of the application
pub type HealthStatus {
  HealthStatus(
    /// Overall status: "healthy", "degraded", or "unhealthy"
    status: String,
    /// Unix timestamp of the check
    timestamp: Int,
    /// Component-specific statuses
    components: Components,
  )
}

/// Component health information
pub type Components {
  Components(couchdb: ComponentHealth)
}

/// Individual component health status
pub type ComponentHealth {
  ComponentHealth(
    status: String,
    message: String,
    /// Optional additional details
    details: Option(json.Json),
  )
}

/// Performs a comprehensive health check
pub fn check_health(cfg: Config) -> HealthStatus {
  let timestamp = utils.current_time_seconds()

  // Check CouchDB
  let couchdb_health = check_couchdb(cfg)

  // Determine overall status based on CouchDB health
  let overall_status = case couchdb_health.status {
    "healthy" -> "healthy"
    _ -> "unhealthy"
  }

  HealthStatus(
    status: overall_status,
    timestamp: timestamp,
    components: Components(couchdb: couchdb_health),
  )
}

/// Check CouchDB connectivity
fn check_couchdb(cfg: Config) -> ComponentHealth {
  let couch_config =
    couchdb.CouchConfig(
      host: cfg.couchdb.host,
      port: cfg.couchdb.port,
      database: cfg.couchdb.database,
      username: cfg.couchdb.username,
      password: cfg.couchdb.password,
    )

  // Try to get database info as a connectivity check
  case couchdb.get_all_docs(couch_config) {
    Ok(docs) -> {
      ComponentHealth(
        status: "healthy",
        message: "Connected",
        details: Some(
          json.object([
            #("database", json.string(cfg.couchdb.database)),
            #("document_count", json.int(list.length(docs))),
          ]),
        ),
      )
    }
    Error(err) -> {
      ComponentHealth(
        status: "unhealthy",
        message: couchdb.error_to_string(err),
        details: None,
      )
    }
  }
}

/// Encode health status to JSON
fn encode_health(health: HealthStatus) -> json.Json {
  json.object([
    #("status", json.string(health.status)),
    #("timestamp", json.int(health.timestamp)),
    #("components", encode_components(health.components)),
  ])
}

fn encode_components(components: Components) -> json.Json {
  json.object([
    #("couchdb", encode_component(components.couchdb)),
  ])
}

fn encode_component(component: ComponentHealth) -> json.Json {
  let base = [
    #("status", json.string(component.status)),
    #("message", json.string(component.message)),
  ]

  let with_details = case component.details {
    option.Some(details) -> [#("details", details), ..base]
    option.None -> base
  }

  json.object(with_details)
}

/// Serve the health check endpoint
pub fn serve_health(req: Request, cfg: Config) -> Response {
  use <- wisp.require_method(req, http.Get)

  let health = check_health(cfg)
  let json_body = encode_health(health) |> json.to_string_tree

  // Return appropriate HTTP status code
  let status_code = case health.status {
    "healthy" -> 200
    _ -> 503
    // Service Unavailable
  }

  wisp.response(status_code)
  |> wisp.set_header("content-type", "application/json")
  |> wisp.set_body(wisp.Text(json_body))
}
// ---- Helper Functions ----
