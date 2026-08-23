///|
test "manifest summarizes an empty document" {
  let document = DebugDocument::new(
    title="empty",
    image=ImageSpec::new(width=640, height=480),
  )
  let manifest = document.manifest()
  inspect(manifest.title, content="empty")
  inspect(manifest.layer_count, content="0")
  inspect(manifest.visible_layer_count, content="0")
  inspect(manifest.total_overlay_count, content="0")
  inspect(manifest.visible_overlay_count, content="0")
  inspect(manifest.layers.length(), content="0")
  assert_true(manifest.content_bounds is None)
  inspect(manifest.diagnostics.info, content="0")
  inspect(manifest.diagnostics.warning, content="1")
  inspect(manifest.diagnostics.error, content="0")
}

///|
test "manifest counts every overlay kind in stable layer order" {
  let rect = Rect::new(x=1.0, y=2.0, width=3.0, height=4.0)
  let layer = Layer::new(id="first", overlays=[
    BBox(rect~, label=Some(Label::new(text="box")), color=None),
    Mask(
      polygons=[
        [
          Point::new(x=10.0, y=10.0),
          Point::new(x=20.0, y=10.0),
          Point::new(x=10.0, y=20.0),
        ],
      ],
      label=None,
      color=None,
    ),
    Keypoints(
      points=[Keypoint::new(point=Point::new(x=30.0, y=40.0), name="p")],
      color=None,
    ),
    Trajectory(
      path=Trajectory::new(id="route", points=[
        Point::new(x=50.0, y=60.0),
        Point::new(x=70.0, y=80.0),
      ]),
      color=None,
    ),
    Heatmap(cells=[HeatCell::new(rect~, value=0.5)], low=None, high=None),
    ErrorRegion(rect~, expected="expected", actual="actual", severity=0.5),
  ])
  let document = DebugDocument::new(
      title="all",
      image=ImageSpec::new(width=100, height=100),
    )
    .add_layer(layer)
    .add_layer(Layer::new(id="second"))
  let manifest = document.manifest()
  inspect(
    manifest.layers.map(layer => layer.id).join(","),
    content="first,second",
  )
  inspect(manifest.total_overlay_count, content="6")
  inspect(manifest.visible_overlay_count, content="6")
  inspect(manifest.overlays.bbox, content="1")
  inspect(manifest.overlays.mask, content="1")
  inspect(manifest.overlays.keypoints, content="1")
  inspect(manifest.overlays.trajectory, content="1")
  inspect(manifest.overlays.heatmap, content="1")
  inspect(manifest.overlays.error_region, content="1")
  inspect(manifest.layers[0].overlays.error_region, content="1")
}

///|
test "manifest excludes hidden layers from visible overlay count" {
  let overlay : Overlay = BBox(
    rect=Rect::new(x=0.0, y=0.0, width=1.0, height=1.0),
    label=None,
    color=None,
  )
  let document = DebugDocument::new(
      title="visibility",
      image=ImageSpec::new(width=10, height=10),
    )
    .add_layer(Layer::new(id="shown", overlays=[overlay]))
    .add_layer(Layer::new(id="hidden", overlays=[overlay]).hidden())
  let manifest = document.manifest()
  inspect(manifest.layer_count, content="2")
  inspect(manifest.visible_layer_count, content="1")
  inspect(manifest.total_overlay_count, content="2")
  inspect(manifest.visible_overlay_count, content="1")
  inspect(manifest.layers[1].visible, content="false")
}

///|
test "manifest includes content bounds and validation severity counts" {
  let valid_rect = Rect::new(x=-2.0, y=3.0, width=5.0, height=7.0)
  let invalid_rect = Rect::new(x=10.0, y=20.0, width=0.0, height=4.0)
  let document : DebugDocument = {
    title: "invalid",
    image: { width: 0, height: 10 },
    image_href: None,
    layers: [
      {
        id: "",
        visible: true,
        opacity: 2.0,
        overlays: [
          BBox(rect=valid_rect, label=None, color=None),
          ErrorRegion(
            rect=invalid_rect,
            expected="left",
            actual="right",
            severity=2.0,
          ),
        ],
      },
    ],
  }
  let manifest = document.manifest()
  inspect(manifest.is_valid, content="false")
  inspect(manifest.diagnostics.info, content="0")
  inspect(manifest.diagnostics.warning, content="2")
  inspect(manifest.diagnostics.error, content="3")
  match manifest.content_bounds {
    Some(bounds) => {
      inspect(bounds.x, content="-2")
      inspect(bounds.y, content="3")
      inspect(bounds.width, content="12")
      inspect(bounds.height, content="21")
    }
    None => fail("expected content bounds")
  }
}

