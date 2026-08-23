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
- MoonBit: 0.1.20260807 (4da23f8, 2026-08-07)
- Command: `moon bench visual_bench.mbt --target native --release --deny-warn`

| Benchmark | Mean ± σ | Range | Sample layout |
| --- | ---: | ---: | --- |
| Render 256 overlays to SVG | 860.11 µs ± 46.54 µs | 785.79–929.27 µs | 10 × 119 runs |
| Render 256 overlays to PNG | 8.32 ms ± 313.24 µs | 7.91–8.80 ms | 10 × 12 runs |
