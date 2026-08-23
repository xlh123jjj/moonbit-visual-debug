///|
pub(all) struct Canvas {
  width : Int
  height : Int
  pixels : Array[Byte]
} derive(Debug)

///|
pub fn Canvas::new(
  width~ : Int,
  height~ : Int,
  background? : Color = Color::rgb(r=15, g=23, b=42),
) -> Canvas {
  let pixels : Array[Byte] = []
  for _ in 0..<(width * height) {
    pixels.push(background.r.to_byte())
    pixels.push(background.g.to_byte())
    pixels.push(background.b.to_byte())
    pixels.push((background.a * 255.0).round().to_int().to_byte())
  }
  { width, height, pixels }
}

///|
pub fn Canvas::from_image_spec(
  image : ImageSpec,
  background? : Color = Color::rgb(r=15, g=23, b=42),
) -> Canvas {
  Canvas::new(width=image.width, height=image.height, background~)
}

///|
pub fn Canvas::set_pixel(
  self : Canvas,
  x : Int,
  y : Int,
  color : Color,
) -> Unit {
  if x >= 0 && y >= 0 && x < self.width && y < self.height {
    let index = (y * self.width + x) * 4
    self.pixels[index] = color.r.to_byte()
    self.pixels[index + 1] = color.g.to_byte()
    self.pixels[index + 2] = color.b.to_byte()
    self.pixels[index + 3] = (color.a * 255.0).round().to_int().to_byte()
  }
}

///|
pub fn Canvas::fill_rect(self : Canvas, rect : Rect, color : Color) -> Unit {
  let x0 = floor_to_int(rect.x)
  let y0 = floor_to_int(rect.y)
  let x1 = ceil_to_int(rect.right())
  let y1 = ceil_to_int(rect.bottom())
  for y in y0..<y1 {
    for x in x0..<x1 {
      self.set_pixel(x, y, color)
    }
  }
}

///|
/// Fills one polygon using even-odd containment evaluated at pixel centers.
///
/// An edge contributes only when a pixel center's horizontal ray crosses its
/// half-open vertical range `[min_y, max_y)`, so shared vertices and horizontal
/// edges have deterministic coverage. Polygons with fewer than three points are
/// ignored and all writes are clipped to the canvas.
pub fn Canvas::fill_polygon(
  self : Canvas,
  polygon : Array[Point],
  color : Color,
) -> Unit {
  self.fill_polygons([polygon], color)
}

///|
/// Fills polygons with the even-odd rule, allowing nested polygons to form holes.
///
/// Pixels are evaluated at `(x + 0.5, y + 0.5)`. The same half-open edge rule as
/// `fill_polygon` makes boundary coverage reproducible regardless of edge order.
pub fn Canvas::fill_polygons(
  self : Canvas,
  polygons : Array[Array[Point]],
  color : Color,
) -> Unit {
  let valid_polygons = polygons.filter(polygon => polygon.length() >= 3)
  if valid_polygons.is_empty() {
    ()
  } else {
    match bounds_of_polygons(valid_polygons) {
      None => ()
      Some(bounds) => {
        let raw_x0 = floor_to_int(bounds.x)
        let raw_y0 = floor_to_int(bounds.y)
        let raw_x1 = ceil_to_int(bounds.right())
        let raw_y1 = ceil_to_int(bounds.bottom())
        let x0 = if raw_x0 < 0 { 0 } else { raw_x0 }
        let y0 = if raw_y0 < 0 { 0 } else { raw_y0 }
        let x1 = if raw_x1 > self.width { self.width } else { raw_x1 }
        let y1 = if raw_y1 > self.height { self.height } else { raw_y1 }
        for y in y0..<y1 {
          for x in x0..<x1 {
            if point_is_inside_polygons(
                x.to_double() + 0.5,
                y.to_double() + 0.5,
                valid_polygons,
              ) {
              self.set_pixel(x, y, color)
            }
          }
        }
      }
    }
  }
}

