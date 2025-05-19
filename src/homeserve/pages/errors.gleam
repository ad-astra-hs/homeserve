import lustre/element/html

pub fn build_404() {
  #([html.title([], "Error 404")], [
    html.h1([], [html.text("Error: 404")]),
    html.h3([], [html.text("I'm not mad, just disappointed.")]),
  ])
}
