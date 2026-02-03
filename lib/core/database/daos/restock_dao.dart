import 'package:drift/drift.dart';
import 'package:pharma_scan/core/database/daos/restock_dao.drift.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/database/user_schema.drift.dart';

import 'package:pharma_scan/core/domain/types/ids.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/domain/entities/scan_history_entry.dart';
import 'package:pharma_scan/core/domain/entities/restock_item_entity.dart';
import 'package:pharma_scan/core/database/utils/sql_error_x.dart';

// Centralized detection moved to `lib/core/database/utils/sql_error_x.dart`.

enum ScanOutcome { added, duplicate }

/// DAO pour gérer les items de réapprovisionnement et l'historique des scans.
///
/// Utilise la structure du schéma SQL distant :
/// - restock_items: id, cis_code, cip_code, nom_canonique, is_princeps, stock_count, etc.
/// - scanned_boxes: id, box_label, cis_code, cip_code, scan_timestamp
///
/// Les tables BDPM (medicaments, medicament_summary, specialites) sont définies dans le schéma SQL
/// et accessibles via customSelect/customUpdate.
@DriftAccessor()
class RestockDao extends DatabaseAccessor<AppDatabase> with $RestockDaoMixin {
  RestockDao(super.attachedDatabase);

  /// Consolidated upsert helper that handles both insert and update operations
  /// This eliminates code duplication and provides a single source of truth for upsert logic
  Future<void> _upsertRestockItem({
    required String cipCode,
    required String cisCode,
    required String nomCanonique,
    required bool isPrinceps,
    String? princepsDeReference,
    String? formePharmaceutique,
    String? voiesAdministration,
    String? formattedDosage,
    String? representativeCip,
    int increment = 1,
  }) async {
    // Use Drift's type-safe DSL with onConflict for upsert
    await into(attachedDatabase.restockItems).insert(
      RestockItemsCompanion(
        cipCode: Value(cipCode),
        cisCode: Value(cisCode),
        nomCanonique: Value(nomCanonique),
        isPrinceps: Value(isPrinceps ? 1 : 0),
        princepsDeReference: Value(princepsDeReference),
        formePharmaceutique: Value(formePharmaceutique),
        voiesAdministration: Value(voiesAdministration),
        formattedDosage: Value(formattedDosage),
        representativeCip: Value(representativeCip),
        stockCount: Value(increment),
        createdAt: Value(DateTime.now().toIso8601String()),
        updatedAt: Value(DateTime.now().toIso8601String()),
      ),
      onConflict: DoUpdate(
        (old) => RestockItemsCompanion.custom(
          stockCount: old.stockCount + Constant(increment),
          updatedAt: Constant(DateTime.now().toIso8601String()),
        ),
      ),
    );
  }

  /// Ajoute un item au réapprovisionnement en utilisant le CIP.
  /// Si l'item existe déjà, incrémente stock_count.
  Future<void> addToRestock(Cip13 cip) async {
    final cipString = cip.toString();

    // Use managers to fetch from the optimized read cache
    final cachedProduct = await attachedDatabase.managers.productScanCache
        .filter((f) => f.cipCode.equals(cipString))
        .getSingleOrNull();

    if (cachedProduct == null) {
      // Fallback: If not in cache, create a minimal item
      // This handles "Unknown" items gracefully
      await _upsertRestockItem(
        cipCode: cipString,
        cisCode: '',
        nomCanonique: Strings.unknown,
        isPrinceps: false,
      );
      return;
    }

    // Map fields directly from the cache to the upsert helper
    await _upsertRestockItem(
      cipCode: cipString,
      cisCode: cachedProduct.cisCode,
      nomCanonique: cachedProduct.nomCanonique,
      isPrinceps: cachedProduct.isPrinceps == 1,
      princepsDeReference: cachedProduct.princepsDeReference,
      formePharmaceutique: cachedProduct.formePharmaceutique,
      voiesAdministration: cachedProduct.voiesAdministration,
      formattedDosage: cachedProduct.formattedDosage,
      representativeCip: cachedProduct.representativeCip,
    );
  }

