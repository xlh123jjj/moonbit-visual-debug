///|
pub(all) struct Color {
  r : Int
  g : Int
  b : Int
  a : Double
} derive(Debug, ToJson)

///|
pub fn Color::rgb(r~ : Int, g~ : Int, b~ : Int) -> Color {
  { r: clamp_byte(r), g: clamp_byte(g), b: clamp_byte(b), a: 1.0 }
}

///|
pub fn Color::rgba(r~ : Int, g~ : Int, b~ : Int, a~ : Double) -> Color {
  { r: clamp_byte(r), g: clamp_byte(g), b: clamp_byte(b), a: clamp_alpha(a) }
}

///|
pub fn Color::with_alpha(self : Color, alpha : Double) -> Color {
  { r: self.r, g: self.g, b: self.b, a: clamp_alpha(alpha) }
}

///|
pub fn Color::to_css(self : Color) -> String {
  if self.a >= 1.0 {
    "rgb(\{self.r},\{self.g},\{self.b})"
  } else {
    "rgba(\{self.r},\{self.g},\{self.b},\{self.a})"
  }
}

///|
pub fn Color::to_hex(self : Color) -> String {
  "#\{hex_byte(self.r)}\{hex_byte(self.g)}\{hex_byte(self.b)}"
}

///|
pub fn palette(index : Int) -> Color {
  let colors = [
    Color::rgb(r=39, g=125, b=255),
    Color::rgb(r=255, g=99, b=72),
    Color::rgb(r=16, g=185, b=129),
    Color::rgb(r=245, g=158, b=11),
    Color::rgb(r=168, g=85, b=247),
    Color::rgb(r=20, g=184, b=166),
    Color::rgb(r=236, g=72, b=153),
    Color::rgb(r=100, g=116, b=139),
  ]
  colors[index % colors.length()]
}

///|
fn clamp_byte(value : Int) -> Int {
  if value < 0 {
    0
  } else if value > 255 {
    255
  } else {
    value
  }
}

///|
fn clamp_alpha(value : Double) -> Double {
  if value < 0.0 {
    0.0
  } else if value > 1.0 {
    1.0
  } else {
    value
  }
}

///|
fn hex_digit(value : Int) -> String {
  match value {
    0 => "0"
    1 => "1"
    2 => "2"
    3 => "3"
    4 => "4"
    5 => "5"
    6 => "6"
    7 => "7"
    8 => "8"
    9 => "9"
    10 => "a"
    11 => "b"
    12 => "c"
    13 => "d"
    14 => "e"
    _ => "f"
  }
}

///|
fn hex_byte(value : Int) -> String {
  let v = clamp_byte(value)
  hex_digit(v / 16) + hex_digit(v % 16)
}
