//// HTML Sanitization Tests
////
//// Comprehensive tests for XSS prevention and HTML sanitization.

import gleam/string
import gleeunit/should

import homeserve/html_sanitize

// ---- Basic Sanitization ----

pub fn sanitize_plain_text_test() {
  let input = "Hello, world!"
  let result = html_sanitize.sanitize(input)
  should.equal(result, "Hello, world!")
}

pub fn sanitize_safe_html_test() {
  let input = "<p>Hello, <strong>world</strong>!</p>"
  let result = html_sanitize.sanitize(input)
  should.equal(result, "<p>Hello, <strong>world</strong>!</p>")
}

pub fn sanitize_empty_string_test() {
  let result = html_sanitize.sanitize("")
  should.equal(result, "")
}

// ---- Dangerous Tag Removal ----

pub fn sanitize_removes_script_tag_and_content_test() {
  let input = "<p>Hello</p><script>alert('xss')</script><p>World</p>"
  let result = html_sanitize.sanitize(input)
  // Script tags AND their content are completely removed
  should.equal(result, "<p>Hello</p><p>World</p>")
}

pub fn sanitize_removes_iframe_tag_test() {
  let input = "<iframe src=\"http://evil.com\"></iframe>"
  let result = html_sanitize.sanitize(input)
  should.equal(result, "")
}

pub fn sanitize_removes_object_tag_test() {
  let input = "<object data=\"malicious.swf\"></object>"
  let result = html_sanitize.sanitize(input)
  should.equal(result, "")
}

pub fn sanitize_removes_embed_tag_test() {
  let input = "<embed src=\"malicious.swf\">"
  let result = html_sanitize.sanitize(input)
  should.equal(result, "")
}

pub fn sanitize_removes_form_elements_test() {
  let input = "<form><input type=\"text\"><input><button>Submit</button></form>"
  let result = html_sanitize.sanitize(input)
  // Form tags removed, button text preserved
  should.equal(result, "Submit")
}

pub fn sanitize_removes_textarea_test() {
  let input = "<textarea>Secret data</textarea>"
  let result = html_sanitize.sanitize(input)
  // Textarea tags removed, content preserved
  should.equal(result, "Secret data")
}

pub fn sanitize_removes_select_test() {
  let input = "<select><option>1</option><option>2</option></select>"
  let result = html_sanitize.sanitize(input)
  // Select/option tags removed, content preserved
  should.equal(result, "12")
}

pub fn sanitize_removes_svg_test() {
  let input = "<svg onload=\"alert(1)\"></svg>"
  let result = html_sanitize.sanitize(input)
  should.equal(result, "")
}

pub fn sanitize_removes_math_test() {
  let input = "<math><mtext>x</mtext></math>"
  let result = html_sanitize.sanitize(input)
  // Math tags removed, inner content preserved
  should.equal(result, "<mtext>x</mtext>")
}

pub fn sanitize_removes_link_tag_test() {
  let input = "<link rel=\"stylesheet\" href=\"evil.css\">"
  let result = html_sanitize.sanitize(input)
  should.equal(result, "")
}

pub fn sanitize_removes_style_tag_test() {
  let input = "<style>body { background: red; }</style>"
  let result = html_sanitize.sanitize(input)
  // Style tags removed, CSS content preserved
  should.equal(result, "body { background: red; }")
}

pub fn sanitize_removes_meta_tag_test() {
  let input = "<meta http-equiv=\"refresh\" content=\"0;url=evil.com\">"
  let result = html_sanitize.sanitize(input)
  should.equal(result, "")
}

pub fn sanitize_removes_base_tag_test() {
  let input = "<base href=\"http://evil.com/\">"
  let result = html_sanitize.sanitize(input)
  should.equal(result, "")
}

pub fn sanitize_removes_title_tag_test() {
  let input = "<title>Evil Title</title>"
  let result = html_sanitize.sanitize(input)
  // Title tags removed, content preserved
  should.equal(result, "Evil Title")
}

pub fn sanitize_removes_applet_test() {
  let input = "<applet code=\"Evil.class\"></applet>"
  let result = html_sanitize.sanitize(input)
  should.equal(result, "")
}

// ---- Case Insensitivity ----

pub fn sanitize_case_insensitive_script_test() {
  let input = "<SCRIPT>alert(1)</SCRIPT>"
  let result = html_sanitize.sanitize(input)
  // Script content completely removed
  should.equal(result, "")
}

pub fn sanitize_case_insensitive_mixed_test() {
  let input = "<ScRiPt>alert(1)</ScRiPt>"
  let result = html_sanitize.sanitize(input)
  // Script content completely removed
  should.equal(result, "")
}

