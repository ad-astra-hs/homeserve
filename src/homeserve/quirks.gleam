import gleam/list
import gleam/option.{Some}
import gleam/regexp
import gleam/string

pub fn parse_document(doc: String) -> String {
  let assert Ok(pattern) = regexp.from_string("^([A-Z]{2}): (.*)$")

  string.split(doc, "\n")
  |> list.map(fn(line) {
    case regexp.scan(pattern, line) {
      [match] -> {
        let assert Ok(Some(character)) = list.first(match.submatches)
        let assert Ok(Some(message)) = list.last(match.submatches)

        quirk_apply(character, message)
      }
      _ -> line
    }
  })
  |> string.join("\n")
}

fn quirk_apply(character: String, message: String) -> String {
  let quirk = case character {
    "ZB" -> #([#("", "")], string.lowercase, "")
    "AA" -> #([#("", "")], string.uppercase, "")
    "SF" -> #([#("", "")], string.lowercase, "")
    "SS" -> #(
      [#("ts", "penis"), #("pmo", "balls")],
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
