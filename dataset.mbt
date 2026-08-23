///|
pub(all) enum CocoError {
  InvalidJson(message~ : String)
  InvalidField(path~ : String, message~ : String)
} derive(Debug, ToJson)

///|
pub(all) struct CocoCategory {
  id : Int
  name : String
} derive(Debug, ToJson)

///|
pub fn CocoCategory::new(id~ : Int, name~ : String) -> CocoCategory {
  { id, name }
}

///|
/// Metadata for one image in a COCO dataset. `file_name` is optional because
/// COCO image assets can be addressed outside the annotation file.
pub(all) struct CocoImage {
  id : Int
  width : Int
  height : Int
  file_name : String?
} derive(Debug, ToJson)

///|
/// Creates a COCO image record. Use `CocoDataset::try_new` to validate it.
pub fn CocoImage::new(
  id~ : Int,
  width~ : Int,
  height~ : Int,
  file_name? : String,
) -> CocoImage {
  { id, width, height, file_name }
}

///|
/// One ground-truth bounding-box annotation in a COCO dataset. Scores belong
/// in `CocoResult` records, not annotations.
pub(all) struct CocoAnnotation {
  id : Int
  image_id : Int
  category_id : Int
  bbox : Rect
  area : Double?
  iscrowd : Int?
} derive(Debug, ToJson)

///|
/// Creates a COCO annotation. Omitted `area` is derived during export;
/// supplied `iscrowd` must be `0` or `1`.
pub fn CocoAnnotation::new(
  id~ : Int,
  image_id~ : Int,
  category_id~ : Int,
  bbox~ : Rect,
  area? : Double,
  iscrowd? : Int,
) -> CocoAnnotation {
  { id, image_id, category_id, bbox, area, iscrowd }
}

///|
/// One scored COCO detection result. Standard COCO result JSON is a root
/// array of these records rather than a dataset `annotations` array.
pub(all) struct CocoResult {
  image_id : Int
  category_id : Int
  bbox : Rect
  score : Double
} derive(Debug, ToJson)

///|
/// Creates a scored COCO result. Use `CocoResults::try_new` to validate it.
pub fn CocoResult::new(
  image_id~ : Int,
  category_id~ : Int,
  bbox~ : Rect,
  score~ : Double,
) -> CocoResult {
  { image_id, category_id, bbox, score }
}

///|
/// A COCO ground-truth object with image, category, and annotation arrays.
/// Legacy annotation-only objects without `images` remain accepted.
pub(all) struct CocoDataset {
  images : Array[CocoImage]
  categories : Array[CocoCategory]
  annotations : Array[CocoAnnotation]
} derive(Debug, ToJson)

///|
/// Creates a COCO dataset without validation for convenient literals. Prefer
/// `CocoDataset::try_new` when constructed input can be invalid.
pub fn CocoDataset::new(
  annotations~ : Array[CocoAnnotation],
  categories? : Array[CocoCategory] = [],
  images? : Array[CocoImage] = [],
) -> CocoDataset {
  { images, categories, annotations }
}

///|
/// Creates and validates a COCO dataset, returning a field-specific error.
pub fn CocoDataset::try_new(
  annotations~ : Array[CocoAnnotation],
  categories? : Array[CocoCategory] = [],
  images? : Array[CocoImage] = [],
) -> Result[CocoDataset, CocoError] {
  let dataset = CocoDataset::new(annotations~, categories~, images~)
  match dataset.validate() {
    Ok(_) => Ok(dataset)
    Err(error) => Err(error)
  }
}

///|
/// A root-array COCO prediction/result payload.
pub(all) struct CocoResults {
  results : Array[CocoResult]
} derive(Debug, ToJson)

///|
/// Creates COCO results without validation for convenient literals. Prefer
/// `CocoResults::try_new` when constructed input can be invalid.
pub fn CocoResults::new(results~ : Array[CocoResult]) -> CocoResults {
  { results, }
}

///|
/// Creates and validates a COCO result payload, including finite scores.
pub fn CocoResults::try_new(
  results~ : Array[CocoResult],
) -> Result[CocoResults, CocoError] {
  let payload = CocoResults::new(results~)
  match payload.validate() {
    Ok(_) => Ok(payload)
    Err(error) => Err(error)
  }
}

///|
/// Parses a COCO ground-truth object. `annotations` is required; `images` and
/// `categories` may be omitted only for legacy annotation-only input.
pub fn CocoDataset::from_json(
  source : String,
) -> Result[CocoDataset, CocoError] {
  try @json.parse(source) catch {
    error => Err(InvalidJson(message=error.to_string()))
  } noraise {
    value => parse_coco_dataset(value)
  }
}

