///|
/// Counts overlays by their concrete rendering kind.
pub(all) struct OverlayKindCounts {
  bbox : Int
  mask : Int
  keypoints : Int
  trajectory : Int
  heatmap : Int
  error_region : Int
} derive(Debug, ToJson)

///|
/// Counts diagnostics produced by document validation.
pub(all) struct DiagnosticSeverityCounts {
  info : Int
  warning : Int
  error : Int
} derive(Debug, ToJson)

///|
/// A stable summary of a source layer in a document manifest.
pub(all) struct LayerManifest {
  id : String
  visible : Bool
  opacity : Double
  overlay_count : Int
  overlays : OverlayKindCounts
} derive(Debug, ToJson)

///|
/// A machine-readable, non-mutating summary of a `DebugDocument`.
pub(all) struct DocumentManifest {
  title : String
  image_width : Int
  image_height : Int
  layer_count : Int
  visible_layer_count : Int
  total_overlay_count : Int
  visible_overlay_count : Int
  overlays : OverlayKindCounts
  visible_overlays : OverlayKindCounts
  content_bounds : Rect?
  diagnostics : DiagnosticSeverityCounts
  is_valid : Bool
  layers : Array[LayerManifest]
} derive(Debug, ToJson)

///|
/// Builds a report manifest without changing the document, its layers, or
/// their overlay arrays. Layer entries preserve the document insertion order.
pub fn DebugDocument::manifest(self : DebugDocument) -> DocumentManifest {
  let layers : Array[LayerManifest] = []
  let mut visible_layer_count = 0
  let mut total_overlay_count = 0
  let mut visible_overlay_count = 0
  let mut overlays = empty_overlay_kind_counts()
  let mut visible_overlays = empty_overlay_kind_counts()
  for layer in self.layers {
    let layer_counts = overlay_kind_counts(layer.overlays)
    let overlay_count = layer.overlays.length()
    layers.push({
      id: layer.id,
      visible: layer.visible,
      opacity: layer.opacity,
      overlay_count,
      overlays: layer_counts,
    })
    total_overlay_count += overlay_count
    overlays = add_overlay_kind_counts(overlays, layer_counts)
    if layer.visible {
      visible_layer_count += 1
      visible_overlay_count += overlay_count
      visible_overlays = add_overlay_kind_counts(visible_overlays, layer_counts)
    }
  }
  let diagnostics = diagnostic_severity_counts(self.validate())
  {
    title: self.title,
    image_width: self.image.width,
    image_height: self.image.height,
    layer_count: self.layers.length(),
    visible_layer_count,
    total_overlay_count,
    visible_overlay_count,
    overlays,
    visible_overlays,
    content_bounds: self.content_bounds(),
    diagnostics,
    is_valid: diagnostics.error == 0,
    layers,
  }
}

///|
/// Serializes this manifest using the core `Json` encoder with a stable field
/// order. String values are encoded by `Json::string`, so user input is escaped.
pub fn DocumentManifest::to_json_text(self : DocumentManifest) -> String {
  manifest_to_json(self).stringify()
}

///|
/// Renders a compact CI summary. User-controlled titles and layer IDs are
/// escaped before insertion into Markdown.
pub fn DocumentManifest::to_markdown(self : DocumentManifest) -> String {
  let out = StringBuilder()
  out.write_string("# \{escape_markdown(self.title)}\n\n")
  out.write_string("- Image: \{self.image_width} × \{self.image_height}\n")
  out.write_string(
    "- Layers: \{self.layer_count} total, \{self.visible_layer_count} visible\n",
  )
  out.write_string(
    "- Overlays: \{self.total_overlay_count} total, \{self.visible_overlay_count} visible\n",
  )
  out.write_string(
    "- Validation: \{self.diagnostics.error} errors, \{self.diagnostics.warning} warnings, \{self.diagnostics.info} info\n\n",
  )
  out.write_string("## Layers\n\n")
  out.write_string("| Layer | Visible | Opacity | Overlays |\n")
  out.write_string("| --- | --- | ---: | ---: |\n")
  for layer in self.layers {
    let visible = if layer.visible { "yes" } else { "no" }
    out.write_string(
      "| \{escape_markdown(layer.id)} | \{visible} | \{layer.opacity} | \{layer.overlay_count} |\n",
    )
  }
  out.write_string("\n## Overlay kinds\n\n")
  out.write_string(
    "| BBox | Mask | Keypoints | Trajectory | Heatmap | Error regions |\n",
  )
  out.write_string("| ---: | ---: | ---: | ---: | ---: | ---: |\n")
  out.write_string(
    "| \{self.overlays.bbox} | \{self.overlays.mask} | \{self.overlays.keypoints} | \{self.overlays.trajectory} | \{self.overlays.heatmap} | \{self.overlays.error_region} |\n\n",
  )
  out.write_string("## Content bounds\n\n")
  match self.content_bounds {
    None => out.write_string("None\n")
    Some(bounds) =>
      out.write_string(
        "x=\{bounds.x}, y=\{bounds.y}, width=\{bounds.width}, height=\{bounds.height}\n",
      )
  }
  out.to_string()
}

