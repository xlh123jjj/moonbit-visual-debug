# Contributing

Thanks for taking a look at `moonbit-visual-debug`.

## Local Checks

Run these before sending changes:

```bash
moon fmt --check
moon check --target wasm-gc --deny-warn
moon test --target wasm-gc --deny-warn
moon info
git diff --exit-code
```

If a C compiler is available, also run:

```bash
moon check --target native --deny-warn
moon test --target native --deny-warn
```

## Patch Guidelines

- Keep public concrete types in the root package unless there is a strong reason to split ownership.
- Add tests for geometry, matching, rendering, or encoding changes.
- Keep generated `pkg.generated.mbti` files in sync with public API changes.
- Document new output formats or report fields in `README.mbt.md`.