  /// Met à jour la quantité d'un item.
  Future<void> updateQuantity(
    Cip13 cip,
    int delta, {
    bool allowZero = false,
  }) async {
    final cipString = cip.toString();

    final existing = await attachedDatabase.managers.restockItems
        .filter((f) => f.cipCode.equals(cipString))
        .getSingleOrNull();

    if (existing == null) return;

    final currentCount = existing.stockCount;
    final newQuantity = currentCount + delta;
    final shouldDelete = allowZero ? newQuantity < 0 : newQuantity <= 0;

    if (shouldDelete) {
      await deleteRestockItemFully(cip);
    } else {
      await attachedDatabase.managers.restockItems
          .filter((f) => f.cipCode.equals(cipString))
          .update(
            (c) => c(
              stockCount: Value(newQuantity),
              updatedAt: Value(DateTime.now().toIso8601String()),
            ),
          );
    }
  }

  /// Supprime complètement un item du réapprovisionnement.
  Future<void> deleteRestockItemFully(Cip13 cip) async {
    final cipString = cip.toString();
    await attachedDatabase.managers.restockItems
        .filter((f) => f.cipCode.equals(cipString))
        .delete();
    // Supprimer aussi les scans associés
    await attachedDatabase.managers.scannedBoxes
        .filter((f) => f.cipCode.equals(cipString))
        .delete();
  }

  /// Toggle l'état "checked" d'un item (utilise la colonne notes pour stocker l'état)
  Future<void> toggleCheck(Cip13 cip) async {
    final cipString = cip.toString();
    final current = await attachedDatabase.managers.restockItems
        .filter((f) => f.cipCode.equals(cipString))
        .getSingleOrNull();

    final isChecked =
        current != null && (current.notes?.contains('"checked":true') ?? false);

    await attachedDatabase.managers.restockItems
        .filter((f) => f.cipCode.equals(cipString))
        .update(
          (c) => c(
            notes: Value('{"checked":${!isChecked}}'),
            updatedAt: Value(DateTime.now().toIso8601String()),
          ),
        );
  }

  /// Supprime tous les items checked.
  Future<void> clearChecked() async {
    await attachedDatabase.managers.restockItems
        .filter((f) => f.notes.contains('"checked":true'))
        .delete();
  }

  /// Supprime tous les items de réapprovisionnement.
  Future<void> clearAll() async {
    await attachedDatabase.managers.restockItems.delete();
    await attachedDatabase.managers.scannedBoxes.delete();
  }

  /// Vérifie si un scan est un doublon (basé sur box_label dans le schéma SQL)
  Future<bool> isDuplicate({required Cip13 cip, required String serial}) async {
    final cipString = cip.toString();
    final rows = await attachedDatabase.managers.scannedBoxes
        .filter(
          (f) => f.cipCode.equals(cipString) & f.boxLabel.contains(serial),
        )
        .get();
    return rows.isNotEmpty;
  }

  /// Force la mise à jour de la quantité.
  Future<void> forceUpdateQuantity({
    required Cip13 cip,
    required int newQuantity,
  }) async {
    final cipString = cip.toString();

    if (newQuantity < 0) {
      await deleteRestockItemFully(cip);
      return;
    }

    final existing = await attachedDatabase.managers.restockItems
        .filter((f) => f.cipCode.equals(cipString))
        .getSingleOrNull();

    if (existing != null) {
      await attachedDatabase.managers.restockItems
          .filter((f) => f.cipCode.equals(cipString))
          .update(
            (c) => c(
              stockCount: Value(newQuantity),
              updatedAt: Value(DateTime.now().toIso8601String()),
            ),
          );
    } else {
      // Créer un nouvel item si il n'existe pas
      await addToRestock(cip);
      if (newQuantity != 1) {
        await forceUpdateQuantity(cip: cip, newQuantity: newQuantity);
      }
    }
  }

  /// Récupère la quantité d'un item.
  Future<int?> getRestockQuantity(Cip13 cip) async {
    final item = await attachedDatabase.managers.restockItems
        .filter((f) => f.cipCode.equals(cip.toString()))
        .getSingleOrNull();
    return item?.stockCount;
  }

