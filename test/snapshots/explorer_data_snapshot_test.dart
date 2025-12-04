// test/snapshots/explorer_data_snapshot_test.dart
//
// Hybrid host-side test to generate a deterministic snapshot of the
// Explorer tab grouping logic for oral administration routes.

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/logic/sanitizer.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import 'package:pharma_scan/features/explorer/domain/logic/explorer_grouping_helper.dart';
import 'package:pharma_scan/features/explorer/domain/models/generic_group_entity.dart';

import '../test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory documentsDir;
  late AppDatabase database;
  late DataInitializationService dataInitializationService;

  setUp(() async {
    // Use a temporary directory as the application documents directory so that
    // DataInitializationService can create its SQLite file and cache safely.
    documentsDir = await Directory.systemTemp.createTemp(
      'pharma_scan_snapshot_',
    );
    PathProviderPlatform.instance = FakePathProviderPlatform(documentsDir.path);

    final dbFile = File(p.join(documentsDir.path, 'medicaments.db'));
    database = AppDatabase.forTesting(
      NativeDatabase(dbFile, setup: configureAppSQLite),
    );
    dataInitializationService = DataInitializationService(database: database);
  });

  tearDown(() async {
    await database.close();
    if (documentsDir.existsSync()) {
      await documentsDir.delete(recursive: true);
    }
  });

  test('generates Explorer snapshot for oral route groups', () async {
    // GIVEN: A fully initialized database using local BDPM TXT files
    // located in tool/data/ (via DataInitializationService cache resolution).
    await dataInitializationService.initializeDatabase(forceRefresh: true);

    final catalogDao = database.catalogDao;

    // WHEN: We fetch generic group summaries for the oral administration route
    // to mimic the Explorer tab filtered on voie d'administration "Orale".
    final groups = await catalogDao.getGenericGroupSummaries(
      routeKeywords: const ['Orale'],
      limit: 5000,
    );

    // Sanity check: we expect at least some groups for this widely used form.
    expect(groups, isNotEmpty);

    // Apply the same clustering logic used by the Explorer UI.
    final groupedObjects = ExplorerGroupingHelper.groupByCommonPrincipes(
      groups,
    );

    // Sort the output deterministically using a normalized key so that
    // snapshot diffs are stable across runs and environments.
    final sortedObjects = [...groupedObjects]
      ..sort((a, b) {
        String keyA;
        if (a is GroupCluster) {
          keyA = a.sortKey;
        } else if (a is GenericGroupEntity) {
          keyA = a.princepsReferenceName;
        } else {
          keyA = '';
        }

        String keyB;
        if (b is GroupCluster) {
          keyB = b.sortKey;
        } else if (b is GenericGroupEntity) {
          keyB = b.princepsReferenceName;
        } else {
          keyB = '';
        }

        final normalizedA = normalizePrincipleOptimal(keyA);
        final normalizedB = normalizePrincipleOptimal(keyB);
        return normalizedA.compareTo(normalizedB);
      });

    final buffer = StringBuffer();

    for (final item in sortedObjects) {
      if (item is GroupCluster) {
        // Sort internal groups for stability.
        final sortedGroups = item.groups.toList()
          ..sort(
            (a, b) =>
                a.princepsReferenceName.compareTo(b.princepsReferenceName),
          );

        buffer
          ..writeln('[CLUSTER] ${item.displayName.toUpperCase()}')
          ..writeln(
            sortedGroups
                .map(
                  (group) => [
                    '  > ${group.princepsReferenceName}',
                    '    - ID: ${group.groupId}',
                    '    - Common: ${group.commonPrincipes}',
                  ].join('\n'),
                )
                .join('\n'),
          );
      } else if (item is GenericGroupEntity) {
        buffer
          ..writeln('[SINGLE] ${item.princepsReferenceName}')
          ..writeln('  - ID: ${item.groupId}');
      }

      buffer.writeln('-' * 40);
    }

    // Write the snapshot to the requested location inside the project.
    final outputFile = File(
      p.join('tool', 'snapshots', 'explorer_oral_reference.txt'),
    );
    await outputFile.parent.create(recursive: true);
    await outputFile.writeAsString(buffer.toString());

    // THEN: The snapshot file must exist and be non-empty.
    expect(outputFile.existsSync(), isTrue);
    expect(outputFile.lengthSync(), greaterThan(0));
  });
}
