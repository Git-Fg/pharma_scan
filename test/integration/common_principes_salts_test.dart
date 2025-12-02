import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';

import '../test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MedicamentSummary.commonPrincipes salt cleanup', () {
    late Directory documentsDir;
    late AppDatabase database;
    late DataInitializationService dataInitializationService;

    setUp(() async {
      documentsDir = await Directory.systemTemp.createTemp(
        'pharma_scan_common_principes_',
      );
      PathProviderPlatform.instance = FakePathProviderPlatform(
        documentsDir.path,
      );

      final dbFile = File(p.join(documentsDir.path, 'medicaments.db'));
      database = AppDatabase.forTesting(
        NativeDatabase(dbFile, setup: configureAppSQLite),
      );
      dataInitializationService = DataInitializationService(database: database);

      await dataInitializationService.initializeDatabase(forceRefresh: true);
    });

    tearDown(() async {
      await database.close();
      if (documentsDir.existsSync()) {
        await documentsDir.delete(recursive: true);
      }
    });

    test('ROPINIROLE summaries have clean common principles', () async {
      final allRows = await database.select(database.medicamentSummary).get();
      final rows = allRows
          .where(
            (row) => row.principesActifsCommuns.any(
              (p) => p.contains('ROPINIROLE'),
            ),
          )
          .toList();

      expect(rows, isNotEmpty);

      for (final row in rows) {
        final principles = row.principesActifsCommuns;
        expect(
          principles,
          isNotEmpty,
          reason: 'ROPINIROLE should expose at least one active principle',
        );
        expect(
          principles.any(
            (p) => p.contains('CHLORHYDRATE'),
          ),
          isFalse,
        );
        expect(
          principles.any(
            (p) => p == 'ROPINIROLE',
          ),
          isTrue,
        );
      }
    });

    test('MÉMANTINE summaries have clean common principles', () async {
      final allRows = await database.select(database.medicamentSummary).get();
      final rows = allRows
          .where(
            (row) => row.principesActifsCommuns.any(
              (p) =>
                  p.contains('MÉMANTINE') ||
                  p.contains('MEMANTINE') ||
                  p.contains('MEMENTINE'),
            ),
          )
          .toList();

      expect(rows, isNotEmpty);

      for (final row in rows) {
        final principles = row.principesActifsCommuns;
        expect(
          principles.any(
            (p) => p.contains('CHLORHYDRATE'),
          ),
          isFalse,
        );
        expect(
          principles.any(
            (p) => p == 'MEMANTINE' || p == 'MÉMANTINE' || p == 'MEMENTINE',
          ),
          isTrue,
        );
      }
    });

    test('INDAPAMIDE, PÉRINDOPRIL summaries drop ERBUMINE', () async {
      final allRows = await database.select(database.medicamentSummary).get();
      final rows = allRows.where(
        (row) {
          final principles = row.principesActifsCommuns;
          final hasIndapamide = principles.any((p) => p.contains('INDAPAMIDE'));
          final hasPerindopril = principles.any(
            (p) => p.startsWith('PERINDOPRIL'),
          );
          return hasIndapamide && hasPerindopril;
        },
      ).toList();

      expect(rows, isNotEmpty);

      for (final row in rows) {
        final principles = row.principesActifsCommuns;
        expect(
          principles.any((p) => p.contains('INDAPAMIDE')),
          isTrue,
        );
        expect(
          principles.any((p) => p.startsWith('PERINDOPRIL')),
          isTrue,
        );
        expect(
          principles.any((p) => p == 'ERBUMINE'),
          isFalse,
        );
      }
    });
  });
}
