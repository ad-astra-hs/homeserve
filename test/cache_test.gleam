//// Cache Tests
////
//// Tests for ETS-based panel and metadata caching.

import gleam/option.{None, Some}
import gleeunit/should

import gleam/int
import homeserve/cache
import homeserve/pages/panel/types.{
  type Meta, type Panel, Credits, Image, Media, Meta, Panel,
}

// ---- Test Helpers ----

fn test_panel(index: Int) -> Panel {
  Panel(
    meta: Meta(
      index: index,
      title: "Panel " <> int.to_string(index),
      media: Media(
        kind: Image,
        url: "/img/" <> int.to_string(index) <> ".png",
        alt: None,
        track: None,
      ),
      credits: Credits([], [], [], []),
      css: [],
      js: [],
      date: 1_234_567_890,
      draft: False,
    ),
    content: "Content for panel " <> int.to_string(index),
  )
}

fn test_meta(index: Int) -> Meta {
  Meta(
    index: index,
    title: "Panel " <> int.to_string(index),
    media: Media(
      kind: Image,
      url: "/img/" <> int.to_string(index) <> ".png",
      alt: None,
      track: None,
    ),
    credits: Credits([], [], [], []),
    css: [],
    js: [],
    date: 1_234_567_890,
    draft: False,
  )
}

// ---- Initialization ----

pub fn cache_init_test() {
  // Just verify init doesn't crash
  cache.init()
  // Test passes if we get here
  should.be_true(True)
}

// ---- Panel Cache ----

pub fn cache_get_empty_test() {
  cache.clear()
  let result = cache.get(1)
  should.equal(result, None)
}

pub fn cache_put_and_get_test() {
  cache.clear()
  let panel = test_panel(1)
  cache.put(1, panel)
  let result = cache.get(1)
  should.equal(result, Some(panel))
}

pub fn cache_get_different_key_test() {
  cache.clear()
  let panel = test_panel(1)
  cache.put(1, panel)
  let result = cache.get(2)
  should.equal(result, None)
}

pub fn cache_put_overwrite_test() {
  cache.clear()
  let panel1 = test_panel(1)
  let panel2 = Panel(..panel1, content: "Updated content")
  cache.put(1, panel1)
  cache.put(1, panel2)
  let result = cache.get(1)
  should.equal(result, Some(panel2))
}

pub fn cache_multiple_panels_test() {
  cache.clear()
  let panel1 = test_panel(1)
  let panel2 = test_panel(2)
  let panel3 = test_panel(3)
  cache.put(1, panel1)
  cache.put(2, panel2)
  cache.put(3, panel3)
  should.equal(cache.get(1), Some(panel1))
  should.equal(cache.get(2), Some(panel2))
  should.equal(cache.get(3), Some(panel3))
}

// ---- Meta List Cache ----

pub fn cache_get_meta_list_empty_test() {
  cache.clear()
  let result = cache.get_meta_list()
  should.equal(result, None)
}

pub fn cache_put_meta_list_and_get_test() {
  cache.clear()
  let metas = [test_meta(1), test_meta(2), test_meta(3)]
  cache.put_meta_list(metas)
  let result = cache.get_meta_list()
  should.equal(result, Some(metas))
}

pub fn cache_get_meta_list_empty_list_test() {
  cache.clear()
  cache.put_meta_list([])
  let result = cache.get_meta_list()
  should.equal(result, None)
}

// ---- Cache Clear ----

pub fn cache_clear_removes_panels_test() {
  cache.clear()
  let panel = test_panel(1)
  cache.put(1, panel)
  cache.clear()
  let result = cache.get(1)
  should.equal(result, None)
}

pub fn cache_clear_removes_meta_list_test() {
  cache.clear()
  let metas = [test_meta(1), test_meta(2)]
  cache.put_meta_list(metas)
  cache.clear()
  let result = cache.get_meta_list()
  should.equal(result, None)
}

pub fn cache_clear_keeps_cache_functional_test() {
  cache.clear()
  let panel = test_panel(1)
  cache.put(1, panel)
  cache.clear()
  // Cache should still work after clear
  let panel2 = test_panel(2)
  cache.put(2, panel2)
  should.equal(cache.get(2), Some(panel2))
}

// ---- Warmup ----

pub fn cache_warmup_panels_test() {
  cache.clear()
  let panels = [test_panel(1), test_panel(2), test_panel(3)]
  cache.warmup_panels(panels)
  should.equal(cache.get(1), Some(test_panel(1)))
  should.equal(cache.get(2), Some(test_panel(2)))
  should.equal(cache.get(3), Some(test_panel(3)))
}

pub fn cache_warmup_empty_panels_test() {
  cache.clear()
  cache.warmup_panels([])
  // Should result in None when accessed
  should.equal(cache.get(1), None)
}

pub fn cache_warmup_meta_list_test() {
  cache.clear()
  let metas = [test_meta(1), test_meta(2), test_meta(3)]
  cache.warmup_meta_list(metas)
  let result = cache.get_meta_list()
  should.equal(result, Some(metas))
}

pub fn cache_warmup_overwrites_existing_test() {
  cache.clear()
  let panel1 = test_panel(1)
  cache.put(1, panel1)
  let panels = [test_panel(2), test_panel(3)]
  cache.warmup_panels(panels)
  // Panel 1 should be gone (warmup replaces entire cache)
  should.equal(cache.get(1), None)
  should.equal(cache.get(2), Some(test_panel(2)))
}

// ---- Integration ----

pub fn cache_panel_and_meta_independent_test() {
  cache.clear()
  let panel = test_panel(1)
  let metas = [test_meta(1), test_meta(2)]
  cache.put(1, panel)
  cache.put_meta_list(metas)
  should.equal(cache.get(1), Some(panel))
  should.equal(cache.get_meta_list(), Some(metas))
  // Clearing should affect both
  cache.clear()
  should.equal(cache.get(1), None)
  should.equal(cache.get_meta_list(), None)
}

pub fn cache_handles_negative_index_test() {
  cache.clear()
  let panel = test_panel(-1)
  cache.put(-1, panel)
  should.equal(cache.get(-1), Some(panel))
}

pub fn cache_handles_large_index_test() {
  cache.clear()
  let panel = test_panel(999_999)
  cache.put(999_999, panel)
  should.equal(cache.get(999_999), Some(panel))
}

pub fn cache_handles_zero_index_test() {
  cache.clear()
  let panel = test_panel(0)
  cache.put(0, panel)
  should.equal(cache.get(0), Some(panel))
}
