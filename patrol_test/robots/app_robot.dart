import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/utils/test_tags.dart';

class AppRobot {
  final PatrolIntegrationTester $;

  AppRobot(this.$);

  // --- Native Actions ---
  Future<void> handlePermissions() async {
    // Patrol 4.0: use $.platform.mobile instead of $.native
    if (await $.platform.mobile.isPermissionDialogVisible()) {
      await $.platform.mobile.grantPermissionWhenInUse();
    }
  }

  // --- Navigation ---
  Future<void> tapScannerTab() async {
    await $(const Key(TestTags.navScanner)).tap();
  }

  Future<void> tapExplorerTab() async {
    await $(const Key(TestTags.navExplorer)).tap();
  }

  Future<void> tapRestockTab() async {
    await $(const Key(TestTags.navRestock)).tap();
  }

  // --- Scanner / Manual Entry ---
  Future<void> openManualEntry() async {
    await $(const Key(TestTags.manualEntryButton)).tap();
  }

  Future<void> enterCipAndSearch(String cip) async {
    // Le champ de saisie dans le BottomSheet (Scan) utilise souvent un focus automatique
    // On cible par le placeholder ou le type si la clé n'est pas sur le BottomSheet spécifique
    final inputFinder = $(Strings.cipPlaceholder);
    await inputFinder.waitUntilVisible();
    await inputFinder.enterText(cip);

    // Attendre que le clavier/UI se stabilise
    await $.pumpAndSettle();

    // Tap "Rechercher"
    await $(Strings.search).tap();
  }

  // --- Explorer ---
  Future<void> searchForMedicament(String query) async {
    await $(const Key(TestTags.searchField)).enterText(query);
    await $.pumpAndSettle();
  }

  // --- Assertions ---
  Future<void> expectItemInRestock(String label) async {
    // Scroll jusqu'à l'élément si la liste est longue
    await $(label).scrollTo(
      view: $(Scrollable).last, // Cible le bon scrollable si plusieurs
    );
    await $(label).waitUntilVisible();
  }

  Future<void> expectMedicamentVisibleInExplorer(String name) async {
    await $(name).waitUntilVisible();
  }
}