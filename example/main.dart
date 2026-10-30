import 'dart:io';
import 'dart:typed_data';

import 'package:textshaperlib/textshaperlib.dart';

/// Prints glyph placements for a user-supplied font without a Flutter runtime.
Future<void> main(List<String> arguments) async {
  if (arguments.length != 2) {
    stderr.writeln('Usage: dart run example/main.dart font.ttf "Text to shape"');
    exitCode = 64;
    return;
  }
  await TextShaperLib.initialize();
  final Uint8List bytes = await File(arguments[0]).readAsBytes();
  final ShapedText text = TextShaperLib.shape(font: bytes, text: arguments[1], fontSize: 32);
  for (final ShapedGlyph glyph in text.glyphs) {
    stdout.writeln('glyph=${glyph.id} cluster=${glyph.cluster} advance=(${glyph.xAdvance}, ${glyph.yAdvance}) offset=(${glyph.xOffset}, ${glyph.yOffset})');
  }
}
