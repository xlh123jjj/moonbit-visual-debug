# Design Notes

## Problem

Computer-vision projects usually need a way to explain failures: a bounding box is offset, a keypoint is missing, a mask covers the wrong object, or a heatmap highlights an unexpected region. These issues are easiest to review visually, but many projects solve the report layer with one-off scripts.

`moonbit-visual-debug` keeps that report layer typed and reusable.

## Package Shape

The root package owns all public concrete types. This keeps construction, methods, pattern matching, generated interfaces, and examples easy to read:

- `geometry.mbt`: image size, points, rectangles, intersection, IoU.
- `color.mbt`: RGBA color helpers and stable palette.
- `overlay.mbt`: labels, keypoints, trajectories, heat cells, layers, documents.
- `svg.mbt`: SVG rendering.
- `report.mbt`: self-contained HTML report rendering.
- `raster.mbt`: RGBA canvas and PNG encoding.
- `analysis.mbt`: detection matching and error-layer generation.
- `dataset.mbt`: COCO annotation/category validation, serialization, and conversion to detections.
- `diff.mbt`: baseline-versus-candidate document summaries and HTML output.

## Rendering Strategy

SVG is the primary presentation backend because it keeps vector details, text labels, and layered structure inspectable. HTML wraps SVG with metadata that can be opened locally or published as a CI artifact.

PNG is intentionally deterministic and dependency-light. The current encoder uses zlib stored blocks instead of compressed DEFLATE, which keeps the implementation small and portable. This is adequate for snapshots and smoke tests; production compression can be added later without changing the public document model.

## Error Analysis

The matcher uses greedy IoU assignment over unused predictions. It is simple, predictable, and good enough for debugging overlays. More specialized matching policies can be added later as separate functions without changing `MatchSummary`.

## Document Diffing

`compare_documents` produces a side-effect-free CI summary. Unique, non-empty layer IDs match by ID; duplicate and empty IDs pair by occurrence order within the same ID, making output stable across runs. `DocumentDiff::to_html` emits a self-contained, escaped HTML artifact for visual review.

## Non-goals

- It does not run neural networks.
- It does not decode external image formats.
- It does not replace a full plotting library.
- It does not depend on a browser or native graphics stack for core rendering.
