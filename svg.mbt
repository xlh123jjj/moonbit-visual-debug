///|
pub(all) struct SvgOptions {
  show_labels : Bool
  show_grid : Bool
  background : Color
} derive(Debug, ToJson)

///|
pub fn SvgOptions::default() -> SvgOptions {
  {
    show_labels: true,
    show_grid: false,
    background: Color::rgb(r=15, g=23, b=42),
  }
}

///|
pub fn DebugDocument::to_svg(self : DebugDocument) -> String {
  self.to_svg_with(SvgOptions::default())
}

///|
pub fn DebugDocument::to_svg_with(self : DebugDocument, options : SvgOptions) -> String {
  let out = StringBuilder()
  out.write_string(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 \{self.image.width} \{self.image.height}\" width=\"\{self.image.width}\" height=\"\{self.image.height}\" role=\"img\" aria-label=\"\{escape_attr(self.title)}\">\n",
  )
  out.write_string("<title>\{escape_text(self.title)}</title>\n")
  out.write_string(
    "<rect width=\"100%\" height=\"100%\" fill=\"\{options.background.to_css()}\"/>\n",
  )
  match self.image_href {
    Some(href) =>
      out.write_string(
        "<image href=\"\{escape_attr(href)}\" x=\"0\" y=\"0\" width=\"\{self.image.width}\" height=\"\{self.image.height}\" preserveAspectRatio=\"xMidYMid meet\"/>\n",
      )
    None => ()
  }
  if options.show_grid {
    write_grid(out, self.image)
  }
  for index, layer in self.visible_layers() {
    out.write_string(
      "<g id=\"layer-\{escape_attr(layer.id)}\" opacity=\"\{layer.opacity}\">\n",
    )
    for overlay_index, overlay in layer.overlays {
      write_overlay(out, overlay, index + overlay_index, options)
    }
    out.write_string("</g>\n")
  }
  out.write_string("</svg>\n")
  out.to_string()
}

///|
fn write_grid(out : StringBuilder, image : ImageSpec) -> Unit {
  let step = grid_step(image)
  out.write_string("<g stroke=\"rgba(148,163,184,0.25)\" stroke-width=\"1\">\n")
  for x = 0; x <= image.width; x = x + step {
    out.write_string("<line x1=\"\{x}\" y1=\"0\" x2=\"\{x}\" y2=\"\{image.height}\"/>\n")
  }
  for y = 0; y <= image.height; y = y + step {
    out.write_string("<line x1=\"0\" y1=\"\{y}\" x2=\"\{image.width}\" y2=\"\{y}\"/>\n")
  }
  out.write_string("</g>\n")
}

///|
fn grid_step(image : ImageSpec) -> Int {
  let long_edge = if image.width > image.height { image.width } else { image.height }
  if long_edge >= 1600 {
    160
  } else if long_edge >= 800 {
    80
  } else {
    40
  }
}

///|
fn write_overlay(out : StringBuilder, overlay : Overlay, index : Int, options : SvgOptions) -> Unit {
  match overlay {
    BBox(rect~, label~, color~) =>
      write_bbox(out, rect, resolve_color(color, index), label, options)
    Mask(polygons~, label~, color~) =>
      write_mask(out, polygons, resolve_color(color, index), label, options)
    Keypoints(points~, color~) =>
      write_keypoints(out, points, resolve_color(color, index))
    Trajectory(path~, color~) =>
      write_trajectory(out, path, resolve_color(color, index))
    Heatmap(cells~, low~, high~) =>
      write_heatmap(out, cells, resolve_color(low, 2), resolve_color(high, 1))
    ErrorRegion(rect~, expected~, actual~, severity~) =>
      write_error_region(out, rect, expected, actual, severity)
  }
}

///|
fn write_bbox(
  out : StringBuilder,
  rect : Rect,
  color : Color,
  label : Label?,
  options : SvgOptions,
) -> Unit {
  out.write_string(
    "<rect x=\"\{rect.x}\" y=\"\{rect.y}\" width=\"\{rect.width}\" height=\"\{rect.height}\" fill=\"none\" stroke=\"\{color.to_css()}\" stroke-width=\"2.5\"/>\n",
  )
  if options.show_labels {
    match label {
      Some(value) => write_label(out, Point::new(x=rect.x, y=rect.y), value, color)
      None => ()
    }
  }
}

///|
fn write_mask(
  out : StringBuilder,
  polygons : Array[Array[Point]],
  color : Color,
  label : Label?,
  options : SvgOptions,
) -> Unit {
  for polygon in polygons {
    out.write_string(
      "<polygon points=\"\{polygon_points(polygon)}\" fill=\"\{color.with_alpha(0.24).to_css()}\" stroke=\"\{color.to_css()}\" stroke-width=\"1.5\"/>\n",
    )
  }
  if options.show_labels && polygons.length() > 0 {
    match label {
      Some(value) => {
        match polygons[0].get(0) {
          Some(point) => write_label(out, point, value, color)
          None => ()
        }
      }
      None => ()
    }
  }
}

