///|
/// Errors returned by the text-only YOLO and Pascal VOC annotation adapters.
pub(all) enum AdapterError {
  InvalidImageSize(message~ : String)
  InvalidYolo(field~ : String, message~ : String)
  InvalidYoloText(message~ : String)
  MissingClassMapping(class_id~ : Int)
  InvalidVoc(path~ : String, message~ : String)
} derive(Debug, ToJson)

///|
/// A YOLO bounding box whose centre and dimensions are normalized to `[0, 1]`.
/// `confidence` is optional because training labels normally omit it.
pub(all) struct YoloBox {
  class_id : Int
  center_x : Double
  center_y : Double
  width : Double
  height : Double
  confidence : Double?
} derive(Debug, ToJson)

///|
/// Creates a validated normalized YOLO record.
pub fn YoloBox::try_new(
  class_id~ : Int,
  center_x~ : Double,
  center_y~ : Double,
  width~ : Double,
  height~ : Double,
  confidence? : Double,
) -> Result[YoloBox, AdapterError] {
  let box = { class_id, center_x, center_y, width, height, confidence }
  match validate_yolo_box(box) {
    Ok(_) => Ok(box)
    Err(error) => Err(error)
  }
}

///|
/// Parses one deterministic YOLO label line (five fields, or six with score).
/// The caller's class mapping is checked so unknown numeric IDs are rejected.
pub fn YoloBox::from_line(
  line : String,
  image~ : ImageSpec,
  classes~ : Array[String],
) -> Result[YoloBox, AdapterError] {
  match validate_image(image) {
    Err(error) => Err(error)
    Ok(_) => {
      let fields = yolo_fields(line)
      if fields.length() != 5 && fields.length() != 6 {
        Err(
          InvalidYoloText(
            message="expected five fields, or six with confidence",
          ),
        )
      } else {
        match parse_int(fields[0], "class_id") {
          Err(error) => Err(error)
          Ok(class_id) =>
            match class_for_id(classes, class_id) {
              Err(error) => Err(error)
              Ok(_) => parse_yolo_values(fields, class_id)
            }
        }
      }
    }
  }
}

///|
/// Converts this normalized box to the library's pixel-space `Rect`.
pub fn YoloBox::to_rect(
  self : YoloBox,
  image : ImageSpec,
) -> Result[Rect, AdapterError] {
  match validate_image(image) {
    Err(error) => Err(error)
    Ok(_) =>
      match validate_yolo_box(self) {
        Err(error) => Err(error)
        Ok(_) => {
          let image_width = image.width.to_double()
          let image_height = image.height.to_double()
          Ok(
            Rect::new(
              x=self.center_x * image_width - self.width * image_width / 2.0,
              y=self.center_y * image_height - self.height * image_height / 2.0,
              width=self.width * image_width,
              height=self.height * image_height,
            ),
          )
        }
      }
  }
}

///|
/// Converts a contained pixel-space rectangle into a normalized YOLO record.
pub fn YoloBox::from_rect(
  class_id~ : Int,
  rect~ : Rect,
  image~ : ImageSpec,
  confidence? : Double,
) -> Result[YoloBox, AdapterError] {
  match validate_image(image) {
    Err(error) => Err(error)
    Ok(_) if !valid_rect(rect) =>
      Err(
        InvalidYolo(
          field="rect",
          message="must contain finite positive dimensions",
        ),
      )
    Ok(_) => {
      let image_width = image.width.to_double()
      let image_height = image.height.to_double()
      YoloBox::try_new(
        class_id~,
        center_x=(rect.x + rect.width / 2.0) / image_width,
        center_y=(rect.y + rect.height / 2.0) / image_height,
        width=rect.width / image_width,
        height=rect.height / image_height,
        confidence?,
      )
    }
  }
}

