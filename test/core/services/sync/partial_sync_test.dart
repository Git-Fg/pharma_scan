import 'dart:io';

import 'package:dart_either/dart_either.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:pharma_scan/core/database/daos/catalog_dao.dart';
import 'package:pharma_scan/core/database/daos/database_dao.dart';
import 'package:pharma_scan/core/database/daos/settings_dao.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import 'package:pharma_scan/core/services/file_download_service.dart';
import '../../../test_utils.dart';

class MockFileDownloadService extends Mock implements FileDownloadService {}

class MockAppDatabase extends Mock implements AppDatabase {}

class MockCatalogDao extends Mock implements CatalogDao {}

class MockSettingsDao extends Mock implements SettingsDao {}

class MockDatabaseDao extends Mock implements DatabaseDao {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DataInitializationService partial sync resilience', () {
    late MockFileDownloadService fileService;
    late MockAppDatabase database;
    late MockCatalogDao catalogDao;
    late MockSettingsDao settingsDao;
    late MockDatabaseDao databaseDao;
    late Directory cacheDir;

    setUpAll(() {
      registerFallbackValue(File('dummy'));
    });

    setUp(() async {
      cacheDir = await Directory.systemTemp.createTemp('sync_cache');
      PathProviderPlatform.instance = FakePathProviderPlatform(cacheDir.path);
      fileService = MockFileDownloadService();
      database = MockAppDatabase();
      catalogDao = MockCatalogDao();
      settingsDao = MockSettingsDao();
      databaseDao = MockDatabaseDao();

      when(() => database.catalogDao).thenReturn(catalogDao);
      when(() => database.settingsDao).thenReturn(settingsDao);
      when(() => database.databaseDao).thenReturn(databaseDao);

      when(() => catalogDao.hasExistingData()).thenAnswer(
        (_) async => false,
      );
      when(() => settingsDao.getBdpmVersion()).thenAnswer(
        (_) async => null,
      );

      when(() => settingsDao.updateBdpmVersion(any())).thenAnswer(
        (_) async => {},
      );

      when(() => databaseDao.populateSummaryTable()).thenAnswer(
        (_) async => 0,
      );
      when(() => databaseDao.populateFts5Index()).thenAnswer(
        (_) async => {},
      );

      when(
        () => fileService.downloadToBytesWithCacheFallback(
          url: any(named: 'url'),
          cacheFile: any(named: 'cacheFile'),
        ),
      ).thenAnswer((invocation) async {
        final url = invocation.namedArguments[#url]! as String;
        if (url.contains('CIS_bdpm')) {
          return const Either.right(<int>[1, 2, 3]);
        }
        throw Exception('network failure');
      });
    });

    tearDown(() async {
      await cacheDir.delete(recursive: true);
    });

    test(
      'emits error and keeps database intact on partial download failure',
      () async {
        final dataInit = DataInitializationService(
          database: database,
          cacheDirectory: cacheDir.path,
          fileDownloadService: fileService,
        );

        final steps = <InitializationStep>[];
        final sub = dataInit.onStepChanged.listen(steps.add);

        await expectLater(
          () => dataInit.initializeDatabase(forceRefresh: true),
          throwsException,
        );

        await Future<void>.delayed(Duration.zero);

        expect(steps, contains(InitializationStep.error));
        verifyNever(() => databaseDao.clearDatabase());

        await sub.cancel();
        dataInit.dispose();
      },
    );
  });
}
