# Shaping contract

## Source ranges and glyph placement

Shape each directional font run using `start`/`end` within the complete source
string. Cluster offsets always refer to that original UTF-16 source. Callers own
bidi itemization, fallback discovery, line breaking, paint and editing geometry.

Each glyph's `outline` is relative to its origin. Add `xOffset`/`yOffset` to the
current pen before drawing, then advance by `xAdvance`/`yAdvance`. All coordinates
use pixels with Y increasing downwards. Preserve contours in a single
nonzero-winding compound path: boolean-unioning them fills counters.

The paths are original unhinted outlines, so raster edges can differ from a
platform's hinted text rasterizer. No rasterizer is included.

## Missing glyphs and font coverage

A missing glyph has ID zero. A null outline is unavailable or was not requested;
an empty outline is a valid spacing glyph. Color fonts return positions but
require a separate color renderer; inspect `ShapedText.monochrome` before using
monochrome paths.

TrueType, CFF and CFF2 are handled by HarfBuzz. Package acceptance uses original
CFF fixtures. Focale's separate application suite covers the variable TrueType
Inter font; this does not establish acceptance for every font format or platform.

## Bounds and failures

The bridge bounds font bytes (16 MiB), UTF-16 input (65,536 code units), output
glyphs (131,072), outline commands (262,144) and serialized output (16 MiB).
Font size must be finite, positive and at most 10,000 pixels. Feature and
variation maps accept up to 128 entries each.

Invalid shaping options throw `ArgumentError`. Input bounds, invalid font
programs and backend failures throw `TextShapingException`. Await initialization
before calling synchronous shaping in a browser isolate.

## Engine provenance

Native builds and the bundled WebAssembly artifacts use the release and archive
digest pinned in `tool/harfbuzz_source.dart`. Browser builds also pin Emscripten;
`assets/web/build.json` records the source digest, toolchain and artifact hashes.

See [ADR 0001](adr/0001-shared-harfbuzz.md) for symbol isolation and ownership,
[contributing](../CONTRIBUTING.md) for rebuilding, and
[third-party notices](../THIRD_PARTY_NOTICES.md) for licenses.
