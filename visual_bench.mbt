///|
fn benchmark_document() -> DebugDocument {
  let mut layer = Layer::new(id="detections")
  for index in 0..<256 {
    let x = (index % 32 * 20).to_double()
    let y = (index / 32 * 20).to_double()
    layer = layer.add(
      BBox(
        rect=Rect::new(x~, y~, width=16.0, height=16.0),
        label=Some(Label::new(text="part", score=0.9)),
        color=None,
      ),
    )
  }
  DebugDocument::new(
    title="benchmark",
    image=ImageSpec::new(width=640, height=160),
  ).add_layer(layer)
}

///|
test "render 256 overlays to SVG" (b : @bench.T) {
  let document = benchmark_document()
  b.bench(fn() { b.keep(document.to_svg()) })
}

///|
test "render 256 overlays to PNG" (b : @bench.T) {
  let document = benchmark_document()
  b.bench(fn() { b.keep(document.to_png()) })
}
