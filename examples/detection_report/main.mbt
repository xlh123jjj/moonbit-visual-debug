///|
fn main {
  let expected = [
    @visual.Detection::new(
      id="gt-person",
      rect=@visual.Rect::new(x=20.0, y=18.0, width=70.0, height=96.0),
      label="person",
    ),
    @visual.Detection::new(
      id="gt-bag",
      rect=@visual.Rect::new(x=98.0, y=64.0, width=38.0, height=46.0),
      label="bag",
    ),
  ]
  let actual = [
    @visual.Detection::new(
      id="pred-person",
      rect=@visual.Rect::new(x=22.0, y=20.0, width=68.0, height=92.0),
      label="person",
      score=0.94,
    ),
    @visual.Detection::new(
      id="pred-backpack",
      rect=@visual.Rect::new(x=100.0, y=66.0, width=36.0, height=42.0),
      label="backpack",
      score=0.71,
    ),
  ]
  let summary = @visual.compare_detections(expected, actual, iou_threshold=0.45)
  let predictions = @visual.Layer::new(id="predictions")
    .add(
      @visual.BBox(
        rect=actual[0].rect,
        label=Some(
          @visual.Label::new(text=actual[0].label, score=actual[0].score),
        ),
        color=Some(@visual.Color::rgb(r=39, g=125, b=255)),
      ),
    )
    .add(
      @visual.BBox(
        rect=actual[1].rect,
        label=Some(
          @visual.Label::new(text=actual[1].label, score=actual[1].score),
        ),
        color=Some(@visual.Color::rgb(r=16, g=185, b=129)),
      ),
    )
  let report = @visual.DebugDocument::new(
      title="detection acceptance report",
      image=@visual.ImageSpec::new(width=180, height=140),
    )
    .add_layer(predictions)
    .add_layer(summary.to_error_layer(id="label-errors"))
  println(report.to_html_report())
}
