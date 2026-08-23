///|
fn diff_document(title : String, layers : Array[Layer]) -> DebugDocument {
  {
    title,
    image: ImageSpec::new(width=100, height=80),
    image_href: None,
    layers,
  }
}

///|
test "document diff reports no changes" {
  let baseline = diff_document("baseline", [Layer::new(id="boxes")])
  let diff = compare_documents(baseline, baseline)
  inspect(diff.title_changed, content="false")
  inspect(diff.image_size_changed, content="false")
  inspect(diff.overlay_count_delta, content="0")
  inspect(diff.layer_changes.length(), content="0")
}

///|
test "document diff reports added and removed layers" {
  let baseline = diff_document("baseline", [
    Layer::new(id="removed"),
    Layer::new(id="shared"),
  ])
  let candidate = diff_document("candidate", [
    Layer::new(id="shared"),
    Layer::new(id="added"),
  ])
  let changes = compare_documents(baseline, candidate).layer_changes
  inspect(changes.length(), content="2")
  inspect(changes[0].id, content="removed")
  debug_inspect(changes[0].kind, content="Removed")
  debug_inspect(changes[0].baseline_index, content="Some(0)")
  debug_inspect(changes[0].candidate_index, content="None")
  inspect(changes[1].id, content="added")
  debug_inspect(changes[1].kind, content="Added")
  debug_inspect(changes[1].baseline_index, content="None")
  debug_inspect(changes[1].candidate_index, content="Some(1)")
}

///|
test "document diff reports title image and layer metadata changes" {
  let baseline = diff_document("before", [
    Layer::new(id="boxes", overlays=[]).with_opacity(0.4),
  ])
  let candidate : DebugDocument = {
    title: "after",
    image: ImageSpec::new(width=120, height=90),
    image_href: None,
    layers: [
      Layer::new(id="boxes", overlays=[])
      .hidden()
      .with_opacity(0.7)
      .add(
        BBox(
          rect=Rect::new(x=1.0, y=2.0, width=3.0, height=4.0),
          label=None,
          color=None,
        ),
      ),
    ],
  }
  let diff = compare_documents(baseline, candidate)
  inspect(diff.title_changed, content="true")
  inspect(diff.image_size_changed, content="true")
  inspect(diff.baseline_image.width, content="100")
  inspect(diff.candidate_image.height, content="90")
  inspect(diff.overlay_count_delta, content="1")
  let change = diff.layer_changes[0]
  debug_inspect(change.kind, content="Changed")
  inspect(change.visibility_changed, content="true")
  inspect(change.opacity_changed, content="true")
  inspect(change.overlay_delta, content="1")
  inspect(baseline.layers[0].visible, content="true")
  inspect(baseline.layers[0].opacity, content="0.4")
}

///|
test "document diff reports image href changes at unchanged dimensions" {
  let baseline : DebugDocument = {
    title: "same",
    image: ImageSpec::new(width=100, height=80),
    image_href: Some("baseline.png"),
    layers: [],
  }
  let candidate : DebugDocument = {
    title: "same",
    image: ImageSpec::new(width=100, height=80),
    image_href: Some("<candidate & \"image\">"),
    layers: [],
  }
  let diff = compare_documents(baseline, candidate)
  inspect(diff.image_size_changed, content="false")
  inspect(diff.image_href_changed, content="true")
  debug_inspect(diff.baseline_image_href, content="Some(\"baseline.png\")")
  debug_inspect(
    diff.candidate_image_href,
    content="Some(\"<candidate & \\\"image\\\">\")",
  )
  inspect(
    diff.to_html().contains("&lt;candidate &amp; &quot;image&quot;&gt;"),
    content="true",
  )
}

///|
test "document diff reports negative overlay deltas" {
  let baseline = diff_document("same", [
    Layer::new(id="boxes", overlays=[
      BBox(
        rect=Rect::new(x=1.0, y=2.0, width=3.0, height=4.0),
        label=None,
        color=None,
      ),
    ]),
  ])
  let candidate = diff_document("same", [Layer::new(id="boxes")])
  let diff = compare_documents(baseline, candidate)
  inspect(diff.overlay_count_delta, content="-1")
  inspect(diff.layer_changes[0].overlay_delta, content="-1")
}

///|
test "document diff preserves candidate inputs" {
  let candidate : DebugDocument = {
    title: "candidate",
    image: ImageSpec::new(width=100, height=80),
    image_href: Some("candidate.png"),
    layers: [Layer::new(id="boxes").hidden().with_opacity(0.25)],
  }
  let baseline = diff_document("baseline", [])
  ignore(compare_documents(baseline, candidate))
  inspect(candidate.title, content="candidate")
  debug_inspect(candidate.image_href, content="Some(\"candidate.png\")")
  inspect(candidate.layers[0].visible, content="false")
  inspect(candidate.layers[0].opacity, content="0.25")
}

///|
test "duplicate and empty ids use stable positional fallbacks" {
  let baseline = diff_document("same", [
    Layer::new(id="duplicate").with_opacity(0.1),
    Layer::new(id="duplicate").with_opacity(0.2),
    Layer::new(id="").with_opacity(0.3),
    Layer::new(id="").with_opacity(0.4),
  ])
  let candidate = diff_document("same", [
    Layer::new(id="duplicate").with_opacity(0.1),
    Layer::new(id="duplicate").with_opacity(0.9),
    Layer::new(id="").with_opacity(0.3),
    Layer::new(id="").with_opacity(0.8),
  ])
  let changes = compare_documents(baseline, candidate).layer_changes
  inspect(changes.length(), content="2")
  inspect(changes[0].id, content="duplicate")
  debug_inspect(changes[0].baseline_index, content="Some(1)")
  debug_inspect(changes[0].candidate_index, content="Some(1)")
  inspect(changes[1].id, content="")
  debug_inspect(changes[1].baseline_index, content="Some(3)")
  debug_inspect(changes[1].candidate_index, content="Some(3)")
}

///|
test "diff html escapes document and layer text" {
  let baseline = diff_document("before", [])
  let candidate = diff_document("<after & \"quoted\">", [
    Layer::new(id="<added & \"layer\">"),
  ])
  let html = compare_documents(baseline, candidate).to_html()
  inspect(html.contains("<after"), content="false")
  inspect(
    html.contains("&lt;after &amp; &quot;quoted&quot;&gt;"),
    content="true",
  )
  inspect(
    html.contains("&lt;added &amp; &quot;layer&quot;&gt;"),
    content="true",
  )
}
