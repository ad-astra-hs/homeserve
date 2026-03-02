//// Security Tests
////
//// These tests verify security protections against common attacks.

import gleam/list
import gleam/option.{None, Some}
import gleam/string
import gleeunit/should

import homeserve/cache
import homeserve/config
import homeserve/db
import homeserve/pages/admin/auth
import homeserve/pages/admin/util
import homeserve/pages/admin/validation.{
  FieldTooLong, InvalidCharacters, InvalidUrl, MissingRequiredField,
}
import homeserve/pages/panel/types
import homeserve/security
import wisp

// ---- Path Traversal Protection Tests ----

pub fn sanitize_filename_normal_test() {
  security.sanitize_filename("image.jpg")
  |> should.equal(Some("image.jpg"))
}

pub fn sanitize_filename_with_directory_test() {
  // Should extract just the filename
  security.sanitize_filename("path/to/image.jpg")
  |> should.equal(Some("image.jpg"))
}

pub fn sanitize_filename_path_traversal_test() {
  // Path traversal attempts should return None
  security.sanitize_filename("../../../etc/passwd")
  |> should.equal(None)
}

pub fn sanitize_filename_url_encoded_traversal_test() {
  // URL encoded path traversal
  security.sanitize_filename("..%2f..%2fetc%2fpasswd")
  |> should.equal(None)
}

pub fn sanitize_filename_null_byte_test() {
  // Null byte injection
  security.sanitize_filename("image.jpg\u{0000}.exe")
  |> should.equal(None)
}

pub fn sanitize_filename_empty_test() {
  security.sanitize_filename("")
  |> should.equal(None)
}

pub fn sanitize_filename_double_dot_test() {
  security.sanitize_filename("..")
  |> should.equal(None)
}

pub fn sanitize_filename_single_dot_test() {
  security.sanitize_filename(".")
  |> should.equal(None)
}

pub fn sanitize_filename_absolute_path_test() {
  // Absolute paths should be normalized
  security.sanitize_filename("/absolute/path/file.txt")
  |> should.equal(Some("file.txt"))
}

pub fn sanitize_filename_backslash_test() {
  // Windows-style paths
  security.sanitize_filename("folder\\file.jpg")
  |> should.equal(Some("file.jpg"))
}

// ---- URL Validation Tests ----

pub fn validate_media_url_valid_relative_test() {
  security.validate_media_url("/assets/image.jpg")
  |> should.equal(Ok("/assets/image.jpg"))
}

pub fn validate_media_url_valid_absolute_test() {
  security.validate_media_url("https://example.com/image.jpg")
  |> should.equal(Ok("https://example.com/image.jpg"))
}

pub fn validate_media_url_javascript_test() {
  security.validate_media_url("javascript:alert('xss')")
  |> should.be_error
}

pub fn validate_media_url_data_uri_test() {
  security.validate_media_url("data:text/html,<script>alert(1)</script>")
  |> should.be_error
}

pub fn validate_media_url_vbscript_test() {
  security.validate_media_url("vbscript:msgbox(1)")
  |> should.be_error
}

pub fn validate_media_url_empty_test() {
  security.validate_media_url("")
  |> should.be_error
}

pub fn validate_media_url_html_injection_test() {
  security.validate_media_url("/assets/<script>alert(1)</script>.jpg")
  |> should.be_error
}

pub fn validate_media_url_quotes_test() {
  security.validate_media_url("/assets/\"onerror=alert(1)")
  |> should.be_error
}

pub fn validate_media_url_whitespace_trim_test() {
  security.validate_media_url("  /assets/image.jpg  ")
  |> should.equal(Ok("/assets/image.jpg"))
}

// ---- Path Within Base Directory Tests ----

pub fn is_path_within_base_valid_test() {
  security.is_path_within_base(
    "/home/user/project/file.txt",
    "/home/user/project",
  )
  |> should.be_true
}

pub fn is_path_within_base_subdir_test() {
  security.is_path_within_base(
    "/home/user/project/subdir/file.txt",
    "/home/user/project",
  )
  |> should.be_true
}

pub fn is_path_within_base_traversal_test() {
  security.is_path_within_base(
    "/home/user/other/file.txt",
    "/home/user/project",
  )
  |> should.be_false
}

pub fn is_path_within_base_parent_dir_test() {
  security.is_path_within_base("/home/user/../etc/passwd", "/home/user/project")
  |> should.be_false
}

// ---- Admin Token Security Tests ----

pub fn admin_token_hash_uniqueness_test() {
  let token = "my-secret-token"
  let hash1 = auth.hash_token(token)
  let hash2 = auth.hash_token(token)

  // Same token should produce different hashes (different salts)
  should.not_equal(hash1, hash2)

  // But both should verify correctly
  should.be_true(auth.verify_token(token, hash1))
  should.be_true(auth.verify_token(token, hash2))
}

pub fn admin_token_hash_verification_wrong_token_test() {
  let token = "correct-token"
  let wrong_token = "wrong-token"
  let hash = auth.hash_token(token)

  // Wrong token should not verify against hash
  should.be_false(auth.verify_token(wrong_token, hash))
}

// ---- Form Validation Security Tests ----