///|
/// Parses a standard root-array COCO result payload. Each object must contain
/// `image_id`, `category_id`, `bbox`, and a finite `score`.
pub fn CocoResults::from_json(
  source : String,
) -> Result[CocoResults, CocoError] {
  try @json.parse(source) catch {
    error => Err(InvalidJson(message=error.to_string()))
  } noraise {
    value => parse_coco_results(value)
  }
}

///|
/// Validates COCO IDs, image dimensions, finite boxes, areas, crowd flags,
/// and referential image IDs in linear time.
pub fn CocoDataset::validate(self : CocoDataset) -> Result[Unit, CocoError] {
  let category_ids : Set[Int] = Set([])
  for index, category in self.categories {
    if category.id <= 0 {
      return Err(
        InvalidField(path="categories[\{index}].id", message="must be positive"),
      )
    }
    if !category_ids.add_and_check(category.id) {
      return Err(
        InvalidField(
          path="categories[\{index}].id",
          message="duplicate category id",
        ),
      )
    }
  }
  let image_ids : Set[Int] = Set([])
  for index, image in self.images {
    if image.id <= 0 {
      return Err(
        InvalidField(path="images[\{index}].id", message="must be positive"),
      )
    }
    if !image_ids.add_and_check(image.id) {
      return Err(
        InvalidField(path="images[\{index}].id", message="duplicate image id"),
      )
    }
    if image.width <= 0 || image.height <= 0 {
      return Err(
        InvalidField(
          path="images[\{index}]",
          message="width and height must be positive",
        ),
      )
    }
  }
  let annotation_ids : Set[Int] = Set([])
  for index, annotation in self.annotations {
    let path = "annotations[\{index}]"
    if annotation.id <= 0 {
      return Err(InvalidField(path="\{path}.id", message="must be positive"))
    }
    if annotation.image_id <= 0 {
      return Err(
        InvalidField(path="\{path}.image_id", message="must be positive"),
      )
    }
    if annotation.category_id <= 0 {
      return Err(
        InvalidField(path="\{path}.category_id", message="must be positive"),
      )
    }
    if !annotation_ids.add_and_check(annotation.id) {
      return Err(
        InvalidField(path="\{path}.id", message="duplicate annotation id"),
      )
    }
    match validate_bbox(annotation.bbox, "\{path}.bbox") {
      Ok(_) => ()
      Err(error) => return Err(error)
    }
    match annotation.area {
      Some(area) if !is_finite(area) =>
        return Err(
          InvalidField(path="\{path}.area", message="must be a finite number"),
        )
      Some(area) if area < 0.0 =>
        return Err(
          InvalidField(path="\{path}.area", message="must be nonnegative"),
        )
      None if !is_finite(annotation.bbox.width * annotation.bbox.height) =>
        return Err(
          InvalidField(
            path="\{path}.area",
            message="derived area must be finite",
          ),
        )
      _ => ()
    }
    match annotation.iscrowd {
      Some(0 | 1) | None => ()
      Some(_) =>
        return Err(
          InvalidField(path="\{path}.iscrowd", message="must be 0 or 1"),
        )
    }
    if !self.images.is_empty() && !image_ids.contains(annotation.image_id) {
      return Err(
        InvalidField(
          path="\{path}.image_id",
          message="does not reference an image",
        ),
      )
    }
  }
  Ok(())
}

///|
/// Validates every result ID, bounding box, and score in linear time.
pub fn CocoResults::validate(self : CocoResults) -> Result[Unit, CocoError] {
  for index, result in self.results {
    let path = "results[\{index}]"
    if result.image_id <= 0 {
      return Err(
        InvalidField(path="\{path}.image_id", message="must be positive"),
      )
    }
    if result.category_id <= 0 {
      return Err(
        InvalidField(path="\{path}.category_id", message="must be positive"),
      )
    }
    match validate_bbox(result.bbox, "\{path}.bbox") {
      Ok(_) => ()
      Err(error) => return Err(error)
    }
    if !is_finite(result.score) {
      return Err(
        InvalidField(path="\{path}.score", message="must be a finite number"),
      )
    }
  }
  Ok(())
}

///|
/// Serializes this ground-truth dataset as a standard COCO object.
pub fn CocoDataset::to_coco_json(
  self : CocoDataset,
) -> Result[String, CocoError] {
  match self.validate() {
    Err(error) => Err(error)
    Ok(_) =>
      Ok(
        Json::object({
          "images": Json::array(self.images.map(image_to_json)),
          "categories": Json::array(self.categories.map(category_to_json)),
          "annotations": Json::array(self.annotations.map(annotation_to_json)),
        }).stringify(indent=2),
      )
  }
}

