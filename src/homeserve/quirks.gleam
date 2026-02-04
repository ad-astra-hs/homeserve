import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/regexp.{type CompileError, type Regexp}
import gleam/result
import gleam/string
import wisp

/// Internal quirk type.
/// Replacements: List of tuples describing a regex matcher and a replacement string.
/// Transform: Function to apply to the message before replacement.
/// Color: Optional color to assign to the dialogue.
type Quirk {
  Quirk(
    replacements: Result(List(#(Regexp, String)), CompileError),
    transform: fn(String) -> String,
    color: Option(String),
  )
}

/// Defines pattern matching for dialogue lines.
/// Format: "XX: message" where XX is a two-letter character code.
fn dialogue_pattern() -> Result(Regexp, CompileError) {
  case regexp.from_string("^([A-Z]{2}): (.*)$") {
    Ok(pattern) -> Ok(pattern)
    Error(err) -> {
      wisp.log_error("Failed to compile dialogue pattern regex: " <> err.error)
      Error(err)
    }
  }
}

/// Compiles a list of string patterns into a list of regex patterns.
fn compile_replacements(
  patterns: List(#(String, String)),
) -> Result(List(#(Regexp, String)), CompileError) {
  list.try_map(patterns, fn(pattern) {
    case regexp.from_string(pattern.0) {
      Ok(regex) -> Ok(#(regex, pattern.1))
      Error(err) -> {
        wisp.log_error(
          "Failed to compile quirk replacement regex '"
          <> pattern.0
          <> "': "
          <> err.error,
        )
        Error(err)
      }
    }
  })
}

/// Retrieves a quirk for a given character.
fn get_quirk(character: String) -> Quirk {
  // Example of how to add a quirk:
  // "TC" -> Quirk(
  //   compile_replacements([#("([aeiou])", "\\1\\1")]),  // Doubles vowels
  //   string.uppercase,                                   // ALL CAPS
  //   Some("#ff0000")                                     // Red color
  // )
  case character {
    _ -> Quirk(compile_replacements([]), fn(a) { a }, None)
  }
}

/// Parses the document and applies quirks to matching dialogue lines.
///
/// When quirked=True, applies character-specific text transformations.
/// When quirked=False, only wraps dialogue in HTML without transformation.
pub fn parse_document(
  doc: String,
  quirked: Bool,
) -> Result(String, CompileError) {
  wisp.log_debug(
    "Parsing document with quirks "
    <> case quirked {
      True -> "enabled"
      False -> "disabled"
    },
  )

  use pattern <- result.try(dialogue_pattern())
  use lines <- result.try(
    list.try_map(string.split(doc, "\n"), fn(line) {
      case regexp.scan(pattern, line) {
        [regexp.Match(_, [Some(character), Some(message)])] ->
          format_dialogue(character, message, quirked)
        _ -> Ok(line)
      }
    }),
  )

  Ok(string.join(lines, "\n"))
}

fn format_dialogue(
  character: String,
  message: String,
  quirked: Bool,
) -> Result(String, CompileError) {
  let Quirk(replacements, transform, color) = get_quirk(character)
  use replacements <- result.try(replacements)

  let quirked_message = case quirked {
    True -> {
      replacements
      |> list.fold(message, fn(message, replacement) {
        regexp.replace(replacement.0, message, replacement.1)
      })
      |> transform
    }
    False -> message
  }

  let style = case color {
    Some(color) -> "style='color:" <> color <> "'"
    None -> ""
  }

  let alt_text = case quirked {
    True -> " title='" <> message <> "'"
    False -> ""
  }

  Ok(
    "<span "
    <> style
    <> alt_text
    <> ">"
    <> character
    <> ": "
    <> quirked_message
    <> "</span>",
  )
}
