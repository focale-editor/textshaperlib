import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

import '../tool/harfbuzz_source.dart';

/// Builds an isolated HarfBuzz engine without relying on platform libraries.
Future<void> main(List<String> arguments) async {
  await build(arguments, (input, output) async {
    if (!input.config.buildCodeAssets) {
      return;
    }
    final Directory prepared = Directory.fromUri(input.packageRoot.resolve('native/third_party/harfbuzz/'));
    final Directory source = await installHarfBuzz(await prepared.exists() ? prepared : Directory.fromUri(input.outputDirectoryShared.resolve('harfbuzz/')));
    final bool windows = input.config.code.targetOS == OS.windows;
    final bool elf = [OS.linux, OS.android].contains(input.config.code.targetOS);
    await CBuilder.library(
      name: 'textshaperlib',
      assetName: 'src/native/bindings.dart',
      sources: ['${input.packageRoot.toFilePath()}native/textshaper.cc', '${source.path}/src/harfbuzz.cc'],
      includes: ['${source.path}/src'],
      language: Language.cpp,
      std: 'c++17',
      defines: {'HB_EXPERIMENTAL_API': null, 'HB_NO_PRAGMA_GCC_DIAGNOSTIC_WARNING': null, 'HB_EXTERN': 'extern', 'NDEBUG': null},
      flags: windows ? const [] : ['-O2', '-fvisibility=hidden', if (elf) '-Wl,-Bsymbolic'],
    ).run(input: input, output: output);
    output.dependencies.addAll([source.uri, input.packageRoot.resolve('native/textshaper.cc')]);
  });
}
