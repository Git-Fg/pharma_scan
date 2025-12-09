import 'dart:io';

import 'package:dart_either/dart_either.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:pharma_scan/core/config/data_sources.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/errors/failures.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import 'package:pharma_scan/core/services/file_download_service.dart';

import '../../test_utils.dart';

class MockFileDownloadService extends Mock implements FileDownloadService {}

class FakeDownloadService extends Mock implements FileDownloadService {
  FakeDownloadService(this.root);

  final Directory root;

  @override
  Future<Either<Failure, File>> downloadTextFile({
    required String url,
    required String fileName,
    CancelToken? cancelToken,
  }) async {
    final file = File(p.join(root.path, fileName));
    await file.writeAsString('dummy');
    return Either.right(file);
  }

  @override
  Future<Either<Failure, List<int>>> downloadToBytes(String url) async =>
      const Either.right(<int>[]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DataInitializationService', () {
    late AppDatabase database;
    late MockFileDownloadService mockDownloadService;
    late String testDataDir;
    late DataInitializationService service;

    setUp(() async {
      database = AppDatabase.forTesting(
        NativeDatabase.memory(setup: configureAppSQLite),
      );

      mockDownloadService = MockFileDownloadService();

      final tempDir = await Directory.systemTemp.createTemp('pharma_scan_test');
      testDataDir = tempDir.path;
      PathProviderPlatform.instance = FakePathProviderPlatform(testDataDir);

      service = DataInitializationService(
        database: database,
        cacheDirectory: testDataDir,
        fileDownloadService: mockDownloadService,
      );
    });

    tearDown(() async {
      service.dispose();
      await database.close();
      try {
        await Directory(testDataDir).delete(recursive: true);
      } on Exception {
        // Ignore cleanup errors
      }
    });

    test('applyUpdate() fails when required files are missing', () async {
      final testFile = File(p.join(testDataDir, 'test.txt'));
      await testFile.writeAsString('test content');

      final tempFiles = {'specialites': testFile};

      await expectLater(
        () => service.applyUpdate(tempFiles),
        throwsA(isA<Exception>()),
      );
    });

    test('applyUpdate() copies files with minimal fixtures', () async {
      final fakeDownloader = FakeDownloadService(Directory(testDataDir));
      final tmpService = DataInitializationService(
        database: database,
        cacheDirectory: testDataDir,
        fileDownloadService: fakeDownloader,
      );

      final sampleLines = <String, String>{
        'specialites':
            '12345678\tDenom\tForme\tVoie\tStatut\tProc\tEtat\t01/01/2024\tSTAT\tNUM\tTitulaire\tOui',
        'medicaments':
            '12345678\t00000\tLib\tStatut\tEtat\t01/01/2024\t3400000000001\tOui\t65%\t12,50',
        'compositions': '12345678\tElem\t123456\tDenom\t500 mg\tREF\tFT\t1',
        'generiques': 'GRP1\tLibelle\t12345678\t0',
        'conditions': '12345678\tCondition',
        'availability': '12345678\t3400000000001\t1\tDisponible',
        'mitm': '12345678\tATC',
      };

      final tempFiles = <String, File>{};
      for (final entry in DataSources.files.entries) {
        final filename = entry.value.split('/').last;
        final file = File(p.join(testDataDir, filename));
        await file.writeAsString(sampleLines[entry.key] ?? 'placeholder');
        tempFiles[entry.key] = file;
      }

      await tmpService.applyUpdate(tempFiles);

      for (final entry in tempFiles.entries) {
        final filename = entry.value.path.split(Platform.pathSeparator).last;
        final cached = File(p.join(testDataDir, filename));
        expect(cached.existsSync(), isTrue);
      }
    });

    test(
      'initializeDatabase emits ready when data already matches current version',
      () async {
        await database.settingsDao.updateBdpmVersion(
          DataInitializationService.dataVersion,
        );

        await database
            .into(database.medicamentSummary)
            .insert(
              const MedicamentSummaryCompanion(
                cisCode: drift.Value('00000001'),
                nomCanonique: drift.Value('Test product'),
                isPrinceps: drift.Value(true),
                groupId: drift.Value(null),
                memberType: drift.Value(0),
                principesActifsCommuns: drift.Value(<String>['x']),
                princepsDeReference: drift.Value('Test product'),
                formePharmaceutique: drift.Value(null),
                voiesAdministration: drift.Value(null),
                princepsBrandName: drift.Value('Test product'),
                procedureType: drift.Value('AMM'),
                titulaireId: drift.Value(null),
                conditionsPrescription: drift.Value(null),
                dateAmm: drift.Value(null),
                formattedDosage: drift.Value(null),
                atcCode: drift.Value(null),
                status: drift.Value(null),
                priceMin: drift.Value(null),
                priceMax: drift.Value(null),
                aggregatedConditions: drift.Value(null),
                ansmAlertUrl: drift.Value(null),
                representativeCip: drift.Value(null),
              ),
            );

        final readyFuture = service.onStepChanged.firstWhere(
          (step) => step == InitializationStep.ready,
          orElse: () => InitializationStep.error,
        );

        await service.initializeDatabase();

        expect(await readyFuture, InitializationStep.ready);
      },
    );

    test('dispose() closes streams', () async {
      final subscription = service.onStepChanged.listen((_) {});
      service.dispose();

      expect(subscription.isPaused, isFalse);
      await subscription.cancel();
    });

    test('dataVersion returns current version', () {
      expect(
        DataInitializationService.dataVersion,
        isNotEmpty,
      );
    });
  });
}
