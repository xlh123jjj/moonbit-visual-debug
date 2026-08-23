///|
/// Classifies a layer difference.
pub(all) enum LayerChangeKind {
  Added
  Removed
  Changed
} derive(Debug, ToJson)

///|
/// Describes one added, removed, or changed layer.
pub(all) struct LayerChange {
  id : String
  kind : LayerChangeKind
  baseline_index : Int?
  candidate_index : Int?
  visibility_changed : Bool
  opacity_changed : Bool
  overlay_delta : Int
} derive(Debug, ToJson)

///|
/// Summarizes changes between two visual debugging documents.
pub(all) struct DocumentDiff {
  baseline_title : String
  candidate_title : String
  baseline_image : ImageSpec
  candidate_image : ImageSpec
  baseline_image_href : String?
  candidate_image_href : String?
  title_changed : Bool
  image_size_changed : Bool
  image_href_changed : Bool
  overlay_count_delta : Int
  layer_changes : Array[LayerChange]
} derive(Debug, ToJson)

///|
/// Compares documents without mutating either input.
///
/// Unique non-empty layer IDs match by ID. Duplicate and empty IDs match by
/// their occurrence order among layers with the same ID.
pub fn compare_documents(
  baseline : DebugDocument,
  candidate : DebugDocument,
) -> DocumentDiff {
  let baseline_used = Array::make(baseline.layers.length(), false)
  let candidate_used = Array::make(candidate.layers.length(), false)
  let layer_changes : Array[LayerChange] = []
  for baseline_index, baseline_layer in baseline.layers {
    let id = baseline_layer.id
    if id != "" &&
      layer_id_count(baseline.layers, id) == 1 &&
      layer_id_count(candidate.layers, id) == 1 {
      match unused_layer_with_id(candidate.layers, candidate_used, id) {
        Some(candidate_index) => {
          baseline_used[baseline_index] = true
          candidate_used[candidate_index] = true
          add_changed_layer(
            layer_changes,
            baseline_layer,
            candidate.layers[candidate_index],
            baseline_index,
            candidate_index,
          )
        }
        None => ()
      }
    }
  }
  for baseline_index, baseline_layer in baseline.layers {
    if !baseline_used[baseline_index] {
      let id = baseline_layer.id
      if id == "" ||
        layer_id_count(baseline.layers, id) > 1 ||
        layer_id_count(candidate.layers, id) > 1 {
        match unused_layer_with_id(candidate.layers, candidate_used, id) {
          Some(candidate_index) => {
            baseline_used[baseline_index] = true
            candidate_used[candidate_index] = true
            add_changed_layer(
              layer_changes,
              baseline_layer,
              candidate.layers[candidate_index],
              baseline_index,
              candidate_index,
            )
          }
          None => ()
        }
      }
    }
  }
  for baseline_index, baseline_layer in baseline.layers {
    if !baseline_used[baseline_index] {
      layer_changes.push({
        id: baseline_layer.id,
        kind: Removed,
        baseline_index: Some(baseline_index),
        candidate_index: None,
        visibility_changed: false,
        opacity_changed: false,
        overlay_delta: -baseline_layer.overlays.length(),
      })
    }
  }
  for candidate_index, candidate_layer in candidate.layers {
    if !candidate_used[candidate_index] {
      layer_changes.push({
        id: candidate_layer.id,
        kind: Added,
        baseline_index: None,
        candidate_index: Some(candidate_index),
        visibility_changed: false,
        opacity_changed: false,
        overlay_delta: candidate_layer.overlays.length(),
      })
    }
  }
  {
    baseline_title: baseline.title,
    candidate_title: candidate.title,
    baseline_image: baseline.image,
    candidate_image: candidate.image,
    baseline_image_href: baseline.image_href,
    candidate_image_href: candidate.image_href,
    title_changed: baseline.title != candidate.title,
    image_size_changed: baseline.image != candidate.image,
    image_href_changed: baseline.image_href != candidate.image_href,
    overlay_count_delta: candidate.overlay_count() - baseline.overlay_count(),
    layer_changes,
  }
}

