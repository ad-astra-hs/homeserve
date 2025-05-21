import gleam/list
import gleam/option.{Some}
import gleam/regexp
import gleam/string

pub fn parse_document(doc: String, quirked: Bool) -> String {
  let assert Ok(pattern) = regexp.from_string("^([A-Z]{2}): (.*)$")

  string.split(doc, "\n")
  |> list.map(fn(line) {
    case regexp.scan(pattern, line) {
      [match] -> {
        let assert Ok(Some(character)) = list.first(match.submatches)
        let assert Ok(Some(message)) = list.last(match.submatches)

        format_dialogue(character, message, quirked)
      }
      _ -> line
    }
  })
  |> string.join("\n")
}

fn format_dialogue(character: String, message: String, quirked: Bool) -> String {
  let quirk = case character {
    "ZB" -> #([#("", "")], string.lowercase, "")
    "AA" -> #([#("e|E", "3"), #("oo|OO|oO|Oo", "oOo")], string.uppercase, "")
    "SF" -> #(
      [#("k|K", "kk"), #("c|C", "k"), #("kkk", "kk"), #("$", ".")],
      string.lowercase,
      "",
    )
    "SS" -> #(
      [
        #("s|S", "$"),
        #(",|\"", ",,"),
        #("'", ","),
        #("\\.", ","),
        #("(.+? .+?)( .+)", "\\1,,\\2"),
      ],
      string.lowercase,
      "#a1a100",
    )
    _ -> #([], fn(a) { a }, "")
  }

  let #(replacement_list, caps, color) = quirk

  let quirked_message =
    replacement_list
    |> list.fold(message, fn(message, replacement) {
      let assert Ok(pattern) = regexp.from_string(replacement.0)
      regexp.replace(pattern, message, replacement.1)
    })
    |> caps

  case quirked {
    True -> {
      "<span style='color:"
      <> color
      <> "' title='"
      <> message
      <> "'>"
      <> character
      <> ": "
      <> quirked_message
      <> "</span>"
    }
    False -> {
      "<span style='color:"
      <> color
      <> "'>"
      <> character
      <> ": "
      <> message
      <> "</span>"
    }
  }
}
