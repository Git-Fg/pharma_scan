import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:pharma_scan/main.dart';
import 'package:pharma_scan/core/services/preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pharma_scan/features/home/screens/main_screen.dart';
import 'package:auto_route/auto_route.dart';
import 'package:pharma_scan/core/router/app_router.dart';
import 'helpers/test_database_helper.dart';
import 'robots/app_robot.dart';

void main() {
  final config = PatrolTesterConfig();

  patrolTest(
    'E2E: Test Navigation with Real DB (Full App Context)',
    config: config,
    ($) async {
      // --- PHASE 1 : SETUP ---
      await $.pump();
      await TestDatabaseHelper.injectTestDatabase();
      final prefs = await SharedPreferences.getInstance();

      // --- PHASE 2 : TEST NAVIGATION WITHIN FULL APP ---

      // Test avec l'app complète et navigation réelle
      await $.pumpWidgetAndSettle(
        ProviderScope(
          overrides: [
            preferencesServiceProvider.overrideWithValue(PreferencesService(prefs)),
          ],
          child: MaterialApp.router(
            routerConfig: AppRouter().config(),
          ),
        ),
      );

      final robot = AppRobot($);

      // Gérer les permissions
      await robot.handlePermissions();

      // Vérifier que l'app se charge correctement (devrait être sur l'onglet scanner)
      expect($('Scanner'), findsOneWidget);
      print('✅ App loaded successfully on Scanner tab');

      // Tester la navigation vers l'onglet explorer
      await robot.tapExplorerTab();
      expect($('Explorer'), findsOneWidget);
      print('✅ Navigation to Explorer tab successful');

      // Tester la navigation vers l'onglet restock
      await robot.tapRestockTab();
      expect($('Liste de rangement'), findsOneWidget);
      print('✅ Navigation to Restock tab successful');

      // Retourner à l'onglet scanner
      await robot.tapScannerTab();
      expect($('Scanner'), findsOneWidget);
      print('✅ Navigation back to Scanner tab successful');

      print('✅ All navigation tests passed with real database!');
    },
  );
}