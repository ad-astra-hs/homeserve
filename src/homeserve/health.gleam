/// Health Check Module
///
/// Provides comprehensive health checks for Homeserve and its dependencies.
/// The health endpoint verifies:
/// - CouchDB connectivity
/// - Cache status
/// - Overall application readiness
import gleam/erlang
import gleam/erlang/process.{type Subject}
import gleam/http
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}

import homeserve/config.{type Config}
import homeserve/couchdb
import homeserve/panel_cache
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
  Components(couchdb: ComponentHealth, cache: ComponentHealth)
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
pub fn check_health(
  cfg: Config,
  cache: Subject(panel_cache.CacheMessage),
) -> HealthStatus {
  let timestamp = current_time_seconds()

  // Check CouchDB
  let couchdb_health = check_couchdb(cfg)

  // Check Cache
  let cache_health = check_cache(cache)

  // Determine overall status
  let overall_status = case couchdb_health.status, cache_health.status {
    "healthy", "healthy" -> "healthy"
    "unhealthy", _ -> "unhealthy"
    _, "unhealthy" -> "unhealthy"
    _, _ -> "degraded"
  }

  HealthStatus(
    status: overall_status,
    timestamp: timestamp,
    components: Components(couchdb: couchdb_health, cache: cache_health),
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

/// Check cache status
fn check_cache(cache: Subject(panel_cache.CacheMessage)) -> ComponentHealth {
  let health = panel_cache.get_health(cache)

  let status = case health.is_healthy, health.is_ready {
    True, True -> "healthy"
    True, False -> "degraded"
    False, _ -> "unhealthy"
  }

  let message = case health.is_ready {
    True -> "Ready with " <> int.to_string(health.panel_count) <> " panels"
    False -> "Not ready (empty cache)"
  }

  let details =
    json.object([
      #("panel_count", json.int(health.panel_count)),
      #("is_ready", json.bool(health.is_ready)),
      #("is_healthy", json.bool(health.is_healthy)),
    ])

  ComponentHealth(status: status, message: message, details: Some(details))
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
    #("cache", encode_component(components.cache)),
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
pub fn serve_health(
  req: Request,
  cfg: Config,
  cache: Subject(panel_cache.CacheMessage),
) -> Response {
  use <- wisp.require_method(req, http.Get)

  let health = check_health(cfg, cache)
  let json_body = encode_health(health) |> json.to_string_tree

  // Return appropriate HTTP status code
  let status_code = case health.status {
    "healthy" -> 200
    "degraded" -> 200
    // Still serving traffic, but with issues
    _ -> 503
    // Service Unavailable
  }

  wisp.response(status_code)
  |> wisp.set_header("content-type", "application/json")
  |> wisp.set_body(wisp.Text(json_body))
}

// ---- Helper Functions ----

fn current_time_seconds() -> Int {
  erlang.system_time(erlang.Second)
}
