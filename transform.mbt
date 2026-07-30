///|
pub(all) struct Affine2D {
  sx : Double
  sy : Double
  tx : Double
  ty : Double
} derive(Debug, ToJson)

///|
pub fn Affine2D::identity() -> Affine2D {
  { sx: 1.0, sy: 1.0, tx: 0.0, ty: 0.0 }
}

///|
pub fn Affine2D::scale(sx~ : Double, sy~ : Double) -> Affine2D {
  { sx, sy, tx: 0.0, ty: 0.0 }
}

///|
pub fn Affine2D::translate(tx~ : Double, ty~ : Double) -> Affine2D {
  { sx: 1.0, sy: 1.0, tx, ty }
}

///|
pub fn Affine2D::then(self : Affine2D, next : Affine2D) -> Affine2D {
  {
    sx: self.sx * next.sx,
    sy: self.sy * next.sy,
    tx: self.tx * next.sx + next.tx,
    ty: self.ty * next.sy + next.ty,
  }
}

///|
pub fn Affine2D::apply_point(self : Affine2D, point : Point) -> Point {
  Point::new(x=point.x * self.sx + self.tx, y=point.y * self.sy + self.ty)
}

///|
pub fn Affine2D::apply_rect(self : Affine2D, rect : Rect) -> Rect {
  Rect::new(
    x=rect.x * self.sx + self.tx,
    y=rect.y * self.sy + self.ty,
    width=rect.width * self.sx,
    height=rect.height * self.sy,
  )
}

///|
pub fn Overlay::transform(self : Overlay, affine : Affine2D) -> Overlay {
  match self {
    BBox(rect~, label~, color~) =>
      BBox(rect=affine.apply_rect(rect), label~, color~)
    Mask(polygons~, label~, color~) =>
      Mask(
        polygons=polygons.map(poly => poly.map(p => affine.apply_point(p))),
        label~,
        color~,
      )
    Keypoints(points~, color~) =>
      Keypoints(
        points=points.map(point => {
          point: affine.apply_point(point.point),
          name: point.name,
          visible: point.visible,
        }),
        color~,
      )
    Trajectory(path~, color~) =>
      Trajectory(
        path=Trajectory::new(
          id=path.id,
          points=path.points.map(p => affine.apply_point(p)),
        ),
        color~,
      )
    Heatmap(cells~, low~, high~) =>
      Heatmap(
        cells=cells.map(cell => {
          HeatCell::new(rect=affine.apply_rect(cell.rect), value=cell.value)
        }),
        low~,
        high~,
      )
    ErrorRegion(rect~, expected~, actual~, severity~) =>
      ErrorRegion(rect=affine.apply_rect(rect), expected~, actual~, severity~)
  }
}

///|
pub fn Layer::transform(self : Layer, affine : Affine2D) -> Layer {
  {
    id: self.id,
    visible: self.visible,
    opacity: self.opacity,
    overlays: self.overlays.map(overlay => overlay.transform(affine)),
  }
}

///|
pub fn DebugDocument::resize(
  self : DebugDocument,
  width~ : Int,
  height~ : Int,
) -> DebugDocument {
  let sx = width.to_double() / self.image.width.to_double()
  let sy = height.to_double() / self.image.height.to_double()
  let affine = Affine2D::scale(sx~, sy~)
  {
    title: self.title,
    image: ImageSpec::new(width~, height~),
    image_href: self.image_href,
    layers: self.layers.map(layer => layer.transform(affine)),
  }
}

///|
pub fn Overlay::bounds(self : Overlay) -> Rect? {
  match self {
    BBox(rect~, ..) => Some(rect)
    Mask(polygons~, ..) => bounds_of_polygons(polygons)
    Keypoints(points~, ..) =>
      bounds_of_points_public(
        points.filter_map(kp => if kp.visible { Some(kp.point) } else { None }),
      )
    Trajectory(path~, ..) => bounds_of_points_public(path.points)
    Heatmap(cells~, ..) => bounds_of_rects(cells.map(cell => cell.rect))
    ErrorRegion(rect~, ..) => Some(rect)
  }
}

///|
pub fn Layer::bounds(self : Layer) -> Rect? {
  bounds_of_rects(self.overlays.filter_map(overlay => overlay.bounds()))
}

///|
pub fn DebugDocument::content_bounds(self : DebugDocument) -> Rect? {
  bounds_of_rects(self.layers.filter_map(layer => layer.bounds()))
}

///|
fn bounds_of_polygons(polygons : Array[Array[Point]]) -> Rect? {
  let points : Array[Point] = []
  for polygon in polygons {
    points.append(polygon)
  }
  bounds_of_points_public(points)
}

///|
fn bounds_of_points_public(points : Array[Point]) -> Rect? {
  match points.get(0) {
    None => None
    Some(first) => {
      let mut min_x = first.x
      let mut min_y = first.y
      let mut max_x = first.x
      let mut max_y = first.y
      for point in points {
        if point.x < min_x {
          min_x = point.x
        }
        if point.y < min_y {
          min_y = point.y
        }
        if point.x > max_x {
          max_x = point.x
        }
        if point.y > max_y {
          max_y = point.y
        }
      }
      Some(
        Rect::new(x=min_x, y=min_y, width=max_x - min_x, height=max_y - min_y),
      )
    }
  }
}

///|
fn bounds_of_rects(rects : Array[Rect]) -> Rect? {
  match rects.get(0) {
    None => None
    Some(first) => {
      let mut min_x = first.x
      let mut min_y = first.y
      let mut max_x = first.right()
      let mut max_y = first.bottom()
      for rect in rects {
        if rect.x < min_x {
          min_x = rect.x
        }
        if rect.y < min_y {
          min_y = rect.y
        }
        if rect.right() > max_x {
          max_x = rect.right()
        }
        if rect.bottom() > max_y {
          max_y = rect.bottom()
        }
      }
      Some(
        Rect::new(x=min_x, y=min_y, width=max_x - min_x, height=max_y - min_y),
      )
    }
  }
}
