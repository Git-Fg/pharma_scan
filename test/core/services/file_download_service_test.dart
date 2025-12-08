import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:pharma_scan/core/errors/failures.dart';
import 'package:pharma_scan/core/services/file_download_service.dart';

class MockDio extends Mock implements Dio {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FileDownloadService', () {
    late FileDownloadService service;
    late Directory tempDir;

    setUp(() async {
      service = FileDownloadService();

      tempDir = await Directory.systemTemp.createTemp('pharma_scan_test');
    });

    tearDown(() async {
      try {
        await tempDir.delete(recursive: true);
      } on Exception {
        // Ignore cleanup errors
      }
    });

    test('checkConnectivity() returns true for valid hostname', () async {
      final result = await service.checkConnectivity('https://www.google.com');

      expect(result, isA<bool>());
    });

    test('checkConnectivity() returns false for invalid hostname', () async {
      final result = await service.checkConnectivity(
        'https://invalid-hostname-12345.com',
      );

      expect(result, isFalse);
    });

    test('downloadToBytes() handles DNS errors gracefully', () async {
      final mockDio = MockDio();
      when(
        () => mockDio.get<List<int>>(any(), options: any(named: 'options')),
      ).thenThrow(const SocketException('dns'));
      when(
        () => mockDio.head<List<int>>(any(), options: any(named: 'options')),
      ).thenThrow(const SocketException('dns'));
      final dnsService = FileDownloadService(dio: mockDio);

      final result = await dnsService.downloadToBytes(
        'http://invalid-hostname-12345.com/file.txt',
      );

      expect(result.isLeft, isTrue);
      result.fold(
        ifLeft: (failure) {
          expect(failure, isA<NetworkFailure>());
        },
        ifRight: (_) => fail('Should fail with network error'),
      );
    });

    test(
      'downloadToBytesWithCacheFallback() uses cache when download fails',
      () async {
        final cacheFile = File(p.join(tempDir.path, 'cache.txt'));
        await cacheFile.writeAsString('cached content');

        final mockDio = MockDio();
        when(
          () => mockDio.get<List<int>>(any(), options: any(named: 'options')),
        ).thenThrow(const SocketException('dns'));
        when(
          () => mockDio.head<List<int>>(any(), options: any(named: 'options')),
        ).thenThrow(const SocketException('dns'));
        final dnsService = FileDownloadService(dio: mockDio);

        final result = await dnsService.downloadToBytesWithCacheFallback(
          url: 'http://invalid-hostname-12345.com/file.txt',
          cacheFile: cacheFile,
        );

        expect(result.isRight, isTrue);
        result.fold(
          ifLeft: (failure) => fail('Should use cache: $failure'),
          ifRight: (bytes) {
            expect(String.fromCharCodes(bytes), equals('cached content'));
          },
        );
      },
    );

    test(
      'downloadToBytesWithCacheFallback() fails when no cache available',
      () async {
        final nonExistentCache = File(p.join(tempDir.path, 'non-existent.txt'));

        final mockDio = MockDio();
        when(
          () => mockDio.get<List<int>>(any(), options: any(named: 'options')),
        ).thenThrow(const SocketException('dns'));
        when(
          () => mockDio.head<List<int>>(any(), options: any(named: 'options')),
        ).thenThrow(const SocketException('dns'));
        final fallbackService = FileDownloadService(dio: mockDio);

        final result = await fallbackService.downloadToBytesWithCacheFallback(
          url: 'http://invalid-hostname-12345.com/file.txt',
          cacheFile: nonExistentCache,
        );

        expect(result.isLeft, isTrue);
        result.fold(
          ifLeft: (failure) {
            expect(failure, isA<NetworkFailure>());
          },
          ifRight: (_) => fail('Should fail when no cache'),
        );
      },
    );

    test('downloadToTempFile() reports progress and writes file', () async {
      final mockDio = MockDio();
      final calls = <int>[];
      when(
        () => mockDio.download(
          any<String>(),
          any<String>(),
          onReceiveProgress: any(named: 'onReceiveProgress'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((invocation) async {
        final savePath = invocation.positionalArguments[1] as String;
        final file = File(savePath);
        await file.parent.create(recursive: true);
        await file.writeAsString('temp');
        final progress =
            invocation.namedArguments[#onReceiveProgress]
                as void Function(int, int)?;
        progress?.call(5, 10);
        return Response(
          statusCode: 200,
          requestOptions: RequestOptions(path: '/temp'),
        );
      });

      final svc = FileDownloadService(dio: mockDio);
      final tempPrefix = p.join(tempDir.path, 'tmp_');

      final result = await svc.downloadToTempFile(
        url: 'http://example.com/temp',
        tempPathPrefix: tempPrefix,
        onReceiveProgress: (r, t) => calls.add(r),
      );

      expect(result.isRight, isTrue);
      expect(calls, contains(5));
      result.fold(
        ifLeft: (failure) => fail('should succeed: $failure'),
        ifRight: (file) {
          expect(file.existsSync(), isTrue);
          file.deleteSync();
        },
      );
    });

    test('downloadToBytes() returns NetworkFailure on dio error', () async {
      final mockDio = MockDio();
      when(
        () => mockDio.get<List<int>>(any(), options: any(named: 'options')),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/err'),
          error: 'boom',
        ),
      );
      when(
        () => mockDio.head<List<int>>(any(), options: any(named: 'options')),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/err'),
          error: 'boom',
        ),
      );
      final svc = FileDownloadService(dio: mockDio);

      final result = await svc.downloadToBytes('http://example.com/err');

      expect(result.isLeft, isTrue);
    });
  });
}