///|
/// Serializes one record with single ASCII-space separators. The mapping is
/// validated even though standard YOLO syntax stores the numeric ID.
pub fn YoloBox::to_line(
  self : YoloBox,
  classes : Array[String],
) -> Result[String, AdapterError] {
  match validate_yolo_box(self) {
    Err(error) => Err(error)
    Ok(_) =>
      match class_for_id(classes, self.class_id) {
        Err(error) => Err(error)
        Ok(_) => {
          let fields = [
            self.class_id.to_string(),
            self.center_x.to_string(),
            self.center_y.to_string(),
            self.width.to_string(),
            self.height.to_string(),
          ]
          match self.confidence {
            Some(confidence) => {
              fields.push(confidence.to_string())
              Ok(fields.join(" "))
            }
            None => Ok(fields.join(" "))
          }
        }
      }
  }
}

///|
/// One object in a Pascal VOC annotation. `bbox` is pixel-space and uses the
/// library's zero-based, half-open `Rect` convention.
pub(all) struct VocObject {
  name : String
  bbox : Rect
} derive(Debug, ToJson)

///|
/// Creates an unvalidated VOC object. `VocAnnotation::try_new` and XML import
/// validate names and boxes before returning a fallible result.
pub fn VocObject::new(name~ : String, bbox~ : Rect) -> VocObject {
  { name, bbox }
}

///|
/// A lightweight Pascal VOC annotation with image dimensions and objects.
pub(all) struct VocAnnotation {
  filename : String?
  size : ImageSpec
  objects : Array[VocObject]
} derive(Debug, ToJson)

///|
/// Creates an unvalidated VOC annotation for convenient literals.
pub fn VocAnnotation::new(
  filename? : String,
  size~ : ImageSpec,
  objects~ : Array[VocObject],
) -> VocAnnotation {
  { filename, size, objects }
}

///|
/// Validates a VOC annotation without reading files or touching the runtime.
pub fn VocAnnotation::try_new(
  filename? : String,
  size~ : ImageSpec,
  objects~ : Array[VocObject],
) -> Result[VocAnnotation, AdapterError] {
  let annotation = VocAnnotation::new(filename?, size~, objects~)
  match validate_voc(annotation) {
    Ok(_) => Ok(annotation)
    Err(error) => Err(error)
  }
}

///|
/// Parses VOC XML containing an optional XML declaration, standard metadata,
/// ordered `<size>` dimensions, and ordered `<object><name><bndbox>` entries.
/// Standard metadata is ignored; required geometric fields remain strict.
pub fn VocAnnotation::from_xml(
  source : String,
) -> Result[VocAnnotation, AdapterError] {
  let cursor = XmlCursor::new(source)
  match cursor.consume_declaration() {
    Err(error) => Err(error)
    Ok(_) =>
      match cursor.expect_open("annotation", "annotation") {
        Err(error) => Err(error)
        Ok(_) => {
          let mut filename : String? = None
          let mut metadata_error : AdapterError? = None
          while !cursor.has_open("size") &&
                metadata_error is None &&
                !cursor.has_open("object") &&
                !cursor.has_close("annotation") {
            if cursor.has_open("filename") && filename is None {
              match cursor.read_text("filename", "annotation.filename") {
                Ok(value) => filename = Some(value)
                Err(error) => metadata_error = Some(error)
              }
            } else {
              match skip_root_metadata(cursor) {
                Ok(true) => ()
                Ok(false) =>
                  metadata_error = Some(
                    InvalidVoc(
                      path="annotation",
                      message="unexpected element before <size>",
                    ),
                  )
                Err(error) => metadata_error = Some(error)
              }
            }
          }
          match metadata_error {
            Some(error) => Err(error)
            None => {
              let size = parse_voc_size(cursor)
              match size {
                Err(error) => Err(error)
                Ok(size) => {
                  let objects : Array[VocObject] = []
                  let mut error : AdapterError? = None
                  while error is None && !cursor.has_close("annotation") {
                    if cursor.has_open("object") {
                      match parse_voc_object(cursor, objects.length()) {
                        Ok(object) => objects.push(object)
                        Err(problem) => error = Some(problem)
                      }
                    } else {
                      match skip_root_metadata(cursor) {
                        Ok(true) => ()
                        Ok(false) =>
                          error = Some(
                            InvalidVoc(
                              path="annotation",
                              message="unexpected element after <size>",
                            ),
                          )
                        Err(problem) => error = Some(problem)
                      }
                    }
                  }
                  match error {
                    Some(problem) => Err(problem)
                    None =>
                      match cursor.expect_close("annotation", "annotation") {
                        Err(problem) => Err(problem)
                        Ok(_) if !cursor.finished() =>
                          Err(
                            InvalidVoc(
                              path="annotation",
                              message="unexpected trailing content",
                            ),
                          )
                        Ok(_) =>
                          VocAnnotation::try_new(filename?, size~, objects~)
                      }
                  }
                }
              }
            }
          }
        }
      }
  }
}

