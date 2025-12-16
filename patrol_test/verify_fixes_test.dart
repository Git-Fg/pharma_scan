import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/database/providers.dart';
import 'package:pharma_scan/core/domain/types/ids.dart';
import 'package:pharma_scan/core/providers/core_providers.dart'; // Export restockDaoProvider
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/main.dart'; // for PharmaScanApp
import 'package:shadcn_ui/shadcn_ui.dart';

import '../test/helpers/test_database.dart';

void main() {
  patrolTest(
    'Verify Restock List and Explorer Search Fixes',
    ($) async {
      // 1. Setup Test Database
      // Create database with real reference.db attached
      final db = createTestDatabase();

      // Pre-set version to prevent auto-initialization flow
      // This ensures the app considers itself "Ready" and doesn't try to download invalid URLs
      await db.appSettingsDao.setBdpmVersion('test-version-1.0');

      // 2. Setup Provider Container with overrides
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
      );

      await $.pumpWidgetAndSettle(
        UncontrolledProviderScope(
          container: container,
          child: const PharmaScanApp(),
        ),
      );

      // 3. Verify Initial State (Liste Tab)
      // "Liste" title or tab label.
      await $.pumpAndSettle();
      print('Checking for Restock Title: ${Strings.restockTitle}');
      expect($(find.text(Strings.restockTitle)), findsAtLeastNWidgets(1));

      // 4. Get a valid CIP from the attached Reference DB
      // We search for "AMOXICILLINE" to match user request
      final existingCips = await db
          .customSelect(
              "SELECT cip_code, nom_canonique FROM reference_db.medicament_summary WHERE nom_canonique LIKE '%AMOXICILLINE%' LIMIT 1")
          .get();

      if (existingCips.isEmpty) {
        throw Exception(
            "Reference DB has no Amoxicilline tests! Test environment is incomplete.");
      }

      final row = existingCips.first;
      final targetCip = row.read<String>('cip_code');
      final targetName = row.read<String>('nom_canonique');
      print('Discovered Target Item: $targetName ($targetCip)');

      final simpleName = "AMOXICILLINE";

      // 5. Simulate "Scanning" an item (Add to Restock)
      // Since we can't easily scan in simulator without mocking camera, we use the DAO directly
      await container
          .read(restockDaoProvider)
          .addToRestock(Cip13.validated(targetCip));

      // 6. Verify item appears in Restock List
      await $.pumpAndSettle();

      // The list item should display the name (or part of it)
      // findRichText is true by default for textContaining? No, check doc.
      // But ShadText might be composed.
      // Just check textContaining.
      final itemFinder = find.textContaining(simpleName, findRichText: true);
      expect($(itemFinder), findsAtLeastNWidgets(1));
      print('Item "$simpleName" found in Restock List.');

      // 7. Verify Explorer Tab
      // Tap "Explorer" (Strings.explorer)
      await $.tap(find.text(Strings.explorer));
      await $.pumpAndSettle();

      // 8. Search in Explorer
      final inputFinder = find.byType(ShadInput);
      await $.enterText(inputFinder, simpleName);

      // Wait for debounce (usually 300-500ms in app)
      await $.pumpAndSettle(const Duration(milliseconds: 1000));

      // 9. Verify Search Results: ClusterTile logic
      // Should find a cluster naming Amoxicilline
      final clusterFinder = find.textContaining(simpleName);
      expect($(clusterFinder), findsAtLeastNWidgets(1));
      print('Cluster "$simpleName" found in Explorer.');

      // 10. Open Details
      await $.tap(clusterFinder.first);
      await $.pumpAndSettle();

      // 11. Verify Drawer
      // Should show 'Détail du groupe' (Strings.groupDetail? drawer_utils uses literal 'Détail du groupe')
      // but let's check text availability.
      expect($(find.text('Détail du groupe')), findsOneWidget);
      // Content should also list items
      expect($(find.textContaining(simpleName)), findsAtLeastNWidgets(1));
      print('Drawer opened and verified.');

      // Cleanup
      await db.close();
      container.dispose();
    },
  );
}
