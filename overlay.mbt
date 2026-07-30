///|
pub(all) struct Label {
  text : String
  score : Double?
} derive(Debug, ToJson)

///|
pub fn Label::new(text~ : String, score? : Double) -> Label {
  { text, score }
}

///|
pub(all) enum MarkerShape {
  Circle
  Square
  Diamond
  Cross
} derive(Debug, ToJson)

///|
pub(all) struct Keypoint {
  point : Point
  name : String
  visible : Bool
} derive(Debug, ToJson)

///|
pub fn Keypoint::new(point~ : Point, name~ : String, visible? : Bool = true) -> Keypoint {
  { point, name, visible }
}

///|
pub(all) struct Trajectory {
  id : String
  points : Array[Point]
} derive(Debug, ToJson)

///|
pub fn Trajectory::new(id~ : String, points~ : Array[Point]) -> Trajectory {
  { id, points }
}

///|
pub(all) struct HeatCell {
  rect : Rect
  value : Double
} derive(Debug, ToJson)

///|
pub fn HeatCell::new(rect~ : Rect, value~ : Double) -> HeatCell {
  { rect, value }
}

///|
pub(all) enum Overlay {
  BBox(rect~ : Rect, label~ : Label?, color~ : Color?)
  Mask(polygons~ : Array[Array[Point]], label~ : Label?, color~ : Color?)
  Keypoints(points~ : Array[Keypoint], color~ : Color?)
  Trajectory(path~ : Trajectory, color~ : Color?)
  Heatmap(cells~ : Array[HeatCell], low~ : Color?, high~ : Color?)
  ErrorRegion(rect~ : Rect, expected~ : String, actual~ : String, severity~ : Double)
} derive(Debug, ToJson)

///|
pub(all) struct Layer {
  id : String
  visible : Bool
  opacity : Double
  overlays : Array[Overlay]
} derive(Debug, ToJson)

///|
pub fn Layer::new(id~ : String, overlays? : Array[Overlay] = []) -> Layer {
  { id, visible: true, opacity: 1.0, overlays }
}

///|
pub fn Layer::hidden(self : Layer) -> Layer {
  {
    id: self.id,
    visible: false,
    opacity: self.opacity,
    overlays: self.overlays,
  }
}

///|
pub fn Layer::with_opacity(self : Layer, opacity : Double) -> Layer {
  {
    id: self.id,
    visible: self.visible,
    opacity: clamp_layer_opacity(opacity),
    overlays: self.overlays,
  }
}

///|
pub fn Layer::add(self : Layer, overlay : Overlay) -> Layer {
  let overlays = self.overlays.copy()
  overlays.push(overlay)
  { id: self.id, visible: self.visible, opacity: self.opacity, overlays }
}

///|
pub(all) struct DebugDocument {
  title : String
  image : ImageSpec
  image_href : String?
  layers : Array[Layer]
} derive(Debug, ToJson)

///|
pub fn DebugDocument::new(
  title~ : String,
  image~ : ImageSpec,
  image_href? : String,
) -> DebugDocument {
  { title, image, image_href, layers: [] }
}

///|
pub fn DebugDocument::add_layer(self : DebugDocument, layer : Layer) -> DebugDocument {
  let layers = self.layers.copy()
  layers.push(layer)
  { title: self.title, image: self.image, image_href: self.image_href, layers }
}

///|
pub fn DebugDocument::overlay_count(self : DebugDocument) -> Int {
  self.layers.fold(init=0, (sum, layer) => sum + layer.overlays.length())
}

///|
pub fn DebugDocument::visible_layers(self : DebugDocument) -> Array[Layer] {
  self.layers.filter(layer => layer.visible)
}

///|
fn clamp_layer_opacity(value : Double) -> Double {
  if value < 0.0 {
    0.0
  } else if value > 1.0 {
    1.0
  } else {
    value
  }
}
