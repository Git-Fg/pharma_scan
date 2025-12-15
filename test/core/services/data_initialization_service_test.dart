import 'dart:async';
import 'dart:io';

import 'package:dart_either/dart_either.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:pharma_scan/core/config/database_config.dart';

import 'package:pharma_scan/core/database/daos/app_settings_dao.dart';
import 'package:pharma_scan/core/database/database.dart';

import 'package:pharma_scan/core/services/data_initialization_service.dart';
import 'package:pharma_scan/core/services/file_download_service.dart';
import 'package:pharma_scan/core/services/logger_service.dart';
import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/core/network/dio_provider.dart';
// import 'package:pharma_scan/core/database/daos/app_settings_dao.dart'; // Duplicate removed
import 'package:riverpod/riverpod.dart';

import 'package:talker_flutter/talker_flutter.dart';
import 'package:pharma_scan/core/providers/sync_provider.dart';

class MockLoggerService extends Mock implements LoggerService {}

class MockTalker extends Mock implements Talker {}

class MockFileDownloadService extends Mock implements FileDownloadService {}

class MockDio extends Mock implements Dio {}

class MockAppDatabase extends Mock implements AppDatabase {}

class MockAppSettingsDao extends Mock implements AppSettingsDao {}

class MockSyncController extends Mock
    implements StreamController<InitializationStep> {}

class MockSyncControllerNotifier extends Mock implements SyncController {}

class MockAssetBundle extends Mock implements AssetBundle {}

// class MockRef extends Mock implements Ref {} // Removed: Ref is sealed

