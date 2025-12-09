import 'package:auto_route/auto_route.dart';
import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pharma_scan/core/services/haptic_service.dart';
import 'package:pharma_scan/features/scanner/presentation/providers/scanner_provider.dart';

extension ScanNavigation on WidgetRef {
  Future<void> navigateToRestockMode(BuildContext context) async {
    read(scannerProvider.notifier).setMode(ScannerMode.restock);
    try {
      AutoTabsRouter.of(context).setActiveIndex(0);
    } on Object {
      // Not inside a tab scaffold (e.g., tests or standalone routes).
    }
    await read(hapticServiceProvider).restockSuccess();
  }
}
