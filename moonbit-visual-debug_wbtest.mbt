///|
test "color clamping and palette remain stable" {
  inspect(Color::rgba(r=300, g=-5, b=128, a=2.0).to_hex(), content="#ff0080")
  inspect(Color::rgba(r=1, g=2, b=3, a=0.5).to_css(), content="rgba(1,2,3,0.5)")
  inspect(palette(8).to_hex(), content="#277dff")
}

///|
test "canvas drawing changes encoded png size" {
  let blank = Canvas::new(width=8, height=8).to_png()
  let canvas = Canvas::new(width=8, height=8)
  canvas.fill_rect(
    Rect::new(x=2.0, y=2.0, width=3.0, height=3.0),
    Color::rgb(r=255, g=0, b=0),
  )
  let painted = canvas.to_png()
  inspect(blank.length() == painted.length(), content="true")
  inspect(blank != painted, content="true")
}