///|
/// Serializes these predictions as the standard root-array COCO result format.
pub fn CocoResults::to_coco_json(
  self : CocoResults,
) -> Result[String, CocoError] {
  match self.validate() {
    Err(error) => Err(error)
    Ok(_) =>
      Ok(Json::array(self.results.map(result_to_json)).stringify(indent=2))
  }
}

///|
/// Converts ground-truth annotations into visual-debug detections.
pub fn CocoDataset::to_detections(self : CocoDataset) -> Array[Detection] {
  self.annotations.map(annotation => {
    let mut label = "category-\{annotation.category_id}"
    for category in self.categories {
      if category.id == annotation.category_id {
        label = category.name
      }
    }
    Detection::new(id="coco-\{annotation.id}", rect=annotation.bbox, label~)
  })
}

///|
fn parse_coco_dataset(value : Json) -> Result[CocoDataset, CocoError] {
  match value {
    Object(root) => {
      let categories = optional_array(root, "categories", parse_categories)
      let images = optional_array(root, "images", parse_images)
      match (categories, images, root.get("annotations")) {
        (Ok(categories), Ok(images), Some(value)) =>
          match parse_annotations(value, "annotations") {
            Ok(annotations) =>
              CocoDataset::try_new(annotations~, categories~, images~)
            Err(error) => Err(error)
          }
        (Err(error), _, _) | (_, Err(error), _) => Err(error)
        (_, _, None) =>
          Err(InvalidField(path="annotations", message="field is required"))
      }
    }
    _ => Err(InvalidJson(message="COCO dataset root must be an object"))
  }
}

///|
fn parse_coco_results(value : Json) -> Result[CocoResults, CocoError] {
  match parse_results(value, "results") {
    Ok(results) => CocoResults::try_new(results~)
    Err(error) => Err(error)
  }
}

///|
fn[T] optional_array(
  object : Map[String, Json],
  field : String,
  parser : (Json, String) -> Result[Array[T], CocoError],
) -> Result[Array[T], CocoError] {
  match object.get(field) {
    None => Ok([])
    Some(value) => parser(value, field)
  }
}

///|
fn parse_categories(
  value : Json,
  path : String,
) -> Result[Array[CocoCategory], CocoError] {
  parse_array(value, path, parse_category)
}

///|
fn parse_images(
  value : Json,
  path : String,
) -> Result[Array[CocoImage], CocoError] {
  parse_array(value, path, parse_image)
}

///|
fn parse_annotations(
  value : Json,
  path : String,
) -> Result[Array[CocoAnnotation], CocoError] {
  parse_array(value, path, parse_annotation)
}

///|
fn parse_results(
  value : Json,
  path : String,
) -> Result[Array[CocoResult], CocoError] {
  parse_array(value, path, parse_result)
}

///|
fn[T] parse_array(
  value : Json,
  path : String,
  parser : (Json, String) -> Result[T, CocoError],
) -> Result[Array[T], CocoError] {
  match value {
    Array(values) => {
      let parsed : Array[T] = []
      let mut error : CocoError? = None
      for index, item in values {
        if error is None {
          match parser(item, "\{path}[\{index}]") {
            Ok(item) => parsed.push(item)
            Err(problem) => error = Some(problem)
          }
        }
      }
      match error {
        Some(problem) => Err(problem)
        None => Ok(parsed)
      }
    }
    _ => Err(InvalidField(path~, message="must be an array"))
  }
}

///|
fn parse_category(
  value : Json,
  path : String,
) -> Result[CocoCategory, CocoError] {
  match value {
    Object(object) =>
      match
        (
          required_int(object, "id", path),
          required_string(object, "name", path),
        ) {
        (Ok(id), Ok(name)) => Ok(CocoCategory::new(id~, name~))
        (Err(error), _) | (_, Err(error)) => Err(error)
      }
    _ => Err(InvalidField(path~, message="must be an object"))
  }
}

///|
fn parse_image(value : Json, path : String) -> Result[CocoImage, CocoError] {
  match value {
    Object(object) =>
      match
        (
          required_int(object, "id", path),
          required_int(object, "width", path),
          required_int(object, "height", path),
          optional_string(object, "file_name", path),
        ) {
        (Ok(id), Ok(width), Ok(height), Ok(file_name)) =>
          Ok(CocoImage::new(id~, width~, height~, file_name?))
        (Err(error), _, _, _)
        | (_, Err(error), _, _)
        | (_, _, Err(error), _)
        | (_, _, _, Err(error)) => Err(error)
      }
    _ => Err(InvalidField(path~, message="must be an object"))
  }
}