///|
/// Exports canonical, escaped Pascal VOC XML. Rectangles are converted from
/// zero-based half-open coordinates to VOC's one-based inclusive convention.
pub fn VocAnnotation::to_xml(
  self : VocAnnotation,
) -> Result[String, AdapterError] {
  match validate_voc(self) {
    Err(error) => Err(error)
    Ok(_) => {
      let output = StringBuilder()
      output.write_string("<annotation>")
      match self.filename {
        Some(filename) => {
          output.write_string("<filename>")
          output.write_string(xml_escape(filename))
          output.write_string("</filename>")
        }
        None => ()
      }
      output.write_string("<size><width>")
      output.write_string(self.size.width.to_string())
      output.write_string("</width><height>")
      output.write_string(self.size.height.to_string())
      output.write_string("</height></size>")
      for object in self.objects {
        let xmin = object.bbox.x.to_int() + 1
        let ymin = object.bbox.y.to_int() + 1
        let xmax = (object.bbox.x + object.bbox.width).to_int()
        let ymax = (object.bbox.y + object.bbox.height).to_int()
        output.write_string("<object><name>")
        output.write_string(xml_escape(object.name))
        output.write_string("</name><bndbox><xmin>")
        output.write_string(xmin.to_string())
        output.write_string("</xmin><ymin>")
        output.write_string(ymin.to_string())
        output.write_string("</ymin><xmax>")
        output.write_string(xmax.to_string())
        output.write_string("</xmax><ymax>")
        output.write_string(ymax.to_string())
        output.write_string("</ymax></bndbox></object>")
      }
      output.write_string("</annotation>")
      Ok(output.to_string())
    }
  }
}

///|
fn validate_image(image : ImageSpec) -> Result[Unit, AdapterError] {
  if image.valid() {
    Ok(())
  } else {
    Err(InvalidImageSize(message="width and height must be positive"))
  }
}

///|
fn valid_number(value : Double) -> Bool {
  !value.is_nan() && !value.is_inf()
}

///|
fn valid_rect(rect : Rect) -> Bool {
  valid_number(rect.x) &&
  valid_number(rect.y) &&
  valid_number(rect.width) &&
  valid_number(rect.height) &&
  rect.width > 0.0 &&
  rect.height > 0.0
}

///|
fn valid_normalized(value : Double) -> Bool {
  valid_number(value) && value >= 0.0 && value <= 1.0
}

///|
fn validate_yolo_box(box : YoloBox) -> Result[Unit, AdapterError] {
  if box.class_id < 0 {
    Err(InvalidYolo(field="class_id", message="must be nonnegative"))
  } else if !valid_normalized(box.center_x) {
    Err(
      InvalidYolo(field="center_x", message="must be a finite number in [0, 1]"),
    )
  } else if !valid_normalized(box.center_y) {
    Err(
      InvalidYolo(field="center_y", message="must be a finite number in [0, 1]"),
    )
  } else if !valid_normalized(box.width) || box.width == 0.0 {
    Err(InvalidYolo(field="width", message="must be a finite number in (0, 1]"))
  } else if !valid_normalized(box.height) || box.height == 0.0 {
    Err(
      InvalidYolo(field="height", message="must be a finite number in (0, 1]"),
    )
  } else if box.center_x - box.width / 2.0 < 0.0 ||
    box.center_x + box.width / 2.0 > 1.0 ||
    box.center_y - box.height / 2.0 < 0.0 ||
    box.center_y + box.height / 2.0 > 1.0 {
    Err(
      InvalidYolo(
        field="box",
        message="must remain within normalized image bounds",
      ),
    )
  } else {
    match box.confidence {
      Some(confidence) if !valid_normalized(confidence) =>
        Err(
          InvalidYolo(
            field="confidence",
            message="must be a finite number in [0, 1]",
          ),
        )
      _ => Ok(())
    }
  }
}