///|
fn write_keypoints(out : StringBuilder, points : Array[Keypoint], color : Color) -> Unit {
  for point in points {
    if point.visible {
      out.write_string(
        "<circle cx=\"\{point.point.x}\" cy=\"\{point.point.y}\" r=\"4\" fill=\"\{color.to_css()}\" stroke=\"white\" stroke-width=\"1\"/>\n",
      )
      if point.name != "" {
        out.write_string(
          "<text x=\"\{point.point.x + 6.0}\" y=\"\{point.point.y - 6.0}\" fill=\"white\" font-size=\"11\" font-family=\"system-ui,sans-serif\">\{escape_text(point.name)}</text>\n",
        )
      }
    }
  }
}

///|
fn write_trajectory(out : StringBuilder, path : Trajectory, color : Color) -> Unit {
  if path.points.length() > 1 {
    out.write_string(
      "<polyline points=\"\{polygon_points(path.points)}\" fill=\"none\" stroke=\"\{color.to_css()}\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/>\n",
    )
  }
  match path.points.last() {
    Some(last) =>
      out.write_string(
        "<circle cx=\"\{last.x}\" cy=\"\{last.y}\" r=\"5\" fill=\"\{color.to_css()}\"/>\n",
      )
    None => ()
  }
}

///|
fn write_heatmap(out : StringBuilder, cells : Array[HeatCell], low : Color, high : Color) -> Unit {
  for cell in cells {
    let color = mix_color(low, high, clamp01(cell.value)).with_alpha(0.46)
    out.write_string(
      "<rect x=\"\{cell.rect.x}\" y=\"\{cell.rect.y}\" width=\"\{cell.rect.width}\" height=\"\{cell.rect.height}\" fill=\"\{color.to_css()}\"/>\n",
    )
  }
}

///|
fn write_error_region(
  out : StringBuilder,
  rect : Rect,
  expected : String,
  actual : String,
  severity : Double,
) -> Unit {
  let color = mix_color(
    Color::rgb(r=245, g=158, b=11),
    Color::rgb(r=220, g=38, b=38),
    clamp01(severity),
  )
  out.write_string(
    "<rect x=\"\{rect.x}\" y=\"\{rect.y}\" width=\"\{rect.width}\" height=\"\{rect.height}\" fill=\"\{color.with_alpha(0.18).to_css()}\" stroke=\"\{color.to_css()}\" stroke-width=\"3\" stroke-dasharray=\"8 5\"/>\n",
  )
  write_label(
    out,
    Point::new(x=rect.x, y=rect.y),
    Label::new(text="expected: \{expected}; actual: \{actual}"),
    color,
  )
}

///|
fn write_label(out : StringBuilder, anchor : Point, label : Label, color : Color) -> Unit {
  let text = match label.score {
    Some(score) => "\{label.text} \{score}"
    None => label.text
  }
  let x = anchor.x
  let y = if anchor.y < 18.0 { anchor.y + 18.0 } else { anchor.y - 6.0 }
  out.write_string(
    "<text x=\"\{x}\" y=\"\{y}\" fill=\"\{color.to_css()}\" font-size=\"13\" font-weight=\"600\" font-family=\"system-ui,sans-serif\">\{escape_text(text)}</text>\n",
  )
}

///|
fn polygon_points(points : Array[Point]) -> String {
  points.map(point => "\{point.x},\{point.y}").join(" ")
}

///|
fn resolve_color(color : Color?, index : Int) -> Color {
  match color {
    Some(value) => value
    None => palette(index)
  }
}

///|
fn mix_color(a : Color, b : Color, t : Double) -> Color {
  let k = clamp01(t)
  Color::rgba(
    r=lerp_int(a.r, b.r, k),
    g=lerp_int(a.g, b.g, k),
    b=lerp_int(a.b, b.b, k),
    a=a.a + (b.a - a.a) * k,
  )
}

///|
fn lerp_int(a : Int, b : Int, t : Double) -> Int {
  (a.to_double() + (b - a).to_double() * t).round().to_int()
}

///|
fn clamp01(value : Double) -> Double {
  if value < 0.0 {
    0.0
  } else if value > 1.0 {
    1.0
  } else {
    value
  }
}

///|
fn escape_text(value : String) -> String {
  value
  .replace(old="&", new="&amp;")
  .replace(old="<", new="&lt;")
  .replace(old=">", new="&gt;")
}

///|
fn escape_attr(value : String) -> String {
  escape_text(value).replace(old="\"", new="&quot;")
}