///|
fn parse_annotation(
  value : Json,
  path : String,
) -> Result[CocoAnnotation, CocoError] {
  match value {
    Object(object) =>
      match
        (
          required_int(object, "id", path),
          required_int(object, "image_id", path),
          required_int(object, "category_id", path),
          required_bbox(object, path),
          optional_number(object, "area", path),
          optional_iscrowd(object, path),
        ) {
        (Ok(id), Ok(image_id), Ok(category_id), Ok(bbox), Ok(area), Ok(iscrowd)) =>
          Ok(
            CocoAnnotation::new(
              id~,
              image_id~,
              category_id~,
              bbox~,
              area?,
              iscrowd?,
            ),
          )
        (Err(error), _, _, _, _, _)
        | (_, Err(error), _, _, _, _)
        | (_, _, Err(error), _, _, _)
        | (_, _, _, Err(error), _, _)
        | (_, _, _, _, Err(error), _)
        | (_, _, _, _, _, Err(error)) => Err(error)
      }
    _ => Err(InvalidField(path~, message="must be an object"))
  }
}

///|
fn parse_result(value : Json, path : String) -> Result[CocoResult, CocoError] {
  match value {
    Object(object) =>
      match
        (
          required_int(object, "image_id", path),
          required_int(object, "category_id", path),
          required_bbox(object, path),
          required_number(object, "score", path),
        ) {
        (Ok(image_id), Ok(category_id), Ok(bbox), Ok(score)) =>
          Ok(CocoResult::new(image_id~, category_id~, bbox~, score~))
        (Err(error), _, _, _)
        | (_, Err(error), _, _)
        | (_, _, Err(error), _)
        | (_, _, _, Err(error)) => Err(error)
      }
    _ => Err(InvalidField(path~, message="must be an object"))
  }
}

///|
fn required_int(
  object : Map[String, Json],
  field : String,
  path : String,
) -> Result[Int, CocoError] {
  let field_path = "\{path}.\{field}"
  match object.get(field) {
    None => Err(InvalidField(path=field_path, message="field is required"))
    Some(Number(value, ..)) if !is_finite(value) =>
      Err(InvalidField(path=field_path, message="must be a finite integer"))
    Some(Number(value, ..)) => {
      let number = value.to_int()
      if number.to_double() == value {
        Ok(number)
      } else {
        Err(InvalidField(path=field_path, message="must be an integer"))
      }
    }
    Some(_) => Err(InvalidField(path=field_path, message="must be a number"))
  }
}

///|
fn required_string(
  object : Map[String, Json],
  field : String,
  path : String,
) -> Result[String, CocoError] {
  let field_path = "\{path}.\{field}"
  match object.get(field) {
    None => Err(InvalidField(path=field_path, message="field is required"))
    Some(String(value)) => Ok(value)
    Some(_) => Err(InvalidField(path=field_path, message="must be a string"))
  }
}

///|
fn optional_string(
  object : Map[String, Json],
  field : String,
  path : String,
) -> Result[String?, CocoError] {
  let field_path = "\{path}.\{field}"
  match object.get(field) {
    None => Ok(None)
    Some(String(value)) => Ok(Some(value))
    Some(_) => Err(InvalidField(path=field_path, message="must be a string"))
  }
}

///|
fn required_bbox(
  object : Map[String, Json],
  path : String,
) -> Result[Rect, CocoError] {
  let field_path = "\{path}.bbox"
  match object.get("bbox") {
    Some(Array(values)) if values.length() == 4 =>
      match
        (
          number_at(values, 0, field_path),
          number_at(values, 1, field_path),
          number_at(values, 2, field_path),
          number_at(values, 3, field_path),
        ) {
        (Ok(x), Ok(y), Ok(width), Ok(height)) => {
          let bbox = Rect::new(x~, y~, width~, height~)
          match validate_bbox(bbox, field_path) {
            Ok(_) => Ok(bbox)
            Err(error) => Err(error)
          }
        }
        (Err(error), _, _, _)
        | (_, Err(error), _, _)
        | (_, _, Err(error), _)
        | (_, _, _, Err(error)) => Err(error)
      }
    Some(Array(_)) =>
      Err(InvalidField(path=field_path, message="must have four numbers"))
    Some(_) => Err(InvalidField(path=field_path, message="must be an array"))
    None => Err(InvalidField(path=field_path, message="field is required"))
  }
}

