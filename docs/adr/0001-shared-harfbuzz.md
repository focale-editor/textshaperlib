# ADR 0001 — One HarfBuzz bridge for native Dart and WebAssembly

## Status

Accepted.

## Context

Document rendering and editable outline conversion require the same contextual
shaping contract without depending on Flutter. Platform HarfBuzz installations
can conflict with bundled versions through ELF symbol interposition.

## Decision

Compile pinned HarfBuzz sources behind a small stateless C bridge. Keep upstream
thread safety enabled, hide upstream symbols and bind ELF references locally.
Native code assets and browser WebAssembly compile the same bridge. Return
bounded immutable glyph data and original SVG contours through a versioned JSON
contract; free every result on its originating backend. Callers retain ownership
of bidi itemization, fallback selection, layout and rasterization.

The build hook downloads a checksum-verified source archive to its shared output
or reuses an explicitly prepared source directory. The browser artifacts include
a source/toolchain/artifact receipt and all upstream notices.

## Alternatives

* Expose the full generated HarfBuzz ABI: substantially larger surface, native-only
  types and additional resource-lifetime responsibilities for every caller.
* Use a system HarfBuzz: different versions and missing engines across targets.
* Reimplement OpenType in Dart: duplicates a mature shaping engine and its corpus.
* Replace paragraph layout: unrelated Unicode layout and editing responsibilities.

## Consequences

The same shaping results are available without Flutter on VM and browser targets.
JSON adds bounded serialization overhead; application caches should retain shaped
runs instead of reshaping each frame. Font programs are currently copied per
call rather than held by long-lived native handles. Color glyph paint remains a
separate responsibility, explicitly distinguished from valid empty contours.
