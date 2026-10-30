import 'dart:io';

import '../tool/harfbuzz_source.dart';

/// Installs the pinned source ahead of an offline native build.
Future<void> main() async {
  final Directory directory = await installHarfBuzz(Directory.fromUri(Platform.script.resolve('../native/third_party/harfbuzz/')));
  stdout.writeln('HarfBuzz $harfBuzzVersion ready in ${directory.path}.');
}
