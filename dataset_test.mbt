///|
test "COCO annotations become named detections" {
  let source =
    #|{
    #|  "categories": [{"id": 3, "name": "widget"}],
    #|  "annotations": [
    #|    {"id": 11, "image_id": 4, "category_id": 3,
    #|     "bbox": [12.5, 8.0, 40.0, 24.0]}
    #|  ]
    #|}
  match CocoDataset::from_json(source) {
    Ok(dataset) => {
      let detections = dataset.to_detections()
      inspect(detections.length(), content="1")
      inspect(detections[0].id, content="coco-11")
      inspect(detections[0].label, content="widget")
      inspect(detections[0].rect.x, content="12.5")
      inspect(detections[0].rect.height, content="24")
      inspect(detections[0].score, content="1")
    }
    Err(_) => fail("expected a valid COCO payload")
  }
}

///|
test "COCO conversion uses a stable fallback label for unknown categories" {
  let source =
    #|{"annotations":[{"id":1,"image_id":2,"category_id":99,
    #|"bbox":[0,0,5,6]}]}
  match CocoDataset::from_json(source) {
    Ok(dataset) =>
      inspect(dataset.to_detections()[0].label, content="category-99")
    Err(_) => fail("an unknown category must not discard an annotation")
  }
}

///|
test "COCO conversion rejects malformed annotation bounds" {
  let source =
    #|{"annotations":[{"id":1,"image_id":2,"category_id":3,
    #|"bbox":[0,0,0,6]}]}
  match CocoDataset::from_json(source) {
    Ok(_) => fail("zero-width bounding boxes are invalid")
    Err(_) => ()
  }
}

///|
test "COCO output round-trips categories and annotations" {
  let original = CocoDataset::new(
    categories=[CocoCategory::new(id=5, name="gadget")],
    annotations=[
      CocoAnnotation::new(
        id=8,
        image_id=2,
        category_id=5,
        bbox=Rect::new(x=1.0, y=2.0, width=3.0, height=4.0),
      ),
    ],
  )
  match original.to_coco_json() {
    Err(_) => fail("valid COCO data must be exportable")
    Ok(source) =>
      match CocoDataset::from_json(source) {
        Ok(decoded) => {
          inspect(decoded.categories[0].name, content="gadget")
          inspect(decoded.annotations[0].bbox.width, content="3")
          debug_inspect(decoded.annotations[0].area, content="Some(12)")
        }
        Err(_) => fail("generated COCO must be readable")
      }
  }
}

///|
test "COCO parser rejects duplicate category ids at the later category" {
  let source =
    #|{
    #|  "categories": [
    #|    {"id": 3, "name": "widget"},
    #|    {"id": 3, "name": "duplicate"}
    #|  ],
    #|  "annotations": []
    #|}
  match CocoDataset::from_json(source) {
    Err(InvalidField(path~, message~)) => {
      inspect(path, content="categories[1].id")
      inspect(message, content="duplicate category id")
    }
    _ => fail("duplicate category ids must be rejected")
  }
}

///|
test "COCO parser rejects duplicate annotation ids at the later annotation" {
  let source =
    #|{
    #|  "annotations": [
    #|    {"id": 7, "image_id": 1, "category_id": 2, "bbox": [0, 0, 4, 5]},
    #|    {"id": 7, "image_id": 2, "category_id": 2, "bbox": [1, 1, 4, 5]}
    #|  ]
    #|}
  match CocoDataset::from_json(source) {
    Err(InvalidField(path~, message~)) => {
      inspect(path, content="annotations[1].id")
      inspect(message, content="duplicate annotation id")
    }
    _ => fail("duplicate annotation ids must be rejected")
  }
}

///|
test "COCO export does not emit a programmatically constructed duplicate id" {
  let dataset = CocoDataset::new(
    categories=[
      CocoCategory::new(id=3, name="widget"),
      CocoCategory::new(id=3, name="duplicate"),
    ],
    annotations=[],
  )
  match dataset.to_coco_json() {
    Err(InvalidField(path~, message~)) => {
      inspect(path, content="categories[1].id")
      inspect(message, content="duplicate category id")
    }
    _ => fail("export must not emit COCO the parser rejects")
  }
}

///|
test "COCO export rejects non-finite bounding-box coordinates" {
  let dataset = CocoDataset::new(annotations=[
    CocoAnnotation::new(
      id=7,
      image_id=1,
      category_id=2,
      bbox=Rect::new(x=0.0 / 0.0, y=0.0, width=4.0, height=5.0),
    ),
  ])
  match dataset.to_coco_json() {
    Err(InvalidField(path~, message~)) => {
      inspect(path, content="annotations[0].bbox")
      inspect(message, content="must contain finite numbers")
    }
    _ => fail("export must not emit non-JSON number values")
  }
}

///|
test "COCO results round-trip a finite score" {
  let results = CocoResults::new(results=[
    CocoResult::new(
      image_id=1,
      category_id=2,
      bbox=Rect::new(x=1.0, y=2.0, width=4.0, height=5.0),
      score=0.75,
    ),
  ])
  match results.to_coco_json() {
    Err(_) => fail("a finite score must be exportable")
    Ok(source) =>
      match CocoResults::from_json(source) {
        Ok(decoded) => inspect(decoded.results[0].score, content="0.75")
        Err(_) => fail("exported finite scores must be readable")
      }
  }
}