///|
fn class_for_id(
  classes : Array[String],
  class_id : Int,
) -> Result[String, AdapterError] {
  match classes.get(class_id) {
    Some(name) if name != "" => Ok(name)
    _ => Err(MissingClassMapping(class_id~))
  }
}

///|
fn yolo_fields(line : String) -> Array[String] {
  let fields : Array[String] = []
  let token = StringBuilder()
  for character in line {
    if character.is_ascii_whitespace() {
      if !token.is_empty() {
        fields.push(token.to_string())
        token.reset()
      }
    } else {
      token.write_char(character)
    }
  }
  if !token.is_empty() {
    fields.push(token.to_string())
  }
  fields
}

///|
fn parse_int(field : String, name : String) -> Result[Int, AdapterError] {
  try {
    let value : Int = @strconv.from_str(field)
    Ok(value)
  } catch {
    _ => Err(InvalidYolo(field=name, message="must be an integer"))
  }
}

///|
fn parse_number(field : String, name : String) -> Result[Double, AdapterError] {
  try {
    let value : Double = @strconv.from_str(field)
    Ok(value)
  } catch {
    _ => Err(InvalidYolo(field=name, message="must be a number"))
  }
}

///|
fn parse_yolo_values(
  fields : Array[String],
  class_id : Int,
) -> Result[YoloBox, AdapterError] {
  match
    (
      parse_number(fields[1], "center_x"),
      parse_number(fields[2], "center_y"),
      parse_number(fields[3], "width"),
      parse_number(fields[4], "height"),
    ) {
    (Ok(center_x), Ok(center_y), Ok(width), Ok(height)) => {
      let confidence = if fields.length() == 6 {
        match parse_number(fields[5], "confidence") {
          Ok(value) => Some(value)
          Err(error) => return Err(error)
        }
      } else {
        None
      }
      YoloBox::try_new(
        class_id~,
        center_x~,
        center_y~,
        width~,
        height~,
        confidence?,
      )
    }
    (Err(error), _, _, _)
    | (_, Err(error), _, _)
    | (_, _, Err(error), _)
    | (_, _, _, Err(error)) => Err(error)
  }
}

///|
fn validate_voc(annotation : VocAnnotation) -> Result[Unit, AdapterError] {
  match validate_image(annotation.size) {
    Err(_) =>
      Err(
        InvalidVoc(
          path="annotation.size",
          message="width and height must be positive",
        ),
      )
    Ok(_) => {
      match annotation.filename {
        Some(filename) =>
          match validate_xml_text(filename[:], "annotation.filename") {
            Ok(_) => ()
            Err(error) => return Err(error)
          }
        None => ()
      }
      for index, object in annotation.objects {
        let path = "annotation.object[\{index}]"
        if object.name == "" {
          return Err(
            InvalidVoc(path="\{path}.name", message="must not be empty"),
          )
        }
        match validate_xml_text(object.name[:], "\{path}.name") {
          Ok(_) => ()
          Err(error) => return Err(error)
        }
        if !valid_rect(object.bbox) {
          return Err(
            InvalidVoc(
              path="\{path}.bndbox",
              message="must contain finite positive dimensions",
            ),
          )
        }
        if object.bbox.x != object.bbox.x.to_int().to_double() ||
          object.bbox.y != object.bbox.y.to_int().to_double() ||
          object.bbox.width != object.bbox.width.to_int().to_double() ||
          object.bbox.height != object.bbox.height.to_int().to_double() {
          return Err(
            InvalidVoc(
              path="\{path}.bndbox",
              message="must use integer pixel coordinates",
            ),
          )
        }
        if object.bbox.x < 0.0 ||
          object.bbox.y < 0.0 ||
          object.bbox.right() > annotation.size.width.to_double() ||
          object.bbox.bottom() > annotation.size.height.to_double() {
          return Err(
            InvalidVoc(
              path="\{path}.bndbox",
              message="must lie within image bounds",
            ),
          )
        }
      }
      Ok(())
    }
  }
}

