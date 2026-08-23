///|
/// Input validation failures for detection metrics.
pub(all) enum MetricsError {
  InvalidIouThreshold(value~ : Double)
  InvalidScoreThreshold(value~ : Double)
  InvalidDetectionScore(id~ : String, score~ : Double)
  EmptyThresholdSweep
} derive(Debug, ToJson)

///|
/// Counts and derived scores for a single class or aggregate. Aggregate
/// `label_mismatch` counts each mismatched match record once.
pub(all) struct AggregateMetrics {
  true_positive : Int
  false_positive : Int
  false_negative : Int
  label_mismatch : Int
  precision : Double
  recall : Double
  f1 : Double
} derive(Debug, ToJson)

///|
/// Per-label metrics. `support` is the number of expected detections. A label
/// mismatch contributes a false negative to its expected class and a false
/// positive to its actual class, so it is visible in both affected class rows.
pub(all) struct ClassMetrics {
  label : String
  true_positive : Int
  false_positive : Int
  false_negative : Int
  label_mismatch : Int
  support : Int
  precision : Double
  recall : Double
  f1 : Double
} derive(Debug, ToJson)

///|
/// One non-zero, typed cell of a detection confusion matrix. `None` denotes
/// an unmatched expected or actual detection.
pub(all) struct ConfusionCell {
  expected_label : String?
  actual_label : String?
  count : Int
} derive(Debug, ToJson)

///|
/// A stable, sparse confusion matrix ordered by expected label then actual label.
pub(all) struct ConfusionMatrix {
  labels : Array[String]
  cells : Array[ConfusionCell]
} derive(Debug, ToJson)

///|
/// A deterministic metrics report for one IoU and score threshold pair.
/// Classes are the lexical union of expected and score-filtered actual labels.
/// Macro scores average those class rows; precision, recall, and F1 use `0.0`
/// whenever their denominator is zero.
pub(all) struct DetectionMetrics {
  iou_threshold : Double
  score_threshold : Double
  matches : MatchSummary
  classes : Array[ClassMetrics]
  confusion : ConfusionMatrix
  micro : AggregateMetrics
  macro_average : AggregateMetrics
} derive(Debug, ToJson)

///|
/// Evaluates detections after filtering actual detections whose score is below
/// `score_threshold`. All thresholds and detection scores must be finite values
/// in the inclusive range `[0, 1]`.
pub fn evaluate_detections(
  expected : Array[Detection],
  actual : Array[Detection],
  iou_threshold? : Double = 0.5,
  score_threshold? : Double = 0.0,
) -> Result[DetectionMetrics, MetricsError] {
  match
    validate_metric_inputs(expected, actual, iou_threshold, score_threshold) {
    Err(error) => Err(error)
    Ok(_) => {
      let filtered_actual = actual.filter(detection => {
        detection.score >= score_threshold
      })
      let matches = compare_detections(
        expected,
        filtered_actual,
        iou_threshold~,
      )
      let labels = metric_labels(matches)
      let classes = class_metrics(matches, labels)
      let confusion = confusion_matrix(matches, labels)
      let micro = aggregate_classes(classes, matches.label_mismatch)
      let macro_average = macro_metrics(classes, matches.label_mismatch)
      Ok({
        iou_threshold,
        score_threshold,
        matches,
        classes,
        confusion,
        micro,
        macro_average,
      })
    }
  }
}

///|
/// Runs the same score-filtered evaluation at every caller-supplied IoU
/// threshold. Results are sorted from the loosest to strictest threshold.
pub fn sweep_iou_thresholds(
  expected : Array[Detection],
  actual : Array[Detection],
  thresholds : Array[Double],
  score_threshold? : Double = 0.0,
) -> Result[Array[DetectionMetrics], MetricsError] {
  if thresholds.length() == 0 {
    Err(EmptyThresholdSweep)
  } else {
    match validate_metric_inputs(expected, actual, 0.0, score_threshold) {
      Err(error) => Err(error)
      Ok(_) => {
        let ordered = thresholds.copy()
        ordered.sort()
        let reports : Array[DetectionMetrics] = []
        for threshold in ordered {
          if !valid_metric_value(threshold) {
            return Err(InvalidIouThreshold(value=threshold))
          }
          match
            evaluate_detections(
              expected,
              actual,
              iou_threshold=threshold,
              score_threshold~,
            ) {
            Ok(report) => reports.push(report)
            Err(error) => return Err(error)
          }
        }
        Ok(reports)
      }
    }
  }
}

