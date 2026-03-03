//// Admin Form Components
////
//// Reusable form input components for the admin panel.
//// Form Input Helpers
//// Panel Form Fields
//// Create Form
//// Edit Form
//// Panel List
//// Volunteer Forms
//// Navigation
//// URI encoding helper

import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import gleam/uri

import lustre/attribute
import lustre/element
import lustre/element/html

import homeserve/config.{type Config}
import homeserve/pages/panel/types.{type Meta, type Panel, Image, Video}
import homeserve/pagination
import homeserve/volunteers.{type Volunteer}

pub fn render_form_group(label_text: String, input_element) {
  html.div([attribute.class("form-group")], [
    html.label([], [html.text(label_text)]),
    input_element,
  ])
}

pub fn render_text_input(
  id: String,
  name: String,
  value: String,
  required: Bool,
  placeholder placeholder_text: String,
) {
  html.input([
    attribute.type_("text"),
    attribute.id(id),
    attribute.name(name),
    attribute.value(value),
    attribute.required(required),
    attribute.placeholder(placeholder_text),
    attribute.class("input"),
  ])
}

pub fn render_number_input(
  id: String,
  name: String,
  value: String,
  required: Bool,
) {
  html.input([
    attribute.type_("number"),
    attribute.id(id),
    attribute.name(name),
    attribute.value(value),
    attribute.required(required),
    attribute.min("1"),
    attribute.class("input"),
  ])
}

pub fn render_textarea_input(id: String, name: String, value: String, rows: Int) {
  html.textarea(
    [
      attribute.id(id),
      attribute.name(name),
      attribute.attribute("rows", int.to_string(rows)),
      attribute.class("input"),
    ],
    value,
  )
}

