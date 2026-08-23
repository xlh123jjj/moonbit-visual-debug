///|
fn metric_detection(
  id : String,
  label : String,
  x? : Double = 0.0,
  score? : Double = 1.0,
) -> Detection {
  Detection::new(
    id~,
    label~,
    score~,
    rect=Rect::new(x~, y=0.0, width=10.0, height=10.0),
  )
}

///|
test "metrics account for label mismatch in both affected classes" {
  let result = evaluate_detections([metric_detection("gt", "cat")], [
    metric_detection("pred", "dog"),
  ]).unwrap()
  debug_inspect(
    result.classes.map(summary => summary.label),
    content="[\"cat\", \"dog\"]",
  )
  inspect(result.classes[0].false_negative, content="1")
  inspect(result.classes[1].false_positive, content="1")
  inspect(result.confusion.cells[0].count, content="1")
  inspect(result.micro.precision, content="0")
  inspect(result.micro.recall, content="0")
}

///|
test "aggregate mismatch counts each matched wrong label once" {
  let result = evaluate_detections([metric_detection("gt", "cat")], [
    metric_detection("pred", "dog"),
  ]).unwrap()
  inspect(result.classes[0].label_mismatch, content="1")
  inspect(result.classes[1].label_mismatch, content="1")
  inspect(result.micro.label_mismatch, content="1")
  inspect(result.macro_average.label_mismatch, content="1")
}

///|
test "metrics define zero-valued aggregates for empty inputs" {
  let result = evaluate_detections([], []).unwrap()
  inspect(result.classes.length(), content="0")
  inspect(result.confusion.cells.length(), content="0")
  inspect(result.micro.f1, content="0")
  inspect(result.macro_average.f1, content="0")
}

///|
test "IoU sweeps sort caller thresholds and reveal stricter matching" {
  let results = sweep_iou_thresholds(
    [metric_detection("gt", "part")],
    [metric_detection("pred", "part", x=2.5)],
    [0.7, 0.5],
  ).unwrap()
  debug_inspect(
    results.map(result => result.iou_threshold),
    content="[0.5, 0.7]",
  )
  inspect(results[0].micro.true_positive, content="1")
  inspect(results[1].micro.false_negative, content="1")
}

///|
test "macro scores do not hide unsupported class performance" {
  let result = evaluate_detections(
    [
      metric_detection("cat-gt", "cat"),
      metric_detection("dog-gt", "dog", x=30.0),
    ],
    [metric_detection("cat-pred", "cat")],
  ).unwrap()
  inspect(result.micro.f1 > result.macro_average.f1, content="true")
  inspect(result.macro_average.precision, content="0.5")
}

///|
test "ties retain input match order while class labels are sorted" {
  let result = evaluate_detections([metric_detection("gt", "zebra")], [
    metric_detection("first", "zebra"),
    metric_detection("second", "aardvark"),
  ]).unwrap()
  debug_inspect(
    result.classes.map(summary => summary.label),
    content="[\"aardvark\", \"zebra\"]",
  )
  match result.matches.records[0].actual {
    Some(actual) => inspect(actual.id, content="first")
    None => fail("expected a stable match")
  }
}

///|
test "metric text renderers escape HTML and CSV fields" {
  let result = evaluate_detections([metric_detection("gt", "<cat&\"\n")], [
    metric_detection("pred", "<cat&\"\n"),
  ]).unwrap()
  let html = result.to_html_table()
  let csv = result.to_csv()
  inspect(html.contains("&lt;cat&amp;&quot;"), content="true")
  inspect(!html.contains("<cat&\""), content="true")
  inspect(csv.contains("\"<cat&\"\"\n\""), content="true")
}

///|
test "metrics reject invalid thresholds and detection scores" {
  match evaluate_detections([], [], iou_threshold=1.1) {
    Err(InvalidIouThreshold(value=1.1)) => ()
    _ => fail("expected an IoU validation error")
  }
  match evaluate_detections([], [], score_threshold=-0.1) {
    Err(InvalidScoreThreshold(value=-0.1)) => ()
    _ => fail("expected a score threshold validation error")
  }
  match evaluate_detections([], [metric_detection("bad", "cat", score=-0.1)]) {
    Err(InvalidDetectionScore(id="bad", score=-0.1)) => ()
    _ => fail("expected a detection-score validation error")
  }
}
