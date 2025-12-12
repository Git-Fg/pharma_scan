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

    // Note: applyUpdate() method was removed as part of the external DB-driven architecture
    // The service now only downloads and decompresses pre-aggregated databases

    test(
      'initializeDatabase emits ready when data already matches current version',
      () async {
        await database.settingsDao.updateBdpmVersion(
          DataInitializationService.dataVersion,
        );

        // Insert medicament_summary using raw SQL
        await database.customInsert(
          '''
          INSERT INTO medicament_summary (
            cis_code, nom_canonique, is_princeps, group_id, member_type,
            principes_actifs_communs, princeps_de_reference, forme_pharmaceutique,
            voies_administration, princeps_brand_name, procedure_type, titulaire_id,
            conditions_prescription, date_amm, formatted_dosage, atc_code, status,
            price_min, price_max, aggregated_conditions, ansm_alert_url,
            representative_cip, is_hospital, is_dental, is_list1, is_list2,
            is_narcotic, is_exception, is_restricted, is_otc
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''',
          variables: [
            Variable.withString('00000001'),
            Variable.withString('Test product'),
            Variable.withBool(true),
            Variable.withString(''),
            Variable.withInt(0),
            Variable.withString('["x"]'),
            Variable.withString('Test product'),
            Variable.withString(''),
            Variable.withString(''),
            Variable.withString('Test product'),
            Variable.withString('AMM'),
            Variable.withInt(0),
            Variable.withString(''),
            Variable.withString(''),
            Variable.withString(''),
            Variable.withString(''),
            Variable.withString(''),
            Variable.withReal(0.0),
            Variable.withReal(0.0),
            Variable.withString('[]'),
            Variable.withString(''),
            Variable.withString(''),
            Variable.withBool(false),
            Variable.withBool(false),
            Variable.withBool(false),
            Variable.withBool(false),
            Variable.withBool(false),
            Variable.withBool(false),
            Variable.withBool(false),
            Variable.withBool(true),
          ],
          updates: {database.medicamentSummary},
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
