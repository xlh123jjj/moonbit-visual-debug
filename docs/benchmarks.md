# Benchmarks

`visual_bench.mbt` measures rendering a `DebugDocument` containing 256 labelled bounding-box overlays. The benchmark uses MoonBit's built-in runner and retains output through `b.keep`, so the render operation is not optimized away.

## Reproduce

```bash
moon bench visual_bench.mbt --target native --release --deny-warn
```

Use the native release target for comparable results. Measurements vary with CPU, compiler version, power state, and operating-system load, so this document records a run rather than imposing a CI timing threshold.

## Recorded Run

- Date: 2026-08-24
- OS: Windows 11 Home, 64-bit (10.0.26200)
- CPU: Intel Core i9-14900HX
- MoonBit: 0.1.20260824 (dae026a, 2026-08-24)
- Command: `moon bench visual_bench.mbt --target native --release --deny-warn`

| Benchmark | Mean ± σ | Range | Sample layout |
| --- | ---: | ---: | --- |
| Render 256 overlays to SVG | 1.04 ms ± 34.31 µs | 979.64 µs–1.07 ms | 10 × 97 runs |
| Render 256 overlays to PNG | 9.09 ms ± 1.03 ms | 8.20–10.91 ms | 10 × 11 runs |
