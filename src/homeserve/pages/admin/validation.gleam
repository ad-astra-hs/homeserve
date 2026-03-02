//// Admin Types
////
//// Shared types for the admin panel.

/// Validation error types for admin forms
pub type ValidationError {
  FieldTooLong(field: String, max: Int)
  InvalidUrl(field: String)
  InvalidCharacters(field: String)
  MissingRequiredField(field: String)
}
