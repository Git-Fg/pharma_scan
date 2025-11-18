import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:pharma_scan/core/config/data_sources.dart';

Future<void> main(List<String> args) async {
  final force = args.contains('--force');
  final overrideDirArgument = args.firstWhere(
    (arg) => arg.startsWith('--dir='),
    orElse: () => '',
  );
  final customDir = overrideDirArgument.isNotEmpty
      ? overrideDirArgument.split('=').last
      : '';

  final cacheDirPath = customDir.isNotEmpty
      ? customDir
      : p.join('.dart_tool', 'bdpm_cache');
  final cacheDir = Directory(cacheDirPath);
  await cacheDir.create(recursive: true);

  stdout.writeln('Preparing BDPM fixtures in ${cacheDir.absolute.path}');

  for (final entry in DataSources.files.entries) {
    final filename = _extractFilenameFromUrl(entry.value);
    final file = File(p.join(cacheDir.path, filename));
    if (!force && await file.exists()) {
      stdout.writeln('✓ $filename already cached – skipping');
      continue;
    }
    stdout.writeln('↻ Downloading $filename ...');
    final response = await http.get(Uri.parse(entry.value));
    if (response.statusCode != 200) {
      stderr.writeln(
        'Failed to download $filename (HTTP ${response.statusCode}).',
      );
      exitCode = 1;
      return;
    }
    await file.writeAsBytes(response.bodyBytes, flush: true);
  }

  stdout.writeln(
    'BDPM fixtures ready. Set PHARMA_BDPM_CACHE=${cacheDir.absolute.path} to reuse them.',
  );
}

String _extractFilenameFromUrl(String url) {
  final uri = Uri.parse(url);
  return uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'bdpm.txt';
}
