import 'dart:io';

import 'package:dart_either/dart_either.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pharma_scan/core/errors/failures.dart';

import 'package:pharma_scan/core/utils/strings.dart';
import 'package:talker_flutter/talker_flutter.dart';

class FileDownloadService {
  FileDownloadService({required Dio dio, required Talker talker})
      : _dio = dio,
        _talker = talker;

  final Dio _dio;
  final Talker _talker;
  static const int _maxInMemoryBytes = 100 * 1024 * 1024; // 100 MB guard

  static bool _isDnsError(Object error) {
    if (error is SocketException) {
      // errno 7 = "No address associated with hostname" (DNS lookup failure)
      return error.osError?.errorCode == 7;
    }
    if (error is DioException) {
      final innerError = error.error;
      if (innerError is SocketException) {
        return innerError.osError?.errorCode == 7;
      }
    }
    return false;
  }

  static String? _extractHostname(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host;
    } on Object catch (_) {
      return null;
    }
  }

  String _getDnsErrorMessage(String url) {
    final hostname = _extractHostname(url) ?? 'serveur';
    final technicalAdvice = '''
DNS resolution failed for $hostname. This typically indicates an Android emulator DNS configuration issue.

Possible fixes:
1. Restart the Android emulator
2. Configure DNS servers via ADB:
   adb shell settings put global private_dns_mode off
   adb shell settings put global private_dns_specifier "8.8.8.8"
3. Check emulator network connectivity
4. Use a physical device instead of emulator
''';
    _talker.warning('[FileDownloadService] $technicalAdvice');
    return Strings.dnsResolutionFailed(hostname);
  }

  Future<bool> checkConnectivity(String url) async {
    try {
      final hostname = _extractHostname(url);
      if (hostname == null) return false;

      final addresses = await InternetAddress.lookup(hostname);
      return addresses.isNotEmpty;
    } on Exception catch (e) {
      _talker.debug(
        '[FileDownloadService] Connectivity check failed for ${_extractHostname(url)}: $e',
      );
      return false;
    }
  }

  /// Downloads a text file directly to application documents directory.
  /// Returns `Either<Failure, File>` for type-safe error handling.
  Future<Either<Failure, File>> downloadTextFile({
    required String url,
    required String fileName,
    CancelToken? cancelToken,
  }) {
    return Either.catchFutureError(
      (e, stackTrace) {
        if (_isDnsError(e)) {
          final dnsMessage = _getDnsErrorMessage(url);
          _talker
            ..error('❌ [FileDownloadService] DNS Resolution Error')
            ..error(dnsMessage)
            ..handle(
              e,
              stackTrace,
              '[FileDownloadService] DNS error while downloading $fileName',
            );
          return NetworkFailure(dnsMessage, stackTrace);
        }
        if (e is DioException && CancelToken.isCancel(e)) {
          _talker.warning(
            '⚠️ [FileDownloadService] Download cancelled by user',
          );
          return CancellationFailure('Download cancelled', stackTrace);
        }
        _talker.handle(
          e,
          stackTrace,
          '❌ [FileDownloadService] Error downloading $fileName',
        );
        return NetworkFailure(e.toString(), stackTrace);
      },
      () async {
        final directory = await getApplicationDocumentsDirectory();
        final savePath = '${directory.path}/$fileName';
        _talker
          ..info('⬇️ [DownloadService] Starting download: $fileName')
          ..debug('🔗 URL: $url');

        var lastLoggedBucket = -1;
        final response = await _dio.download(
          url,
          savePath,
          cancelToken: cancelToken,
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
          _talker
            ..info(
              '✅ [DownloadService] Download complete. Saved to: $savePath',
            )
            ..debug('📄 File size: ${await file.length()} bytes');
          return file;
        }
        throw Exception('Server returned status: ${response.statusCode}');
      },
    );
  }

  Future<Either<Failure, List<int>>> downloadToBytes(String url) {
    return Either.catchFutureError(
      (e, stackTrace) {
        if (_isDnsError(e)) {
          final dnsMessage = _getDnsErrorMessage(url);
          _talker
            ..error('❌ [FileDownloadService] DNS Resolution Error')
            ..error(dnsMessage)
            ..handle(
              e,
              stackTrace,
              '[FileDownloadService] DNS error while downloading $url',
            );
          return NetworkFailure(dnsMessage, stackTrace);
        }
        _talker.handle(
          e,
          stackTrace,
          '[FileDownloadService] Error while downloading $url',
        );
        return NetworkFailure(e.toString(), stackTrace);
      },
      () async {
        int? plannedSize;
        try {
          final headResponse = await _dio.head<List<int>>(
            url,
            options: Options(
              followRedirects: true,
              validateStatus: (status) => status != null && status < 400,
            ),
          );
          final lengthHeader = headResponse.headers.value(
            Headers.contentLengthHeader,
          );
          plannedSize =
              lengthHeader != null ? int.tryParse(lengthHeader) : null;
          if (plannedSize != null && plannedSize > _maxInMemoryBytes) {
            _talker.warning(
              '[FileDownloadService] Download size ${plannedSize / (1024 * 1024)} MB exceeds in-memory limit. Use downloadTextFile/downloadToTempFile to stream.',
            );
            throw NetworkFailure(
              Strings.downloadTooLargeForMemory,
              StackTrace.current,
            );
          }
        } on DioException {
          // Proceed with GET if HEAD fails (some servers block HEAD).
        }

        final response = await _dio.get<List<int>>(
          url,
          options: Options(responseType: ResponseType.bytes),
        );
        final data = response.data;
        if (response.statusCode == 200 && data != null) {
          if (data.length > _maxInMemoryBytes) {
            _talker.warning(
              '[FileDownloadService] Downloaded ${data.length / (1024 * 1024)} MB into memory. Consider streaming for future calls.',
            );
          }
          return data;
        }
        throw NetworkFailure(
          'Failed to download file: HTTP ${response.statusCode}',
          StackTrace.current,
        );
      },
    );
  }

  Future<Either<Failure, List<int>>> downloadToBytesWithCacheFallback({
    required String url,
    required File cacheFile,
  }) async {
    final downloadEither = await downloadToBytes(url);
    return downloadEither.fold(
      ifLeft: (failure) async {
        if (await cacheFile.exists()) {
          _talker.warning(
            '[FileDownloader] Falling back to cached file ${cacheFile.path} after download failure.',
          );
          try {
            final cachedBytes = await cacheFile.readAsBytes();
            return Either<Failure, List<int>>.right(cachedBytes);
          } on Exception catch (e, stackTrace) {
            _talker.error(
              '[FileDownloader] Failed to read cached file',
              e,
              stackTrace,
            );
            return Either<Failure, List<int>>.left(
              NetworkFailure(
                'Download failed and cache read failed: ${failure.message}',
                stackTrace,
              ),
            );
          }
        }
        return Either<Failure, List<int>>.left(failure);
      },
      ifRight: (bytes) async {
        try {
          await cacheFile.parent.create(recursive: true);
          await cacheFile.writeAsBytes(bytes, flush: true);
          return Either<Failure, List<int>>.right(bytes);
        } on Exception catch (e, stackTrace) {
          _talker.error(
            '[FileDownloader] Failed to write cache file',
            e,
            stackTrace,
          );
          // Return bytes even if cache write fails
          return Either<Failure, List<int>>.right(bytes);
        }
      },
    );
  }

  Future<Either<Failure, File>> downloadToTempFile({
    required String url,
    required String tempPathPrefix,
    void Function(int received, int total)? onReceiveProgress,
  }) {
    return Either.catchFutureError(
      (e, stackTrace) {
        if (_isDnsError(e)) {
          final dnsMessage = _getDnsErrorMessage(url);
          _talker
            ..error('❌ [FileDownloadService] DNS Resolution Error')
            ..error(dnsMessage)
            ..handle(
              e,
              stackTrace,
              '[FileDownloadService] DNS error while downloading to temp file',
            );
          return NetworkFailure(dnsMessage, stackTrace);
        }
        _talker.handle(
          e,
          stackTrace,
          '[FileDownloadService] Error downloading to temp file',
        );
        return NetworkFailure(e.toString(), stackTrace);
      },
      () async {
        final tempFile = File(
          '$tempPathPrefix${DateTime.now().millisecondsSinceEpoch}.tmp',
        );
        await tempFile.parent.create(recursive: true);
        await _dio.download(
          url,
          tempFile.path,
          onReceiveProgress: onReceiveProgress,
        );
        return tempFile;
      },
    );
  }

  void dispose() {
    _dio.close();
  }
}