pub fn form_validation_null_byte_in_title_test() {
  let form_data =
    wisp.FormData(
      values: [
        #("title", "Test\u{0000}Title"),
        #("media_url", "/assets/image.jpg"),
        #("content", "Content"),
      ],
      files: [],
    )

  case util.build_panel_from_form(form_data, 1, 1000) {
    Error(errors) -> {
      let has_invalid_chars =
        list.any(errors, fn(e) {
          case e {
            InvalidCharacters("title") -> True
            _ -> False
          }
        })
      should.be_true(has_invalid_chars)
    }
    Ok(_) -> should.fail()
  }
}

pub fn form_validation_null_byte_in_content_test() {
  let form_data =
    wisp.FormData(
      values: [
        #("title", "Valid Title"),
        #("media_url", "/assets/image.jpg"),
        #("content", "Content\u{0000}WithNull"),
      ],
      files: [],
    )

  case util.build_panel_from_form(form_data, 1, 1000) {
    Error(errors) -> {
      let has_invalid_chars =
        list.any(errors, fn(e) {
          case e {
            InvalidCharacters("content") -> True
            _ -> False
          }
        })
      should.be_true(has_invalid_chars)
    }
    Ok(_) -> should.fail()
  }
}

pub fn form_validation_xss_in_media_url_test() {
  let form_data =
    wisp.FormData(
      values: [
        #("title", "Valid Title"),
        #("media_url", "javascript:void(0)"),
        #("content", "Content"),
      ],
      files: [],
    )

  case util.build_panel_from_form(form_data, 1, 1000) {
    Error(errors) -> {
      let has_url_error =
        list.any(errors, fn(e) {
          case e {
            InvalidUrl("media_url") -> True
            _ -> False
          }
        })
      should.be_true(has_url_error)
    }
    Ok(_) -> should.fail()
  }
}

pub fn form_validation_very_long_title_test() {
  let long_title = string.repeat("a", 300)
  let form_data =
    wisp.FormData(
      values: [
        #("title", long_title),
        #("media_url", "/assets/image.jpg"),
        #("content", "Content"),
      ],
      files: [],
    )

  case util.build_panel_from_form(form_data, 1, 1000) {
    Error(errors) -> {
      let has_length_error =
        list.any(errors, fn(e) {
          case e {
            FieldTooLong("title", _) -> True
            _ -> False
          }
        })
      should.be_true(has_length_error)
    }
    Ok(_) -> should.fail()
  }
}

pub fn form_validation_whitespace_only_title_test() {
  let form_data =
    wisp.FormData(
      values: [
        #("title", "   "),
        #("media_url", "/assets/image.jpg"),
        #("content", "Content"),
      ],
      files: [],
    )

  case util.build_panel_from_form(form_data, 1, 1000) {
    Error(errors) -> {
      let has_required_error =
        list.any(errors, fn(e) {
          case e {
            MissingRequiredField("title") -> True
            _ -> False
          }
        })
      should.be_true(has_required_error)
    }
    Ok(_) -> should.fail()
  }
}

// ---- Database Security Tests ----

pub fn database_sql_injection_protection_test() {
  // Mnesia doesn't use SQL, so SQL injection isn't possible
  // But let's verify special characters in panel titles are handled
  let mnesia_cfg = config.MnesiaConfig(data_dir: None)
  let _ = db.initialize(mnesia_cfg)

  let panel =
    types.Panel(
      meta: types.Meta(
        index: 999,
        title: "Title'; DROP TABLE panels; --",
        media: types.Media(types.Image, "/assets/test.jpg", None, None),
        credits: types.Credits([], [], [], []),
        css: [],
        js: [],
        date: 1_704_067_200,
        draft: False,
      ),
      content: "Content with 'quotes' and \"double quotes\"",
    )

  // Should save successfully (no SQL injection possible with Mnesia)
  let save_result = db.save_panel(panel)
  should.be_ok(save_result)

  // Should load correctly with special characters preserved
  case db.load_panel(999) {
    Ok(loaded) -> {
      should.equal(loaded.meta.title, "Title'; DROP TABLE panels; --")
    }
    Error(_) -> should.fail()
  }
}

// ---- Cache Security Tests ----

pub fn cache_isolation_test() {
  let mnesia_cfg = config.MnesiaConfig(data_dir: None)
  let _ = db.initialize(mnesia_cfg)
  let _ = db.clear_all_data()

  // Create and cache a panel
  let panel1 =
    types.Panel(
      meta: types.Meta(
        index: 500,
        title: "Cached Panel",
        media: types.Media(types.Image, "/assets/test.jpg", None, None),
        credits: types.Credits([], [], [], []),
        css: [],
        js: [],
        date: 1_704_067_200,
        draft: False,
      ),
      content: "Cached content",
    )

  let _ = db.save_panel(panel1)

  // Warm cache
  cache.warmup_panels([panel1])

  // Verify cache hit
  case cache.get(500) {
    Some(cached) -> should.equal(cached.meta.title, "Cached Panel")
    None -> should.fail()
  }

  // Clear cache
  cache.clear()

  // Verify cache miss after clear
  case cache.get(500) {
    Some(_) -> should.fail()
    None -> should.be_true(True)
  }
}