///|
priv struct XmlCursor {
  mut rest : StringView
}

///|
fn XmlCursor::new(source : String) -> XmlCursor {
  { rest: source[:].trim() }
}

///|
fn XmlCursor::consume_declaration(
  self : XmlCursor,
) -> Result[Unit, AdapterError] {
  self.rest = self.rest.trim_start()
  if !self.rest.has_prefix("<?xml") {
    Ok(())
  } else {
    match self.rest.find("?>") {
      None =>
        Err(
          InvalidVoc(path="annotation", message="unterminated XML declaration"),
        )
      Some(index) => {
        let (_, tail) = self.rest.split_at(index)
        match tail.strip_prefix("?>") {
          Some(rest) => {
            self.rest = rest
            Ok(())
          }
          None =>
            Err(
              InvalidVoc(
                path="annotation",
                message="unterminated XML declaration",
              ),
            )
        }
      }
    }
  }
}

///|
fn XmlCursor::has_open(self : XmlCursor, name : String) -> Bool {
  self.rest.trim_start().has_prefix("<\{name}>")
}

///|
fn XmlCursor::has_close(self : XmlCursor, name : String) -> Bool {
  self.rest.trim_start().has_prefix("</\{name}>")
}

///|
fn XmlCursor::expect_open(
  self : XmlCursor,
  name : String,
  path : String,
) -> Result[Unit, AdapterError] {
  self.rest = self.rest.trim_start()
  match self.rest.strip_prefix("<\{name}>") {
    Some(rest) => {
      self.rest = rest
      Ok(())
    }
    None => Err(InvalidVoc(path~, message="expected <\{name}>"))
  }
}

///|
fn XmlCursor::expect_close(
  self : XmlCursor,
  name : String,
  path : String,
) -> Result[Unit, AdapterError] {
  self.rest = self.rest.trim_start()
  match self.rest.strip_prefix("</\{name}>") {
    Some(rest) => {
      self.rest = rest
      Ok(())
    }
    None => Err(InvalidVoc(path~, message="expected </\{name}>"))
  }
}

///|
fn XmlCursor::read_text(
  self : XmlCursor,
  name : String,
  path : String,
) -> Result[String, AdapterError] {
  match self.expect_open(name, path) {
    Err(error) => Err(error)
    Ok(_) => {
      let closing = "</\{name}>"
      match self.rest.find(closing) {
        None => Err(InvalidVoc(path~, message="missing closing </\{name}>"))
        Some(index) => {
          let (raw, tail) = self.rest.split_at(index)
          match tail.strip_prefix(closing) {
            None => Err(InvalidVoc(path~, message="missing closing </\{name}>"))
            Some(rest) => {
              self.rest = rest
              xml_unescape(raw, path)
            }
          }
        }
      }
    }
  }
}

///|
fn XmlCursor::finished(self : XmlCursor) -> Bool {
  self.rest.trim().is_empty()
}

///|
fn skip_text_element(
  cursor : XmlCursor,
  name : String,
  path : String,
) -> Result[Unit, AdapterError] {
  match cursor.read_text(name, path) {
    Ok(_) => Ok(())
    Err(error) => Err(error)
  }
}