void main() {
  late MockLoggerService mockLogger;
  late MockFileDownloadService mockDownloadService;
  late MockDio mockDio;
  late MockAppDatabase mockDb;
  late MockAppSettingsDao mockAppSettings;
  late MockAssetBundle mockAssetBundle;
  late MockSyncControllerNotifier mockSyncNotifier;
  late DataInitializationService service;
  late Directory testDir;

  setUpAll(() {
    registerFallbackValue(InitializationStep.idle);
  });

  DataInitializationService createService(ProviderContainer container) {
    // We create a temporary provider solely to get access to a valid `Ref`
    final tempProvider = Provider((ref) {
      return DataInitializationService(
        ref: ref, // This is a real Ref
        fileDownloadService: mockDownloadService,
        dio: mockDio,
        assetBundle: mockAssetBundle,
      );
    });
    return container.read(tempProvider);
  }

  setUp(() async {
    mockLogger = MockLoggerService();
    mockDownloadService = MockFileDownloadService();
    mockDio = MockDio();
    mockDb = MockAppDatabase();
    mockAppSettings = MockAppSettingsDao();
    mockAssetBundle = MockAssetBundle();
    mockSyncNotifier = MockSyncControllerNotifier();

    // Create a temporary directory for each test
    testDir = await Directory.systemTemp.createTemp('pharma_scan_test_');

    // Setup DB and DAO mocks
    when(() => mockDb.appSettingsDao).thenReturn(mockAppSettings);
    when(() => mockDb.checkDatabaseIntegrity()).thenAnswer((_) async {});
    when(() => mockDb.close()).thenAnswer((_) async {});

    // Setup default app settings behavior
    when(() => mockAppSettings.bdpmVersion).thenAnswer((_) async => null);
    when(() => mockAppSettings.setBdpmVersion(any())).thenAnswer((_) async {});

    // Setup Logger
    when(() => mockLogger.info(any())).thenReturn(null);
    when(() => mockLogger.warning(any())).thenReturn(null);
    when(() => mockLogger.error(any(), any(), any())).thenReturn(null);
    when(() => mockLogger.talker).thenReturn(MockTalker());

    // Setup Sync Controller
    when(() => mockSyncNotifier.startSync()).thenAnswer((_) async => true);

    // Setup Path Provider Mock with dynamic temp dir
    PathProviderPlatform.instance = FakePathProviderPlatform(testDir.path);

    final container = ProviderContainer(
      overrides: [
        loggerProvider.overrideWithValue(mockLogger),
        databaseProvider().overrideWithValue(mockDb),
        fileDownloadServiceProvider.overrideWithValue(mockDownloadService),
        dioProvider.overrideWithValue(mockDio),
        syncControllerProvider.overrideWith(() => mockSyncNotifier),
      ],
    );

    service = createService(container);
  });

  tearDown(() async {
    if (await testDir.exists()) {
      await testDir.delete(recursive: true);
    }
  });

  group('Database Initialization', () {
    test('Existing valid database with version should NOT trigger any action',
        () async {
      when(() => mockAppSettings.bdpmVersion).thenAnswer((_) async => 'v1.0.0');

      // Create dummy DB file to simulate existing DB
      File(p.join(testDir.path, DatabaseConfig.dbFilename)).createSync();

      final streamFuture = expectLater(
        service.onStepChanged,
        emitsThrough(InitializationStep.ready),
      );

      await service.initializeDatabase();
      await streamFuture;

      // Should not download or load asset
      verifyNever(() => mockDownloadService.downloadToBytes(any()));
      verifyNever(() => mockAssetBundle.load(any()));
      verify(() => mockDb.checkDatabaseIntegrity()).called(1);
    });

    test('DB file exists but integrity check fails -> Downloads fresh DB',
        () async {
      when(() => mockAppSettings.bdpmVersion).thenAnswer((_) async => 'v1.0.0');

      // Create DB file that will fail integrity
      File(p.join(testDir.path, DatabaseConfig.dbFilename)).createSync();

      // First call fails (integrity check), subsequent calls succeed
      var integrityCallCount = 0;
      when(() => mockDb.checkDatabaseIntegrity()).thenAnswer((_) async {
        integrityCallCount++;
        if (integrityCallCount == 1) {
          throw Exception('Integrity check failed');
        }
      });

      final gzipBytes = GZipCodec().encode([1, 2, 3]);
      when(() => mockDownloadService.downloadToBytes(any()))
          .thenAnswer((_) async => Right(gzipBytes));

      final streamFuture = expectLater(
        service.onStepChanged,
        emitsInOrder([
          InitializationStep.downloading,
          InitializationStep.ready,
        ]),
      );

      await service.initializeDatabase();
      await streamFuture;

      // Should download after integrity failure
      verify(() => mockDownloadService.downloadToBytes(any())).called(1);
      verify(() => mockDb.checkDatabaseIntegrity()).called(greaterThan(0));
    });

    test('Force refresh -> Downloads even with valid existing DB', () async {
      when(() => mockAppSettings.bdpmVersion).thenAnswer((_) async => 'v1.0.0');

      File(p.join(testDir.path, DatabaseConfig.dbFilename)).createSync();

      final gzipBytes = GZipCodec().encode([1, 2, 3]);
      when(() => mockDownloadService.downloadToBytes(any()))
          .thenAnswer((_) async => Right(gzipBytes));

      final streamFuture = expectLater(
        service.onStepChanged,
        emitsInOrder([
          InitializationStep.downloading,
          InitializationStep.ready,
        ]),
      );

      await service.initializeDatabase(forceRefresh: true);
      await streamFuture;

      verify(() => mockDownloadService.downloadToBytes(any())).called(1);
    });
  });

  group('Asset Bundling - Ship & Copy', () {
    test('Missing DB + Present Asset -> Hydrates from Asset', () async {
      when(() => mockAppSettings.bdpmVersion).thenAnswer((_) async => null);

      // Mock Asset Bundle success with GZIPPED data
      final dummyData = [10, 20, 30];
      final compressedData = GZipCodec().encode(dummyData);
      final byteData = ByteData.sublistView(Uint8List.fromList(compressedData));
      when(() => mockAssetBundle.load(any())).thenAnswer((_) async => byteData);

      final streamFuture = expectLater(
        service.onStepChanged,
        emitsInOrder([
          InitializationStep.ready,
        ]),
      );

      await service.initializeDatabase();
      await streamFuture;

      // Verify Asset loaded
      verify(() => mockAssetBundle.load('assets/database/reference.db.gz'))
          .called(1);

      // Verify Download NOT called
      verifyNever(
          () => mockDownloadService.downloadToBytes(any())); // No download

      // Verify File Created and Decompressed
      final dbFile = File(p.join(testDir.path, DatabaseConfig.dbFilename));
      expect(await dbFile.exists(), true);
      expect(
          await dbFile.readAsBytes(), dummyData); // Should match ORIGINAL data

      // Verify version set to bundled
      verify(() => mockAppSettings.setBdpmVersion('bundled')).called(1);
    });
    test('Fresh install + Missing Asset -> Falls back to download', () async {
      when(() => mockAppSettings.bdpmVersion).thenAnswer((_) async => null);

      // Mock Asset Bundle failure
      when(() => mockAssetBundle.load(any()))
          .thenThrow(Exception('Asset not found'));

      final gzipBytes = GZipCodec().encode([1, 2, 3]);
      when(() => mockDownloadService.downloadToBytes(any()))
          .thenAnswer((_) async => Right(gzipBytes));

      final streamFuture = expectLater(
        service.onStepChanged,
        emitsInOrder([
          InitializationStep.downloading,
          InitializationStep.ready,
        ]),
      );

      await service.initializeDatabase();
      await streamFuture;

      // Verify attempted to load asset first
      verify(() => mockAssetBundle.load('assets/database/reference.db.gz'))
          .called(1);

      // Verify fell back to download
      verify(() => mockDownloadService.downloadToBytes(any())).called(1);

      // Verify version was set (initial-install marker)
      verify(() => mockAppSettings.setBdpmVersion(any())).called(1);
    });

    test('DB exists but file is present -> Does NOT load asset', () async {
      when(() => mockAppSettings.bdpmVersion)
          .thenAnswer((_) async => 'bundled');

      // DB file exists (was previously hydrated)
      File(p.join(testDir.path, DatabaseConfig.dbFilename)).createSync();

      final streamFuture = expectLater(
        service.onStepChanged,
        emitsThrough(InitializationStep.ready),
      );

      await service.initializeDatabase();
      await streamFuture;

      // Should NOT attempt to load asset (DB already exists)
      verifyNever(() => mockAssetBundle.load(any()));
      verifyNever(() => mockDownloadService.downloadToBytes(any()));
    });

    test(
        'Asset load succeeds but integrity check fails -> Falls back to download',
        () async {
      when(() => mockAppSettings.bdpmVersion).thenAnswer((_) async => null);

      final dummyData = [10, 20, 30];
      final compressedData = GZipCodec().encode(dummyData);
      final byteData = ByteData.sublistView(Uint8List.fromList(compressedData));
      when(() => mockAssetBundle.load(any())).thenAnswer((_) async => byteData);

      // Integrity check fails for bundled asset, succeeds after download
      var integrityCallCount = 0;
      when(() => mockDb.checkDatabaseIntegrity()).thenAnswer((_) async {
        integrityCallCount++;
        if (integrityCallCount == 1) {
          throw Exception('Corrupt bundled asset');
        }
      });

      final gzipBytes = GZipCodec().encode([4, 5, 6]);
      when(() => mockDownloadService.downloadToBytes(any()))
          .thenAnswer((_) async => Right(gzipBytes));

      await service.initializeDatabase();

      // Should have attempted asset load
      verify(() => mockAssetBundle.load('assets/database/reference.db.gz'))
          .called(1);

      // Should have fallen back to download after integrity failure
      verify(() => mockDownloadService.downloadToBytes(any())).called(1);
    });
  });

  group('Version Transitions', () {
    test('DB with bundled version already exists -> Initializes without errors',
        () async {
      when(() => mockAppSettings.bdpmVersion)
          .thenAnswer((_) async => 'bundled');

      File(p.join(testDir.path, DatabaseConfig.dbFilename)).createSync();

      await service.initializeDatabase();

      // Should complete successfully without downloading or loading asset
      verifyNever(() => mockAssetBundle.load(any()));
      verifyNever(() => mockDownloadService.downloadToBytes(any()));
    });

    test('Empty version string treated as fresh install', () async {
      when(() => mockAppSettings.bdpmVersion).thenAnswer((_) async => '');

      final dummyData = [10, 20, 30];
      final compressedData = GZipCodec().encode(dummyData);
      final byteData = ByteData.sublistView(Uint8List.fromList(compressedData));
      when(() => mockAssetBundle.load(any())).thenAnswer((_) async => byteData);

      await service.initializeDatabase();

      // Should hydrate from asset (empty string = no version)
      verify(() => mockAssetBundle.load('assets/database/reference.db.gz'))
          .called(1);
    });
  });
}

class FakePathProviderPlatform extends PathProviderPlatform {
  final String path;
  FakePathProviderPlatform(this.path);

  @override
  Future<String?> getApplicationDocumentsPath() async {
    return path;
  }
}