///|
/// Renders a compact escaped HTML table suitable for CI artifacts.
pub fn DetectionMetrics::to_html_table(self : DetectionMetrics) -> String {
  let out = StringBuilder()
  out.write_string(
    "<table><thead><tr><th>label</th><th>tp</th><th>fp</th><th>fn</th><th>precision</th><th>recall</th><th>f1</th><th>support</th></tr></thead><tbody>",
  )
  for summary in self.classes {
    out.write_string("<tr><td>")
    out.write_string(escape_metrics_html(summary.label))
    out.write_string("</td><td>")
    out.write_string(summary.true_positive.to_string())
    out.write_string("</td><td>")
    out.write_string(summary.false_positive.to_string())
    out.write_string("</td><td>")
    out.write_string(summary.false_negative.to_string())
    out.write_string("</td><td>")
    out.write_string(summary.precision.to_string())
    out.write_string("</td><td>")
    out.write_string(summary.recall.to_string())
    out.write_string("</td><td>")
    out.write_string(summary.f1.to_string())
    out.write_string("</td><td>")
    out.write_string(summary.support.to_string())
    out.write_string("</td></tr>")
  }
  out.write_string("</tbody></table>")
  out.to_string()
}

///|
/// Renders stable LF-delimited CSV class metrics text for CI logs and artifacts.
pub fn DetectionMetrics::to_csv(self : DetectionMetrics) -> String {
  let lines : Array[String] = [
    "label,true_positive,false_positive,false_negative,label_mismatch,precision,recall,f1,support",
  ]
  for summary in self.classes {
    lines.push(
      "\{escape_metrics_csv(summary.label)},\{summary.true_positive},\{summary.false_positive},\{summary.false_negative},\{summary.label_mismatch},\{summary.precision},\{summary.recall},\{summary.f1},\{summary.support}",
    )
  }
  lines.join("\n")
}

///|
fn validate_metric_inputs(
  expected : Array[Detection],
  actual : Array[Detection],
  iou_threshold : Double,
  score_threshold : Double,
) -> Result[Unit, MetricsError] {
  if !valid_metric_value(iou_threshold) {
    Err(InvalidIouThreshold(value=iou_threshold))
  } else if !valid_metric_value(score_threshold) {
    Err(InvalidScoreThreshold(value=score_threshold))
  } else {
    match invalid_detection_score(expected) {
      Some((id, score)) => Err(InvalidDetectionScore(id~, score~))
      None =>
        match invalid_detection_score(actual) {
          Some((id, score)) => Err(InvalidDetectionScore(id~, score~))
          None => Ok(())
        }
    }
  }
}

///|
fn valid_metric_value(value : Double) -> Bool {
  !value.is_nan() && !value.is_inf() && value >= 0.0 && value <= 1.0
}

///|
fn invalid_detection_score(detections : Array[Detection]) -> (String, Double)? {
  for detection in detections {
    if !valid_metric_value(detection.score) {
      return Some((detection.id, detection.score))
    }
  }
  None
}

///|
fn metric_labels(matches : MatchSummary) -> Array[String] {
  let labels : Array[String] = []
  for record in matches.records {
    match record.expected {
      Some(detection) =>
        if !labels.contains(detection.label) {
          labels.push(detection.label)
        }
      None => ()
    }
    match record.actual {
      Some(detection) =>
        if !labels.contains(detection.label) {
          labels.push(detection.label)
        }
      None => ()
    }
  }
  labels.sort_by(String::lexical_compare)
  labels
}

