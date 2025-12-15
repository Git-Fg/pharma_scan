import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import 'package:pharma_scan/core/services/file_download_service.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/database/daos/app_settings_dao.dart';
import 'package:pharma_scan/core/database/providers.dart';
import 'package:pharma_scan/core/services/logger_service.dart';

// Mocks
class MockDio extends Mock implements Dio {}

class MockFileDownloadService extends Mock implements FileDownloadService {}

class MockLoggerService extends Mock implements LoggerService {}

class MockResponse extends Mock implements Response {}

// Custom Ref mock
class MockRef extends Mock implements Ref {}

void main() {
  late MockDio mockDio;
  late MockFileDownloadService mockDownloadService;
  late MockLoggerService mockLogger;
  late AppDatabase db;
  late DataInitializationService service;
  late MockRef mockRef;

  setUp(() async {
    mockDio = MockDio();
    mockDownloadService = MockFileDownloadService();
    mockLogger = MockLoggerService();
    mockRef = MockRef();

    // Use in-memory database
    db = AppDatabase(NativeDatabase.memory());

    // Create _metadata table manually since it's injected
    // by backend but we want to simulate existing state.
    // Or we can rely on ReferenceDatabase.initMetadataTable if accessible? no it is TS.
    // We can use db.customStatement.
    await db.customStatement(
        'CREATE TABLE IF NOT EXISTS _metadata (key TEXT PRIMARY KEY, value TEXT) STRICT;');

    // Mock provider read
    when(() => mockRef.read(databaseProvider())).thenReturn(db);

    service = DataInitializationService(
      ref: mockRef,
      fileDownloadService: mockDownloadService,
      dio: mockDio,
      loggerService: mockLogger,
    );

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
  });

  tearDown(() async {
    await db.close();
  });

  test(
      'Should suggest update when local metadata is missing (new install/legacy)',
      () async {
    // No metadata inserted

    final result = await service.checkVersionStatus();

    expect(result, isNotNull);
    expect(result!.updateAvailable, isTrue);
    expect(result.localDate, isNull);
    expect(result.remoteTag, '2025-01-01T12:00:00Z');
  });

  test('Should suggest update when local is older than remote', () async {
    // Insert old metadata
    await db.customStatement('INSERT INTO _metadata (key, value) VALUES (?, ?)',
        ['last_updated', '2024-01-01T00:00:00Z']);

    final result = await service.checkVersionStatus();

    expect(result, isNotNull);
    expect(result!.updateAvailable, isTrue);
    expect(result.localDate, '2024-01-01T00:00:00Z');
  });

  test('Should NOT suggest update when local is same as remote', () async {
    // Insert same metadata
    await db.customStatement('INSERT INTO _metadata (key, value) VALUES (?, ?)',
        ['last_updated', '2025-01-01T12:00:00Z']);

    final result = await service.checkVersionStatus();

    expect(result, isNotNull);
    expect(result!.updateAvailable, isFalse);
  });

  test(
      'Should NOT suggest update when local is newer (unlikely but possible dev)',
      () async {
    await db.customStatement('INSERT INTO _metadata (key, value) VALUES (?, ?)',
        ['last_updated', '2026-01-01T12:00:00Z']);

    final result = await service.checkVersionStatus();

    expect(result, isNotNull);
    expect(result!.updateAvailable, isFalse);
  });

  test('Should NOT suggest update when updatePolicy is NEVER', () async {
    // Insert new metadata (update available)
    await db.customStatement('INSERT INTO _metadata (key, value) VALUES (?, ?)',
        ['last_updated', '2024-01-01T00:00:00Z']);

    // Set policy to NEVER in AppSettings
    // We need to use AppSettingsDao to set it, or direct SQL if table known?
    // Let's use DAO to ensure encoding is correct.
    final settingsDao = AppSettingsDao(db);
    await settingsDao.setUpdatePolicy('never');

    // We need to ensure service uses this DAO.
    when(() => mockRef.read(appSettingsDaoProvider)).thenReturn(settingsDao);

    final result = await service.checkVersionStatus();

    expect(result, isNotNull);
    expect(result!.updateAvailable, isTrue); // It *is* available
    expect(result.blockedByPolicy, isTrue); // But blocked
  });

  test('Should suggest update when updatePolicy is ALWAYS or ASK', () async {
    await db.customStatement('INSERT INTO _metadata (key, value) VALUES (?, ?)',
        ['last_updated', '2024-01-01T00:00:00Z']);

    final settingsDao = AppSettingsDao(db);
    await settingsDao.setUpdatePolicy('ask');
    when(() => mockRef.read(appSettingsDaoProvider)).thenReturn(settingsDao);

    final result = await service.checkVersionStatus();

    expect(result!.blockedByPolicy, isFalse);
  });

  // Policy tests
  // We need to verify that checkVersionStatus calls appSettingsDao.updatePolicy
  // Since we are using real DB, we can use real AppSettingsDao (part of DB).
  // But AppSettingsDao reads from SharedPreferences usually?
  // Wait, AppSettingsDao in this project drifts from KeyValueTable?
  // Let's check AppSettingsDao implementation.
  // If it uses KeyValueTable, we can insert into it.
}
