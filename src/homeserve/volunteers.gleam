/// Volunteers module for Homeserve.
/// Loads volunteer information from volunteers.toml file.
import gleam/dict
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import simplifile
import tom

// ---- Types ----

/// Volunteer information structure.
pub type Volunteer {
  Volunteer(name: String, social_links: List(String), bio: String)
}

/// Errors that can occur when loading volunteer data.
pub type VolunteerError {
  FileNotFound(path: String)
  ParseError(message: String)
}

// ---- Constants ----

const default_volunteers_path = "./volunteers.toml"

// ---- Public Functions ----

/// Loads volunteer data from the default path (volunteers.toml).
pub fn load() -> Result(List(Volunteer), VolunteerError) {
  load_from(default_volunteers_path)
}

/// Attempts to load volunteers.toml from the current directory.
pub fn load_from(path: String) -> Result(List(Volunteer), VolunteerError) {
  use toml_content <- result.then(
    simplifile.read(path)
    |> result.map_error(fn(_err) { FileNotFound(path) }),
  )
  use parsed_toml <- result.then(
    tom.parse(toml_content)
    |> result.map_error(fn(err) {
      case err {
        tom.Unexpected(got, expected) ->
          ParseError("Unexpected '" <> got <> "', expected " <> expected)
        tom.KeyAlreadyInUse(key) ->
          ParseError("Duplicate key: " <> string.join(key, "."))
      }
    }),
  )
  parse_volunteers(parsed_toml)
}

/// Finds a volunteer by name.
pub fn find_volunteer(
  volunteers: List(Volunteer),
  name: String,
) -> Option(Volunteer) {
  case list.filter(volunteers, fn(v) { v.name == name }) {
    [found, ..] -> Some(found)
    [] -> None
  }
}

// ---- Private Functions ----

fn parse_volunteers(
  toml: dict.Dict(String, tom.Toml),
) -> Result(List(Volunteer), VolunteerError) {
  let volunteer_entries = dict.to_list(toml)

  let volunteers =
    volunteer_entries
    |> list.fold([], fn(acc, pair) {
      case pair {
        #(key, tom.Table(table)) -> {
          let name = case dict.get(table, "name") {
            Ok(tom.String(n)) -> n
            _ -> key
            // Use key as name if no name field
          }

          case name {
            "" -> acc
            _ -> {
              let social_links = case dict.get(table, "social_links") {
                Ok(tom.Array(arr)) ->
                  arr
                  |> list.map(fn(item) {
                    case item {
                      tom.String(s) -> s
                      _ -> ""
                    }
                  })
                  |> list.filter(fn(s) { s != "" })
                _ -> []
              }

              let bio = case dict.get(table, "bio") {
                Ok(tom.String(b)) -> b
                _ -> ""
              }

              [Volunteer(name:, social_links:, bio:), ..acc]
            }
          }
        }
        _ -> acc
      }
    })

  Ok(volunteers)
}
