import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'harfbuzz_source.dart';

/// Rebuilds the shipped browser artifacts with Emscripten 4.0.15.
Future<void> main(List<String> arguments) async {
  final String compiler = arguments.single;
  final ProcessResult version = await Process.run(compiler, ['--version']);
  if (version.exitCode != 0 || !version.stdout.toString().contains('4.0.15')) {
    throw StateError('Emscripten 4.0.15 is required.');
  }
  final Directory root = Directory.fromUri(Platform.script.resolve('../'));
  final Directory source = await installHarfBuzz(Directory('${root.path}/native/third_party/harfbuzz'));
  final ProcessResult result = await Process.run(compiler, [
    '-std=c++17',
    '-O2',
    '-fvisibility=hidden',
    '-DHB_EXTERN=extern',
    '-DHB_EXPERIMENTAL_API',
    '-DHB_NO_PRAGMA_GCC_DIAGNOSTIC_WARNING',
    '-DNDEBUG',
    '-I${source.path}/src',
    '${source.path}/src/harfbuzz.cc',
    '${root.path}/native/textshaper.cc',
    '-sMODULARIZE=1',
    '-sEXPORT_ES6=1',
    '-sENVIRONMENT=web,worker,node',
    '-sALLOW_MEMORY_GROWTH=1',
    '-sMAXIMUM_MEMORY=268435456',
    '-sFILESYSTEM=0',
    '-sEXPORTED_FUNCTIONS=["_malloc","_free","_textshaper_shape","_textshaper_free","_textshaper_version"]',
    '-sEXPORTED_RUNTIME_METHODS=["HEAPU8","UTF8ToString"]',
    '-o',
    '${root.path}/assets/web/textshaperlib.mjs',
  ]);
  if (result.exitCode != 0) {
    throw ProcessException(compiler, [], result.stderr.toString(), result.exitCode);
  }
  final Map<String, String> hashes = {};
  for (final String name in ['textshaperlib.mjs', 'textshaperlib.wasm']) {
    hashes[name] = sha256.convert(await File('${root.path}/assets/web/$name').readAsBytes()).toString();
  }
  await File('${root.path}/assets/web/build.json')
      .writeAsString('${const JsonEncoder.withIndent('  ').convert({'harfbuzz': harfBuzzVersion, 'sourceSha256': harfBuzzSha256, 'emscripten': '4.0.15', 'artifacts': hashes})}\n');
}
