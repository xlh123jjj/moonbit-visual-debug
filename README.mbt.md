# moonbit-visual-debug

`moonbit-visual-debug` is a MoonBit library for building visual debugging overlays around computer-vision and image-analysis workflows. It models bounding boxes, masks, keypoints, trajectories, heatmaps, and error regions, then renders them as SVG, HTML reports, or PNG snapshots.

The project is intentionally library-first: it does not try to be a detector, segmenter, or SVG engine. It gives those systems a small, typed reporting layer that is easy to run in CI and simple enough to embed in examples, notebooks, demos, and acceptance reports.

## Features

- Geometry primitives for image-space points, rectangles, sizes, and IoU.
- Overlay model for bbox, mask, keypoint, trajectory, heatmap, and error-region views.
- SVG renderer with optional grid, labels, image background, layers, and opacity.
- HTML report renderer with embedded SVG and layer summary.
- RGBA canvas plus pure MoonBit PNG encoder for deterministic smoke-test snapshots.
- Detection comparison helper for true positive, false positive, false negative, and label-mismatch analysis.
- Demo CLI that prints a complete HTML report.

## Install

```bash
moon add xlh123jjj/moonbit-visual-debug
```

For local development:

```bash
moon check --target wasm-gc --deny-warn
moon test --target wasm-gc
moon fmt --deny-warn
moon info --deny-warn
```

Native builds work when a system C compiler is installed. The CI workflow installs the MoonBit toolchain on Ubuntu and runs the same checks.

## Quick Example

```mbt check
test "build a report" {
  let detections = Layer::new(id="detections")
  .add(
    BBox(
      rect=Rect::new(x=12.0, y=10.0, width=48.0, height=36.0),
      label=Some(Label::new(text="part", score=0.91)),
      color=Some(Color::rgb(r=39, g=125, b=255)),
    ),
  )
  .add(
    Keypoints(
      points=[
        Keypoint::new(point=Point::new(x=20.0, y=22.0), name="a"),
        Keypoint::new(point=Point::new(x=48.0, y=35.0), name="b"),
      ],
      color=None,
    ),
  )
  let doc = DebugDocument::new(
    title="inspection",
    image=ImageSpec::new(width=96, height=64),
  )
  .add_layer(detections)
  inspect(doc.overlay_count(), content="2")
  inspect(doc.to_svg().contains("<svg"), content="true")
  inspect(doc.to_html_report().contains("<table>"), content="true")
  inspect(doc.to_png()[1], content="b'\\x50'")
}
```

## Demo CLI

```bash
moon run --target wasm-gc cmd/main > report.html
```

Open `report.html` in a browser to inspect the embedded SVG report. On machines with a C compiler, `moon run cmd/main` also works with the native target.

## Design Boundaries

This package focuses on deterministic overlay generation. It avoids runtime coupling to a specific image library, model framework, dataset format, or UI framework. The PNG backend currently renders rectangular masks by polygon bounds for fast snapshots; detailed polygon geometry is preserved by SVG and HTML reports.

Planned extensions:

- COCO-style detection and keypoint import/export helpers.
- VOC and YOLO box adapters.
- Richer raster polygon filling.
- Report diffing for baseline-vs-current CI artifacts.
- Small browser viewer for filtering layers and inspecting records.

## Competition Fit

The project targets MoonBit ecosystem tooling and application infrastructure. It is meant to be reusable by algorithm developers who need visual acceptance evidence but do not want to build a reporting stack from scratch. Before selecting this topic, nearby Mooncakes packages were checked for overlap; the known SVG-related packages focus on SVG parsing/rendering rather than vision-debug overlay modeling and report generation.

## License

Apache-2.0. See `LICENSE`.
