import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:textshaperlib/textshaperlib.dart';

import 'fixtures/load_native.dart' if (dart.library.js_interop) 'fixtures/load_web.dart';

void main() {
  late Uint8List font;
  late Uint8List fallback;
  setUpAll(() async {
    await TextShaperLib.initialize(assetBaseUrl: '../assets/web/');
    font = await loadFont('curves.otf');
    fallback = await loadFont('fallback.otf');
  });
  test('original CFF contours, ligatures and feature overrides', () {
    final ShapedText shaped = TextShaperLib.shape(font: font, text: 'Ofi O', fontSize: 100);
    expect(TextShaperLib.version, '15.0.0');
    expect(shaped.glyphs.map((glyph) => glyph.cluster), [0, 1, 3, 4]);
    expect(shaped.glyphs.first.outline, contains('C'));
    expect(shaped.glyphs.first.outline!.split('M').length, 3);
    expect(shaped.glyphs[2].outline, '');
    expect(TextShaperLib.shape(font: font, text: 'fi', fontSize: 100, features: {'liga': 0}).glyphs, hasLength(2));
  });
  test('contextual ranges retain absolute UTF-16 clusters and RTL order', () {
    final ShapedText shaped = TextShaperLib.shape(font: fallback, text: 'O אב O', start: 2, end: 4, direction: 'rtl', fontSize: 40);
    expect(shaped.glyphs.every((glyph) => glyph.id != 0), isTrue);
    expect(shaped.glyphs.first.cluster, inInclusiveRange(2, 3));
    final ShapedText supplementary = TextShaperLib.shape(font: fallback, text: 'O\u{10400}O', start: 1, end: 3, fontSize: 40);
    expect(supplementary.glyphs.single.cluster, 1);
  });
  test('missing glyphs, invalid programs and bounded inputs are explicit', () {
    expect(TextShaperLib.shape(font: font, text: 'α', fontSize: 20).glyphs.single.id, 0);
    expect(() => TextShaperLib.shape(font: Uint8List(12), text: 'O', fontSize: 20), throwsA(isA<TextShapingException>()));
    expect(() => TextShaperLib.shape(font: font, text: 'O', fontSize: double.nan), throwsA(isA<TextShapingException>()));
    expect(() => TextShaperLib.shape(font: font, text: 'O', fontSize: 20, features: {'bad': 1}), throwsArgumentError);
    expect(TextShaperLib.shape(font: font, text: '', fontSize: 20).glyphs, isEmpty);
  });
}
