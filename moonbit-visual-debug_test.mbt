///|
fn sample_document() -> DebugDocument {
  let boxes = Layer::new(id="detections")
    .add(
      BBox(
        rect=Rect::new(x=10.0, y=12.0, width=40.0, height=30.0),
        label=Some(Label::new(text="person", score=0.92)),
        color=None,
      ),
    )
    .add(
      Keypoints(
        points=[
          Keypoint::new(point=Point::new(x=18.0, y=20.0), name="eye"),
          Keypoint::new(point=Point::new(x=30.0, y=24.0), name="hand"),
        ],
        color=Some(Color::rgb(r=16, g=185, b=129)),
      ),
    )
  let heat = Layer::new(id="heat")
    .with_opacity(0.85)
    .add(
      Heatmap(
        cells=[
          HeatCell::new(
            rect=Rect::new(x=0.0, y=0.0, width=16.0, height=16.0),
            value=0.1,
          ),
          HeatCell::new(
            rect=Rect::new(x=16.0, y=0.0, width=16.0, height=16.0),
            value=0.9,
          ),
        ],
        low=None,
        high=None,
      ),
    )
  DebugDocument::new(title="demo", image=ImageSpec::new(width=96, height=64))
  .add_layer(boxes)
  .add_layer(heat)
}

///|
test "rect intersection and iou" {
  let a = Rect::new(x=0.0, y=0.0, width=10.0, height=10.0)
  let b = Rect::new(x=5.0, y=5.0, width=10.0, height=10.0)
  inspect(a.intersects(b), content="true")
  debug_inspect(a.intersection(b).map(r => r.area()), content="Some(25)")
  inspect(a.iou(b) > 0.14 && a.iou(b) < 0.15, content="true")
}

///|
test "document overlay counting and svg rendering" {
  let doc = sample_document()
  inspect(doc.overlay_count(), content="3")
  let svg = doc.to_svg()
  inspect(svg.contains("<svg"), content="true")
  inspect(svg.contains("layer-detections"), content="true")
  inspect(svg.contains("<rect"), content="true")
  inspect(svg.contains("<circle"), content="true")
}

///|
test "html report embeds svg and summary table" {
  let html = sample_document().to_html_report()
  inspect(html.contains("<!doctype html>"), content="true")
  inspect(html.contains("<table>"), content="true")
  inspect(html.contains("3 overlays"), content="true")
}

///|
test "png encoder writes standard signature" {
  let png = sample_document().to_png()
  inspect(png.length() > 32, content="true")
  inspect(png[0], content="b'\\x89'")
  inspect(
    png[1],
    content=(
      #|b'\x50'
    ),
  )
  inspect(
    png[2],
    content=(
      #|b'\x4E'
    ),
  )
  inspect(
    png[3],
    content=(
      #|b'\x47'
    ),
  )
}

///|
test "detection matcher reports false positive and mismatch" {
  let expected = [
    Detection::new(
      id="gt-1",
      rect=Rect::new(x=0.0, y=0.0, width=20.0, height=20.0),
      label="cat",
    ),
    Detection::new(
      id="gt-2",
      rect=Rect::new(x=40.0, y=40.0, width=20.0, height=20.0),
      label="dog",
    ),
  ]
  let actual = [
    Detection::new(
      id="pred-1",
      rect=Rect::new(x=1.0, y=1.0, width=18.0, height=18.0),
      label="cat",
    ),
    Detection::new(
      id="pred-2",
      rect=Rect::new(x=40.0, y=40.0, width=20.0, height=20.0),
      label="wolf",
    ),
    Detection::new(
      id="pred-3",
      rect=Rect::new(x=70.0, y=70.0, width=10.0, height=10.0),
      label="noise",
    ),
  ]
  let summary = compare_detections(expected, actual)
  inspect(summary.true_positive, content="1")
  inspect(summary.false_positive, content="1")
  inspect(summary.label_mismatch, content="1")
  inspect(summary.to_error_layer().overlays.length(), content="2")
}

///|
test "document resize transforms overlay bounds" {
  let resized = sample_document().resize(width=192, height=128)
  inspect(resized.image.width, content="192")
  inspect(resized.image.height, content="128")
  match resized.content_bounds() {
    Some(bounds) => {
      inspect(bounds.x, content="0")
      inspect(bounds.width > 90.0, content="true")
    }
    None => fail("expected bounds")
  }
}

///|
test "validation reports invalid rectangles" {
  let invalid = DebugDocument::new(
    title="bad",
    image=ImageSpec::new(width=64, height=64),
  ).add_layer(
    Layer::new(id="bad-box").add(
      BBox(
        rect=Rect::new(x=0.0, y=0.0, width=0.0, height=10.0),
        label=None,
        color=None,
      ),
    ),
  )
  inspect(invalid.is_valid(), content="false")
  inspect(invalid.validate().length(), content="1")
}
