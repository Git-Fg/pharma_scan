import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:talker/talker.dart';
import 'package:talker_dio_logger/talker_dio_logger.dart';

part 'dio_provider.g.dart';

// Trigger regeneration

/// Provider for a centralized Dio instance with global configuration
@Riverpod(keepAlive: true)
Dio dio(Ref ref) {
  return _createDioInstance();
}

/// Creates a configured Dio instance with global settings
Dio _createDioInstance() {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(minutes: 5),
      sendTimeout: const Duration(minutes: 2),
      headers: {
        'User-Agent': 'PharmaScan/1.0.0 (Flutter)',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ),
  );

  // Add logging interceptor for debugging
  dio.interceptors.add(
    TalkerDioLogger(
      settings: TalkerDioLoggerSettings(
        printRequestHeaders: true,
        printResponseHeaders: false,
        printResponseMessage: true,
        requestPen: AnsiPen()..green(),
        responsePen: AnsiPen()..blue(),
        errorPen: AnsiPen()..red(),
      ),
    ),
  );

  return dio;
}

/// Provider for a Dio instance specifically for file downloads
/// Uses longer timeouts for large file downloads
@Riverpod(keepAlive: true)
Dio downloadDio(Ref ref) {
  return _createDownloadDioInstance();
}

/// Creates a Dio instance optimized for file downloads
Dio _createDownloadDioInstance() {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout:
          const Duration(minutes: 10), // Longer timeout for downloads
      sendTimeout: const Duration(minutes: 2),
      headers: {
        'User-Agent': 'PharmaScan/1.0.0 (Flutter)',
        'Accept': '*/*', // Accept any content type for downloads
      },
    ),
  );

  // Add logging interceptor for debugging
  dio.interceptors.add(
    TalkerDioLogger(
      settings: TalkerDioLoggerSettings(
        printRequestHeaders: false, // Reduce noise for downloads
        printResponseHeaders: false,
        errorPen: AnsiPen()..red(),
      ),
    ),
  );

  return dio;
}
