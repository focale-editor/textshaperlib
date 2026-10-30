# Contributing to TextShaperLib

Keep changes focused and public APIs independent of Flutter and application
document models. Document coordinates, UTF-16 offsets, ownership and failures.
Prefer immutable results, named constructor parameters and explicit local types.
New shaping behavior needs acceptance against original font fixtures on both VM
and browser.

## Validation

Run the standard checks before submitting a change:

```console
dart pub get
dart format --output=none --set-exit-if-changed .
dart analyze
dart test
dart test --platform chrome
```

Set `CHROME_EXECUTABLE` if Chrome is not available at the default location.
Use a real host application when changing symbol visibility or library ownership:
a VM-only test does not load GTK's competing HarfBuzz library.

## Updating the engine

Keep the source version and SHA-256 in `tool/harfbuzz_source.dart`, the upstream
notices and the version expectation in `test/shaping_test.dart` in sync. Review
upstream license changes. Rebuild browser assets whenever the C bridge, HarfBuzz
version or Emscripten version changes:

```console
dart run tool/build_web.dart /path/to/emsdk/upstream/emscripten/em++
```

The command requires Emscripten 4.0.15. Review the generated receipt in
`assets/web/build.json` and run both backend test suites after rebuilding. Update
the consuming application's dependency and license fingerprints when needed.
Do not commit downloaded source trees or SDK installations.

## Documentation and releases

Keep the README practical; place technical contracts under `docs/` and
architectural decisions under `docs/adr/`. Maintain `screenshots/overview.svg`
and its 512-pixel PNG together, using the shared Focale aperture and palette:

```console
rsvg-convert -w 512 -h 512 screenshots/overview.svg -o screenshots/overview.png
```

Record changes in `CHANGELOG.md`. Follow the repository's commit style, with a
capital after the scope and a final period, for example:
`feat(shaping): Added contextual glyph shaping.`
