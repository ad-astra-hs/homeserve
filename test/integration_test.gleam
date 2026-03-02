//// Integration Tests for Homeserve
////
//// These tests verify the full request/response cycle for critical paths.

import gleam/list
import gleam/option.{None, Some}
import gleeunit/should

import homeserve/config
import homeserve/db
import homeserve/pages/panel/loader
import homeserve/pages/panel/types
import homeserve/volunteers

// Test configuration - uses in-memory storage
fn test_config() -> config.MnesiaConfig {
  config.MnesiaConfig(data_dir: None)
}

/// Setup function to clear database before tests
fn setup_test_db(cfg: config.MnesiaConfig) {
  let _ = db.initialize(cfg)
  let _ = db.clear_all_data()
  Nil
}

// ---- Panel Integration Tests ----

pub fn panel_create_and_load_test() {
  let cfg = test_config()

  // Initialize database
  let _ = db.initialize(cfg)

  // Create a test panel
  let panel =
    types.Panel(
      meta: types.Meta(
        index: 1,
        title: "Test Panel",
        media: types.Media(
          kind: types.Image,
          url: "/assets/test.jpg",
          alt: Some("Test image"),
          track: None,
        ),
        credits: types.Credits(
          artists: ["Test Artist"],
          writers: [],
          musicians: [],
          misc: [],
        ),
        css: [],
        js: [],
        date: 1_704_067_200,
        draft: False,
      ),
      content: "Test content for the panel",
    )

  // Save the panel
  let save_result = db.save_panel(panel)
  should.be_ok(save_result)

  // Load it back
  let load_result = loader.load_panel(1)
  should.be_ok(load_result)

  let loaded_panel = case load_result {
    Ok(p) -> p
    Error(_) -> panic as "Should have loaded panel"
  }

  // Verify data
  should.equal(loaded_panel.meta.title, "Test Panel")
  should.equal(loaded_panel.meta.index, 1)
  should.equal(loaded_panel.content, "Test content for the panel")
  should.equal(loaded_panel.meta.credits.artists, ["Test Artist"])
}

pub fn panel_not_found_test() {
  let cfg = test_config()
  let _ = db.initialize(cfg)

  // Try to load a panel that doesn't exist
  let result = loader.load_panel(999_999)

  // Should return an error (FileNotFound or DatabaseError)
  case result {
    Error(_) -> True
    Ok(_) -> panic as "Should not have found panel"
  }
}

pub fn panel_update_test() {
  let cfg = test_config()
  let _ = db.initialize(cfg)

  // Create initial panel
  let panel =
    types.Panel(
      meta: types.Meta(
        index: 1,
        title: "Original Title",
        media: types.Media(
          kind: types.Image,
          url: "/assets/test.jpg",
          alt: None,
          track: None,
        ),
        credits: types.Credits([], [], [], []),
        css: [],
        js: [],
        date: 1_704_067_200,
        draft: False,
      ),
      content: "Original content",
    )

  // Save and verify
  let _ = should.be_ok(db.save_panel(panel))

  // Update the panel
  let updated_panel =
    types.Panel(
      meta: types.Meta(..panel.meta, title: "Updated Title"),
      content: "Updated content",
    )

  let _ = should.be_ok(db.update_panel(updated_panel))

  // Load and verify update
  let loaded = case loader.load_panel(1) {
    Ok(p) -> p
    Error(_) -> panic as "Should have loaded updated panel"
  }

  should.equal(loaded.meta.title, "Updated Title")
  should.equal(loaded.content, "Updated content")
}

// ---- Volunteer Integration Tests ----

pub fn volunteer_create_and_load_test() {
  let cfg = test_config()
  let _ = db.initialize(cfg)

  // Create a volunteer
  let volunteer =
    volunteers.Volunteer(
      name: "Jane Doe",
      social_links: ["https://example.com/jane"],
      bio: "Test bio for Jane",
    )

  // Save the volunteer
  let save_result = db.save_volunteer(volunteer)
  should.be_ok(save_result)

  // Load it back
  let load_result = db.load_volunteer("Jane Doe")
  should.be_ok(load_result)

  let loaded = case load_result {
    Ok(v) -> v
    Error(_) -> panic as "Should have loaded volunteer"
  }

  should.equal(loaded.name, "Jane Doe")
  should.equal(loaded.bio, "Test bio for Jane")
  should.equal(loaded.social_links, ["https://example.com/jane"])
}

pub fn volunteer_not_found_returns_file_not_found_test() {
  let cfg = test_config()
  let _ = db.initialize(cfg)

  // Try to load a volunteer that doesn't exist
  let result = db.load_volunteer("Nonexistent Person")
  should.be_error(result)

  // Should be FileNotFound, not a crash
  case result {
    Error(volunteers.FileNotFound(_)) -> True
    Error(other) -> {
      let _ = other
      panic as "Expected FileNotFound error for missing volunteer"
    }
    Ok(_) -> panic as "Should not have found volunteer"
  }
}

pub fn volunteer_update_test() {
  let cfg = test_config()
  let _ = db.initialize(cfg)

  // Create initial volunteer
  let volunteer =
    volunteers.Volunteer(
      name: "John Smith",
      social_links: [],
      bio: "Original bio",
    )

  let _ = should.be_ok(db.save_volunteer(volunteer))

  // Update
  let updated =
    volunteers.Volunteer(..volunteer, bio: "Updated bio", social_links: [
      "https://example.com/john",
    ])

  let _ = should.be_ok(db.update_volunteer(updated))

  // Verify
  let loaded = case db.load_volunteer("John Smith") {
    Ok(v) -> v
    Error(_) -> panic as "Should have loaded updated volunteer"
  }

  should.equal(loaded.bio, "Updated bio")
  should.equal(loaded.social_links, ["https://example.com/john"])
}

pub fn volunteer_delete_test() {
  let cfg = test_config()
  let _ = db.initialize(cfg)

  // Create and save
  let volunteer =
    volunteers.Volunteer(
      name: "To Delete",
      social_links: [],
      bio: "Will be deleted",
    )
  let _ = should.be_ok(db.save_volunteer(volunteer))

  // Verify exists
  should.be_ok(db.load_volunteer("To Delete"))

  // Delete
  let _ = should.be_ok(db.delete_volunteer("To Delete"))

  // Verify deleted
  should.be_error(db.load_volunteer("To Delete"))
}

// ---- Metadata Listing Tests ----

pub fn get_all_meta_test() {
  let cfg = test_config()
  setup_test_db(cfg)

  // Create multiple panels
  let panel1 =
    types.Panel(
      meta: types.Meta(
        index: 1,
        title: "Panel One",
        media: types.Media(types.Image, "/assets/1.jpg", None, None),
        credits: types.Credits([], [], [], []),
        css: [],
        js: [],
        date: 1_704_067_200,
        draft: False,
      ),
      content: "Content 1",
    )

  let panel2 =
    types.Panel(
      meta: types.Meta(
        index: 2,
        title: "Panel Two",
        media: types.Media(types.Image, "/assets/2.jpg", None, None),
        credits: types.Credits([], [], [], []),
        css: [],
        js: [],
        date: 1_704_067_201,
        draft: False,
      ),
      content: "Content 2",
    )

  let _ = should.be_ok(db.save_panel(panel1))
  let _ = should.be_ok(db.save_panel(panel2))

  // Get all metadata
  let result = db.get_all_meta()
  should.be_ok(result)

  let metas = case result {
    Ok(m) -> m
    Error(_) -> panic as "Should have gotten metadata"
  }

  should.equal(list.length(metas), 2)
}
