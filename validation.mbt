///|
pub(all) enum DiagnosticLevel {
  Info
  Warning
  Error
} derive(Debug, ToJson)

///|
pub(all) struct Diagnostic {
  level : DiagnosticLevel
  path : String
  message : String
} derive(Debug, ToJson)

///|
pub fn Diagnostic::new(
  level~ : DiagnosticLevel,
  path~ : String,
  message~ : String,
) -> Diagnostic {
  { level, path, message }
}

///|
pub fn DebugDocument::validate(self : DebugDocument) -> Array[Diagnostic] {
  let diagnostics : Array[Diagnostic] = []
  if !self.image.valid() {
    diagnostics.push(
      Diagnostic::new(
        level=Error,
        path="image",
        message="image dimensions must be positive",
      ),
    )
  }
  if self.layers.is_empty() {
    diagnostics.push(
      Diagnostic::new(
        level=Warning,
        path="layers",
        message="document has no layers",
      ),
    )
  }
  for layer_index, layer in self.layers {
    validate_layer(diagnostics, layer, layer_index)
  }
  diagnostics
}

///|
pub fn DebugDocument::is_valid(self : DebugDocument) -> Bool {
  self.validate().all(diag => !(diag.level is Error))
}

///|
fn validate_layer(
  out : Array[Diagnostic],
  layer : Layer,
  layer_index : Int,
) -> Unit {
  let path = "layers[\{layer_index}]"
  if layer.id == "" {
    out.push(Diagnostic::new(level=Warning, path~, message="layer id is empty"))
  }
  if layer.opacity < 0.0 || layer.opacity > 1.0 {
    out.push(
      Diagnostic::new(
        level=Error,
        path~,
        message="layer opacity is outside 0..1",
      ),
    )
  }
  if layer.overlays.is_empty() {
    out.push(
      Diagnostic::new(level=Info, path~, message="layer has no overlays"),
    )
  }
  for overlay_index, overlay in layer.overlays {
    validate_overlay(out, overlay, "\{path}.overlays[\{overlay_index}]")
  }
}

///|
fn validate_overlay(
  out : Array[Diagnostic],
  overlay : Overlay,
  path : String,
) -> Unit {
  match overlay {
    BBox(rect~, ..) => validate_rect(out, rect, path)
    Mask(polygons~, ..) =>
      if polygons.is_empty() {
        out.push(
          Diagnostic::new(level=Warning, path~, message="mask has no polygons"),
        )
      } else {
        for index, polygon in polygons {
          if polygon.length() < 3 {
            out.push(
              Diagnostic::new(
                level=Warning,
                path="\{path}.polygons[\{index}]",
                message="polygon has fewer than three points",
              ),
            )
          }
        }
      }
    Keypoints(points~, ..) =>
      if points.is_empty() {
        out.push(
          Diagnostic::new(
            level=Warning,
            path~,
            message="keypoint overlay has no points",
          ),
        )
      }
    Trajectory(path=trajectory, ..) =>
      if trajectory.points.length() < 2 {
        out.push(
          Diagnostic::new(
            level=Warning,
            path~,
            message="trajectory has fewer than two points",
          ),
        )
      }
    Heatmap(cells~, ..) =>
      if cells.is_empty() {
        out.push(
          Diagnostic::new(level=Warning, path~, message="heatmap has no cells"),
        )
      } else {
        for index, cell in cells {
          validate_rect(out, cell.rect, "\{path}.cells[\{index}]")
          if cell.value < 0.0 || cell.value > 1.0 {
            out.push(
              Diagnostic::new(
                level=Warning,
                path="\{path}.cells[\{index}].value",
                message="heat value is outside 0..1 and will be clamped by renderers",
              ),
            )
          }
        }
      }
    ErrorRegion(rect~, severity~, ..) => {
      validate_rect(out, rect, path)
      if severity < 0.0 || severity > 1.0 {
        out.push(
          Diagnostic::new(
            level=Warning,
            path="\{path}.severity",
            message="severity is outside 0..1 and will be clamped by renderers",
          ),
        )
      }
    }
  }
}

///|
fn validate_rect(out : Array[Diagnostic], rect : Rect, path : String) -> Unit {
  if rect.width <= 0.0 || rect.height <= 0.0 {
    out.push(
      Diagnostic::new(
        level=Error,
        path~,
        message="rectangle size must be positive",
      ),
    )
  }
}
