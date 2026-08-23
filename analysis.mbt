///|
pub(all) struct Detection {
  id : String
  rect : Rect
  label : String
  score : Double
} derive(Debug, ToJson)

///|
pub fn Detection::new(
  id~ : String,
  rect~ : Rect,
  label~ : String,
  score? : Double = 1.0,
) -> Detection {
  { id, rect, label, score }
}

///|
pub(all) enum MatchKind {
  TruePositive
  FalsePositive
  FalseNegative
  LabelMismatch
} derive(Debug, ToJson)

///|
pub(all) struct MatchRecord {
  kind : MatchKind
  expected : Detection?
  actual : Detection?
  iou : Double
} derive(Debug, ToJson)

///|
pub fn MatchRecord::is_error(self : MatchRecord) -> Bool {
  match self.kind {
    TruePositive => false
    _ => true
  }
}

///|
pub(all) struct MatchSummary {
  records : Array[MatchRecord]
  true_positive : Int
  false_positive : Int
  false_negative : Int
  label_mismatch : Int
} derive(Debug, ToJson)

///|
pub fn MatchSummary::error_count(self : MatchSummary) -> Int {
  self.false_positive + self.false_negative + self.label_mismatch
}

///|
pub fn MatchSummary::precision(self : MatchSummary) -> Double {
  let denom = self.true_positive + self.false_positive + self.label_mismatch
  if denom == 0 {
    0.0
  } else {
    self.true_positive.to_double() / denom.to_double()
  }
}

///|
pub fn MatchSummary::recall(self : MatchSummary) -> Double {
  let denom = self.true_positive + self.false_negative + self.label_mismatch
  if denom == 0 {
    0.0
  } else {
    self.true_positive.to_double() / denom.to_double()
  }
}

///|
pub fn compare_detections(
  expected : Array[Detection],
  actual : Array[Detection],
  iou_threshold? : Double = 0.5,
) -> MatchSummary {
  let used_actual = Array::make(actual.length(), false)
  let records : Array[MatchRecord] = []
  let mut true_positive = 0
  let mut false_negative = 0
  let mut label_mismatch = 0
  for exp in expected {
    let candidate = best_unused_match(exp, actual, used_actual, iou_threshold)
    match candidate {
      None => {
        false_negative += 1
        records.push({
          kind: FalseNegative,
          expected: Some(exp),
          actual: None,
          iou: 0.0,
        })
      }
      Some((index, act, iou)) => {
        used_actual[index] = true
        if exp.label == act.label {
          true_positive += 1
          records.push({
            kind: TruePositive,
            expected: Some(exp),
            actual: Some(act),
            iou,
          })
        } else {
          label_mismatch += 1
          records.push({
            kind: LabelMismatch,
            expected: Some(exp),
            actual: Some(act),
            iou,
          })
        }
      }
    }
  }
  for index, act in actual {
    if !used_actual[index] {
      records.push({
        kind: FalsePositive,
        expected: None,
        actual: Some(act),
        iou: 0.0,
      })
    }
  }
  let false_positive = records.count_if(record => record.kind is FalsePositive)
  { records, true_positive, false_positive, false_negative, label_mismatch }
}

///|
fn best_unused_match(
  expected : Detection,
  actual : Array[Detection],
  used_actual : Array[Bool],
  iou_threshold : Double,
) -> (Int, Detection, Double)? {
  let mut best : (Int, Detection, Double)? = None
  for index, candidate in actual {
    if !used_actual[index] {
      let score = expected.rect.iou(candidate.rect)
      if score > 0.0 && score >= iou_threshold {
        match best {
          None => best = Some((index, candidate, score))
          Some((_, _, best_score)) =>
            if score > best_score {
              best = Some((index, candidate, score))
            }
        }
      }
    }
  }
  best
}

///|
pub fn MatchSummary::to_error_layer(
  self : MatchSummary,
  id? : String = "errors",
) -> Layer {
  let mut layer = Layer::new(id~)
  for record in self.records {
    match record.kind {
      TruePositive => ()
      FalseNegative =>
        match record.expected {
          Some(exp) =>
            layer = layer.add(
              ErrorRegion(
                rect=exp.rect,
                expected=exp.label,
                actual="missing",
                severity=1.0,
              ),
            )
          None => ()
        }
      FalsePositive =>
        match record.actual {
          Some(act) =>
            layer = layer.add(
              ErrorRegion(
                rect=act.rect,
                expected="none",
                actual=act.label,
                severity=0.7,
              ),
            )
          None => ()
        }
      LabelMismatch =>
        match (record.expected, record.actual) {
          (Some(exp), Some(act)) =>
            layer = layer.add(
              ErrorRegion(
                rect=act.rect,
                expected=exp.label,
                actual=act.label,
                severity=0.85,
              ),
            )
          _ => ()
        }
    }
  }
  layer
}
