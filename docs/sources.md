# Sources And Scope

This repository contains original MoonBit source written for the MoonBit August hackathon project `moonbit-visual-debug`.

## Ecosystem Check

Before implementation, Mooncakes search results were checked for nearby packages. The closest visible overlap was SVG-oriented tooling such as `Milky2018/svg`, which is a standalone SVG parser and deterministic CPU renderer. This project has a different scope: it models computer-vision debug overlays and emits reports; SVG is only one output backend.

## External References

- MoonBit toolchain documentation and `moon` command behavior.
- MoonBit package layout and `README.mbt.md` doctest conventions.
- PNG file format basics: PNG signature, IHDR/IDAT/IEND chunks, CRC32, Adler-32, and zlib stored blocks.

No third-party source code was copied into the implementation.
