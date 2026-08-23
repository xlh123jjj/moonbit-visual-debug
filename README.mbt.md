# moonbit-visual-debug

Typed visual-debugging reports for MoonBit computer-vision and image-analysis workflows.

## Project Positioning

`moonbit-visual-debug` turns structured algorithm outputs into inspectable visual evidence. It models boxes, masks, keypoints, trajectories, heatmaps, error regions, and detection matches, then renders a deterministic SVG, self-contained HTML report, or PNG snapshot.

It is a library-first reporting layer, not a detector, segmenter, image decoder, or general SVG engine. The package is intended for CI artifacts, experiments, demos, and reviewable visual regression evidence.

## Core Capabilities

- Image-space geometry, intersection, and IoU primitives.
- Typed overlays for bounding boxes, polygon masks, keypoints, trajectories, heatmaps, and error regions.
- SVG and standalone HTML reports with layer metadata.
- Pure MoonBit RGBA canvas and deterministic PNG encoding.
- Detection comparison with true-positive, false-positive, false-negative, and label-mismatch output.
- COCO datasets/results plus YOLO and Pascal VOC box adapters.
- Baseline-versus-candidate document diffs, per-class metrics, and machine-readable manifests.

## Quick Start

```bash
moon add xlh123jjj/moonbit-visual-debug
```

```mbt check
///|
test "build a visual inspection report" {
  let layer = Layer::new(id="detections").add(
    BBox(
      rect=Rect::new(x=12.0, y=10.0, width=48.0, height=36.0),
      label=Some(Label::new(text="part", score=0.91)),
      color=Some(Color::rgb(r=39, g=125, b=255)),
    ),
  )
  let doc = DebugDocument::new(
    title="inspection",
    image=ImageSpec::new(width=96, height=64),
  ).add_layer(layer)
  inspect(doc.overlay_count(), content="1")
  inspect(doc.to_svg().contains("<svg"), content="true")
  inspect(doc.to_html_report().contains("<table>"), content="true")
}
```

## CLI

```bash
moon run --target wasm-gc cmd/main > report.html
```

The command writes a self-contained HTML report to standard output. Open `report.html` in a browser, or attach it to a CI job as a review artifact.

## Dataset Interoperability

`CocoDataset::from_json` accepts a COCO object containing `annotations`, optional `categories`, and image metadata. It validates required IDs and `[x, y, width, height]` boxes, then resolves category names when producing `Detection` values. Scored prediction arrays are handled separately by `CocoResults`. Unknown category IDs remain usable through a stable `category-<id>` fallback label.

```mbt check
///|
test "load COCO annotations" {
  let source =
    #|{"categories":[{"id":1,"name":"part"}],
    #|"annotations":[{"id":7,"image_id":1,"category_id":1,
    #|"bbox":[10,12,20,16]}]}
  match CocoDataset::from_json(source) {
    Ok(dataset) => inspect(dataset.to_detections()[0].label, content="part")
    Err(_) => fail("expected valid COCO data")
  }
}
```

## Architecture

| Component | Responsibility |
| --- | --- |
| `geometry.mbt`, `color.mbt` | Value types and deterministic presentation primitives. |
| `overlay.mbt`, `transform.mbt` | Overlay document model, composition, transforms, and bounds. |
| `svg.mbt`, `report.mbt`, `raster.mbt` | SVG, HTML, canvas, and PNG output backends. |
| `analysis.mbt`, `validation.mbt` | Detection matching, error overlays, and input diagnostics. |
| `dataset.mbt`, `adapter.mbt` | COCO, YOLO, and Pascal VOC interchange. |
| `diff.mbt`, `metrics.mbt`, `manifest.mbt` | CI-ready diffing, evaluation summaries, and stable exports. |

## Benchmarks

`visual_bench.mbt` uses MoonBit's built-in benchmark runner. On the recorded Windows 11 native-release run, rendering 256 labelled overlays averaged 934.37 µs for SVG and 9.39 ms for PNG. See [docs/benchmarks.md](docs/benchmarks.md) for the command, environment, and complete measurements.

Run the same benchmark locally with:

```bash
moon bench visual_bench.mbt --target native --release --deny-warn
```

## Testing

```bash
moon fmt --check
moon check --target wasm-gc --deny-warn
moon test --target wasm-gc --deny-warn
moon check --target native --deny-warn
moon test --target native --deny-warn
moon info --target wasm-gc
git diff --exit-code
```

The suite covers rendering, polygon rasterization, PNG block boundaries, COCO/YOLO/VOC interchange, malformed annotations, matching thresholds, report diffs, metrics, manifests, and diagnostic behavior.

## CI

GitHub Actions installs the current stable MoonBit toolchain, checks formatting and generated interfaces, runs warning-denied wasm-gc tests on Ubuntu, macOS, and Windows, and validates native builds, coverage, and benchmark compilation on Ubuntu.

## Scope

The package deliberately has no runtime dependency on an image library, model framework, dataset host, or browser. Polygon detail is retained in SVG and HTML, and the PNG backend uses deterministic even-odd polygon filling for masks.

## License

Apache-2.0. See `LICENSE`.
