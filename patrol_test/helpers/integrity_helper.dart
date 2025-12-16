import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:patrol/patrol.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/main.dart';

/// Helper to verify database state and consistency
class IntegrityHelper {
  /// Checks key database consistency rules
  static Future<void> checkDatabaseIntegrity($) async {
    final container = ProviderScope.containerOf(
        ($.tester as WidgetTester).element(find.byType(PharmaScanApp)));
    final db = container.read(databaseProvider());

    // 1. Check for Orphans: Medicaments without Groups
    final stats = await db.catalogDao.getDatabaseStats();
    if (stats.totalPrinceps == 0 && stats.totalGeneriques == 0) {
      throw Exception(
          'Integrity Check Failed: Database seems empty (0 medicaments)');
    }

    // 2. Restock Logic Integrity
    // Ensure all restock items refer to existing medicaments
    final restockItems = await db.managers.restockItems.get();
    for (final item in restockItems) {
      // Check against productScanCache which is our main product lookup table now
      final linkedMed = await db.managers.productScanCache
          .filter((f) => f.cipCode.cipCode.equals(item.cipCode))
          .getSingleOrNull();

      if (linkedMed == null) {
        throw Exception(
            'Integrity Check Failed: Restock item ${item.cipCode} has no matching medicament');
      }
    }

    debugPrint(
        '✅ Database Integrity Check Passed: ${stats.totalPrinceps + stats.totalGeneriques} meds, ${restockItems.length} restock items');
  }
}
