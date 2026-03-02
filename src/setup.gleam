/// Homeserve Setup Utility
///
/// Usage: gleam run -m setup [command]
///
/// Commands:
///   verify    - Verify Mnesia database (default)
///   token     - Generate a secure admin token hash
///
/// This script provides setup utilities for Homeserve including
/// database verification and secure token generation.
import gleam/bit_array
import gleam/crypto
import gleam/int
import gleam/list
import gleam/string

import homeserve/config
import homeserve/db
import homeserve/mnesia_db
import homeserve/pages/admin/auth
import wisp

/// Exit the application cleanly with a status code
@external(erlang, "init", "stop")
fn exit(status: Int) -> Nil

/// Print usage information
fn print_usage() {
  wisp.log_info("Homeserve Setup Utility")
  wisp.log_info("")
  wisp.log_info("Usage: gleam run -m setup [command]")
  wisp.log_info("")
  wisp.log_info("Commands:")
  wisp.log_info("  verify    Verify Mnesia database (default)")
  wisp.log_info("  token     Generate a secure admin token hash")
  wisp.log_info("")
  wisp.log_info("Examples:")
  wisp.log_info("  gleam run -m setup")
  wisp.log_info("  gleam run -m setup verify")
  wisp.log_info("  gleam run -m setup token")
}

/// Main entry point
pub fn main() {
  wisp.configure_logger()

  // Get command line arguments and convert from Erlang strings
  let args = get_args() |> list.map(erlang_list_to_string)

  case args {
    ["--help"] | ["-h"] | ["help"] -> print_usage()
    ["token"] -> generate_token()
    ["verify"] | [] -> verify_database()
    [unknown, ..] -> {
      wisp.log_error("Unknown command: " <> unknown)
      print_usage()
      exit(1)
    }
  }
}

/// Get command line arguments (skipping the program name)
@external(erlang, "init", "get_plain_arguments")
fn get_args() -> List(List(Int))

/// Convert an Erlang string (list of integers) to a Gleam string
fn erlang_list_to_string(chars: List(Int)) -> String {
  // Convert list of codepoints to a string using from_utf_codepoints
  let codepoints = list.filter_map(chars, fn(c) { string.utf_codepoint(c) })
  string.from_utf_codepoints(codepoints)
}

/// Verify Mnesia database setup
fn verify_database() {
  wisp.log_info("=== Homeserve Database Verification ===")
  wisp.log_info("")

  // Load configuration
  let cfg = config.load()

  wisp.log_info("Initializing Mnesia database...")

  // Initialize and verify database
  case db.initialize(cfg.mnesia) {
    Error(err) -> {
      wisp.log_error(
        "Failed to initialize database: " <> mnesia_db.error_to_string(err),
      )
      exit(1)
    }
    Ok(_) -> {
      wisp.log_info("✓ Database initialized and verified")

      // Verify database is accessible by checking table sizes
      case mnesia_db.get_table_size(mnesia_db.panel_table) {
        Ok(panel_count) -> {
          wisp.log_info(
            "✓ Panels table accessible - found "
            <> int.to_string(panel_count)
            <> " panels",
          )
        }
        Error(err) -> {
          wisp.log_warning(
            "Database initialized but panel table check failed: "
            <> mnesia_db.error_to_string(err),
          )
        }
      }

      case mnesia_db.get_table_size(mnesia_db.volunteer_table) {
        Ok(volunteer_count) -> {
          wisp.log_info(
            "✓ Volunteers table accessible - found "
            <> int.to_string(volunteer_count)
            <> " volunteers",
          )
        }
        Error(err) -> {
          wisp.log_warning(
            "Database initialized but volunteer table check failed: "
            <> mnesia_db.error_to_string(err),
          )
        }
      }
    }
  }

  wisp.log_info("")
  wisp.log_info("=== Verification Complete ===")
}

/// Generate a secure admin token with SHA-256 hash
fn generate_token() {
  wisp.log_info("=== Secure Admin Token Generator ===")
  wisp.log_info("")

  // Generate a random token
  let token = generate_random_token(32)

  wisp.log_info("Generated secure admin token:")
  wisp.log_info("")
  wisp.log_info("Plaintext token (give this to users):")
  wisp.log_info("  " <> token)
  wisp.log_info("")

  // Hash the token for config
  let hashed = auth.hash_token(token)

  wisp.log_info("Hashed token (put this in homeserve.toml):")
  wisp.log_info("  token = \"" <> hashed <> "\"")
  wisp.log_info("")
  wisp.log_info("IMPORTANT:")
  wisp.log_info("1. Copy the hashed token to your homeserve.toml")
  wisp.log_info("2. Share the plaintext token with authorized users")
  wisp.log_info(
    "3. Store the plaintext token securely (e.g., password manager)",
  )
  wisp.log_info("")
  wisp.log_info("=== Token Generation Complete ===")
}

/// Generate a cryptographically secure random token of specified byte length,
/// returned as a URL-safe base64 string (no padding).
fn generate_random_token(bytes: Int) -> String {
  crypto.strong_random_bytes(bytes)
  |> bit_array.base64_url_encode(False)
}
