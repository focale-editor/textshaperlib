import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:textshaperlib/src/native/bindings.dart';
import 'package:textshaperlib/src/text_shaping_exception.dart';

/// Native code assets are resolved by Dart before execution.
Future<void> initialize({String? assetBaseUrl}) async {}

/// Native calls are available without asynchronous module loading.
bool get isAvailable => true;

/// The upstream release compiled into the code asset.
String get version => versionNative().cast<Utf8>().toDartString();

/// Copies inputs into bounded native memory and releases every temporary.
String shape(Uint8List font, String text, double size, int face, int start, int end, String direction, String script, String language, String features, String variations, bool outlines) =>
    using((arena) {
      final Pointer<Uint8> bytes = arena<Uint8>(font.length)..asTypedList(font.length).setAll(0, font);
      final Pointer<Uint16> characters = arena<Uint16>(text.length + 1)..asTypedList(text.length).setAll(0, text.codeUnits);

      /// Keeps an encoded option alive until the bridge returns.
      Pointer<Char> string(String value) => value.toNativeUtf8(allocator: arena).cast();
      final Pointer<Char> result = shapeNative(
        bytes,
        font.length,
        face,
        characters,
        text.length,
        start,
        end,
        size,
        string(features),
        string(variations),
        string(direction),
        string(script),
        string(language),
        outlines ? 1 : 0,
      );
      if (result == nullptr) {
        throw const TextShapingException('limits');
      }
      try {
        return result.cast<Utf8>().toDartString();
      } finally {
        freeNative(result);
      }
    });