///|
fn skip_source_metadata(cursor : XmlCursor) -> Result[Unit, AdapterError] {
  match cursor.expect_open("source", "annotation.source") {
    Err(error) => Err(error)
    Ok(_) => {
      while !cursor.has_close("source") {
        if cursor.has_open("database") {
          match
            skip_text_element(cursor, "database", "annotation.source.database") {
            Ok(_) => ()
            Err(error) => return Err(error)
          }
        } else {
          return Err(
            InvalidVoc(path="annotation.source", message="unexpected element"),
          )
        }
      }
      cursor.expect_close("source", "annotation.source")
    }
  }
}

///|
fn skip_root_metadata(cursor : XmlCursor) -> Result[Bool, AdapterError] {
  if cursor.has_open("folder") {
    match skip_text_element(cursor, "folder", "annotation.folder") {
      Ok(_) => Ok(true)
      Err(error) => Err(error)
    }
  } else if cursor.has_open("path") {
    match skip_text_element(cursor, "path", "annotation.path") {
      Ok(_) => Ok(true)
      Err(error) => Err(error)
    }
  } else if cursor.has_open("segmented") {
    match skip_text_element(cursor, "segmented", "annotation.segmented") {
      Ok(_) => Ok(true)
      Err(error) => Err(error)
    }
  } else if cursor.has_open("source") {
    match skip_source_metadata(cursor) {
      Ok(_) => Ok(true)
      Err(error) => Err(error)
    }
  } else {
    Ok(false)
  }
}

///|
fn skip_object_metadata(
  cursor : XmlCursor,
  path : String,
) -> Result[Bool, AdapterError] {
  if cursor.has_open("pose") {
    match skip_text_element(cursor, "pose", "\{path}.pose") {
      Ok(_) => Ok(true)
      Err(error) => Err(error)
    }
  } else if cursor.has_open("truncated") {
    match skip_text_element(cursor, "truncated", "\{path}.truncated") {
      Ok(_) => Ok(true)
      Err(error) => Err(error)
    }
  } else if cursor.has_open("difficult") {
    match skip_text_element(cursor, "difficult", "\{path}.difficult") {
      Ok(_) => Ok(true)
      Err(error) => Err(error)
    }
  } else if cursor.has_open("occluded") {
    match skip_text_element(cursor, "occluded", "\{path}.occluded") {
      Ok(_) => Ok(true)
      Err(error) => Err(error)
    }
  } else {
    Ok(false)
  }
}

///|
fn parse_voc_size(cursor : XmlCursor) -> Result[ImageSpec, AdapterError] {
  match cursor.expect_open("size", "annotation.size") {
    Err(_) if cursor.has_open("object") || cursor.has_open("annotation") =>
      Err(InvalidVoc(path="annotation.size", message="element is required"))
    Err(error) => Err(error)
    Ok(_) =>
      match
        (
          cursor.read_text("width", "annotation.size"),
          cursor.read_text("height", "annotation.size"),
        ) {
        (Ok(width_text), Ok(height_text)) =>
          match
            (
              parse_voc_int(width_text, "annotation.size.width"),
              parse_voc_int(height_text, "annotation.size.height"),
            ) {
            (Ok(width), Ok(height)) if width > 0 && height > 0 =>
              if cursor.has_open("depth") {
                match
                  skip_text_element(cursor, "depth", "annotation.size.depth") {
                  Err(error) => Err(error)
                  Ok(_) =>
                    match cursor.expect_close("size", "annotation.size") {
                      Ok(_) => Ok(ImageSpec::new(width~, height~))
                      Err(error) => Err(error)
                    }
                }
              } else {
                match cursor.expect_close("size", "annotation.size") {
                  Ok(_) => Ok(ImageSpec::new(width~, height~))
                  Err(error) => Err(error)
                }
              }
            (Ok(_), Ok(_)) =>
              Err(
                InvalidVoc(
                  path="annotation.size",
                  message="width and height must be positive",
                ),
              )
            (Err(error), _) | (_, Err(error)) => Err(error)
          }
        (Err(error), _) | (_, Err(error)) => Err(error)
      }
  }
}