///|
fn required_number(
  object : Map[String, Json],
  field : String,
  path : String,
) -> Result[Double, CocoError] {
  let field_path = "\{path}.\{field}"
  match object.get(field) {
    None => Err(InvalidField(path=field_path, message="field is required"))
    Some(Number(value, ..)) if is_finite(value) => Ok(value)
    Some(Number(_, ..)) =>
      Err(InvalidField(path=field_path, message="must be a finite number"))
    Some(_) => Err(InvalidField(path=field_path, message="must be a number"))
  }
}

///|
fn optional_number(
  object : Map[String, Json],
  field : String,
  path : String,
) -> Result[Double?, CocoError] {
  let field_path = "\{path}.\{field}"
  match object.get(field) {
    None => Ok(None)
    Some(Number(value, ..)) if is_finite(value) => Ok(Some(value))
    Some(Number(_, ..)) =>
      Err(InvalidField(path=field_path, message="must be a finite number"))
    Some(_) => Err(InvalidField(path=field_path, message="must be a number"))
  }
}

///|
fn optional_iscrowd(
  object : Map[String, Json],
  path : String,
) -> Result[Int?, CocoError] {
  match object.get("iscrowd") {
    None => Ok(None)
    Some(Number(value, ..)) if is_finite(value) &&
      (value == 0.0 || value == 1.0) => Ok(Some(value.to_int()))
    Some(Number(_, ..)) =>
      Err(InvalidField(path="\{path}.iscrowd", message="must be 0 or 1"))
    Some(_) =>
      Err(InvalidField(path="\{path}.iscrowd", message="must be a number"))
  }
}

///|
fn number_at(
  values : Array[Json],
  index : Int,
  path : String,
) -> Result[Double, CocoError] {
  match values[index] {
    Number(value, ..) if is_finite(value) => Ok(value)
    Number(_, ..) =>
      Err(
        InvalidField(
          path="\{path}[\{index}]",
          message="must be a finite number",
        ),
      )
    _ => Err(InvalidField(path="\{path}[\{index}]", message="must be a number"))
  }
}

///|
fn validate_bbox(bbox : Rect, path : String) -> Result[Unit, CocoError] {
  if !is_finite(bbox.x) ||
    !is_finite(bbox.y) ||
    !is_finite(bbox.width) ||
    !is_finite(bbox.height) {
    Err(InvalidField(path~, message="must contain finite numbers"))
  } else if bbox.width <= 0.0 || bbox.height <= 0.0 {
    Err(InvalidField(path~, message="width and height must be positive"))
  } else {
    Ok(())
  }
}

///|
fn is_finite(value : Double) -> Bool {
  !value.is_nan() && !value.is_inf()
}

///|
fn category_to_json(category : CocoCategory) -> Json {
  Json::object({
    "id": Json::number(category.id.to_double()),
    "name": Json::string(category.name),
  })
}

///|
fn image_to_json(image : CocoImage) -> Json {
  let fields : Map[String, Json] = {
    "id": Json::number(image.id.to_double()),
    "width": Json::number(image.width.to_double()),
    "height": Json::number(image.height.to_double()),
  }
  match image.file_name {
    Some(file_name) => fields["file_name"] = Json::string(file_name)
    None => ()
  }
  Json::object(fields)
}

///|
fn annotation_to_json(annotation : CocoAnnotation) -> Json {
  let fields : Map[String, Json] = {
    "id": Json::number(annotation.id.to_double()),
    "image_id": Json::number(annotation.image_id.to_double()),
    "category_id": Json::number(annotation.category_id.to_double()),
    "bbox": bbox_to_json(annotation.bbox),
    "area": Json::number(annotation_area(annotation)),
  }
  match annotation.iscrowd {
    Some(iscrowd) => fields["iscrowd"] = Json::number(iscrowd.to_double())
    None => ()
  }
  Json::object(fields)
}

///|
fn result_to_json(result : CocoResult) -> Json {
  Json::object({
    "image_id": Json::number(result.image_id.to_double()),
    "category_id": Json::number(result.category_id.to_double()),
    "bbox": bbox_to_json(result.bbox),
    "score": Json::number(result.score),
  })
}

///|
fn bbox_to_json(bbox : Rect) -> Json {
  Json::array([
    Json::number(bbox.x),
    Json::number(bbox.y),
    Json::number(bbox.width),
    Json::number(bbox.height),
  ])
}

///|
fn annotation_area(annotation : CocoAnnotation) -> Double {
  match annotation.area {
    Some(area) => area
    None => annotation.bbox.width * annotation.bbox.height
  }
}
