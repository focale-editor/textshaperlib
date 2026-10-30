import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Loads the same original fixtures from the Dart browser-test server.
Future<Uint8List> loadFont(String name) async {
  final web.Response response = await web.window.fetch('fixtures/$name'.toJS).toDart;
  if (!response.ok) {
    throw StateError('Fixture download failed: ${response.status}');
  }
  return (await response.arrayBuffer().toDart).toDart.asUint8List();
}
