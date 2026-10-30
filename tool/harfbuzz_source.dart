import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:zcodec/zcodec.dart';

/// Upstream release shared by the native and WebAssembly engines.
const String harfBuzzVersion = '15.0.0';

/// Digest of the official tag archive, checked before extracting any files.
const String harfBuzzSha256 = 'fe4b8bad7afbbae75d61b2095c267c98f4ed04fe4a117680130ed253d2732efe';

/// Fetches bounded, verified sources once, serializing concurrent build hooks.
Future<Directory> installHarfBuzz(Directory destination) async {
  destination = Directory(destination.path.replaceFirst(RegExp(r'[/\\]+$'), ''));
  await destination.parent.create(recursive: true);
  final RandomAccessFile lock = await File('${destination.path}.lock').open(mode: FileMode.append);
  try {
    await lock.lock(FileLock.blockingExclusive);
    final File receipt = File('${destination.path}/.sha256');
    if (await receipt.exists() && await receipt.readAsString() == harfBuzzSha256) {
      return destination;
    }
    final HttpClient client = HttpClient()..connectionTimeout = const Duration(seconds: 30);
    final BytesBuilder bytes = BytesBuilder(copy: false);
    try {
      final HttpClientRequest request = await client.getUrl(Uri.parse('https://codeload.github.com/harfbuzz/harfbuzz/tar.gz/refs/tags/$harfBuzzVersion'));
      final HttpClientResponse response = await request.close().timeout(const Duration(seconds: 60));
      if (response.statusCode != 200) {
        throw HttpException('HarfBuzz source download returned ${response.statusCode}.');
      }
      await for (final List<int> chunk in response.timeout(const Duration(seconds: 60))) {
        if (bytes.length + chunk.length > 64 * 1024 * 1024) {
          throw const FormatException('HarfBuzz archive exceeds the byte limit.');
        }
        bytes.add(chunk);
      }
    } finally {
      client.close(force: true);
    }
    final Uint8List compressed = bytes.takeBytes();
    if (sha256.convert(compressed).toString() != harfBuzzSha256) {
      throw const FormatException('HarfBuzz source checksum mismatch.');
    }
    final Uint8List tar = const GzipCodec(maxOutputBytes: 256 * 1024 * 1024).decode(compressed);
    final TarArchive archive = const TarDecoder(
      limits: TarLimits(maxEntryBytes: 64 * 1024 * 1024, maxTotalBytes: 256 * 1024 * 1024),
    ).convert(tar);
    final Directory temporary = await destination.parent.createTemp('.harfbuzz-');
    try {
      const String prefix = 'harfbuzz-$harfBuzzVersion/';
      for (final TarEntry entry in archive.entries) {
        if (!entry.name.startsWith('${prefix}src/') && entry.name != '${prefix}COPYING') {
          continue;
        }
        final String relative = entry.name.substring(prefix.length);
        if (relative.split('/').any((segment) => segment == '..') || relative.contains('\\')) {
          throw const FormatException('Invalid HarfBuzz archive path.');
        }
        // Only regular source files are installed; archive links are never followed.
        if (entry.type != TarEntryType.regular) {
          continue;
        }
        final File file = File('${temporary.path}/$relative');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(entry.data);
      }
      if (!await File('${temporary.path}/src/harfbuzz.cc').exists()) {
        throw const FormatException('HarfBuzz source archive is incomplete.');
      }
      await File('${temporary.path}/.sha256').writeAsString(harfBuzzSha256);
      if (await destination.exists()) {
        await destination.delete(recursive: true);
      }
      return await temporary.rename(destination.path);
    } finally {
      if (await temporary.exists()) {
        await temporary.delete(recursive: true);
      }
    }
  } finally {
    await lock.close();
  }
}