///|
/// Renders a deterministic, self-contained HTML summary of this diff.
pub fn DocumentDiff::to_html(self : DocumentDiff) -> String {
  let out = StringBuilder()
  out.write_string(
    "<!doctype html>\n<html lang=\"en\"><head><meta charset=\"utf-8\"/>",
  )
  out.write_string("<title>Visual document diff</title><style>")
  out.write_string(diff_css())
  out.write_string("</style></head><body><main><h1>Visual document diff</h1>")
  out.write_string("<section><h2>Document</h2><table><tbody>")
  out.write_string("<tr><th>Title</th><td>")
  out.write_string(escape_diff_html(self.baseline_title))
  out.write_string("</td><td>")
  out.write_string(escape_diff_html(self.candidate_title))
  out.write_string("</td></tr><tr><th>Image</th><td>")
  out.write_string(
    "\{self.baseline_image.width}×\{self.baseline_image.height}",
  )
  out.write_string("</td><td>")
  out.write_string(
    "\{self.candidate_image.width}×\{self.candidate_image.height}",
  )
  out.write_string("</td></tr><tr><th>Image href</th><td>")
  out.write_string(escape_diff_html(image_href_text(self.baseline_image_href)))
  out.write_string("</td><td>")
  out.write_string(escape_diff_html(image_href_text(self.candidate_image_href)))
  out.write_string("</td></tr><tr><th>Overlay delta</th><td colspan=\"2\">")
  out.write_string(
    "\{self.overlay_count_delta}</td></tr></tbody></table></section>",
  )
  out.write_string("<section><h2>Layer changes</h2><table><thead><tr>")
  out.write_string(
    "<th>Layer</th><th>Change</th><th>Baseline</th><th>Candidate</th>",
  )
  out.write_string(
    "<th>Visible</th><th>Opacity</th><th>Overlays</th></tr></thead><tbody>",
  )
  for change in self.layer_changes {
    out.write_string("<tr><td>")
    out.write_string(escape_diff_html(change.id))
    out.write_string("</td><td>\{layer_change_name(change.kind)}</td><td>")
    out.write_string(index_text(change.baseline_index))
    out.write_string("</td><td>")
    out.write_string(index_text(change.candidate_index))
    out.write_string("</td><td>\{change.visibility_changed}</td><td>")
    out.write_string(
      "\{change.opacity_changed}</td><td>\{change.overlay_delta}</td></tr>",
    )
  }
  out.write_string("</tbody></table></section></main></body></html>\n")
  out.to_string()
}

///|
fn layer_id_count(layers : Array[Layer], id : String) -> Int {
  layers.fold(init=0, (count, layer) => {
    count + (if layer.id == id { 1 } else { 0 })
  })
}

///|
fn unused_layer_with_id(
  layers : Array[Layer],
  used : Array[Bool],
  id : String,
) -> Int? {
  let mut found : Int? = None
  for index, layer in layers {
    if found is None && !used[index] && layer.id == id {
      found = Some(index)
    }
  }
  found
}

///|
fn add_changed_layer(
  changes : Array[LayerChange],
  baseline : Layer,
  candidate : Layer,
  baseline_index : Int,
  candidate_index : Int,
) -> Unit {
  let visibility_changed = baseline.visible != candidate.visible
  let opacity_changed = baseline.opacity != candidate.opacity
  let overlay_delta = candidate.overlays.length() - baseline.overlays.length()
  if visibility_changed || opacity_changed || overlay_delta != 0 {
    changes.push({
      id: baseline.id,
      kind: Changed,
      baseline_index: Some(baseline_index),
      candidate_index: Some(candidate_index),
      visibility_changed,
      opacity_changed,
      overlay_delta,
    })
  }
}

///|
fn layer_change_name(kind : LayerChangeKind) -> String {
  match kind {
    Added => "added"
    Removed => "removed"
    Changed => "changed"
  }
}

///|
fn index_text(index : Int?) -> String {
  match index {
    Some(value) => "\{value}"
    None => "—"
  }
}

///|
fn image_href_text(image_href : String?) -> String {
  match image_href {
    Some(value) => value
    None => "—"
  }
}

///|
fn escape_diff_html(value : String) -> String {
  let out = StringBuilder()
  for char in value {
    match char {
      '&' => out.write_string("&amp;")
      '<' => out.write_string("&lt;")
      '>' => out.write_string("&gt;")
      '"' => out.write_string("&quot;")
      '\'' => out.write_string("&#39;")
      _ => out.write_char(char)
    }
  }
  out.to_string()
}

///|
fn diff_css() -> String {
  "body{margin:0;background:#f8fafc;color:#0f172a;font:14px/1.5 system-ui,sans-serif}main{max-width:960px;margin:0 auto;padding:24px}h1{margin:0 0 20px}h2{font-size:16px;margin:20px 0 8px}table{width:100%;border-collapse:collapse;background:#fff}th,td{text-align:left;padding:8px;border:1px solid #cbd5e1}th{background:#e2e8f0}"
}
