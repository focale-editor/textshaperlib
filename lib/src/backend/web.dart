import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:textshaperlib/src/text_shaping_exception.dart';
import 'package:web/web.dart' as web;

/// Browser module, retained once loaded.
_Module? _module;

/// Shared loading operation, cleared on failure so a retry is possible.
Future<void>? _loading;

/// Absolute module location chosen on first initialization.
String? _url;

/// Loads the same HarfBuzz release as the native backend.
Future<void> initialize({String? assetBaseUrl}) async {
  final String base = assetBaseUrl ?? 'assets/packages/textshaperlib/assets/web/';
  final String origin = globalContext.has('document') ? web.document.baseURI : globalContext.getProperty<web.WorkerLocation>('location'.toJS).href;
  final String url = web.URL('${base.endsWith('/') ? base : '$base/'}textshaperlib.mjs', origin).href;
  if (_url != null && url != _url) {
    throw StateError('TextShaperLib asset URL cannot change after initialization.');
  }
  _url = url;
  try {
    await (_loading ??= _load(url));
  } on Object {
    _loading = null;
    rethrow;
  }
}

/// Imports a packaged ES module without eval or an inline script.
Future<void> _load(String url) async {
  final _Exports exports = _Exports(await importModule(url.toJS).toDart.timeout(const Duration(seconds: 30)));
  _module = await exports.create().toDart.timeout(const Duration(seconds: 60));
}

/// Whether initialization completed in this browser isolate.
bool get isAvailable => _module != null;

/// Loaded upstream release.
String get version => _ready.readString(_ready.version());

/// Requires an explicitly initialized browser module.
_Module get _ready => _module ?? (throw const TextShapingException('unavailable'));

/// Shapes within WebAssembly and releases all caller-owned linear memory.
String shape(Uint8List font, String text, double size, int face, int start, int end, String direction, String script, String language, String features, String variations, bool outlines) {
  final _Module module = _ready;
  final List<int> allocations = [];

  /// Copies a terminated input into caller-owned linear memory.
  int copy(Uint8List bytes) {
    final int pointer = module.allocate(bytes.length + 1);
    if (pointer == 0) {
      throw const TextShapingException('limits');
    }
    allocations.add(pointer);
    final Uint8List payload = Uint8List(bytes.length + 1)..setRange(0, bytes.length, bytes);
    module.heap.set(payload.toJS, pointer);
    return pointer;
  }

  /// Encodes an ASCII/UTF-8 option for the shared bridge.
  int string(String value) => copy(utf8.encode(value));
  try {
    final Uint16List characters = Uint16List.fromList([...text.codeUnits, 0]);
    final int fontPointer = copy(font);
    final int textPointer = copy(characters.buffer.asUint8List());
    final int featuresPointer = string(features);
    final int variationsPointer = string(variations);
    final int directionPointer = string(direction);
    final int scriptPointer = string(script);
    final int languagePointer = string(language);
    final int result = module.shape(
      fontPointer,
      font.length,
      face,
      textPointer,
      text.length,
      start,
      end,
      size,
      featuresPointer,
      variationsPointer,
      directionPointer,
      scriptPointer,
      languagePointer,
      outlines ? 1 : 0,
    );
    if (result == 0) {
      throw const TextShapingException('limits');
    }
    try {
      return module.readString(result);
    } finally {
      module.releaseResult(result);
    }
  } finally {
    for (final int pointer in allocations) {
      module.release(pointer);
    }
  }
}

/// Bulk copy into the current WebAssembly memory view.
extension on JSUint8Array {
  /// Copies bytes without retaining a view across memory growth.
  external void set(JSUint8Array bytes, int offset);
}

/// The dynamically imported ES module namespace.
extension type _Exports(JSObject _) implements JSObject {
  /// Instantiates the bundled WebAssembly module.
  @JS('default')
  external JSPromise<_Module> create();
}

/// Small shared native/WebAssembly bridge contract.
extension type _Module(JSObject _) implements JSObject {
  /// Current memory view, refreshed after allocating or shaping.
  @JS('HEAPU8')
  external JSUint8Array get heap;

  /// Allocates input memory.
  @JS('_malloc')
  external int allocate(int size);

  /// Releases input memory.
  @JS('_free')
  external void release(int pointer);

  /// Releases a bridge result.
  @JS('_textshaper_free')
  external void releaseResult(int pointer);

  /// Shapes the contextual font run into an owned result.
  @JS('_textshaper_shape')
  external int shape(int bytes, int length, int face, int text, int textLength, int start, int end, double size, int features, int variations, int direction, int script, int language, int draw);

  /// Reads an owned UTF-8 result before release.
  @JS('UTF8ToString')
  external String readString(int pointer);

  /// Returns the upstream version string.
  @JS('_textshaper_version')
  external int version();
}
