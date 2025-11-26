import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:pharma_scan/core/config/data_sources.dart';

Future<void> main(List<String> args) async {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(minutes: 2),
      headers: const {'Accept': '*/*'},
    ),
  );
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
      : p.join('tool', 'data');
  final cacheDir = Directory(cacheDirPath);
  await cacheDir.create(recursive: true);

  print('Preparing BDPM fixtures in ${cacheDir.absolute.path}');

  for (final entry in DataSources.files.entries) {
    final filename = _extractFilenameFromUrl(entry.value);
    final file = File(p.join(cacheDir.path, filename));
    if (!force && await file.exists()) {
      print('✓ $filename already cached – skipping');
      continue;
    }
    print('↻ Downloading $filename ...');
    final response = await dio.get<List<int>>(
      entry.value,
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = response.data;
    if (response.statusCode != 200 || bytes == null) {
      print('Failed to download $filename (HTTP ${response.statusCode}).');
      exitCode = 1;
      return;
    }
    await file.writeAsBytes(bytes, flush: true);
  }

  print(
    'BDPM fixtures ready in ${cacheDir.absolute.path}. '
    'Set PHARMA_BDPM_CACHE=${cacheDir.absolute.path} to override the default location.',
  );
}

String _extractFilenameFromUrl(String url) {
  final uri = Uri.parse(url);
  return uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'bdpm.txt';
}