pub fn render_select(
  id: String,
  name: String,
  options: List(#(String, String)),
  selected: String,
) {
  html.select(
    [attribute.id(id), attribute.name(name), attribute.class("input")],
    list.map(options, fn(option) {
      let #(value, label) = option
      html.option(
        [attribute.value(value), attribute.selected(value == selected)],
        label,
      )
    }),
  )
}

///
/// Shared form fields for create and edit operations.
/// Reduces duplication between create and edit forms.
/// Renders the shared panel form fields.
/// Used by both create and edit forms to ensure consistency.
fn render_panel_form_fields(
  index_input input: element.Element(String),
  title_value value: String,
  media_kind kind: String,
  media_url_value url: String,
  media_alt_value alt: String,
  media_track_value track: String,
  content_value content: String,
  artists_value artists: String,
  writers_value writers: String,
  musicians_value musicians: String,
  misc_value misc: String,
  css_value css: String,
  js_value js: String,
  draft_checked draft: Bool,
) -> element.Element(String) {
  html.div([], [
    html.div([attribute.class("form-row")], [
      render_form_group("Panel Index", input),
      render_form_group(
        "Title",
        render_text_input("title", "title", value, True, "Panel Title"),
      ),
    ]),
    html.div([attribute.class("form-row")], [
      render_form_group(
        "Media Type",
        render_select(
          "media_kind",
          "media_kind",
          [#("image", "Image"), #("video", "Video")],
          kind,
        ),
      ),
      render_form_group(
        "Media URL",
        render_text_input(
          "media_url",
          "media_url",
          url,
          True,
          "/assets/panel1.png",
        ),
      ),
    ]),
    html.div([attribute.class("form-row")], [
      render_form_group(
        "Alt Text",
        render_text_input(
          "media_alt",
          "media_alt",
          alt,
          False,
          "Alt text for accessibility",
        ),
      ),
      render_form_group(
        "Audio Track URL (Optional)",
        render_text_input(
          "media_track",
          "media_track",
          track,
          False,
          "https://example.com/music.mp3 or /assets/music.mp3",
        ),
      ),
    ]),
    render_form_group(
      "Content (Markdown)",
      render_textarea_input("content", "content", content, 10),
    ),
    html.div([attribute.class("form-row")], [
      render_form_group(
        "Artists (comma-separated)",
        render_text_input(
          "artists",
          "artists",
          artists,
          False,
          "Artist 1, Artist 2",
        ),
      ),
      render_form_group(
        "Writers (comma-separated)",
        render_text_input(
          "writers",
          "writers",
          writers,
          False,
          "Writer 1, Writer 2",
        ),
      ),
    ]),
    html.div([attribute.class("form-row")], [
      render_form_group(
        "Musicians (comma-separated)",
        render_text_input(
          "musicians",
          "musicians",
          musicians,
          False,
          "Musician 1, Musician 2",
        ),
      ),
      render_form_group(
        "Other Contributors (comma-separated)",
        render_text_input("misc", "misc", misc, False, "Helper 1, Helper 2"),
      ),
    ]),
    html.div([attribute.class("form-row")], [
      render_form_group(
        "CSS Files (comma-separated)",
        render_text_input(
          "css",
          "css",
          css,
          False,
          "custom.css, animations.css",
        ),
      ),
      render_form_group(
        "JS Files (comma-separated)",
        render_text_input("js", "js", js, False, "script.js, effects.js"),
      ),
    ]),
    html.div([attribute.class("form-group")], [
      html.label([], [
        html.input([
          attribute.type_("checkbox"),
          attribute.name("draft"),
          attribute.value("true"),
          attribute.checked(draft),
        ]),
        html.text(" Save as Draft"),
      ]),
    ]),
  ])
}

/// Renders the CSRF token hidden field
fn render_csrf_field(csrf_token: String) {
  html.input([
    attribute.type_("hidden"),
    attribute.name("csrf_token"),
    attribute.value(csrf_token),
  ])
}

pub fn render_create_form(csrf_token: String, cfg: Config) {
  let warning = case cfg.admin.token == "changeme" {
    True ->
      html.div(
        [
          attribute.class("box-inner"),
          attribute.styles([
            #("background", "#f77"),
            #("margin-bottom", "10pt"),
          ]),
        ],
        [
          html.strong([], [html.text("WARNING: ")]),
          html.text(
            "Using default admin token. Set a secure token in homeserve.toml before deploying!",
          ),
        ],
      )
    False -> element.none()
  }

  html.div([attribute.class("page-container box")], [
    warning,
    render_admin_nav(),
    html.h2([attribute.class("heading-bordered text-center")], [
      html.text("CREATE NEW PANEL"),
    ]),
    html.form(
      [
        attribute.method("POST"),
        attribute.action("/admin/create"),
      ],
      [
        render_csrf_field(csrf_token),
        render_panel_form_fields(
          index_input: render_number_input("index", "index", "", True),
          title_value: "",
          media_kind: "image",
          media_url_value: "",
          media_alt_value: "",
          media_track_value: "",
          content_value: "",
          artists_value: "",
          writers_value: "",
          musicians_value: "",
          misc_value: "",
          css_value: "",
          js_value: "",
          draft_checked: False,
        ),
        html.div([attribute.class("flex-row")], [
          html.button(
            [attribute.type_("submit"), attribute.class("btn btn-primary")],
            [html.text("CREATE PANEL")],
          ),
        ]),
      ],
    ),
  ])
}

pub fn render_edit_form(csrf_token: String, panel: Panel) {
  let media_kind = case panel.meta.media.kind {
    Image -> "image"
    Video -> "video"
  }
  let media_alt = case panel.meta.media.alt {
    Some(alt) -> alt
    None -> ""
  }
  let media_track = case panel.meta.media.track {
    Some(track) -> track
    None -> ""
  }
  let artists = string.join(panel.meta.credits.artists, ", ")
  let writers = string.join(panel.meta.credits.writers, ", ")
  let musicians = string.join(panel.meta.credits.musicians, ", ")
  let misc = string.join(panel.meta.credits.misc, ", ")
  let css_files = string.join(panel.meta.css, ", ")
  let js_files = string.join(panel.meta.js, ", ")

  html.div([attribute.class("page-container box-dark")], [
    render_admin_nav(),
    html.h2([attribute.class("heading-bordered text-center")], [
      html.text("EDIT PANEL #" <> int.to_string(panel.meta.index)),
    ]),
    html.form(
      [
        attribute.method("POST"),
        attribute.action("/admin/update"),
      ],
      [
        render_csrf_field(csrf_token),
        html.input([
          attribute.type_("hidden"),
          attribute.name("index"),
          attribute.value(int.to_string(panel.meta.index)),
        ]),
        render_panel_form_fields(
          index_input: html.input([
            attribute.type_("text"),
            attribute.value(int.to_string(panel.meta.index)),
            attribute.disabled(True),
            attribute.class("input"),
          ]),
          title_value: panel.meta.title,
          media_kind: media_kind,
          media_url_value: panel.meta.media.url,
          media_alt_value: media_alt,
          media_track_value: media_track,
          content_value: panel.content,
          artists_value: artists,
          writers_value: writers,
          musicians_value: musicians,
          misc_value: misc,
          css_value: css_files,
          js_value: js_files,
          draft_checked: panel.meta.draft,
        ),
        html.div([attribute.class("flex-row")], [
          html.button(
            [attribute.type_("submit"), attribute.class("btn btn-primary")],
            [html.text("UPDATE PANEL")],
          ),
          html.a(
            [
              attribute.href("/admin/list"),
              attribute.class("btn btn-secondary"),
            ],
            [html.text("CANCEL")],
          ),
        ]),
      ],
    ),
  ])
}

pub fn render_panel_list(
  panels: List(Meta),
  current_page: Int,
  total_pages: Int,
  total_items: Int,
) {
  let sorted_panels =
    list.sort(panels, fn(a, b) { int.compare(a.index, b.index) })

  html.div([attribute.class("page-container box-dark")], [
    render_admin_nav(),
    html.h2([attribute.class("heading-bordered text-center")], [
      html.text("ALL PANELS"),
    ]),
    html.p([attribute.class("text-center text-muted")], [
      html.text(
        "Showing "
        <> int.to_string(list.length(sorted_panels))
        <> " of "
        <> int.to_string(total_items)
        <> " panels",
      ),
    ]),
    html.table([attribute.class("table")], [
      html.thead([], [
        html.tr([], [
          html.th([], [html.text("#")]),
          html.th([], [html.text("TITLE")]),
          html.th([], [html.text("STATUS")]),
          html.th([], [html.text("ACTIONS")]),
        ]),
      ]),
      html.tbody(
        [],
        list.map(sorted_panels, fn(p) {
          html.tr([], [
            html.td([], [html.text(int.to_string(p.index))]),
            html.td([], [html.text(p.title)]),
            html.td([], [
              case p.draft {
                True ->
                  html.span([attribute.class("status-draft")], [
                    html.text("DRAFT"),
                  ])
                False ->
                  html.span([attribute.class("status-published")], [
                    html.text("PUBLISHED"),
                  ])
              },
            ]),
            html.td([], [
              html.a(
                [
                  attribute.href("/admin/edit/" <> int.to_string(p.index)),
                  attribute.class("btn btn-secondary"),
                ],
                [html.text("EDIT")],
              ),
              html.text(" "),
              html.a(
                [
                  attribute.href("/admin/delete/" <> int.to_string(p.index)),
                  attribute.class("btn btn-danger"),
                ],
                [html.text("DELETE")],
              ),
            ]),
          ])
        }),
      ),
    ]),
    render_pagination(current_page, total_pages, "list"),
  ])
}

/// Renders the volunteer create form
pub fn render_volunteer_create_form(csrf_token: String) {
  html.div([attribute.class("page-container box")], [
    render_volunteer_admin_nav(),
    html.h2([attribute.class("heading-bordered text-center")], [
      html.text("CREATE NEW VOLUNTEER"),
    ]),
    html.form(
      [
        attribute.method("POST"),
        attribute.action("/admin/volunteers/create"),
      ],
      [
        render_csrf_field(csrf_token),
        render_form_group(
          "Name",
          render_text_input("name", "name", "", True, "Volunteer Name"),
        ),
        render_form_group("Bio", render_textarea_input("bio", "bio", "", 5)),
        render_form_group(
          "Social Links (comma-separated)",
          render_text_input(
            "social_links",
            "social_links",
            "",
            False,
            "https://example.com, https://twitter.com/user",
          ),
        ),
        html.div([attribute.class("flex-row")], [
          html.button(
            [attribute.type_("submit"), attribute.class("btn btn-primary")],
            [html.text("CREATE VOLUNTEER")],
          ),
        ]),
      ],
    ),
  ])
}

/// Renders the volunteer edit form
pub fn render_volunteer_edit_form(csrf_token: String, volunteer: Volunteer) {
  let social_links = string.join(volunteer.social_links, ", ")

  html.div([attribute.class("page-container box-dark")], [
    render_volunteer_admin_nav(),
    html.h2([attribute.class("heading-bordered text-center")], [
      html.text("EDIT VOLUNTEER: " <> volunteer.name),
    ]),
    html.form(
      [
        attribute.method("POST"),
        attribute.action("/admin/volunteers/update"),
      ],
      [
        render_csrf_field(csrf_token),
        html.input([
          attribute.type_("hidden"),
          attribute.name("original_name"),
          attribute.value(volunteer.name),
        ]),
        render_form_group(
          "Name",
          render_text_input(
            "name",
            "name",
            volunteer.name,
            True,
            "Volunteer Name",
          ),
        ),
        render_form_group(
          "Bio",
          render_textarea_input("bio", "bio", volunteer.bio, 5),
        ),
        render_form_group(
          "Social Links (comma-separated)",
          render_text_input(
            "social_links",
            "social_links",
            social_links,
            False,
            "https://example.com, https://twitter.com/user",
          ),
        ),
        html.div([attribute.class("flex-row")], [
          html.button(
            [attribute.type_("submit"), attribute.class("btn btn-primary")],
            [html.text("UPDATE VOLUNTEER")],
          ),
          html.a(
            [
              attribute.href("/admin/volunteers/list"),
              attribute.class("btn btn-secondary"),
            ],
            [html.text("CANCEL")],
          ),
        ]),
      ],
    ),
  ])
}

/// Renders the volunteer list with pagination
pub fn render_volunteer_list(
  volunteers: List(Volunteer),
  current_page: Int,
  total_pages: Int,
  total_items: Int,
) {
  let sorted_volunteers =
    list.sort(volunteers, fn(a, b) { string.compare(a.name, b.name) })

  html.div([attribute.class("page-container box-dark")], [
    render_volunteer_admin_nav(),
    html.h2([attribute.class("heading-bordered text-center")], [
      html.text("ALL VOLUNTEERS"),
    ]),
    html.p([attribute.class("text-center text-muted")], [
      html.text(
        "Showing "
        <> int.to_string(list.length(sorted_volunteers))
        <> " of "
        <> int.to_string(total_items)
        <> " volunteers",
      ),
    ]),
    html.table([attribute.class("table")], [
      html.thead([], [
        html.tr([], [
          html.th([], [html.text("NAME")]),
          html.th([], [html.text("BIO")]),
          html.th([], [html.text("LINKS")]),
          html.th([], [html.text("ACTIONS")]),
        ]),
      ]),
      html.tbody(
        [],
        list.map(sorted_volunteers, fn(v) {
          let bio_preview = case string.length(v.bio) > 50 {
            True -> string.slice(v.bio, 0, 47) <> "..."
            False -> v.bio
          }
          html.tr([], [
            html.td([], [html.text(v.name)]),
            html.td([], [html.text(bio_preview)]),
            html.td([], [html.text(int.to_string(list.length(v.social_links)))]),
            html.td([], [
              html.a(
                [
                  attribute.href(
                    "/admin/volunteers/edit/" <> uri.percent_encode(v.name),
                  ),
                  attribute.class("btn btn-secondary"),
                ],
                [html.text("EDIT")],
              ),
              html.text(" "),
              html.a(
                [
                  attribute.href(
                    "/admin/volunteers/delete/" <> uri.percent_encode(v.name),
                  ),
                  attribute.class("btn btn-danger"),
                ],
                [html.text("DELETE")],
              ),
            ]),
          ])
        }),
      ),
    ]),
    render_pagination(current_page, total_pages, "volunteers/list"),
  ])
}

/// Renders the volunteer delete confirmation
pub fn render_volunteer_delete_confirmation(csrf_token: String, name: String) {
  html.div([attribute.class("dead-center")], [
    html.h1([], [html.text("DELETE VOLUNTEER")]),
    html.p([], [html.text("Volunteer: \"" <> name <> "\"")]),
    html.p([attribute.class("status-draft")], [
      html.text("This action cannot be undone!"),
    ]),
    html.form(
      [
        attribute.method("POST"),
        attribute.action(
          "/admin/volunteers/delete/" <> uri.percent_encode(name),
        ),
      ],
      [
        render_csrf_field(csrf_token),
        html.div([attribute.class("flex-row")], [
          html.button(
            [attribute.type_("submit"), attribute.class("btn btn-danger")],
            [html.text("YES, DELETE")],
          ),
          html.a(
            [
              attribute.href("/admin/volunteers/list"),
              attribute.class("btn btn-secondary"),
            ],
            [html.text("CANCEL")],
          ),
        ]),
      ],
    ),
  ])
}

fn render_admin_nav() {
  html.div([attribute.class("nav-links")], [
    html.a(
      [
        attribute.href("/admin"),
        attribute.class("btn btn-primary"),
      ],
      [html.text("CREATE")],
    ),
    html.a(
      [
        attribute.href("/admin/list"),
        attribute.class("btn btn-secondary"),
      ],
      [html.text("LIST")],
    ),
    html.a(
      [
        attribute.href("/admin/volunteers"),
        attribute.class("btn btn-secondary"),
      ],
      [html.text("VOLUNTEERS")],
    ),
  ])
}

fn render_volunteer_admin_nav() {
  html.div([attribute.class("nav-links")], [
    html.a(
      [
        attribute.href("/admin/volunteers"),
        attribute.class("btn btn-primary"),
      ],
      [html.text("CREATE")],
    ),
    html.a(
      [
        attribute.href("/admin/volunteers/list"),
        attribute.class("btn btn-secondary"),
      ],
      [html.text("LIST")],
    ),
    html.a(
      [
        attribute.href("/admin"),
        attribute.class("btn btn-secondary"),
      ],
      [html.text("PANELS")],
    ),
  ])
}

// ---- Pagination Component ----

/// Renders pagination controls for admin pages
fn render_pagination(current_page: Int, total_pages: Int, base_path: String) {
  let build_url = fn(page) {
    "/admin/" <> base_path <> "?page=" <> int.to_string(page)
  }
  pagination.render_pagination(
    current_page,
    total_pages,
    build_url,
    build_url,
    None,
  )
}