  /// Adds a manual item to restock when not found in database.
  Future<void> addManualToRestock({
    required String princeps,
    String? generic,
    int quantity = 1,
  }) async {
    final cipCode = 'MAN-${DateTime.now().millisecondsSinceEpoch}';
    await _upsertRestockItem(
      cipCode: cipCode,
      cisCode: '',
      nomCanonique: generic ?? princeps,
      isPrinceps: generic == null || generic.isEmpty,
      princepsDeReference: princeps,
      increment: quantity,
    );
  }

  /// Enregistre un scan dans scanned_boxes (structure du schéma SQL)
  Future<ScanOutcome> recordScan({
    required Cip13 cip,
    String? serial,
    String? batchNumber,
    DateTime? expiryDate,
  }) async {
    try {
      // Récupérer cis_code depuis medicaments
      final medicament = await attachedDatabase.managers.medicaments
          .filter((f) => f.cipCode.equals(cip.toString()))
          .getSingleOrNull();

      final cisCode = medicament?.cisCode ?? '';
      final boxLabel = serial != null
          ? '${cip}_$serial${batchNumber != null ? '_$batchNumber' : ''}'
          : cip.toString();

      await attachedDatabase.managers.scannedBoxes.create(
        (c) => c(
          boxLabel: boxLabel,
          cisCode: Value(cisCode),
          cipCode: Value(cip.toString()),
          scanTimestamp: Value(DateTime.now().toIso8601String()),
        ),
      );
      return .added;
    } catch (e) {
      if (e.isUniqueConstraintViolation()) {
        return .duplicate;
      }
      rethrow;
    }
  }

  /// Stream des items de réapprovisionnement via la vue view_restock_items
  Stream<List<RestockItemEntity>> watchRestockItems() {
    return attachedDatabase.restockViewsDrift
        .restockItemsWithDetails()
        .watch()
        .map(
          (rows) => rows.map((row) => RestockItemEntity.fromData(row)).toList(),
        );
  }

  // Removed _mapRowToRestockItem as it is no longer needed.

  /// Ajoute une boîte unique avec gestion des doublons
  Future<ScanOutcome> addUniqueBox({
    required Cip13 cip,
    String? serial,
    String? batchNumber,
    DateTime? expiryDate,
  }) async {
    if (serial == null || serial.isEmpty) {
      await addToRestock(cip);
      return .added;
    }

    try {
      await attachedDatabase.transaction(() async {
        await recordScan(
          cip: cip,
          serial: serial,
          batchNumber: batchNumber,
          expiryDate: expiryDate,
        );
        await addToRestock(cip);
      });
      return .added;
    } catch (e) {
      if (e.isUniqueConstraintViolation()) {
        return .duplicate;
      }
      rethrow;
    }
  }

  /// Stream de l'historique des scans (adapté pour la structure du schéma SQL)
  Stream<List<ScanHistoryEntry>> watchScanHistory(int limit) {
    final safeLimit = limit < 1 ? 1 : (limit > 500 ? 500 : limit);

    // Utiliser la requête générée depuis queries.drift qui a été mise à jour
    return attachedDatabase.queriesDrift
        .getScanHistory(limit: safeLimit)
        .watch()
        .map<List<ScanHistoryEntry>>(
          (rows) => rows.map(ScanHistoryEntry.fromData).toList(),
        );
  }

  /// Supprime l'historique des scans.
  Future<void> clearHistory() async {
    await attachedDatabase.managers.scannedBoxes.delete();
  }

  /// Stream des totaux de scans par CIP
  Stream<List<({Cip13 cip, int quantity})>> watchScannedBoxTotals() {
    return customSelect(
      'SELECT cip_code AS cip, COUNT(*) AS quantity FROM scanned_boxes GROUP BY cip_code',
      readsFrom: {attachedDatabase.scannedBoxes},
    ).watch().map((rows) {
      return rows.map((row) {
        final cip = Cip13.validated(row.readNullable<String>('cip') ?? '');
        final quantity = row.readNullable<int>('quantity') ?? 0;
        return (cip: cip, quantity: quantity);
      }).toList();
    });
  }
}
