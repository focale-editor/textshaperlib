import 'dart:io';
import 'dart:typed_data';

/// Loads original authored fixtures for VM acceptance.
Future<Uint8List> loadFont(String name) => File('test/fixtures/$name').readAsBytes();
