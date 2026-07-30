///|
pub(all) struct ReportOptions {
  svg : SvgOptions
  include_metadata : Bool
  theme : String
} derive(Debug, ToJson)

///|
pub fn ReportOptions::default() -> ReportOptions {
  { svg: SvgOptions::default(), include_metadata: true, theme: "light" }
}

///|
pub fn DebugDocument::to_html_report(self : DebugDocument) -> String {
  self.to_html_report_with(ReportOptions::default())
}

///|
pub fn DebugDocument::to_html_report_with(
  self : DebugDocument,
  options : ReportOptions,
) -> String {
  let out = StringBuilder()
  out.write_string("<!doctype html>\n<html lang=\"en\">\n<head>\n")
  out.write_string("<meta charset=\"utf-8\"/>\n")
  out.write_string(
    "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\"/>\n",
  )
  out.write_string("<title>\{escape_html(self.title)}</title>\n")
  out.write_string("<style>\{report_css(options.theme)}</style>\n")
  out.write_string("</head>\n<body>\n")
  out.write_string("<main>\n")
  out.write_string("<header><h1>\{escape_html(self.title)}</h1>")
  out.write_string(
    "<p>\{self.image.width}x\{self.image.height}, \{self.overlay_count()} overlays</p></header>\n",
  )
  out.write_string(
    "<section class=\"stage\">\n\{self.to_svg_with(options.svg)}</section>\n",
  )
  if options.include_metadata {
    write_layer_summary(out, self)
  }
  out.write_string("</main>\n</body>\n</html>\n")
  out.to_string()
}

///|
fn write_layer_summary(out : StringBuilder, doc : DebugDocument) -> Unit {
  out.write_string(
    "<section class=\"summary\"><h2>Layers</h2><table><thead><tr>",
  )
  out.write_string(
    "<th>Layer</th><th>Visible</th><th>Opacity</th><th>Overlays</th>",
  )
  out.write_string("</tr></thead><tbody>\n")
  for layer in doc.layers {
    out.write_string("<tr><td>\{escape_html(layer.id)}</td>")
    out.write_string("<td>\{layer.visible}</td><td>\{layer.opacity}</td>")
    out.write_string("<td>\{layer.overlays.length()}</td></tr>\n")
  }
  out.write_string("</tbody></table></section>\n")
}

///|
fn report_css(theme : String) -> String {
  let dark = theme == "dark"
  let bg = if dark { "#0f172a" } else { "#f8fafc" }
  let fg = if dark { "#e2e8f0" } else { "#0f172a" }
  let panel = if dark { "#111827" } else { "#ffffff" }
  let border = if dark { "#334155" } else { "#cbd5e1" }
  let css =
    $|:root{color-scheme:light dark}
    $|body{margin:0;background:\{bg};color:\{fg};font:14px/1.5 system-ui,-apple-system,Segoe UI,sans-serif}
    $|main{max-width:1120px;margin:0 auto;padding:24px}
    $|header{display:flex;align-items:baseline;justify-content:space-between;gap:16px;margin-bottom:18px}
    $|h1{font-size:24px;margin:0}
    $|h2{font-size:16px;margin:0 0 10px}
    $|p{margin:0;color:#64748b}
    $|.stage{background:\{panel};border:1px solid \{border};overflow:auto}
    $|.stage svg{display:block;max-width:100%;height:auto}
    $|.summary{margin-top:18px}
    $|table{width:100%;border-collapse:collapse;background:\{panel};border:1px solid \{border}}
    $|th,td{text-align:left;padding:8px 10px;border-bottom:1px solid \{border}}
    $|th{font-size:12px;text-transform:uppercase;color:#64748b}
  css
}

///|
fn escape_html(value : String) -> String {
  value
  .replace(old="&", new="&amp;")
  .replace(old="<", new="&lt;")
  .replace(old=">", new="&gt;")
  .replace(old="\"", new="&quot;")
}
