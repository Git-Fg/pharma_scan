import 'package:patrol/patrol.dart';
import 'package:pharma_scan/core/utils/strings.dart';

class AppRobot {
  final PatrolIntegrationTester $;

  AppRobot(this.$);

  // --- Native Actions ---
  Future<void> handlePermissions() async {
    // Utilisation de $.platform.mobile au lieu de $.native
    if (await $.platform.mobile.isPermissionDialogVisible()) {
      await $.platform.mobile.grantPermissionWhenInUse();
    }
  }

  // --- Navigation ---
  Future<void> tapRestockTab() async {
    // Pour l'instant, utilise le texte en attendant que les widgets utilisent TestTags
    await $(Strings.restockTabLabel).tap();
  }

  // --- Scanner / Manual Entry Actions ---
  Future<void> openManualEntry() async {
    // Trouve le bouton "Saisie" dans les contrôles du scanner
    await $(Strings.manualEntry).tap();
  }

  Future<void> enterCip(String cip) async {
    // Attend que la bottom sheet soit visible
    await $(Strings.cipPlaceholder).waitUntilVisible();
    await $(Strings.cipPlaceholder).enterText(cip);

    // Pump and settle pour laisser le temps à l'UI de réagir
    await $.pumpAndSettle();

    await $(Strings.search).tap();
  }

  // --- Assertions ---
  Future<void> expectItemInRestock(String label, int quantity) async {
    // Vérifie que l'item est bien dans la liste de rangement
    await $(label).scrollTo();
    await $(label).waitUntilVisible();

    // On peut utiliser "which" pour des assertions plus complexes si nécessaire
    await $(quantity.toString()).waitUntilVisible();
  }
}