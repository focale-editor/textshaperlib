import 'dart:convert';
import 'dart:typed_data';

import 'package:textshaperlib/src/backend/native.dart' if (dart.library.js_interop) 'package:textshaperlib/src/backend/web.dart' as backend;
import 'package:textshaperlib/src/text_shaping_exception.dart';

/// OpenType shaping with UTF-16 source clusters and original font contours.
///
/// Layout, bidirectional itemization, font fallback and painting belong to the
/// caller. Shape each directional font run with the complete source as context.
abstract final class TextShaperLib {
  /// Loads the browser module; native code assets are ready automatically.
  static Future<void> initialize({String? assetBaseUrl}) => backend.initialize(assetBaseUrl: assetBaseUrl);

  /// Whether synchronous shaping is available in this isolate.
  static bool get isAvailable => backend.isAvailable;

  /// HarfBuzz release actually loaded by this isolate.
  static String get version => backend.version;

  /// Shapes a directional font run, preserving source-relative UTF-16 clusters.
  ///
  /// Glyph offsets, advances and optional SVG contours use y-down pixel units.
  /// Contours are relative to each glyph origin; accumulate advances and add
  /// offsets when painting. A missing glyph has ID zero. A null contour means
  /// unavailable or not requested; an empty contour is a valid spacing glyph.
  /// Feature and variation tags are four printable ASCII characters. Color
  /// fonts retain glyph positions but require a separate color renderer.
  static ShapedText shape({
    required Uint8List font,
    required String text,
    required double fontSize,
    int faceIndex = 0,
    int start = 0,
    int? end,
    String? direction,
    String? script,
    String? language,
    Map<String, int> features = const {},
    Map<String, double> variations = const {},
    bool outlines = true,
  }) {
    final int limit = end ?? text.length;
    if (font.isEmpty ||
        font.length > 16 * 1024 * 1024 ||
        text.length > 65536 ||
        !fontSize.isFinite ||
        fontSize <= 0 ||
        fontSize > 10000 ||
        faceIndex < 0 ||
        faceIndex > 65535 ||
        start < 0 ||
        limit < start ||
        limit > text.length) {
      throw const TextShapingException('limits');
    }
    if (direction != null && !['ltr', 'rtl', 'ttb', 'btt'].contains(direction) ||
        script != null && !RegExp(r'^[A-Za-z]{4}$').hasMatch(script) ||
        language != null && !RegExp(r'^[A-Za-z0-9-]{1,64}$').hasMatch(language) ||
        features.length > 128 ||
        variations.length > 128 ||
        [...features.keys, ...variations.keys].any((tag) => !RegExp(r'^[A-Za-z0-9 ]{4}$').hasMatch(tag)) ||
        features.values.any((value) => value < 0 || value > 0xffffffff) ||
        variations.values.any((value) => !value.isFinite || value.abs() > 1e9)) {
      throw ArgumentError('Invalid OpenType shaping options.');
    }
    final String result = backend.shape(
      font,
      text,
      fontSize,
      faceIndex,
      start,
      limit,
      direction ?? '',
      script ?? '',
      language ?? '',
      features.entries.map((entry) => '${entry.key}=${entry.value}').join(','),
      variations.entries.map((entry) => '${entry.key}=${entry.value}').join(','),
      outlines,
    );
    final Map<String, dynamic> decoded = jsonDecode(result) as Map<String, dynamic>;
    if (decoded['error'] case final String code) {
      throw TextShapingException(code);
    }
    if (decoded['version'] != 1) {
      throw const TextShapingException('abi');
    }
    return ShapedText._(
      glyphs: List.unmodifiable(
        (decoded['glyphs'] as List<dynamic>).map((row) {
          final List<dynamic> values = row as List<dynamic>;
          return ShapedGlyph._(
            id: values[0] as int,
            cluster: values[1] as int,
            xAdvance: (values[2] as num).toDouble(),
            yAdvance: (values[3] as num).toDouble(),
            xOffset: (values[4] as num).toDouble(),
            yOffset: (values[5] as num).toDouble(),
            outline: values[6] as String?,
          );
        }),
      ),
      monochrome: decoded['monochrome'] as bool,
      weight: (decoded['weight'] as num).toDouble(),
      italic: decoded['italic'] as bool,
      underlinePosition: (decoded['underlinePosition'] as num).toDouble(),
      underlineThickness: (decoded['underlineThickness'] as num).toDouble(),
      strikePosition: (decoded['strikePosition'] as num).toDouble(),
      strikeThickness: (decoded['strikeThickness'] as num).toDouble(),
      ascender: (decoded['ascender'] as num).toDouble(),
      descender: (decoded['descender'] as num).toDouble(),
    );
  }
}

/// Immutable shaped glyphs in visual order, with horizontal font metrics.
final class ShapedText {
  /// Glyphs in HarfBuzz's visual traversal order.
  final List<ShapedGlyph> glyphs;

  /// Whether the font can be represented by monochrome contours.
  final bool monochrome;

  /// Weight of the selected font instance before any platform synthesis.
  final double weight;

  /// Whether the selected font instance is italic before platform synthesis.
  final bool italic;

  /// Distance above the baseline in pixels.
  final double ascender;

  /// Distance below the baseline in pixels.
  final double descender;

  /// Font-authored underline offset below the baseline.
  final double underlinePosition;

  /// Font-authored underline stroke width.
  final double underlineThickness;

  /// Font-authored strike-through offset below the baseline.
  final double strikePosition;

  /// Font-authored strike-through stroke width.
  final double strikeThickness;

  /// Creates the validated backend result.
  const ShapedText._({
    required this.glyphs,
    required this.monochrome,
    required this.weight,
    required this.italic,
    required this.ascender,
    required this.descender,
    required this.underlinePosition,
    required this.underlineThickness,
    required this.strikePosition,
    required this.strikeThickness,
  });

  /// Horizontal displacement of the complete run.
  double get xAdvance => glyphs.fold(0, (sum, glyph) => sum + glyph.xAdvance);

  /// Vertical displacement of the complete run.
  double get yAdvance => glyphs.fold(0, (sum, glyph) => sum + glyph.yAdvance);
}

/// One font glyph and its position relative to the current pen.
final class ShapedGlyph {
  /// Font-specific glyph identifier, or zero when missing.
  final int id;

  /// Source UTF-16 offset of the shaping cluster.
  final int cluster;

  /// Horizontal movement after this glyph.
  final double xAdvance;

  /// Downward movement after this glyph.
  final double yAdvance;

  /// Horizontal displacement from the current pen.
  final double xOffset;

  /// Downward displacement from the current pen.
  final double yOffset;

  /// Original SVG path in pixel coordinates, without the glyph placement.
  final String? outline;

  /// Retains one validated glyph returned by the backend.
  const ShapedGlyph._({required this.id, required this.cluster, required this.xAdvance, required this.yAdvance, required this.xOffset, required this.yOffset, required this.outline});
}
