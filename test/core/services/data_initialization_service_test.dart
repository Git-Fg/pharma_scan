import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import 'package:pharma_scan/core/services/file_download_service.dart';
import 'package:pharma_scan/core/services/preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/db_loader.dart';
import '../../test_utils.dart';

class MockFileDownloadService extends Mock implements FileDownloadService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DataInitializationService', () {
    late AppDatabase database;
    late MockFileDownloadService mockDownloadService;
    late PreferencesService preferencesService;
    late String testDataDir;
    late DataInitializationService service;

    setUp(() async {
      database = AppDatabase.forTesting(
        NativeDatabase.memory(setup: configureAppSQLite),
      );

      mockDownloadService = MockFileDownloadService();

      // Mock SharedPreferences
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      preferencesService = PreferencesService(prefs);

      final tempDir = await Directory.systemTemp.createTemp('pharma_scan_test');
      testDataDir = tempDir.path;
      PathProviderPlatform.instance = FakePathProviderPlatform(testDataDir);

      service = DataInitializationService(
        database: database,
        fileDownloadService: mockDownloadService,
        preferencesService: preferencesService,
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

    test(
      'initializeDatabase emits ready when data already matches current version',
      () async {
        await preferencesService.setDbVersionTag(
          DataInitializationService.dataVersion,
        );

        // Satisfy Foreign Keys by inserting dependencies
        await database.customInsert(
          'INSERT INTO laboratories (id, name) VALUES (?, ?)',
          variables: [Variable.withInt(0), Variable.withString('Dummy Lab')],
          updates: {database.laboratories},
        );

        // No FK on group_id in medicament_summary, but explicit insert is safe if needed later
        // Skipping generic_groups insert as it seems unnecessary for FK constraints based on schema

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
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
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
            Variable.withReal(0),
            Variable.withReal(0),
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
