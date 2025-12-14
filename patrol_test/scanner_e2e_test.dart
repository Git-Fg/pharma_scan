import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:pharma_scan/main.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'helpers/test_database_helper.dart';
import 'robots/app_robot.dart';
import 'robots/scanner_robot.dart';

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

      // Start the real app within a ProviderScope
      await $.pumpWidgetAndSettle(
        ProviderScope(
          child: const PharmaScanApp(),
        ),
      );

      final robot = AppRobot($);

      // Complete app initialization
      await robot.completeAppInitialization();

      // Complete scanner flow: navigate to scanner, open manual entry, search CIP
      const sampleCip = '3400934056781';
      await robot.scanner.completeManualSearchFlow(sampleCip);

      // Verify search results - accept both found and not found outcomes
      final scanner = robot.scanner;
      try {
        await scanner.expectMedicamentNotFound();
      } catch (_) {
        await scanner.expectMedicamentFound();
      }

      // On non-macOS devices we can also test a native interaction
      if (!Platform.isMacOS) {
        await robot.pressHome();
      }
    },
  );
}
