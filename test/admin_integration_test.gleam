//// Admin Integration Tests
////
//// These tests verify the full admin panel request/response cycle.

import gleam/list
import gleam/option.{None, Some}
import gleam/string
import gleeunit/should

import homeserve/config
import homeserve/db
import homeserve/pages/admin/auth
import homeserve/pages/admin/util
import homeserve/pages/panel/types
import homeserve/volunteers
import wisp

// Test configuration
fn test_mnesia_config() -> config.MnesiaConfig {
  config.MnesiaConfig(data_dir: None)
}

// ---- Admin Authentication Tests ----

pub fn verify_token_plaintext_test() {
  // Plaintext tokens should work
  auth.verify_token("my-secret", "my-secret")
  |> should.be_true
}

pub fn verify_token_wrong_test() {
  auth.verify_token("wrong-token", "correct-token")
  |> should.be_false
}

pub fn verify_token_hashed_test() {
  // Hash and verify
  let token = "secure-token-123"
  let hash = auth.hash_token(token)

  // Hash should be valid SHA-256 format
  should.be_true(string.starts_with(hash, "sha256:"))

  // Verification should succeed
  auth.verify_token(token, hash)
  |> should.be_true
}

pub fn verify_token_hashed_wrong_test() {
  let token = "correct-token"
  let hash = auth.hash_token(token)

  // Wrong token should fail against hash
  auth.verify_token("wrong-token", hash)
  |> should.be_false
}

// ---- Panel Admin CRUD Tests ----

pub fn panel_create_and_load_integration_test() {
  let mnesia_cfg = test_mnesia_config()

  // Initialize database
  let _ = db.initialize(mnesia_cfg)

  // Create a test panel
  let panel =
    types.Panel(
      meta: types.Meta(
        index: 100,
        title: "Admin Test Panel",
        media: types.Media(
          kind: types.Image,
          url: "/assets/test.jpg",
          alt: Some("Test"),
          track: None,
        ),
        credits: types.Credits(
          artists: ["Test Artist"],
          writers: ["Test Writer"],
          musicians: [],
          misc: [],
        ),
        css: [],
        js: [],
        date: 1_704_067_200,
        draft: False,
      ),
      content: "Test content for admin panel",
    )

  // Save the panel
  let save_result = db.save_panel(panel)
  should.be_ok(save_result)

  // Load and verify
  let load_result = db.load_panel(100)
  should.be_ok(load_result)

  case load_result {
    Ok(loaded) -> {
      should.equal(loaded.meta.title, "Admin Test Panel")
      should.equal(loaded.meta.index, 100)
      should.equal(loaded.content, "Test content for admin panel")
    }
    Error(_) -> should.fail()
  }
}

pub fn panel_update_integration_test() {
  let mnesia_cfg = test_mnesia_config()
  let _ = db.initialize(mnesia_cfg)

  // Create initial panel
  let panel =
    types.Panel(
      meta: types.Meta(
        index: 200,
        title: "Original Title",
        media: types.Media(types.Image, "/assets/test.jpg", None, None),
        credits: types.Credits([], [], [], []),
        css: [],
        js: [],
        date: 1_704_067_200,
        draft: False,
      ),
      content: "Original content",
    )

  let _ = should.be_ok(db.save_panel(panel))

  // Update the panel
  let updated =
    types.Panel(
      meta: types.Meta(..panel.meta, title: "Updated Title", draft: True),
      content: "Updated content",
    )

  let _ = should.be_ok(db.update_panel(updated))

  // Verify update
  case db.load_panel(200) {
    Ok(loaded) -> {
      should.equal(loaded.meta.title, "Updated Title")
      should.equal(loaded.content, "Updated content")
      should.equal(loaded.meta.draft, True)
    }
    Error(_) -> should.fail()
  }
}

pub fn panel_delete_integration_test() {
  let mnesia_cfg = test_mnesia_config()
  let _ = db.initialize(mnesia_cfg)

  // Create panel
  let panel =
    types.Panel(
      meta: types.Meta(
        index: 300,
        title: "To Delete",
        media: types.Media(types.Image, "/assets/test.jpg", None, None),
        credits: types.Credits([], [], [], []),
        css: [],
        js: [],
        date: 1_704_067_200,
        draft: False,
      ),
      content: "Will be deleted",
    )

  let _ = should.be_ok(db.save_panel(panel))

  // Verify exists
  should.be_ok(db.load_panel(300))

  // Delete
  let _ = should.be_ok(db.delete_panel(300))

  // Verify deleted
  should.be_error(db.load_panel(300))
}

// ---- Volunteer Admin CRUD Tests ----

