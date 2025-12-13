import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:pharma_scan/main.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/services/preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'robots/app_robot.dart';

void main() {
  // Configuration globale pour les tests Patrol (optionnel mais utile pour les timeouts)
  final config = PatrolTesterConfig();

  patrolTest(
    'Simple app initialization test',
    config: config,
    ($) async {
      // Mock SharedPreferences
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      // Pump de l'application
      // Note: On utilise pumpWidgetAndSettle pour attendre la fin des animations d'intro
      await $.pumpWidgetAndSettle(
        ProviderScope(
          overrides: [
            preferencesServiceProvider.overrideWithValue(PreferencesService(prefs)),
          ],
          child: const PharmaScanApp(),
        ),
      );

      expect($(Strings.appName), findsOneWidget);
    },
  );

  patrolTest(
    'E2E: Cold start -> Permission -> Manual Restock -> Verify DB',
    config: config,
    ($) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await $.pumpWidgetAndSettle(
        ProviderScope(
          overrides: [
            preferencesServiceProvider.overrideWithValue(PreferencesService(prefs)),
          ],
          child: const PharmaScanApp(),
        ),
      );

      final robot = AppRobot($);

      // Gestion native des permissions via la nouvelle API
      await robot.handlePermissions();

      // Vérification écran initial
      expect($(Strings.readyToScan), findsOneWidget);

      // Flux critique
      await robot.openManualEntry();

      const targetCip = '3400934056781';
      await robot.enterCip(targetCip);

      // Attendre que l'animation de la bottom sheet se termine
      await $.pumpAndSettle();

      await robot.tapRestockTab();

      // Validation
      await $(targetCip).waitUntilVisible();
    },
  );

  patrolTest(
    'Native interaction: Press home button',
    config: config,
    ($) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await $.pumpWidgetAndSettle(
        ProviderScope(
          overrides: [
            preferencesServiceProvider.overrideWithValue(PreferencesService(prefs)),
          ],
          child: const PharmaScanApp(),
        ),
      );

      // Utilisation de la nouvelle API Platform
      // $.platform.mobile gère intelligemment iOS et Android
      await $.platform.mobile.pressHome();

      // Pour revenir sur l'app (test de résilience)
      await $.platform.mobile.openApp();

      // Vérifier qu'on est toujours dans un état cohérent
      expect($(Strings.appName), findsOneWidget);
    },
  );
}