///|
fn class_metrics(
  matches : MatchSummary,
  labels : Array[String],
) -> Array[ClassMetrics] {
  let summaries : Array[ClassMetrics] = []
  for label in labels {
    let mut true_positive = 0
    let mut false_positive = 0
    let mut false_negative = 0
    let mut label_mismatch = 0
    for record in matches.records {
      match record.kind {
        TruePositive =>
          match record.expected {
            Some(expected) => if expected.label == label { true_positive += 1 }
            None => ()
          }
        FalsePositive =>
          match record.actual {
            Some(actual) => if actual.label == label { false_positive += 1 }
            None => ()
          }
        FalseNegative =>
          match record.expected {
            Some(expected) => if expected.label == label { false_negative += 1 }
            None => ()
          }
        LabelMismatch =>
          match (record.expected, record.actual) {
            (Some(expected), Some(actual)) => {
              if expected.label == label {
                false_negative += 1
                label_mismatch += 1
              }
              if actual.label == label {
                false_positive += 1
                label_mismatch += 1
              }
            }
            _ => ()
          }
      }
    }
    let aggregate = metric_scores(
      true_positive, false_positive, false_negative, label_mismatch,
    )
    summaries.push({
      label,
      true_positive,
      false_positive,
      false_negative,
      label_mismatch,
      support: true_positive + false_negative,
      precision: aggregate.precision,
      recall: aggregate.recall,
      f1: aggregate.f1,
    })
  }
  summaries
}

///|
fn confusion_matrix(
  matches : MatchSummary,
  labels : Array[String],
) -> ConfusionMatrix {
  let cells : Array[ConfusionCell] = []
  for expected_label in labels {
    for actual_label in labels {
      let count = matches.records.count_if(record => {
        has_label(record.expected, expected_label) &&
        has_label(record.actual, actual_label)
      })
      if count > 0 {
        cells.push({
          expected_label: Some(expected_label),
          actual_label: Some(actual_label),
          count,
        })
      }
    }
    let missing = matches.records.count_if(record => {
      has_label(record.expected, expected_label) && record.actual is None
    })
    if missing > 0 {
      cells.push({
        expected_label: Some(expected_label),
        actual_label: None,
        count: missing,
      })
    }
  }
  for actual_label in labels {
    let extra = matches.records.count_if(record => {
      record.expected is None && has_label(record.actual, actual_label)
    })
    if extra > 0 {
      cells.push({
        expected_label: None,
        actual_label: Some(actual_label),
        count: extra,
      })
    }
  }
  { labels, cells }
}

///|
fn aggregate_classes(
  classes : Array[ClassMetrics],
  label_mismatch : Int,
) -> AggregateMetrics {
  let mut true_positive = 0
  let mut false_positive = 0
  let mut false_negative = 0
  for summary in classes {
    true_positive += summary.true_positive
    false_positive += summary.false_positive
    false_negative += summary.false_negative
  }
  metric_scores(true_positive, false_positive, false_negative, label_mismatch)
}

///|
fn macro_metrics(
  classes : Array[ClassMetrics],
  label_mismatch : Int,
) -> AggregateMetrics {
  if classes.length() == 0 {
    metric_scores(0, 0, 0, label_mismatch)
  } else {
    let aggregate = aggregate_classes(classes, label_mismatch)
    let mut precision = 0.0
    let mut recall = 0.0
    let mut f1 = 0.0
    for summary in classes {
      precision += summary.precision
      recall += summary.recall
      f1 += summary.f1
    }
    let count = classes.length().to_double()
    {
      ..aggregate,
      precision: precision / count,
      recall: recall / count,
      f1: f1 / count,
    }
  }
}

///|
fn metric_scores(
  true_positive : Int,
  false_positive : Int,
  false_negative : Int,
  label_mismatch : Int,
) -> AggregateMetrics {
  let predicted = true_positive + false_positive
  let expected = true_positive + false_negative
  let precision = if predicted == 0 {
    0.0
  } else {
    true_positive.to_double() / predicted.to_double()
  }
  let recall = if expected == 0 {
    0.0
  } else {
    true_positive.to_double() / expected.to_double()
  }
  let f1 = if precision + recall == 0.0 {
    0.0
  } else {
    2.0 * precision * recall / (precision + recall)
  }
  {
    true_positive,
    false_positive,
    false_negative,
    label_mismatch,
    precision,
    recall,
    f1,
  }
}

///|
fn has_label(detection : Detection?, label : String) -> Bool {
  match detection {
    Some(value) => value.label == label
    None => false
  }
}

///|
fn escape_metrics_html(value : String) -> String {
  value
  .replace(old="&", new="&amp;")
  .replace(old="<", new="&lt;")
  .replace(old=">", new="&gt;")
  .replace(old="\"", new="&quot;")
  .replace(old="'", new="&#39;")
}

///|
fn escape_metrics_csv(value : String) -> String {
  let escaped = value.replace(old="\"", new="\"\"")
  "\"\{escaped}\""
}
