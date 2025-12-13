import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:pharma_scan/main.dart';
import 'package:pharma_scan/core/services/preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'helpers/test_database_helper.dart';
import 'robots/app_robot.dart';
import 'package:pharma_scan/core/utils/strings.dart';

void main() {
  final config = PatrolTesterConfig();

  patrolTest(
    'E2E: Scanner manual entry -> search -> result or not found',
    config: config,
    ($) async {
      // Prepare device/app state
      await $.pump();

      // Inject a known test database to avoid network operations
      await TestDatabaseHelper.injectTestDatabase();

      // Load prefs prepared by the helper
      final prefs = await SharedPreferences.getInstance();

      // Start the real app within a ProviderScope that uses the test prefs
      await $.pumpWidgetAndSettle(
        ProviderScope(
          overrides: [
            preferencesServiceProvider
                .overrideWithValue(PreferencesService(prefs)),
          ],
          child: const PharmaScanApp(),
        ),
      );

      final robot = AppRobot($);

      // Grant permissions if requested (simulates first-run behaviour)
      await robot.handlePermissions();

      // Navigate to Scanner tab
      await robot.tapScannerTab();
      await $.pumpAndSettle();

      // Open manual CIP entry and perform a search
      await robot.openManualEntry();
      await $.pumpAndSettle();

      // Use a sample CIP (may or may not exist in the test DB); we accept both outcomes
      const sampleCip = '3400934056781';
      await robot.enterCipAndSearch(sampleCip);

      // Wait for either a not-found message or the medication detail action to appear
      // If the DB contains the CIP, we expect a medication card / 'Fiche' button.
      try {
        await $(Strings.medicamentNotFound)
            .waitUntilVisible(timeout: const Duration(seconds: 4));
        // Medicament not found — acceptable outcome for this e2e if sample CIP absent
        expect($(Strings.medicamentNotFound), findsOneWidget);
      } catch (_) {
        // Otherwise expect the medication UI (a 'Fiche' button) to be visible
        await $(Strings.ficheInfo)
            .waitUntilVisible(timeout: const Duration(seconds: 4));
        expect($(Strings.ficheInfo), findsOneWidget);
      }

      // On non-macOS devices we can also test a native interaction
      if (!Platform.isMacOS) {
        await $.native.pressHome();
      }
    },
  );
}
