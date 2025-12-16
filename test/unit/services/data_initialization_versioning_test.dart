import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import 'package:pharma_scan/core/services/file_download_service.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/database/daos/app_settings_dao.dart';
import 'package:pharma_scan/core/services/logger_service.dart';
import 'package:pharma_scan/core/network/dio_provider.dart';
import 'package:pharma_scan/core/providers/core_providers.dart';

// Mocks
class MockDio extends Mock implements Dio {}

class MockFileDownloadService extends Mock implements FileDownloadService {}

class MockLoggerService extends Mock implements LoggerService {}

class MockResponse extends Mock implements Response<Map<String, dynamic>> {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockDio mockDio;
  late MockFileDownloadService mockDownloadService;
  late MockLoggerService mockLogger;
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    mockDio = MockDio();
    mockDownloadService = MockFileDownloadService();
    mockLogger = MockLoggerService();

    // Use in-memory database
    db = AppDatabase.forTesting(NativeDatabase.memory(), mockLogger);

    // Create _metadata table manually
    await db.customStatement(
        'CREATE TABLE IF NOT EXISTS _metadata (key TEXT PRIMARY KEY, value TEXT) STRICT;');

    // Setup mocks
    registerFallbackValue(Uri.parse('http://example.com'));
    registerFallbackValue(RequestOptions(path: ''));

    // Default Dio response
    when(() => mockDio
            .get<Map<String, dynamic>>(any(), options: any(named: 'options')))
        .thenAnswer((_) async => Response(
              requestOptions: RequestOptions(path: ''),
              statusCode: 200,
              data: {
                'tag_name': '2025-01-01T12:00:00Z',
                'assets': [
                  {
                    'name': 'reference.db.gz',
                    'browser_download_url': 'http://example.com/db.gz'
                  }
                ]
              },
            ));

    // Create container with overrides
    container = ProviderContainer(
      overrides: [
        // Can't override family provider directly, but we can override via dependency injection
        loggerProvider.overrideWithValue(mockLogger),
        fileDownloadServiceProvider.overrideWithValue(mockDownloadService),
        dioProvider.overrideWithValue(mockDio),
      ],
    );
  });

  tearDown(() async {
    await db.close();
    container.dispose();
  });

  DataInitializationService getService() {
    return container.read(dataInitializationServiceProvider);
  }

  test(
      'Should suggest update when local metadata is missing (new install/legacy)',
      () async {
    final service = getService();
    final result = await service.checkVersionStatus();

    expect(result, isNotNull);
    expect(result!.updateAvailable, isTrue);
    expect(result.localDate, isNull);
    expect(result.remoteTag, '2025-01-01T12:00:00Z');
  });

  test('Should suggest update when local is older than remote', () async {
    await db.customStatement('INSERT INTO _metadata (key, value) VALUES (?, ?)',
        ['last_updated', '2024-01-01T00:00:00Z']);

    final service = getService();
    final result = await service.checkVersionStatus();

    expect(result, isNotNull);
    expect(result!.updateAvailable, isTrue);
    expect(result.localDate, '2024-01-01T00:00:00Z');
  });

  test('Should NOT suggest update when local is same as remote', () async {
    await db.customStatement('INSERT INTO _metadata (key, value) VALUES (?, ?)',
        ['last_updated', '2025-01-01T12:00:00Z']);

    final service = getService();
    final result = await service.checkVersionStatus();

    expect(result, isNotNull);
    expect(result!.updateAvailable, isFalse);
  });

  test('Should NOT suggest update when local is newer', () async {
    await db.customStatement('INSERT INTO _metadata (key, value) VALUES (?, ?)',
        ['last_updated', '2026-01-01T12:00:00Z']);

    final service = getService();
    final result = await service.checkVersionStatus();

    expect(result, isNotNull);
    expect(result!.updateAvailable, isFalse);
  });

  test('Should NOT suggest update when updatePolicy is NEVER', () async {
    await db.customStatement('INSERT INTO _metadata (key, value) VALUES (?, ?)',
        ['last_updated', '2024-01-01T00:00:00Z']);

    final settingsDao = AppSettingsDao(db);
    await settingsDao.setUpdatePolicy('never');

    // We already overrode databaseProvider, so appSettingsDaoProvider (if read from ref) should use valid db.

    final service = getService();
    final result = await service.checkVersionStatus();

    expect(result, isNotNull);
    expect(result!.updateAvailable, isTrue);
    expect(result.blockedByPolicy, isTrue);
  });

  test('Should suggest update when updatePolicy is ALWAYS or ASK', () async {
    await db.customStatement('INSERT INTO _metadata (key, value) VALUES (?, ?)',
        ['last_updated', '2024-01-01T00:00:00Z']);

    final settingsDao = AppSettingsDao(db);
    await settingsDao.setUpdatePolicy('ask');

    final service = getService();
    final result = await service.checkVersionStatus();

    expect(result!.blockedByPolicy, isFalse);
  });
}