///|
test "manifest JSON and Markdown are stable and escape user strings" {
  let document = DebugDocument::new(
    title="a \"quoted\" <title> & line\nnext",
    image=ImageSpec::new(width=2, height=3),
  ).add_layer(Layer::new(id="layer|one\n*bold*"))
  let manifest = document.manifest()
  inspect(
    manifest.to_json_text(),
    content="{\"title\":\"a \\\"quoted\\\" <title> & line\\nnext\",\"image\":{\"width\":2,\"height\":3},\"layer_count\":1,\"visible_layer_count\":1,\"total_overlay_count\":0,\"visible_overlay_count\":0,\"overlays\":{\"bbox\":0,\"mask\":0,\"keypoints\":0,\"trajectory\":0,\"heatmap\":0,\"error_region\":0},\"visible_overlays\":{\"bbox\":0,\"mask\":0,\"keypoints\":0,\"trajectory\":0,\"heatmap\":0,\"error_region\":0},\"content_bounds\":null,\"diagnostics\":{\"info\":1,\"warning\":0,\"error\":0},\"is_valid\":true,\"layers\":[{\"id\":\"layer|one\\n*bold*\",\"visible\":true,\"opacity\":1,\"overlay_count\":0,\"overlays\":{\"bbox\":0,\"mask\":0,\"keypoints\":0,\"trajectory\":0,\"heatmap\":0,\"error_region\":0}}]}",
  )
  inspect(
    manifest.to_markdown(),
    content=(
      #|# a \"quoted\" &lt;title&gt; &amp; line\nnext
      #|
      #|- Image: 2 × 3
      #|- Layers: 1 total, 1 visible
      #|- Overlays: 0 total, 0 visible
      #|- Validation: 0 errors, 0 warnings, 1 info
      #|
      #|## Layers
      #|
      #|| Layer | Visible | Opacity | Overlays |
      #|| --- | --- | ---: | ---: |
      #|| layer\|one\n\*bold\* | yes | 1 | 0 |
      #|
      #|## Overlay kinds
      #|
      #|| BBox | Mask | Keypoints | Trajectory | Heatmap | Error regions |
      #|| ---: | ---: | ---: | ---: | ---: | ---: |
      #|| 0 | 0 | 0 | 0 | 0 | 0 |
      #|
      #|## Content bounds
      #|
      #|None
      #|
    ),
  )
}

///|
test "manifest counts all overlay variants across hidden and visible layers" {
  let visible = Layer::new(id="visible")
    .add(
      BBox(
        rect=Rect::new(x=1.0, y=1.0, width=2.0, height=2.0),
        label=None,
        color=None,
      ),
    )
    .add(
      Mask(
        polygons=[
          [
            Point::new(x=2.0, y=2.0),
            Point::new(x=5.0, y=2.0),
            Point::new(x=3.0, y=4.0),
          ],
        ],
        label=None,
        color=None,
      ),
    )
    .add(
      Keypoints(
        points=[Keypoint::new(point=Point::new(x=3.0, y=3.0), name="p")],
        color=None,
      ),
    )
    .add(
      Trajectory(
        path=Trajectory::new(id="t", points=[
          Point::new(x=0.0, y=0.0),
          Point::new(x=4.0, y=4.0),
        ]),
        color=None,
      ),
    )
    .add(
      Heatmap(
        cells=[
          HeatCell::new(
            rect=Rect::new(x=0.0, y=0.0, width=1.0, height=1.0),
            value=0.5,
          ),
        ],
        low=None,
        high=None,
      ),
    )
    .add(
      ErrorRegion(
        rect=Rect::new(x=4.0, y=4.0, width=1.0, height=1.0),
        expected="left",
        actual="right",
        severity=0.8,
      ),
    )
  let hidden = Layer::new(id="hidden")
    .add(
      BBox(
        rect=Rect::new(x=8.0, y=8.0, width=1.0, height=1.0),
        label=None,
        color=None,
      ),
    )
    .hidden()
  let manifest = DebugDocument::new(
      title="all kinds",
      image=ImageSpec::new(width=16, height=16),
    )
    .add_layer(visible)
    .add_layer(hidden)
    .manifest()
  inspect(manifest.total_overlay_count, content="7")
  inspect(manifest.visible_overlay_count, content="6")
  inspect(manifest.overlays.bbox, content="2")
  inspect(manifest.overlays.mask, content="1")
  inspect(manifest.overlays.keypoints, content="1")
  inspect(manifest.overlays.trajectory, content="1")
  inspect(manifest.overlays.heatmap, content="1")
  inspect(manifest.overlays.error_region, content="1")
}
