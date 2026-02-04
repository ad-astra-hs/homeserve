/// Homeserve Setup Utility
///
/// Usage: gleam run -m setup [command]
///
/// Commands:
///   verify    - Verify CouchDB connection (default)
///   token     - Generate a secure admin token hash
///
/// This script provides setup utilities for Homeserve including
/// database verification and secure token generation.
import gleam/int
import gleam/list
import gleam/string

import homeserve/config
import homeserve/couchdb
import homeserve/db
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
  wisp.log_info("  verify    Verify CouchDB connection (default)")
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

/// Verify CouchDB connection and database setup
fn verify_database() {
  wisp.log_info("=== Homeserve Database Verification ===")
  wisp.log_info("")

  // Load configuration
  let cfg = config.load()

  // Create CouchDB config from application config
  let couch_config = couchdb.config_from_app_config(cfg)

  wisp.log_info(
    "Connecting to CouchDB at "
    <> couch_config.host
    <> ":"
    <> int.to_string(couch_config.port),
  )
  wisp.log_info("Database: " <> couch_config.database)

  // Initialize and verify database
  case db.initialize(couch_config) {
    Error(err) -> {
      wisp.log_error(
        "Failed to initialize database: " <> couchdb.error_to_string(err),
      )
      wisp.log_error(
        "Please ensure CouchDB is running on "
        <> couch_config.host
        <> ":"
        <> int.to_string(couch_config.port),
      )
      wisp.log_error(
        "You can start CouchDB with: docker run -d -p 5984:5984 couchdb:latest",
      )
      exit(1)
    }
    Ok(_) -> {
      wisp.log_info("✓ Database initialized and verified")

      // Verify database is accessible by testing a simple operation
      case couchdb.get_all_docs(couch_config) {
        Ok(docs) -> {
          let doc_count = list.length(docs)
          wisp.log_info(
            "✓ Database accessible - found "
            <> int.to_string(doc_count)
            <> " existing documents",
          )
        }
        Error(err) -> {
          wisp.log_warning(
            "Database initialized but verification failed: "
            <> couchdb.error_to_string(err),
          )
          wisp.log_warning(
            "This may indicate connection issues or permission problems",
          )
        }
      }
    }
  }

  wisp.log_info("")
  wisp.log_info("=== Verification Complete ===")
}

/// Generate a secure admin token with bcrypt hash
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

/// Generate a random alphanumeric token of specified length
fn generate_random_token(length: Int) -> String {
  let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

  generate_random_string(length, chars, "")
}

fn generate_random_string(remaining: Int, chars: String, acc: String) -> String {
  case remaining {
    0 -> acc
    _ -> {
      let char_index = int.random(string.length(chars))
      let char = string.slice(chars, char_index, 1)
      generate_random_string(remaining - 1, chars, acc <> char)
    }
  }
}