///|
fn parse_voc_object(
  cursor : XmlCursor,
  index : Int,
) -> Result[VocObject, AdapterError] {
  let path = "annotation.object[\{index}]"
  match cursor.expect_open("object", path) {
    Err(error) => Err(error)
    Ok(_) =>
      match cursor.read_text("name", "\{path}.name") {
        Err(error) => Err(error)
        Ok(name) if name == "" =>
          Err(InvalidVoc(path="\{path}.name", message="must not be empty"))
        Ok(name) => {
          let mut metadata_error : AdapterError? = None
          while !cursor.has_open("bndbox") && metadata_error is None {
            match skip_object_metadata(cursor, path) {
              Ok(true) => ()
              Ok(false) =>
                metadata_error = Some(
                  InvalidVoc(path="\{path}.bndbox", message="expected <bndbox>"),
                )
              Err(error) => metadata_error = Some(error)
            }
          }
          match metadata_error {
            Some(error) => Err(error)
            None =>
              match cursor.expect_open("bndbox", "\{path}.bndbox") {
                Err(error) => Err(error)
                Ok(_) =>
                  match
                    (
                      cursor.read_text("xmin", "\{path}.bndbox.xmin"),
                      cursor.read_text("ymin", "\{path}.bndbox.ymin"),
                      cursor.read_text("xmax", "\{path}.bndbox.xmax"),
                      cursor.read_text("ymax", "\{path}.bndbox.ymax"),
                    ) {
                    (Ok(xmin), Ok(ymin), Ok(xmax), Ok(ymax)) =>
                      parse_voc_box(cursor, path, name, xmin, ymin, xmax, ymax)
                    (Err(error), _, _, _)
                    | (_, Err(error), _, _)
                    | (_, _, Err(error), _)
                    | (_, _, _, Err(error)) => Err(error)
                  }
              }
          }
        }
      }
  }
}

///|
fn parse_voc_box(
  cursor : XmlCursor,
  path : String,
  name : String,
  xmin_text : String,
  ymin_text : String,
  xmax_text : String,
  ymax_text : String,
) -> Result[VocObject, AdapterError] {
  match
    (
      parse_voc_int(xmin_text, "\{path}.bndbox.xmin"),
      parse_voc_int(ymin_text, "\{path}.bndbox.ymin"),
      parse_voc_int(xmax_text, "\{path}.bndbox.xmax"),
      parse_voc_int(ymax_text, "\{path}.bndbox.ymax"),
    ) {
    (Ok(xmin), Ok(ymin), Ok(xmax), Ok(ymax)) if xmin >= 1 &&
      ymin >= 1 &&
      xmax >= xmin &&
      ymax >= ymin =>
      match cursor.expect_close("bndbox", "\{path}.bndbox") {
        Err(error) => Err(error)
        Ok(_) =>
          match cursor.expect_close("object", path) {
            Err(error) => Err(error)
            Ok(_) =>
              Ok(
                VocObject::new(
                  name~,
                  bbox=Rect::new(
                    x=(xmin - 1).to_double(),
                    y=(ymin - 1).to_double(),
                    width=(xmax - xmin + 1).to_double(),
                    height=(ymax - ymin + 1).to_double(),
                  ),
                ),
              )
          }
      }
    (Ok(_), Ok(_), Ok(_), Ok(_)) =>
      Err(
        InvalidVoc(
          path="\{path}.bndbox",
          message="xmax and ymax must be at least xmin and ymin",
        ),
      )
    (Err(error), _, _, _)
    | (_, Err(error), _, _)
    | (_, _, Err(error), _)
    | (_, _, _, Err(error)) => Err(error)
  }
}

///|
fn parse_voc_int(value : String, path : String) -> Result[Int, AdapterError] {
  try {
    let number : Int = @strconv.from_str(value.trim())
    Ok(number)
  } catch {
    _ => Err(InvalidVoc(path~, message="must be an integer"))
  }
}

