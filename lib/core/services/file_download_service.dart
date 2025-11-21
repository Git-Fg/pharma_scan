import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pharma_scan/core/config/app_config.dart';
import 'package:pharma_scan/core/services/logger_service.dart';
import 'package:talker_flutter/talker_flutter.dart';

// WHY: Centralized Dio-based download service with manual Talker logging to
// ensure consistent observability across all network file transfers.
class FileDownloadService {
  FileDownloadService({Dio? dio, Talker? talker})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: AppConfig.connectTimeout,
              receiveTimeout: AppConfig.downloadReceiveTimeout,
              headers: const {'Accept': '*/*'},
            ),
          ),
      _talker = talker ?? LoggerService().talker;

  final Dio _dio;
  final Talker _talker;

  /// Downloads a text file directly to application documents directory.
  /// Returns the saved file or null if the transfer failed.
  Future<File?> downloadTextFile({
    required String url,
    required String fileName,
    CancelToken? cancelToken,
  }) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final savePath = '${directory.path}/$fileName';
      _talker.info('⬇️ [DownloadService] Starting download: $fileName');
      _talker.debug('🔗 URL: $url');

      var lastLoggedBucket = -1;
      final response = await _dio.download(
        url,
        savePath,
        cancelToken: cancelToken,
        deleteOnError: true,
        onReceiveProgress: (received, total) {
          if (total <= 0) return;
          final bucket = ((received / total) * 4).floor();
          if (bucket != lastLoggedBucket) {
            lastLoggedBucket = bucket;
            final percentage = (received / total * 100).toStringAsFixed(0);
            _talker.verbose('⏳ [DownloadService] Progress: $percentage%');
          }
        },
      );

      if (response.statusCode == 200) {
        final file = File(savePath);
        _talker.info(
          '✅ [DownloadService] Download complete. Saved to: $savePath',
        );
        _talker.debug('📄 File size: ${await file.length()} bytes');
        return file;
      }
      _talker.error(
        '❌ [DownloadService] Server returned status: ${response.statusCode}',
      );
      return null;
    } on DioException catch (error, stackTrace) {
      if (CancelToken.isCancel(error)) {
        _talker.warning('⚠️ [DownloadService] Download cancelled by user');
      } else {
        _talker.handle(
          error,
          stackTrace,
          '❌ [DownloadService] Network error downloading $fileName',
        );
      }
      return null;
    } catch (error, stackTrace) {
      _talker.handle(error, stackTrace, '❌ [DownloadService] Unexpected error');
      return null;
    }
  }

  // WHY: Download file to bytes in memory. Used when the file needs to be processed
  // immediately or when caching logic is handled by the caller.
  Future<List<int>> downloadToBytes(String url) async {
    try {
      final response = await _dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final data = response.data;
      if (response.statusCode == 200 && data != null) {
        return data;
      }
      throw Exception('Failed to download file: HTTP ${response.statusCode}');
    } on DioException catch (error, stackTrace) {
      _talker.handle(
        error,
        stackTrace,
        '[FileDownloadService] Dio error while downloading $url',
      );
      rethrow;
    } catch (error, stackTrace) {
      _talker.handle(
        error,
        stackTrace,
        '[FileDownloadService] Unexpected error while downloading $url',
      );
      rethrow;
    }
  }

  // WHY: Download file to disk with optional cache fallback.
  // If download fails and cache file exists, returns cached bytes.
  // Used by DataInitializationService for persistent caching in app documents directory.
  Future<List<int>> downloadToBytesWithCacheFallback({
    required String url,
    required File cacheFile,
  }) async {
    try {
      final bytes = await downloadToBytes(url);
      await cacheFile.parent.create(recursive: true);
      await cacheFile.writeAsBytes(bytes, flush: true);
      return bytes;
    } catch (error) {
      if (await cacheFile.exists()) {
        LoggerService.warning(
          '[FileDownloader] Falling back to cached file ${cacheFile.path} after download failure.',
        );
        return cacheFile.readAsBytes();
      }
      rethrow;
    }
  }

  // WHY: Download file to temporary location.
  // Used by SyncService for one-time file processing before cleanup.
  Future<File> downloadToTempFile({
    required String url,
    required String tempPathPrefix,
  }) async {
    final tempFile = File(
      '$tempPathPrefix${DateTime.now().millisecondsSinceEpoch}.tmp',
    );
    await tempFile.parent.create(recursive: true);
    await _dio.download(url, tempFile.path, deleteOnError: true);
    return tempFile;
  }

  void dispose() {
    _dio.close();
  }
}
