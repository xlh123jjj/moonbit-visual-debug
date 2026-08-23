///|
test "YOLO lines round-trip through normalized boxes and pixel rectangles" {
  let image = ImageSpec::new(width=200, height=100)
  let classes = ["person", "bicycle"]
  let parsed = YoloBox::from_line("1 0.5 0.25 0.2 0.4 0.9", image~, classes~).unwrap()
  inspect(parsed.class_id, content="1")
  match parsed.confidence {
    Some(0.9) => ()
    _ => fail("expected parsed confidence")
  }
  let rect = parsed.to_rect(image).unwrap()
  inspect(rect.x, content="80")
  inspect(rect.y, content="5")
  inspect(rect.width, content="40")
  inspect(rect.height, content="40")
  inspect(parsed.to_line(classes).unwrap(), content="1 0.5 0.25 0.2 0.4 0.9")
}

///|
test "YOLO rejects invalid normalized values and missing class mapping" {
  let image = ImageSpec::new(width=20, height=10)
  let classes = ["person"]
  let out_of_bounds = YoloBox::from_line("0 1.1 0.5 0.2 0.2", image~, classes~)
  let missing_class = YoloBox::from_line("1 0.5 0.5 0.2 0.2", image~, classes~)
  match out_of_bounds {
    Err(
      InvalidYolo(field="center_x", message="must be a finite number in [0, 1]")
    ) => ()
    _ => fail("expected normalized centre validation error")
  }
  match missing_class {
    Err(MissingClassMapping(class_id=1)) => ()
    _ => fail("expected missing class mapping error")
  }
}

///|
test "YOLO rejects nonpositive pixel images and confidence outside the unit range" {
  let classes = ["person"]
  let bad_image = ImageSpec::new(width=0, height=10)
  let bad_confidence = YoloBox::from_line(
    "0 0.5 0.5 0.2 0.2 1.1",
    image=ImageSpec::new(width=20, height=10),
    classes~,
  )
  match YoloBox::from_line("0 0.5 0.5 0.2 0.2", image=bad_image, classes~) {
    Err(InvalidImageSize(message="width and height must be positive")) => ()
    _ => fail("expected invalid image error")
  }
  match bad_confidence {
    Err(
      InvalidYolo(
        field="confidence",
        message="must be a finite number in [0, 1]"
      )
    ) => ()
    _ => fail("expected confidence validation error")
  }
}

///|
test "YOLO pixel rectangles round-trip at image boundaries" {
  let image = ImageSpec::new(width=20, height=10)
  let box = YoloBox::from_rect(
    class_id=0,
    rect=Rect::new(x=0.0, y=0.0, width=20.0, height=10.0),
    image~,
  ).unwrap()
  inspect(box.center_x, content="0.5")
  inspect(box.center_y, content="0.5")
  inspect(box.width, content="1")
  inspect(box.height, content="1")
  let rect = box.to_rect(image).unwrap()
  inspect(rect.x, content="0")
  inspect(rect.y, content="0")
  inspect(rect.width, content="20")
  inspect(rect.height, content="10")
  match
    YoloBox::from_rect(
      class_id=0,
      rect=Rect::new(x=0.0, y=0.0, width=21.0, height=10.0),
      image~,
    ) {
    Err(InvalidYolo(field="width", message="must be a finite number in (0, 1]")) =>
      ()
    _ => fail("expected out-of-image rectangle rejection")
  }
}

///|
test "VOC XML round-trips escaped names and 1-based inclusive coordinates" {
  let annotation = VocAnnotation::new(
    filename="a&b<.jpg",
    size=ImageSpec::new(width=20, height=10),
    objects=[
      VocObject::new(
        name="cat & dog <1>",
        bbox=Rect::new(x=0.0, y=0.0, width=20.0, height=10.0),
      ),
    ],
  )
  let xml = annotation.to_xml().unwrap()
  assert_true(xml.contains("a&amp;b&lt;.jpg"))
  assert_true(xml.contains("cat &amp; dog &lt;1&gt;"))
  assert_true(
    xml.contains("<xmin>1</xmin><ymin>1</ymin><xmax>20</xmax><ymax>10</ymax>"),
  )
  let parsed = VocAnnotation::from_xml(xml).unwrap()
  match parsed.filename {
    Some("a&b<.jpg") => ()
    _ => fail("expected unescaped filename")
  }
  inspect(parsed.objects[0].bbox.x, content="0")
  inspect(parsed.objects[0].bbox.y, content="0")
  inspect(parsed.objects[0].bbox.width, content="20")
  inspect(parsed.objects[0].bbox.height, content="10")
}

///|
test "VOC parser rejects missing ordered elements and nonpositive boxes" {
  let missing_size = VocAnnotation::from_xml(
    "<annotation><object><name>cat</name><bndbox><xmin>1</xmin><ymin>1</ymin><xmax>2</xmax><ymax>2</ymax></bndbox></object></annotation>",
  )
  let out_of_order = VocAnnotation::from_xml(
    "<annotation><size><height>10</height><width>20</width></size></annotation>",
  )
  let zero_width = VocAnnotation::from_xml(
    "<annotation><size><width>20</width><height>10</height></size><object><name>cat</name><bndbox><xmin>2</xmin><ymin>1</ymin><xmax>1</xmax><ymax>2</ymax></bndbox></object></annotation>",
  )
  match missing_size {
    Err(InvalidVoc(path="annotation.size", message="element is required")) => ()
    _ => fail("expected missing size error")
  }
  match out_of_order {
    Err(InvalidVoc(path="annotation.size", message="expected <width>")) => ()
    _ => fail("expected ordered size error")
  }
  match zero_width {
    Err(
      InvalidVoc(
        path="annotation.object[0].bndbox",
        message="xmax and ymax must be at least xmin and ymin"
      )
    ) => ()
    _ => fail("expected nonpositive box error")
  }
}

///|
test "VOC parser accepts declarations, standard metadata, and numeric XML entities" {
  let document =
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<annotation><folder>VOC2012</folder><filename>dog&#x20;&amp;&#32;cat.jpg</filename><path>/tmp/dog.jpg</path><source><database>Unknown</database></source><size><width>20</width><height>10</height><depth>3</depth></size><segmented>0</segmented><object><name>dog</name><pose>Unspecified</pose><truncated>0</truncated><difficult>0</difficult><bndbox><xmin>1</xmin><ymin>1</ymin><xmax>20</xmax><ymax>10</ymax></bndbox></object></annotation>
  let parsed = VocAnnotation::from_xml(document).unwrap()
  match parsed.filename {
    Some("dog & cat.jpg") => ()
    _ => fail("expected numeric XML entities to be decoded")
  }
  inspect(parsed.objects.length(), content="1")
  inspect(parsed.objects[0].bbox.width, content="20")
}

///|
test "VOC parser rejects invalid XML control character references" {
  let document = "<annotation><filename>bad&#1;name</filename><size><width>20</width><height>10</height></size></annotation>"
  match VocAnnotation::from_xml(document) {
    Err(InvalidVoc(path="annotation.filename", message="invalid XML character")) =>
      ()
    _ => fail("expected invalid XML control rejection")
  }
}