///|
fn empty_overlay_kind_counts() -> OverlayKindCounts {
  { bbox: 0, mask: 0, keypoints: 0, trajectory: 0, heatmap: 0, error_region: 0 }
}

///|
fn overlay_kind_counts(overlays : Array[Overlay]) -> OverlayKindCounts {
  let mut bbox = 0
  let mut mask = 0
  let mut keypoints = 0
  let mut trajectory = 0
  let mut heatmap = 0
  let mut error_region = 0
  for overlay in overlays {
    match overlay {
      BBox(..) => bbox += 1
      Mask(..) => mask += 1
      Keypoints(..) => keypoints += 1
      Trajectory(..) => trajectory += 1
      Heatmap(..) => heatmap += 1
      ErrorRegion(..) => error_region += 1
    }
  }
  { bbox, mask, keypoints, trajectory, heatmap, error_region }
}

///|
fn add_overlay_kind_counts(
  left : OverlayKindCounts,
  right : OverlayKindCounts,
) -> OverlayKindCounts {
  {
    bbox: left.bbox + right.bbox,
    mask: left.mask + right.mask,
    keypoints: left.keypoints + right.keypoints,
    trajectory: left.trajectory + right.trajectory,
    heatmap: left.heatmap + right.heatmap,
    error_region: left.error_region + right.error_region,
  }
}

///|
fn diagnostic_severity_counts(
  diagnostics : Array[Diagnostic],
) -> DiagnosticSeverityCounts {
  let mut info = 0
  let mut warning = 0
  let mut error = 0
  for diagnostic in diagnostics {
    match diagnostic.level {
      Info => info += 1
      Warning => warning += 1
      Error => error += 1
    }
  }
  { info, warning, error }
}

///|
fn manifest_to_json(manifest : DocumentManifest) -> Json {
  Json::object({
    "title": Json::string(manifest.title),
    "image": Json::object({
      "width": Json::number(manifest.image_width.to_double()),
      "height": Json::number(manifest.image_height.to_double()),
    }),
    "layer_count": Json::number(manifest.layer_count.to_double()),
    "visible_layer_count": Json::number(
      manifest.visible_layer_count.to_double(),
    ),
    "total_overlay_count": Json::number(
      manifest.total_overlay_count.to_double(),
    ),
    "visible_overlay_count": Json::number(
      manifest.visible_overlay_count.to_double(),
    ),
    "overlays": overlay_kind_counts_to_json(manifest.overlays),
    "visible_overlays": overlay_kind_counts_to_json(manifest.visible_overlays),
    "content_bounds": optional_rect_to_json(manifest.content_bounds),
    "diagnostics": diagnostic_severity_counts_to_json(manifest.diagnostics),
    "is_valid": Json::boolean(manifest.is_valid),
    "layers": Json::array(manifest.layers.map(layer_manifest_to_json)),
  })
}

///|
fn layer_manifest_to_json(layer : LayerManifest) -> Json {
  Json::object({
    "id": Json::string(layer.id),
    "visible": Json::boolean(layer.visible),
    "opacity": Json::number(layer.opacity),
    "overlay_count": Json::number(layer.overlay_count.to_double()),
    "overlays": overlay_kind_counts_to_json(layer.overlays),
  })
}

///|
fn overlay_kind_counts_to_json(counts : OverlayKindCounts) -> Json {
  Json::object({
    "bbox": Json::number(counts.bbox.to_double()),
    "mask": Json::number(counts.mask.to_double()),
    "keypoints": Json::number(counts.keypoints.to_double()),
    "trajectory": Json::number(counts.trajectory.to_double()),
    "heatmap": Json::number(counts.heatmap.to_double()),
    "error_region": Json::number(counts.error_region.to_double()),
  })
}

///|
fn optional_rect_to_json(bounds : Rect?) -> Json {
  match bounds {
    None => Json::null()
    Some(rect) =>
      Json::object({
        "x": Json::number(rect.x),
        "y": Json::number(rect.y),
        "width": Json::number(rect.width),
        "height": Json::number(rect.height),
      })
  }
}

///|
fn diagnostic_severity_counts_to_json(
  counts : DiagnosticSeverityCounts,
) -> Json {
  Json::object({
    "info": Json::number(counts.info.to_double()),
    "warning": Json::number(counts.warning.to_double()),
    "error": Json::number(counts.error.to_double()),
  })
}

///|
fn escape_markdown(value : String) -> String {
  value
  .replace_all(old="\\", new="\\\\")
  .replace_all(old="\n", new="\\n")
  .replace_all(old="&", new="&amp;")
  .replace_all(old="<", new="&lt;")
  .replace_all(old=">", new="&gt;")
  .replace_all(old="|", new="\\|")
  .replace_all(old="*", new="\\*")
  .replace_all(old="_", new="\\_")
  .replace_all(old="[", new="\\[")
  .replace_all(old="]", new="\\]")
  .replace_all(old="`", new="\\`")
  .replace_all(old="#", new="\\#")
  .replace_all(old="\"", new="\\\"")
}