pub fn sanitize_case_insensitive_iframe_test() {
  let input = "<IFRAME src='evil.com'></IFRAME>"
  let result = html_sanitize.sanitize(input)
  should.equal(result, "")
}

// ---- Event Handler Removal ----

pub fn sanitize_removes_onclick_attribute_test() {
  let input = "<p onclick=\"alert(1)\">Click me</p>"
  let result = html_sanitize.sanitize(input)
  should.equal(result, "<p>Click me</p>")
}

pub fn sanitize_removes_onload_attribute_test() {
  let input = "<img src=\"img.jpg\" onload=\"alert(1)\">"
  let result = html_sanitize.sanitize(input)
  should.equal(result, "<img src=\"img.jpg\">")
}

pub fn sanitize_removes_onerror_attribute_test() {
  let input = "<img src=\"img.jpg\" onerror=\"alert(1)\">"
  let result = html_sanitize.sanitize(input)
  should.equal(result, "<img src=\"img.jpg\">")
}

pub fn sanitize_removes_onmouseover_attribute_test() {
  let input = "<p onmouseover=\"alert(1)\">Hover</p>"
  let result = html_sanitize.sanitize(input)
  should.equal(result, "<p>Hover</p>")
}

pub fn sanitize_removes_onsubmit_attribute_test() {
  let input = "<div onsubmit=\"alert(1)\">Form</div>"
  let result = html_sanitize.sanitize(input)
  should.equal(result, "<div>Form</div>")
}

pub fn sanitize_removes_all_event_handlers_test() {
  let input =
    "<div onclick=\"a()\" ondblclick=\"b()\" onmousedown=\"c()\" onmouseup=\"d()\">Events</div>"
  let result = html_sanitize.sanitize(input)
  should.equal(result, "<div>Events</div>")
}

// ---- JavaScript URL Removal ----

pub fn sanitize_removes_javascript_href_test() {
  let input = "<a href=\"javascript:alert(1)\">Click</a>"
  let result = html_sanitize.sanitize(input)
  // Note: leaves a space after tag name due to attribute removal
  should.equal(result, "<a >Click</a>")
}

pub fn sanitize_removes_javascript_src_test() {
  let input = "<img src=\"javascript:alert(1)\">"
  let result = html_sanitize.sanitize(input)
  should.equal(result, "<img >")
}

pub fn sanitize_removes_javascript_action_test() {
  let input = "<form action=\"javascript:alert(1)\"></form>"
  let result = html_sanitize.sanitize(input)
  should.equal(result, "")
}

// ---- VBScript URL Removal ----

pub fn sanitize_removes_vbscript_href_test() {
  let input = "<a href=\"vbscript:msgbox(1)\">Click</a>"
  let result = html_sanitize.sanitize(input)
  should.equal(result, "<a >Click</a>")
}

pub fn sanitize_removes_vbscript_src_test() {
  let input = "<img src=\"vbscript:msgbox(1)\">"
  let result = html_sanitize.sanitize(input)
  should.equal(result, "<img >")
}

// ---- Data URL Removal ----

pub fn sanitize_removes_dangerous_data_url_test() {
  let input = "<a href=\"data:text/html,<script>alert(1)</script>\">Click</a>"
  let result = html_sanitize.sanitize(input)
  should.equal(result, "<a >Click</a>")
}

pub fn sanitize_keeps_image_data_url_test() {
  let input = "<img src=\"data:image/png;base64,ABC123\">"
  let result = html_sanitize.sanitize(input)
  should.equal(result, "<img src=\"data:image/png;base64,ABC123\">")
}

pub fn sanitize_keeps_jpeg_data_url_test() {
  let input = "<img src=\"data:image/jpeg;base64,ABC123\">"
  let result = html_sanitize.sanitize(input)
  should.equal(result, "<img src=\"data:image/jpeg;base64,ABC123\">")
}

pub fn sanitize_keeps_gif_data_url_test() {
  let input = "<img src=\"data:image/gif;base64,ABC123\">"
  let result = html_sanitize.sanitize(input)
  should.equal(result, "<img src=\"data:image/gif;base64,ABC123\">")
}

// ---- Script Escaping ----

pub fn sanitize_escapes_script_tag_test() {
  let input = "<script>"
  let result = html_sanitize.sanitize(input)
  // Script opening tag escaped
  should.equal(result, "&lt;script>")
}

pub fn sanitize_escapes_closing_script_tag_test() {
  let input = "</script>"
  let result = html_sanitize.sanitize(input)
  // Script closing tag escaped
  should.equal(result, "&lt;/script>")
}

