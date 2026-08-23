///|
test "detection matching never treats zero IoU as a match" {
  let expected = [
    Detection::new(
      id="gt",
      rect=Rect::new(x=0.0, y=0.0, width=10.0, height=10.0),
      label="part",
    ),
  ]
  let actual = [
    Detection::new(
      id="pred",
      rect=Rect::new(x=20.0, y=20.0, width=10.0, height=10.0),
      label="part",
    ),
  ]
  let summary = compare_detections(expected, actual, iou_threshold=0.0)
  inspect(summary.true_positive, content="0")
  inspect(summary.false_negative, content="1")
  inspect(summary.false_positive, content="1")
}

///|
test "detection matching accepts an exact positive IoU threshold" {
  let expected = [
    Detection::new(
      id="gt",
      rect=Rect::new(x=0.0, y=0.0, width=10.0, height=10.0),
      label="part",
    ),
  ]
  let actual = [
    Detection::new(
      id="pred",
      rect=Rect::new(x=0.0, y=0.0, width=10.0, height=10.0),
      label="part",
    ),
  ]
  let summary = compare_detections(expected, actual, iou_threshold=1.0)
  inspect(summary.true_positive, content="1")
  inspect(summary.error_count(), content="0")
}
