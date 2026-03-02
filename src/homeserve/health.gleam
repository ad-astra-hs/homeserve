/// Health Check Module
///
/// Provides comprehensive health checks for Homeserve and its dependencies.
/// The health endpoint verifies Mnesia connectivity and overall application readiness.
import gleam/http
import gleam/json
import gleam/option.{type Option, None, Some}
import homeserve/utils

import homeserve/config.{type Config}
import homeserve/mnesia_db
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
  Components(database: ComponentHealth)
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

  // Check Mnesia database
  let db_health = check_database(cfg)

  // Determine overall status based on database health
  let overall_status = case db_health.status {
    "healthy" -> "healthy"
    _ -> "unhealthy"
  }

  HealthStatus(
    status: overall_status,
    timestamp: timestamp,
    components: Components(database: db_health),
  )
}

/// Check Mnesia database connectivity
fn check_database(_cfg: Config) -> ComponentHealth {
  // Try to get table info as a connectivity check
  case mnesia_db.get_table_size(mnesia_db.panel_table) {
    Ok(panel_count) -> {
      case mnesia_db.get_table_size(mnesia_db.volunteer_table) {
        Ok(volunteer_count) -> {
          ComponentHealth(
            status: "healthy",
            message: "Connected",
            details: Some(
              json.object([
                #("panel_count", json.int(panel_count)),
                #("volunteer_count", json.int(volunteer_count)),
              ]),
            ),
          )
        }
        Error(_) -> {
          ComponentHealth(
            status: "healthy",
            message: "Connected (panels only)",
            details: Some(
              json.object([
                #("panel_count", json.int(panel_count)),
                #("volunteer_count", json.int(0)),
              ]),
            ),
          )
        }
      }
    }
    Error(err) -> {
      ComponentHealth(
        status: "unhealthy",
        message: mnesia_db.error_to_string(err),
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
    #("database", encode_component(components.database)),
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