pub fn sanitize_escapes_javascript_protocol_test() {
  let input = "Click here: javascript:alert(1)"
  let result = html_sanitize.sanitize(input)
  should.be_true(string.contains(result, "[removed:"))
}

pub fn sanitize_escapes_vbscript_protocol_test() {
  let input = "Click here: vbscript:msgbox(1)"
  let result = html_sanitize.sanitize(input)
  should.be_true(string.contains(result, "[removed:"))
}

// ---- Complex Scenarios ----

pub fn sanitize_nested_dangerous_content_test() {
  let input =
    "<div><script>alert(1)</script><p>Safe</p><iframe src=\"evil\"></iframe></div>"
  let result = html_sanitize.sanitize(input)
  should.equal(result, "<div><p>Safe</p></div>")
}

pub fn sanitize_multiple_event_handlers_test() {
  let input =
    "<img src=\"img.jpg\" onclick=\"a()\" onload=\"b()\" onerror=\"c()\">"
  let result = html_sanitize.sanitize(input)
  should.equal(result, "<img src=\"img.jpg\">")
}

pub fn sanitize_script_with_attributes_test() {
  let input =
    "<script type=\"text/javascript\" src=\"evil.js\" async defer>alert(1)</script>"
  let result = html_sanitize.sanitize(input)
  // Script tag and all content removed
  should.equal(result, "")
}

pub fn sanitize_preserves_safe_attributes_test() {
  let input =
    "<a href=\"http://example.com\" class=\"link\" id=\"myLink\" target=\"_blank\">Link</a>"
  let result = html_sanitize.sanitize(input)
  should.equal(
    result,
    "<a href=\"http://example.com\" class=\"link\" id=\"myLink\" target=\"_blank\">Link</a>",
  )
}

pub fn sanitize_preserves_safe_html_structure_test() {
  let input =
    "<article><header><h1>Title</h1></header><section><p>Content</p></section></article>"
  let result = html_sanitize.sanitize(input)
  should.equal(
    result,
    "<article><header><h1>Title</h1></header><section><p>Content</p></section></article>",
  )
}

// ---- Edge Cases ----

pub fn sanitize_handles_malformed_html_test() {
  let input = "<p>Unclosed paragraph <script>alert(1)"
  let result = html_sanitize.sanitize(input)
  should.be_false(string.contains(result, "<script>"))
}

pub fn sanitize_handles_unicode_test() {
  let input = "<p>Hello 世界 🌍</p><script>alert(1)</script>"
  let result = html_sanitize.sanitize(input)
  should.equal(result, "<p>Hello 世界 🌍</p>")
}

pub fn sanitize_handles_html_entities_test() {
  let input = "<p>Tom &amp; Jerry</p>"
  let result = html_sanitize.sanitize(input)
  should.equal(result, "<p>Tom &amp; Jerry</p>")
}

pub fn sanitize_handles_newlines_test() {
  let input = "<p>Line 1\nLine 2</p>\n<script>alert(1)</script>"
  let result = html_sanitize.sanitize(input)
  should.be_false(string.contains(result, "<script>"))
}

// ---- Real-World XSS Vectors ----

pub fn sanitize_xss_img_onerror_test() {
  let input = "<img src=x onerror=\"alert(String.fromCharCode(88,83,83))\">"
  let result = html_sanitize.sanitize(input)
  should.equal(result, "<img src=x>")
}

pub fn sanitize_xss_svg_onload_test() {
  let input = "<svg/onload=\"alert(1)\">"
  let result = html_sanitize.sanitize(input)
  should.equal(result, "")
}

pub fn sanitize_xss_input_autofocus_test() {
  let input = "<input autofocus onfocus=\"alert(1)\">"
  let result = html_sanitize.sanitize(input)
  should.equal(result, "")
}

pub fn sanitize_xss_video_source_test() {
  let input = "<video><source onerror=\"alert(1)\"></video>"
  let result = html_sanitize.sanitize(input)
  // Video and source tags removed
  should.equal(result, "")
}

pub fn sanitize_xss_body_onload_test() {
  let input = "<body onload=\"alert(1)\"><p>Content</p></body>"
  let result = html_sanitize.sanitize(input)
  should.equal(result, "<body><p>Content</p></body>")
}

pub fn sanitize_xss_link_rel_stylesheet_test() {
  let input = "<link rel=\"stylesheet\" href=\"javascript:alert(1)\">"
  let result = html_sanitize.sanitize(input)
  should.equal(result, "")
}
