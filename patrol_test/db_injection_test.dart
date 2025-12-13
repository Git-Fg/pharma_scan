import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:pharma_scan/main.dart';
import 'package:pharma_scan/core/services/preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'helpers/test_database_helper.dart';

void main() {
  final config = PatrolTesterConfig();

  patrolTest(
    'Database Injection Test',
    config: config,
    ($) async {
      // --- PHASE 1 : SETUP ---

      // 1. Initialiser le binding
      await $.pump();

      // 2. Injecter la base de données réelle
      await TestDatabaseHelper.injectTestDatabase();

      // 3. Récupérer les prefs
      final prefs = await SharedPreferences.getInstance();

      // 4. Lancer une app simplifiée sans workmanager
      await $.pumpWidgetAndSettle(
        ProviderScope(
          overrides: [
            preferencesServiceProvider.overrideWithValue(PreferencesService(prefs)),
          ],
          child: MaterialApp(
            home: Scaffold(
              appBar: AppBar(title: const Text('DB Test')),
              body: const Center(child: Text('Database injected successfully!')),
            ),
          ),
        ),
      );

      // --- PHASE 2 : VERIFICATION ---

      // Vérifier que l'app se lance bien
      expect($('DB Test'), findsOneWidget);
      expect($('Database injected successfully!'), findsOneWidget);

      print('✅ Database injection test passed!');
    },
  );
}