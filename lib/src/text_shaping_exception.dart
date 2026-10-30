/// A bounded shaping operation could not produce a usable result.
final class TextShapingException implements Exception {
  /// Stable failure category: limits, font, shape, abi or unavailable.
  final String code;

  /// Creates a typed backend failure without application-specific policy.
  const TextShapingException(this.code);

  @override
  String toString() => 'TextShapingException($code)';
}
