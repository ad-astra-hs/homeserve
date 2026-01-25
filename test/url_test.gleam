import gleam/result
import gleam/uri
import gleeunit/should

// ---- URL Encoding Tests ----

pub fn percent_encode_space_test() {
  let encoded = uri.percent_encode("Alice Artist")

  encoded |> should.equal("Alice%20Artist")
}

pub fn percent_decode_space_test() {
  let decoded = uri.percent_decode("Alice%20Artist")

  decoded |> should.equal(Ok("Alice Artist"))
}

pub fn percent_encode_special_chars_test() {
  let encoded = uri.percent_encode("Bob & Carol's Team")

  // Should encode & but not necessarily '
  encoded |> should.equal("Bob%20%26%20Carol's%20Team")
}

pub fn percent_decode_special_chars_test() {
  let decoded = uri.percent_decode("Bob%20%26%20Carol's%20Team")

  decoded |> should.equal(Ok("Bob & Carol's Team"))
}

pub fn percent_decode_with_fallback_test() {
  // Test the pattern used in router.gleam
  let volunteer = "Alice%20Artist"
  let decoded = uri.percent_decode(volunteer) |> result.unwrap(volunteer)

  decoded |> should.equal("Alice Artist")
}

pub fn percent_decode_invalid_fallback_test() {
  // Invalid percent encoding should fall back to original
  let volunteer = "Invalid%ZZEncoding"
  let decoded = uri.percent_decode(volunteer) |> result.unwrap(volunteer)

  // Should return original since %ZZ is invalid
  decoded |> should.equal("Invalid%ZZEncoding")
}

pub fn percent_encode_unicode_test() {
  let encoded = uri.percent_encode("日本語")

  // Unicode characters should be percent-encoded
  should.be_true(encoded != "日本語")
}

pub fn percent_decode_unicode_test() {
  let original = "日本語"
  let encoded = uri.percent_encode(original)
  let decoded = uri.percent_decode(encoded)

  decoded |> should.equal(Ok(original))
}

pub fn roundtrip_encoding_test() {
  let names = [
    "Alice Artist",
    "Bob Writer",
    "Charlie & Dave",
    "Test (Parentheses)",
    "Name/With/Slashes",
  ]

  names
  |> list_each(fn(name) {
    let encoded = uri.percent_encode(name)
    let decoded = uri.percent_decode(encoded)
    decoded |> should.equal(Ok(name))
  })
}

fn list_each(list: List(a), f: fn(a) -> b) -> Nil {
  case list {
    [] -> Nil
    [first, ..rest] -> {
      f(first)
      list_each(rest, f)
    }
  }
}
