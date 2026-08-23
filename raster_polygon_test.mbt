///|
fn pixel_has_color(canvas : Canvas, x : Int, y : Int, color : Color) -> Bool {
  let index = (y * canvas.width + x) * 4
  canvas.pixels[index] == color.r.to_byte() &&
  canvas.pixels[index + 1] == color.g.to_byte() &&
  canvas.pixels[index + 2] == color.b.to_byte() &&
  canvas.pixels[index + 3] == (color.a * 255.0).round().to_int().to_byte()
}

///|
test "fill_polygon colors triangle pixels whose centers are inside" {
  let background = Color::rgb(r=1, g=2, b=3)
  let fill = Color::rgb(r=220, g=38, b=38)
  let canvas = Canvas::new(width=6, height=6, background~)
  canvas.fill_polygon(
    [
      Point::new(x=1.0, y=1.0),
      Point::new(x=5.0, y=1.0),
      Point::new(x=1.0, y=5.0),
    ],
    fill,
  )
  inspect(pixel_has_color(canvas, 1, 1, fill), content="true")
  inspect(pixel_has_color(canvas, 3, 1, fill), content="true")
  inspect(pixel_has_color(canvas, 4, 2, background), content="true")
  inspect(pixel_has_color(canvas, 0, 0, background), content="true")
}

///|
test "fill_polygon clips negative coordinates to the canvas" {
  let background = Color::rgb(r=1, g=2, b=3)
  let fill = Color::rgb(r=59, g=130, b=246)
  let canvas = Canvas::new(width=4, height=4, background~)
  canvas.fill_polygon(
    [
      Point::new(x=-3.0, y=-3.0),
      Point::new(x=3.0, y=-3.0),
      Point::new(x=3.0, y=3.0),
      Point::new(x=-3.0, y=3.0),
    ],
    fill,
  )
  inspect(pixel_has_color(canvas, 0, 0, fill), content="true")
  inspect(pixel_has_color(canvas, 2, 2, fill), content="true")
  inspect(pixel_has_color(canvas, 3, 0, background), content="true")
  inspect(pixel_has_color(canvas, 0, 3, background), content="true")
}

///|
test "fill_polygon follows concave boundaries" {
  let background = Color::rgb(r=1, g=2, b=3)
  let fill = Color::rgb(r=16, g=185, b=129)
  let canvas = Canvas::new(width=6, height=6, background~)
  canvas.fill_polygon(
    [
      Point::new(x=1.0, y=1.0),
      Point::new(x=5.0, y=1.0),
      Point::new(x=5.0, y=3.0),
      Point::new(x=3.0, y=3.0),
      Point::new(x=3.0, y=5.0),
      Point::new(x=1.0, y=5.0),
    ],
    fill,
  )
  inspect(pixel_has_color(canvas, 1, 1, fill), content="true")
  inspect(pixel_has_color(canvas, 4, 1, fill), content="true")
  inspect(pixel_has_color(canvas, 1, 4, fill), content="true")
  inspect(pixel_has_color(canvas, 4, 4, background), content="true")
}

///|
test "fill_polygons applies even-odd holes" {
  let background = Color::rgb(r=1, g=2, b=3)
  let fill = Color::rgb(r=168, g=85, b=247)
  let canvas = Canvas::new(width=8, height=8, background~)
  canvas.fill_polygons(
    [
      [
        Point::new(x=1.0, y=1.0),
        Point::new(x=7.0, y=1.0),
        Point::new(x=7.0, y=7.0),
        Point::new(x=1.0, y=7.0),
      ],
      [
        Point::new(x=3.0, y=3.0),
        Point::new(x=5.0, y=3.0),
        Point::new(x=5.0, y=5.0),
        Point::new(x=3.0, y=5.0),
      ],
    ],
    fill,
  )
  inspect(pixel_has_color(canvas, 2, 2, fill), content="true")
  inspect(pixel_has_color(canvas, 3, 3, background), content="true")
  inspect(pixel_has_color(canvas, 6, 6, fill), content="true")
}

///|
test "fill_polygons ignores empty and degenerate polygons" {
  let background = Color::rgb(r=1, g=2, b=3)
  let fill = Color::rgb(r=245, g=158, b=11)
  let canvas = Canvas::new(width=4, height=4, background~)
  canvas.fill_polygon([], fill)
  canvas.fill_polygons(
    [
      [Point::new(x=1.0, y=1.0)],
      [Point::new(x=0.0, y=0.0), Point::new(x=3.0, y=3.0)],
    ],
    fill,
  )
  inspect(
    canvas.to_png() == Canvas::new(width=4, height=4, background~).to_png(),
    content="true",
  )
}

///|
test "mask overlays use even-odd polygon rasterization deterministically" {
  let background = Color::rgb(r=1, g=2, b=3)
  let mask_color = Color::rgb(r=14, g=165, b=233)
  let document = DebugDocument::new(
    title="mask",
    image=ImageSpec::new(width=8, height=8),
  ).add_layer(
    Layer::new(id="mask").add(
      Mask(
        polygons=[
          [
            Point::new(x=1.0, y=1.0),
            Point::new(x=7.0, y=1.0),
            Point::new(x=7.0, y=7.0),
            Point::new(x=1.0, y=7.0),
          ],
          [
            Point::new(x=3.0, y=3.0),
            Point::new(x=5.0, y=3.0),
            Point::new(x=5.0, y=5.0),
            Point::new(x=3.0, y=5.0),
          ],
        ],
        label=None,
        color=Some(mask_color),
      ),
    ),
  )
  let first = document.to_canvas(background~)
  let second = document.to_canvas(background~)
  inspect(
    pixel_has_color(first, 2, 2, mask_color.with_alpha(0.45)),
    content="true",
  )
  inspect(pixel_has_color(first, 3, 3, background), content="true")
  inspect(first.to_png() == second.to_png(), content="true")
}