///|
fn xml_escape(value : String) -> String {
  value
  .replace_all(old="&", new="&amp;")
  .replace_all(old="<", new="&lt;")
  .replace_all(old=">", new="&gt;")
  .replace_all(old="\"", new="&quot;")
  .replace_all(old="'", new="&apos;")
}

///|
fn xml_unescape(
  value : StringView,
  path : String,
) -> Result[String, AdapterError] {
  match validate_xml_text(value, path) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  if value.contains("<") {
    return Err(InvalidVoc(path~, message="text must escape '<'"))
  }
  let parts = value.split("&").to_array()
  let output = StringBuilder()
  output.write_view(parts[0])
  for index in 1..<parts.length() {
    let part = parts[index]
    match entity_prefix(part) {
      None if part.has_prefix("#") =>
        return Err(InvalidVoc(path~, message="invalid XML character"))
      None => return Err(InvalidVoc(path~, message="invalid XML entity"))
      Some((entity, tail)) => {
        output.write_string(entity)
        output.write_view(tail)
      }
    }
  }
  Ok(output.to_string())
}

///|
fn entity_prefix(value : StringView) -> (String, StringView)? {
  match value.strip_prefix("amp;") {
    Some(tail) => Some(("&", tail))
    None =>
      match value.strip_prefix("lt;") {
        Some(tail) => Some(("<", tail))
        None =>
          match value.strip_prefix("gt;") {
            Some(tail) => Some((">", tail))
            None =>
              match value.strip_prefix("quot;") {
                Some(tail) => Some(("\"", tail))
                None =>
                  match value.strip_prefix("apos;") {
                    Some(tail) => Some(("'", tail))
                    None => numeric_entity_prefix(value)
                  }
              }
          }
      }
  }
}

///|
fn numeric_entity_prefix(value : StringView) -> (String, StringView)? {
  match value.strip_prefix("#") {
    None => None
    Some(rest) =>
      match rest.find(";") {
        None => None
        Some(index) => {
          let (digits, tail) = rest.split_at(index)
          match tail.strip_prefix(";") {
            None => None
            Some(remaining) => {
              let (base, number) = match digits.strip_prefix("x") {
                Some(hex) => (16, hex)
                None =>
                  match digits.strip_prefix("X") {
                    Some(hex) => (16, hex)
                    None => (10, digits)
                  }
              }
              match parse_xml_codepoint(number, base) {
                Some(codepoint) if valid_xml_codepoint(codepoint) =>
                  match codepoint.to_char() {
                    Some(character) => Some((character.to_string(), remaining))
                    None => None
                  }
                _ => None
              }
            }
          }
        }
      }
  }
}

///|
fn parse_xml_codepoint(digits : StringView, base : Int) -> Int? {
  if digits.is_empty() {
    return None
  }
  let mut value = 0
  for character in digits {
    let digit = if character >= '0' && character <= '9' {
      character.to_int() - '0'.to_int()
    } else if character >= 'a' && character <= 'f' {
      character.to_int() - 'a'.to_int() + 10
    } else if character >= 'A' && character <= 'F' {
      character.to_int() - 'A'.to_int() + 10
    } else {
      return None
    }
    if digit >= base || value > (0x10ffff - digit) / base {
      return None
    }
    value = value * base + digit
  }
  Some(value)
}

///|
fn valid_xml_codepoint(value : Int) -> Bool {
  value == 0x9 ||
  value == 0xa ||
  value == 0xd ||
  (value >= 0x20 && value <= 0xd7ff) ||
  (value >= 0xe000 && value <= 0xfffd) ||
  (value >= 0x10000 && value <= 0x10ffff)
}

///|
fn validate_xml_text(
  value : StringView,
  path : String,
) -> Result[Unit, AdapterError] {
  for character in value {
    if !valid_xml_codepoint(character.to_int()) {
      return Err(InvalidVoc(path~, message="invalid XML character"))
    }
  }
  Ok(())
}
