//// Volunteer Types
////
//// Volunteer data is stored in Mnesia and managed through the Admin interface.
//// This module provides the Volunteer type and related error types.

/// Volunteer information structure.
pub type Volunteer {
  Volunteer(name: String, social_links: List(String), bio: String)
}

/// Errors that can occur when loading volunteer data.
pub type VolunteerError {
  FileNotFound(path: String)
  ParseError(message: String)
}