pub fn volunteer_create_and_load_integration_test() {
  let mnesia_cfg = test_mnesia_config()
  let _ = db.initialize(mnesia_cfg)

  // Create volunteer
  let volunteer =
    volunteers.Volunteer(
      name: "Test Volunteer",
      social_links: ["https://example.com/test"],
      bio: "Test bio",
    )

  // Save
  let _ = should.be_ok(db.save_volunteer(volunteer))

  // Load and verify
  case db.load_volunteer("Test Volunteer") {
    Ok(loaded) -> {
      should.equal(loaded.name, "Test Volunteer")
      should.equal(loaded.bio, "Test bio")
      should.equal(loaded.social_links, ["https://example.com/test"])
    }
    Error(_) -> should.fail()
  }
}

pub fn volunteer_update_integration_test() {
  let mnesia_cfg = test_mnesia_config()
  let _ = db.initialize(mnesia_cfg)

  // Create
  let volunteer =
    volunteers.Volunteer(
      name: "Update Test",
      social_links: [],
      bio: "Original bio",
    )

  let _ = should.be_ok(db.save_volunteer(volunteer))

  // Update
  let updated =
    volunteers.Volunteer(..volunteer, bio: "Updated bio", social_links: [
      "https://new-link.com",
    ])

  let _ = should.be_ok(db.update_volunteer(updated))

  // Verify
  case db.load_volunteer("Update Test") {
    Ok(loaded) -> {
      should.equal(loaded.bio, "Updated bio")
      should.equal(loaded.social_links, ["https://new-link.com"])
    }
    Error(_) -> should.fail()
  }
}

pub fn volunteer_delete_integration_test() {
  let mnesia_cfg = test_mnesia_config()
  let _ = db.initialize(mnesia_cfg)

  // Create
  let volunteer =
    volunteers.Volunteer(
      name: "Delete Test",
      social_links: [],
      bio: "To be deleted",
    )

  let _ = should.be_ok(db.save_volunteer(volunteer))

  // Verify exists
  should.be_ok(db.load_volunteer("Delete Test"))

  // Delete
  let _ = should.be_ok(db.delete_volunteer("Delete Test"))

  // Verify deleted
  should.be_error(db.load_volunteer("Delete Test"))
}

// ---- Form Validation Tests ----

pub fn build_panel_from_form_valid_test() {
  let form_data =
    wisp.FormData(
      values: [
        #("title", "Valid Panel"),
        #("media_url", "/assets/image.jpg"),
        #("content", "Valid content here"),
        #("media_alt", "Alt text"),
        #("media_track", ""),
        #("artists", "Artist1, Artist2"),
        #("writers", "Writer1"),
        #("musicians", ""),
        #("misc", ""),
        #("css", ""),
        #("js", ""),
        #("draft", "false"),
      ],
      files: [],
    )

  case util.build_panel_from_form(form_data, 1, 1000) {
    Ok(panel) -> {
      should.equal(panel.meta.title, "Valid Panel")
      should.equal(panel.meta.media.url, "/assets/image.jpg")
      should.equal(panel.content, "Valid content here")
      should.equal(panel.meta.credits.artists, ["Artist1", "Artist2"])
    }
    Error(_) -> should.fail()
  }
}

pub fn build_panel_from_form_missing_title_test() {
  let form_data =
    wisp.FormData(
      values: [
        #("title", ""),
        #("media_url", "/assets/image.jpg"),
        #("content", "Content"),
      ],
      files: [],
    )

  case util.build_panel_from_form(form_data, 1, 1000) {
    Error(errors) -> {
      // Should have validation errors
      should.be_true(errors != [])
    }
    Ok(_) -> should.fail()
  }
}

pub fn build_panel_from_form_invalid_url_test() {
  let form_data =
    wisp.FormData(
      values: [
        #("title", "Test"),
        #("media_url", "javascript:alert('xss')"),
        #("content", "Content"),
      ],
      files: [],
    )

  case util.build_panel_from_form(form_data, 1, 1000) {
    Error(errors) -> {
      let has_url_error =
        list.any(errors, fn(e) {
          case e {
            util.InvalidUrl("media_url") -> True
            _ -> False
          }
        })
      should.be_true(has_url_error)
    }
    Ok(_) -> should.fail()
  }
}

// ---- CSRF Token Tests ----

pub fn csrf_token_generation_test() {
  let token1 = auth.generate_csrf_token()
  let token2 = auth.generate_csrf_token()

  // Tokens should not be empty
  should.be_true(string.length(token1) > 0)
  should.be_true(string.length(token2) > 0)

  // Tokens should be different (random)
  should.not_equal(token1, token2)
}
