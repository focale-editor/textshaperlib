import 'dart:ffi';

/// Shapes a run into owned UTF-8 JSON using the private native bridge.
@Native<Pointer<Char> Function(Pointer<Uint8>, Uint32, Uint32, Pointer<Uint16>, Uint32, Uint32, Uint32, Double, Pointer<Char>, Pointer<Char>, Pointer<Char>, Pointer<Char>, Pointer<Char>, Int32)>(
  symbol: 'textshaper_shape',
)
external Pointer<Char> shapeNative(
  Pointer<Uint8> font,
  int fontLength,
  int faceIndex,
  Pointer<Uint16> text,
  int textLength,
  int start,
  int end,
  double size,
  Pointer<Char> features,
  Pointer<Char> variations,
  Pointer<Char> direction,
  Pointer<Char> script,
  Pointer<Char> language,
  int draw,
);

/// Releases one bridge result in the allocator that created it.
@Native<Void Function(Pointer<Char>)>(symbol: 'textshaper_free')
external void freeNative(Pointer<Char> value);

/// Reports the compiled HarfBuzz version.
@Native<Pointer<Char> Function()>(symbol: 'textshaper_version')
external Pointer<Char> versionNative();
