<p align="center">
  <img src="screenshots/overview.png" alt="TextShaperLib package illustration" width="180">
</p>

# TextShaperLib

TextShaperLib provides contextual OpenType text shaping and original glyph
contours for Dart. It keeps font discovery, paragraph layout and application
policy outside the package, and uses HarfBuzz 15.0.0 for the same glyph
selection, positioning and outlines on native and browser targets.

## Features

* Contextual shaping with font-specific glyph IDs and UTF-16 source clusters.
* Directional font runs with script, language and source-range settings.
* OpenType feature overrides, including ligatures and kerning.
* Variable-font axes and face selection within font collections.
* Glyph advances, offsets, font metrics and original SVG contours.
* Source-built native code assets and a bundled WebAssembly engine.

The package has no widgets, document model, font fallback resolver or rasterizer.
The caller supplies font bytes and directional runs; TextShaperLib returns the
positioned glyphs. Bidi itemization, line breaking, painting and editing geometry
remain application responsibilities.

## Native setup

Requires Dart 3.13 or later. Add the dependency from pub.dev:

```console
dart pub add textshaperlib
```

The first native build downloads the pinned HarfBuzz source archive into the
application's shared `.dart_tool` hook cache, verifies its SHA-256, compiles it
with the platform C++ toolchain, and bundles the resulting code asset. The
source tree is excluded from the package archive. System HarfBuzz libraries
are neither used nor required; bundled symbols are isolated from them.

For an offline build, download and verify the source before disconnecting:

```console
dart run textshaperlib:prepare_library
```

This places the pinned source beside TextShaperLib's native bridge. The compiler
and Dart dependencies must also be available locally.

The hook declares Android, iOS, Linux, macOS and Windows targets. Linux VM is
validated; application acceptance on the other native platforms remains pending.

## Web setup

Flutter bundles TextShaperLib's precompiled ES module and WebAssembly binary from
its Web-only package assets. Call `initialize` before shaping:

```dart
await TextShaperLib.initialize();
```

The WebAssembly module uses the same verified HarfBuzz archive as native builds
and the pinned Emscripten version recorded in `assets/web/build.json`. Web
consumers need no C compiler or Emscripten installation. Browser acceptance is
currently validated in Chromium.

For plain Dart Web projects, copy `textshaperlib.mjs` and `textshaperlib.wasm`
from `assets/web/` to a public directory and pass its URL to
`TextShaperLib.initialize(assetBaseUrl: ...)`. Relative URLs resolve against the
document base URL, or the worker location inside a Web worker. Serve `.wasm`
files as `application/wasm`. The module loads through a dynamic `import()`,
without an inline script or evaluation permission.

## Usage

```dart
import 'dart:typed_data';

import 'package:textshaperlib/textshaperlib.dart';

ShapedText shapeLabel(Uint8List fontBytes, String text) {
  return TextShaperLib.shape(
    font: fontBytes,
    text: text,
    fontSize: 32,
    direction: 'ltr',
    features: {'liga': 1},
    variations: {'wght': 500},
  );
}
```

Initialize the browser engine before calling the function. Native code assets
are ready automatically; calling `initialize` there is also safe.

Paint each glyph's `outline` at the current pen plus its `xOffset`/`yOffset`, then
advance the pen by `xAdvance`/`yAdvance`. Keep the shaped result for subsequent
paints while the text, font instance and shaping options remain unchanged.

A complete command-line example is included in [example/main.dart](example/main.dart).

## Contextual ranges

Pass the complete source string to `shape`, then select the directional font run
with `start` and `end`. These are UTF-16 code-unit offsets, with `end` exclusive.
Returned clusters refer to the complete source, preserving offsets across
fallback runs and surrounding shaping context.

A glyph is not necessarily one character: ligatures can combine characters and
combining marks can share a cluster. Preserve HarfBuzz's returned glyph order;
do not sort the result by cluster when painting right-to-left text.

## OpenType features and variations

The `features` and `variations` maps use four-character OpenType tags. For
example, `features: {'liga': 0}` disables standard ligatures and
`variations: {'wght': 500}` selects a variable font's weight coordinate.
These settings operate on the supplied font's tables; they do not synthesize
missing typefaces or styles.

Use `faceIndex` to select a face from a font collection. Set `outlines: false`
when only glyph selection, positions and metrics are needed.

## Shaping contract

Glyph offsets, advances, metrics and SVG contours use pixel units with Y
increasing downwards. Each contour is local to the glyph origin. Preserve all
contours in one nonzero-winding compound path so counters remain empty;
boolean-unioning the individual contours fills them.

A missing glyph has ID zero. A null outline is unavailable or was not requested;
an empty outline is a valid spacing glyph. Check `ShapedText.monochrome` before
using monochrome paths. Color fonts provide positions but need a color renderer.
The returned contours are unhinted, so raster edges can differ from a platform's
hinted text rasterizer.

HarfBuzz handles TrueType, CFF and CFF2. Package acceptance uses original CFF
fixtures; Focale's separate application suite covers variable TrueType Inter.
This does not establish acceptance for every font or platform.

Inputs and output sizes are bounded. Invalid shaping options throw
`ArgumentError`; bounds, invalid font programs and backend failures use
`TextShapingException`. See [docs/shaping.md](docs/shaping.md) for limits and
coordinate details.

## Performance

Shaping runs synchronously on the calling isolate. Retain immutable `ShapedText`
results instead of reshaping unchanged text on every frame. Font bytes are copied
for each call; the API does not retain a native font handle between runs.

Use `outlines: false` for measurement when contours are not needed. For large
batches, move work to a background isolate or Web worker. Each browser isolate
must await its own `TextShaperLib.initialize()` before shaping.

## Rebuilding browser assets

Maintainers need Emscripten 4.0.15:

```console
dart run tool/build_web.dart /path/to/emsdk/upstream/emscripten/em++
```

The command downloads and verifies HarfBuzz when needed, then replaces the
browser module in `assets/web/`. It records the source digest, toolchain version
and artifact hashes in `assets/web/build.json`.

See [CONTRIBUTING.md](CONTRIBUTING.md) for validation commands,
[ADR 0001](docs/adr/0001-shared-harfbuzz.md) for the shared engine design, and
[CHANGELOG.md](CHANGELOG.md) for changes.

## License

TextShaperLib is MIT-licensed. See [LICENSE](LICENSE) and
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for the bundled HarfBuzz and
Emscripten licenses, source archive and checksum.

---

Built for **[Focale](https://focale-editor.app)**, an advanced local image editor. Discover what these packages make possible in a real creative workflow.