///|
pub fn Canvas::stroke_rect(
  self : Canvas,
  rect : Rect,
  color : Color,
  width? : Int = 2,
) -> Unit {
  let x0 = floor_to_int(rect.x)
  let y0 = floor_to_int(rect.y)
  let x1 = ceil_to_int(rect.right())
  let y1 = ceil_to_int(rect.bottom())
  for offset in 0..<width {
    for x in x0..<x1 {
      self.set_pixel(x, y0 + offset, color)
      self.set_pixel(x, y1 - 1 - offset, color)
    }
    for y in y0..<y1 {
      self.set_pixel(x0 + offset, y, color)
      self.set_pixel(x1 - 1 - offset, y, color)
    }
  }
}

///|
pub fn Canvas::draw_point(
  self : Canvas,
  point : Point,
  color : Color,
  radius? : Int = 3,
) -> Unit {
  let cx = point.x.round().to_int()
  let cy = point.y.round().to_int()
  let rr = radius * radius
  for y in (cy - radius)..<=(cy + radius) {
    for x in (cx - radius)..<=(cx + radius) {
      let dx = x - cx
      let dy = y - cy
      if dx * dx + dy * dy <= rr {
        self.set_pixel(x, y, color)
      }
    }
  }
}

///|
pub fn DebugDocument::to_canvas(
  self : DebugDocument,
  background? : Color = Color::rgb(r=15, g=23, b=42),
) -> Canvas {
  let canvas = Canvas::from_image_spec(self.image, background~)
  for layer_index, layer in self.visible_layers() {
    for overlay_index, overlay in layer.overlays {
      draw_overlay(canvas, overlay, layer_index + overlay_index)
    }
  }
  canvas
}

///|
pub fn DebugDocument::to_png(self : DebugDocument) -> Bytes {
  self.to_canvas().to_png()
}

///|
fn draw_overlay(canvas : Canvas, overlay : Overlay, index : Int) -> Unit {
  match overlay {
    BBox(rect~, color~, ..) =>
      canvas.stroke_rect(rect, resolve_raster_color(color, index))
    Mask(polygons~, color~, ..) => {
      let color = resolve_raster_color(color, index).with_alpha(0.45)
      canvas.fill_polygons(polygons, color)
    }
    Keypoints(points~, color~) => {
      let color = resolve_raster_color(color, index)
      for point in points {
        if point.visible {
          canvas.draw_point(point.point, color)
        }
      }
    }
    Trajectory(path~, color~) => {
      let color = resolve_raster_color(color, index)
      for point in path.points {
        canvas.draw_point(point, color, radius=2)
      }
    }
    Heatmap(cells~, low~, high~) => {
      let low_color = resolve_raster_color(low, 2)
      let high_color = resolve_raster_color(high, 1)
      for cell in cells {
        canvas.fill_rect(
          cell.rect,
          raster_mix(low_color, high_color, clamp_raster(cell.value)).with_alpha(
            0.55,
          ),
        )
      }
    }
    ErrorRegion(rect~, severity~, ..) => {
      let color = raster_mix(
        Color::rgb(r=245, g=158, b=11),
        Color::rgb(r=220, g=38, b=38),
        clamp_raster(severity),
      )
      canvas.stroke_rect(rect, color, width=4)
    }
  }
}

///|
pub fn Canvas::to_png(self : Canvas) -> Bytes {
  let png : Array[Byte] = [
    byte(137),
    byte(80),
    byte(78),
    byte(71),
    byte(13),
    byte(10),
    byte(26),
    byte(10),
  ]
  append_chunk(png, "IHDR", ihdr_data(self.width, self.height))
  let scanlines = png_scanlines(self)
  append_chunk(png, "IDAT", zlib_store(scanlines))
  append_chunk(png, "IEND", [])
  Bytes::from_array(png)
}

///|
fn ihdr_data(width : Int, height : Int) -> Array[Byte] {
  let data : Array[Byte] = []
  append_u32_be(data, width.reinterpret_as_uint())
  append_u32_be(data, height.reinterpret_as_uint())
  data.push(byte(8)) // bit depth
  data.push(byte(6)) // RGBA
  data.push(byte(0)) // compression
  data.push(byte(0)) // filter
  data.push(byte(0)) // interlace
  data
}

///|
fn png_scanlines(canvas : Canvas) -> Array[Byte] {
  let raw : Array[Byte] = []
  for y in 0..<canvas.height {
    raw.push(byte(0))
    let start = y * canvas.width * 4
    for i in 0..<(canvas.width * 4) {
      raw.push(canvas.pixels[start + i])
    }
  }
  raw
}

