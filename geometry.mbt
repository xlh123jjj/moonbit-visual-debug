///|
pub(all) struct ImageSpec {
  width : Int
  height : Int
} derive(Debug, Eq, ToJson)

///|
pub fn ImageSpec::new(width~ : Int, height~ : Int) -> ImageSpec {
  { width, height }
}

///|
pub fn ImageSpec::area(self : ImageSpec) -> Int {
  self.width * self.height
}

///|
pub fn ImageSpec::valid(self : ImageSpec) -> Bool {
  self.width > 0 && self.height > 0
}

///|
pub(all) struct Point {
  x : Double
  y : Double
} derive(Debug, ToJson)

///|
pub fn Point::new(x~ : Double, y~ : Double) -> Point {
  { x, y }
}

///|
pub fn Point::translate(self : Point, dx~ : Double, dy~ : Double) -> Point {
  { x: self.x + dx, y: self.y + dy }
}

///|
pub fn Point::scale(self : Point, sx~ : Double, sy~ : Double) -> Point {
  { x: self.x * sx, y: self.y * sy }
}

///|
pub(all) struct Size {
  width : Double
  height : Double
} derive(Debug, ToJson)

///|
pub fn Size::new(width~ : Double, height~ : Double) -> Size {
  { width, height }
}

///|
pub(all) struct Rect {
  x : Double
  y : Double
  width : Double
  height : Double
} derive(Debug, ToJson)

///|
pub fn Rect::new(x~ : Double, y~ : Double, width~ : Double, height~ : Double) -> Rect {
  { x, y, width, height }
}

///|
pub fn Rect::right(self : Rect) -> Double {
  self.x + self.width
}

///|
pub fn Rect::bottom(self : Rect) -> Double {
  self.y + self.height
}

///|
pub fn Rect::area(self : Rect) -> Double {
  if self.width <= 0.0 || self.height <= 0.0 {
    0.0
  } else {
    self.width * self.height
  }
}

///|
pub fn Rect::translate(self : Rect, dx~ : Double, dy~ : Double) -> Rect {
  { x: self.x + dx, y: self.y + dy, width: self.width, height: self.height }
}

///|
pub fn Rect::scale(self : Rect, sx~ : Double, sy~ : Double) -> Rect {
  {
    x: self.x * sx,
    y: self.y * sy,
    width: self.width * sx,
    height: self.height * sy,
  }
}

///|
pub fn Rect::intersects(self : Rect, other : Rect) -> Bool {
  self.x < other.right() &&
  other.x < self.right() &&
  self.y < other.bottom() &&
  other.y < self.bottom()
}

///|
pub fn Rect::intersection(self : Rect, other : Rect) -> Rect? {
  let left = max_double(self.x, other.x)
  let top = max_double(self.y, other.y)
  let right = min_double(self.right(), other.right())
  let bottom = min_double(self.bottom(), other.bottom())
  if right <= left || bottom <= top {
    None
  } else {
    Some(Rect::new(x=left, y=top, width=right - left, height=bottom - top))
  }
}

///|
pub fn Rect::iou(self : Rect, other : Rect) -> Double {
  match self.intersection(other) {
    None => 0.0
    Some(overlap) => {
      let inter = overlap.area()
      let union = self.area() + other.area() - inter
      if union <= 0.0 {
        0.0
      } else {
        inter / union
      }
    }
  }
}

///|
fn min_double(a : Double, b : Double) -> Double {
  if a < b { a } else { b }
}

///|
fn max_double(a : Double, b : Double) -> Double {
  if a > b { a } else { b }
}