///|
test "COCO export rejects a programmatically constructed duplicate annotation id" {
  let dataset = CocoDataset::new(annotations=[
    CocoAnnotation::new(
      id=7,
      image_id=1,
      category_id=2,
      bbox=Rect::new(x=0.0, y=0.0, width=4.0, height=5.0),
    ),
    CocoAnnotation::new(
      id=7,
      image_id=2,
      category_id=2,
      bbox=Rect::new(x=1.0, y=1.0, width=4.0, height=5.0),
    ),
  ])
  match dataset.to_coco_json() {
    Err(InvalidField(path~, message~)) => {
      inspect(path, content="annotations[1].id")
      inspect(message, content="duplicate annotation id")
    }
    _ => fail("export must not emit duplicate annotation ids")
  }
}

///|
test "COCO export rejects a nonpositive constructed bounding box" {
  let dataset = CocoDataset::new(annotations=[
    CocoAnnotation::new(
      id=7,
      image_id=1,
      category_id=2,
      bbox=Rect::new(x=0.0, y=0.0, width=0.0, height=5.0),
    ),
  ])
  match dataset.to_coco_json() {
    Err(InvalidField(path~, message~)) => {
      inspect(path, content="annotations[0].bbox")
      inspect(message, content="width and height must be positive")
    }
    _ => fail("export must not emit nonpositive bounding boxes")
  }
}

///|
test "COCO parser rejects a non-finite score token" {
  let source =
    #|{"annotations":[{"id":7,"image_id":1,"category_id":2,
    #|"bbox":[0,0,4,5],"score":NaN}]}
  match CocoDataset::from_json(source) {
    Err(InvalidJson(_)) => ()
    _ => fail("non-finite score tokens are not valid JSON")
  }
}

///|
test "COCO dataset round-trips standard image and annotation metadata" {
  let original = CocoDataset::new(
    categories=[CocoCategory::new(id=5, name="gadget")],
    images=[CocoImage::new(id=2, width=640, height=480, file_name="gadget.png")],
    annotations=[
      CocoAnnotation::new(
        id=8,
        image_id=2,
        category_id=5,
        bbox=Rect::new(x=1.0, y=2.0, width=3.0, height=4.0),
        area=12.0,
        iscrowd=0,
      ),
    ],
  )
  match original.to_coco_json() {
    Err(_) => fail("valid standard COCO data must be exportable")
    Ok(source) =>
      match CocoDataset::from_json(source) {
        Ok(decoded) => {
          inspect(decoded.images[0].width, content="640")
          debug_inspect(
            decoded.images[0].file_name,
            content="Some(\"gadget.png\")",
          )
          debug_inspect(decoded.annotations[0].area, content="Some(12)")
          debug_inspect(decoded.annotations[0].iscrowd, content="Some(0)")
        }
        Err(_) => fail("generated standard COCO must be readable")
      }
  }
}

///|
test "COCO result arrays round-trip finite scores separately from annotations" {
  let original = CocoResults::new(results=[
    CocoResult::new(
      image_id=2,
      category_id=5,
      bbox=Rect::new(x=1.0, y=2.0, width=3.0, height=4.0),
      score=0.75,
    ),
  ])
  match original.to_coco_json() {
    Err(_) => fail("finite COCO results must be exportable")
    Ok(source) => {
      assert_true(source.has_prefix("["))
      match CocoResults::from_json(source) {
        Ok(decoded) => inspect(decoded.results[0].score, content="0.75")
        Err(_) => fail("generated COCO results must be readable")
      }
    }
  }
}

///|
test "COCO checked construction rejects duplicate and nonpositive identifiers" {
  let duplicate_images = CocoDataset::try_new(annotations=[], images=[
    CocoImage::new(id=1, width=10, height=10),
    CocoImage::new(id=1, width=10, height=10),
  ])
  let nonpositive_annotation = CocoDataset::try_new(annotations=[
    CocoAnnotation::new(
      id=0,
      image_id=1,
      category_id=2,
      bbox=Rect::new(x=0.0, y=0.0, width=4.0, height=5.0),
    ),
  ])
  match (duplicate_images, nonpositive_annotation) {
    (
      Err(InvalidField(path=duplicate_path, ..)),
      Err(InvalidField(path=zero_path, ..)),
    ) => {
      inspect(duplicate_path, content="images[1].id")
      inspect(zero_path, content="annotations[0].id")
    }
    _ => fail("invalid IDs must be rejected by checked construction")
  }
}

///|
test "COCO checked construction rejects direct nonfinite values" {
  let invalid_area = CocoDataset::try_new(annotations=[
    CocoAnnotation::new(
      id=1,
      image_id=1,
      category_id=1,
      bbox=Rect::new(x=0.0, y=0.0, width=4.0, height=5.0),
      area=0.0 / 0.0,
    ),
  ])
  let invalid_score = CocoResults::try_new(results=[
    CocoResult::new(
      image_id=1,
      category_id=1,
      bbox=Rect::new(x=0.0, y=0.0, width=4.0, height=5.0),
      score=1.0 / 0.0,
    ),
  ])
  match (invalid_area, invalid_score) {
    (
      Err(InvalidField(path=area_path, ..)),
      Err(InvalidField(path=score_path, ..)),
    ) => {
      inspect(area_path, content="annotations[0].area")
      inspect(score_path, content="results[0].score")
    }
    _ => fail("NaN and infinity must never be serialized as JSON numbers")
  }
}

///|
test "COCO parser rejects exponent overflow when it represents infinity" {
  let source =
    #|[{"image_id":1,"category_id":1,"bbox":[0,0,4,5],"score":1e999}]
  match CocoResults::from_json(source) {
    Err(_) => ()
    Ok(_) => fail("an overflowed JSON number must not become a COCO score")
  }
}
