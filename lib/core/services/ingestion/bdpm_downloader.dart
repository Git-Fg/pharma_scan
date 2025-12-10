import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pharma_scan/core/config/data_sources.dart';
import 'package:pharma_scan/core/services/file_download_service.dart';
import 'package:pharma_scan/core/services/logger_service.dart';

class BdpmDownloader {
  BdpmDownloader({
    required FileDownloadService fileDownloadService,
    String? cacheDirectory,
  }) : _fileDownloadService = fileDownloadService,
       _globalCacheDir = cacheDirectory;

  final FileDownloadService _fileDownloadService;
  final String? _globalCacheDir;

  Future<Map<String, String>> downloadAllWithCacheCheck() async {
    final cachedFiles = <String, String>{};
    final missingFiles = <MapEntry<String, String>>[];

    for (final entry in DataSources.files.entries) {
      final filename = _extractFilenameFromUrl(entry.value);
      final cacheDir = _globalCacheDir;

      if (cacheDir != null) {
        final cacheFile = File(p.join(cacheDir, filename));
        if (await cacheFile.exists()) {
          LoggerService.info(
            '[BdpmDownloader] Using cached BDPM file $filename from $cacheDir',
          );
          cachedFiles[entry.key] = cacheFile.path;
          continue;
        }
      }

      missingFiles.add(entry);
    }

    if (missingFiles.isEmpty) {
      LoggerService.info('[BdpmDownloader] All BDPM files found in cache.');
      return cachedFiles;
    }

    var completedCount = 0;
    final totalToDownload = missingFiles.length;
    final downloadFutures = missingFiles.map(
      (entry) async {
        try {
          LoggerService.info(
            '[BdpmDownloader] Downloading ${entry.key} from ${entry.value}',
          );
          final path = await _getFilePath(entry.key, entry.value);
          completedCount += 1;
          LoggerService.info(
            '[BdpmDownloader] Downloaded ${entry.key} ($completedCount/$totalToDownload)',
          );
          return MapEntry(entry.key, path);
        } on Exception catch (e, stackTrace) {
          final filename = _extractFilenameFromUrl(entry.value);
          final fallback = await _findFallback(filename);
          if (fallback != null) {
            LoggerService.warning(
              '[BdpmDownloader] Download failed for ${entry.key}, using cached file: $e',
            );
            return MapEntry(entry.key, fallback.path);
          }
          LoggerService.error(
            '[BdpmDownloader] Download failed for ${entry.key} and no cache available',
            e,
            stackTrace,
          );
          throw Exception(
            'Failed to download ${entry.key} (${_extractFilenameFromUrl(entry.value)}): $e',
          );
        }
      },
    );

    final downloadResults = await Future.wait(downloadFutures);
    return {...cachedFiles, ...Map.fromEntries(downloadResults)};
  }

  Future<Map<String, String>> resolveFullFileSet(
    Map<String, File> updatedFiles,
  ) async {
    final filePaths = <String, String>{};
    final cacheDir = _globalCacheDir;
    final appDir = await getApplicationDocumentsDirectory();
    final missingFiles = <String>[];

    for (final key in DataSources.files.keys) {
      final sourceUrl = DataSources.files[key];
      if (sourceUrl == null) continue;

      final filename = _extractFilenameFromUrl(sourceUrl);

      if (updatedFiles.containsKey(key)) {
        final destinationPath = cacheDir != null
            ? p.join(cacheDir, filename)
            : p.join(appDir.path, filename);
        final destinationFile = File(destinationPath);

        if (await destinationFile.exists()) {
          filePaths[key] = destinationPath;
          LoggerService.info(
            '[BdpmDownloader] Using updated file $key from cache: $destinationPath',
          );
          continue;
        } else {
          LoggerService.warning(
            '[BdpmDownloader] Updated file $key not found at expected cache path: $destinationPath',
          );
        }
      }

      File? cachedFile;

      if (cacheDir != null) {
        final cacheFile = File(p.join(cacheDir, filename));
        if (await cacheFile.exists()) {
          cachedFile = cacheFile;
        }
      }

      if (cachedFile == null) {
        final appCacheFile = File(p.join(appDir.path, filename));
        if (await appCacheFile.exists()) {
          cachedFile = appCacheFile;
        }
      }

      if (cachedFile != null) {
        filePaths[key] = cachedFile.path;
        LoggerService.info(
          '[BdpmDownloader] Using cached file $key: ${cachedFile.path}',
        );
      } else {
        missingFiles.add(key);
      }
    }

    if (missingFiles.isNotEmpty) {
      throw Exception(
        'Required BDPM files missing from both update and cache: '
        '${missingFiles.join(', ')}. Full initialization required.',
      );
    }

    LoggerService.info(
      '[BdpmDownloader] Resolved complete file set (${filePaths.length} files)',
    );

    return filePaths;
  }

  Future<File?> _findFallback(String filename) async {
    final cacheDir = _globalCacheDir;
    if (cacheDir != null) {
      final cacheFile = File(p.join(cacheDir, filename));
      if (await cacheFile.exists()) {
        return cacheFile;
      }
    }

    final directory = await getApplicationDocumentsDirectory();
    final appCacheFile = File(p.join(directory.path, filename));
    if (await appCacheFile.exists()) {
      return appCacheFile;
    }
    return null;
  }

  String _extractFilenameFromUrl(String url) {
    final uri = Uri.parse(url);
    return uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'bdpm.txt';
  }

  Future<String> _getFilePath(String storageKey, String url) async {
    final filename = _extractFilenameFromUrl(url);
    final cacheDir = _globalCacheDir;

    if (cacheDir != null) {
      final cacheFile = File(p.join(cacheDir, filename));
      if (await cacheFile.exists()) {
        return cacheFile.path;
      }
    }

    final bytes = await _fetchFileBytesWithCache(url: url, filename: filename);

    if (cacheDir != null) {
      await _writeGlobalCache(filename, bytes);
      return File(p.join(cacheDir, filename)).path;
    }

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<List<int>> _fetchFileBytesWithCache({
    required String url,
    required String filename,
  }) async {
    final directory = await getApplicationDocumentsDirectory();
    final cacheFile = File('${directory.path}/$filename');

    const maxRetries = 3;
    var retryCount = 0;
    while (retryCount < maxRetries) {
      final downloadEither = await _fileDownloadService
          .downloadToBytesWithCacheFallback(
            url: url,
            cacheFile: cacheFile,
          );

      final result = downloadEither.fold(
        ifLeft: (_) => null,
        ifRight: (bytes) => bytes,
      );

      if (result != null) {
        return result;
      }

      retryCount++;
      if (retryCount < maxRetries) {
        final delayMs = 2000 * (1 << (retryCount - 1));
        await Future<void>.delayed(Duration(milliseconds: delayMs));
      }
    }

    if (await cacheFile.exists()) {
      LoggerService.warning(
        '[BdpmDownloader] Download failed after retries, using cached file: $filename',
      );
      return cacheFile.readAsBytes();
    }

    throw Exception('Failed to download $filename after retries and no cache');
  }

  Future<void> _writeGlobalCache(String filename, List<int> bytes) async {
    final cacheDir = _globalCacheDir;
    if (cacheDir == null) return;
    final file = File(p.join(cacheDir, filename));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
  }
}