///|
fn zlib_store(raw : Array[Byte]) -> Array[Byte] {
  let out : Array[Byte] = [byte(0x78), byte(0x01)]
  let mut offset = 0
  while offset < raw.length() {
    let remaining = raw.length() - offset
    let len = if remaining > 65535 { 65535 } else { remaining }
    let final_block = offset + len >= raw.length()
    out.push(if final_block { byte(1) } else { byte(0) })
    append_u16_le(out, len)
    append_u16_le(out, 65535 - len)
    for i in 0..<len {
      out.push(raw[offset + i])
    }
    offset += len
  }
  append_u32_be(out, adler32(raw))
  out
}

///|
fn append_chunk(out : Array[Byte], kind : String, data : Array[Byte]) -> Unit {
  append_u32_be(out, data.length().reinterpret_as_uint())
  let kind_bytes = string_ascii(kind)
  out.append(kind_bytes)
  out.append(data)
  let crc_input = kind_bytes + data
  append_u32_be(out, crc32(crc_input))
}

///|
fn append_u16_le(out : Array[Byte], value : Int) -> Unit {
  out.push(value.to_byte())
  out.push((value >> 8).to_byte())
}

///|
fn byte(value : Int) -> Byte {
  value.to_byte()
}

///|
fn append_u32_be(out : Array[Byte], value : UInt) -> Unit {
  out.push((value >> 24).to_byte())
  out.push((value >> 16).to_byte())
  out.push((value >> 8).to_byte())
  out.push(value.to_byte())
}

///|
fn string_ascii(value : String) -> Array[Byte] {
  value.iter().map(ch => ch.to_int().to_byte()).collect()
}

///|
fn crc32(bytes : Array[Byte]) -> UInt {
  let mut crc = 0xffffffffU
  for byte in bytes {
    crc = crc ^ byte.to_uint()
    for _ in 0..<8 {
      if (crc & 1U) == 1U {
        crc = (crc >> 1) ^ 0xedb88320U
      } else {
        crc = crc >> 1
      }
    }
  }
  crc ^ 0xffffffffU
}

///|
fn adler32(bytes : Array[Byte]) -> UInt {
  let mut a = 1
  let mut b = 0
  for byte in bytes {
    a = (a + byte.to_int()) % 65521
    b = (b + a) % 65521
  }
  ((b << 16) | a).reinterpret_as_uint()
}

///|
fn resolve_raster_color(color : Color?, index : Int) -> Color {
  match color {
    Some(value) => value
    None => palette(index)
  }
}

///|
fn raster_mix(a : Color, b : Color, t : Double) -> Color {
  let k = clamp_raster(t)
  Color::rgba(
    r=(a.r.to_double() + (b.r - a.r).to_double() * k).round().to_int(),
    g=(a.g.to_double() + (b.g - a.g).to_double() * k).round().to_int(),
    b=(a.b.to_double() + (b.b - a.b).to_double() * k).round().to_int(),
    a=a.a + (b.a - a.a) * k,
  )
}

///|
fn clamp_raster(value : Double) -> Double {
  if value < 0.0 {
    0.0
  } else if value > 1.0 {
    1.0
  } else {
    value
  }
}

///|
fn floor_to_int(value : Double) -> Int {
  value.floor().to_int()
}

///|
fn ceil_to_int(value : Double) -> Int {
  value.ceil().to_int()
}

///|
fn point_is_inside_polygons(
  x : Double,
  y : Double,
  polygons : Array[Array[Point]],
) -> Bool {
  let mut inside = false
  for polygon in polygons {
    if point_is_inside_polygon(x, y, polygon) {
      inside = !inside
    }
  }
  inside
}

///|
fn point_is_inside_polygon(
  x : Double,
  y : Double,
  polygon : Array[Point],
) -> Bool {
  if polygon.length() < 3 {
    false
  } else {
    let mut inside = false
    let mut previous = polygon[polygon.length() - 1]
    for current in polygon {
      let crosses_scanline = (previous.y <= y && y < current.y) ||
        (current.y <= y && y < previous.y)
      if crosses_scanline {
        let crossing_x = previous.x +
          (y - previous.y) * (current.x - previous.x) / (current.y - previous.y)
        if x < crossing_x {
          inside = !inside
        }
      }
      previous = current
    }
    inside
  }
}
