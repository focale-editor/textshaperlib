# Original font-outline fixture

`curves.otf` is an application-authored CFF font with an empty `.notdef`, a space,
a two-contour cubic `O`, simple `f`/`i` shapes and a distinct triangular `fi`
ligature selected by an actual GSUB `liga` rule. It uses 1,000 units per em and
700-unit advances, except for the 300-unit ligature that overlaps a following glyph. It contains no third-party font artwork.

Regenerate with Python and FontTools:

```bash
python3 test/fixtures/generate.py
```

The fixture checks original CFF control points, winding/counters and shaped
ligatures through HarfBuzz, embedded font registration and the real text compositor.
Focale's application suite separately checks bundled Inter's quadratic/composite outlines,
combining marks, kerning and default/weight-varied TrueType instances.


`fallback.otf` is a separate original CFF program with Greek alpha/beta and Hebrew
aleph/bet, their triangular ligature, a combining acute, a precomposed O-acute and a
supplementary Deseret character. It has distinct metrics and deliberately different
glyphs from `curves.otf`. The native runner exposes only this file through a temporary
Fontconfig directory; the primary face remains an embedded document font. No
installed/user fonts are copied or changed. The same generator rebuilds both files.
