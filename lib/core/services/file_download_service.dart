import 'package:dart_either/dart_either.dart';
import 'package:dio/dio.dart';

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
    // Basic string check to avoid importing dart:io SocketException
    final str = error.toString();
    return str.contains('SocketException') &&
        (str.contains('errno = 7') || str.contains('No address associated'));
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
    final technicalAdvice =
        '''
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
      // We can use Dio head request as simple check
      // Or simple return true if we don't want check overhead
      return true;
    } on Exception catch (e) {
      _talker.debug(
        '[FileDownloadService] Connectivity check failed for ${_extractHostname(url)}: $e',
      );
      return false;
    }
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
          plannedSize = lengthHeader != null
              ? int.tryParse(lengthHeader)
              : null;
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

  void dispose() {
    _dio.close();
  }
}
