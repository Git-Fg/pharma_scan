import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/utils/test_tags.dart';
import 'package:pharma_scan/features/explorer/presentation/widgets/medicament_tile.dart';
import 'package:pharma_scan/main.dart';
import '../test/fixtures/seed_builder.dart';
import '../test/robots/explorer_robot.dart';
import '../test/test_utils.dart' show setPrincipeNormalizedForAllPrinciples;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Search & Navigation Flow - Critical User Journey', () {
    testWidgets(
      'should complete search -> result -> detail -> back with keyboard interaction',
      (WidgetTester tester) async {
        final tempDir = await Directory.systemTemp.createTemp(
          'pharma_scan_test_',
        );
        final dbFile = File(p.join(tempDir.path, 'medicaments.db'));

        final database = AppDatabase.forTesting(
          NativeDatabase(dbFile, setup: configureAppSQLite),
        );

        await SeedBuilder()
            .inGroup('GROUP_DOLIPRANE', 'DOLIPRANE 1000 mg')
            .addPrinceps(
              'DOLIPRANE 1000 mg, comprimé',
              'CIP_PRINCEPS',
              cis: 'CIS_PRINCEPS',
              dosage: '1000',
              form: 'Comprimé',
              lab: 'SANOFI',
            )
            .addGeneric(
              'PARACETAMOL 1000 mg, comprimé',
              'CIP_GENERIC1',
              cis: 'CIS_GENERIC1',
              dosage: '1000',
              form: 'Comprimé',
              lab: 'BIOGARAN',
            )
            .addGeneric(
              'PARACETAMOL 1000 mg, comprimé',
              'CIP_GENERIC2',
              cis: 'CIS_GENERIC2',
              dosage: '1000',
              form: 'Comprimé',
              lab: 'SANDOZ',
            )
            .addGeneric(
              'PARACETAMOL 1000 mg, comprimé',
              'CIP_GENERIC3',
              cis: 'CIS_GENERIC3',
              dosage: '1000',
              form: 'Comprimé',
              lab: 'TEVA',
            )
            .inGroup('GROUP_NARCOTIC', 'MORPHINE 10 mg')
            .addPrinceps(
              'MORPHINE 10 mg, comprimé',
              'CIP_NARCOTIC',
              cis: 'CIS_NARCOTIC',
              dosage: '10',
              form: 'Comprimé',
              lab: 'LAB_NARCOTIC',
            )
            .insertInto(database);

        await database.databaseDao.insertBatchData(
          specialites: [
            {
              'cis_code': 'CIS_NARCOTIC',
              'nom_specialite': 'MORPHINE 10 mg, comprimé',
              'procedure_type': 'Autorisation',
              'forme_pharmaceutique': 'Comprimé',
              'titulaire': 'LAB_NARCOTIC',
              'conditions_prescription': 'STUPÉFIANT',
            },
          ],
          medicaments: [],
          principes: [],
          generiqueGroups: [],
          groupMembers: [],
        );

        await setPrincipeNormalizedForAllPrinciples(database);
        final dataInit = DataInitializationService(database: database);
        await dataInit.runSummaryAggregationForTesting();

        await database.settingsDao.updateBdpmVersion(
          DataInitializationService.dataVersion,
        );

        final container = ProviderContainer(
          overrides: [appDatabaseProvider.overrideWithValue(database)],
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const PharmaScanApp(),
          ),
        );

        await tester.pumpAndSettle(const Duration(seconds: 2));

        final explorerTab = find.byKey(const ValueKey(TestTags.navExplorer));
        expect(explorerTab, findsOneWidget);
        await tester.tap(explorerTab);
        await tester.pumpAndSettle();

        expect(find.text(Strings.explorer), findsWidgets);

        final robot = ExplorerRobot(tester);

        await robot.searchFor('Doliprane');
        await tester.pumpAndSettle(const Duration(milliseconds: 500));

        final resultTiles = find.byType(MedicamentTile);
        expect(
          resultTiles,
          findsWidgets,
          reason: 'Expected search results for Doliprane',
        );

        await tester.tap(resultTiles.first);
        await tester.pumpAndSettle();

        expect(
          find.text(Strings.princeps),
          findsOneWidget,
          reason: 'Group detail should show Princeps section',
        );
        expect(
          find.text(Strings.generics),
          findsOneWidget,
          reason: 'Group detail should show Generics section',
        );

        final backButton = find.bySemanticsLabel(Strings.back);
        if (backButton.evaluate().isNotEmpty) {
          await tester.tap(backButton.first);
        }
        await tester.pumpAndSettle();

        expect(
          find.text(Strings.explorer),
          findsWidgets,
          reason: 'Should return to Explorer screen after back navigation',
        );
        expect(
          find.bySemanticsLabel(Strings.searchLabel),
          findsOneWidget,
          reason: 'Search field should still be visible after returning',
        );

        await database.close();
        await tempDir.delete(recursive: true);
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );
  });
}
