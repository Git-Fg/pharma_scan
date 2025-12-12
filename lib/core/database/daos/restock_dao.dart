import 'package:drift/drift.dart';
import 'package:pharma_scan/core/database/daos/restock_dao.drift.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/domain/types/ids.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/features/history/domain/entities/scan_history_entry.dart';
import 'package:pharma_scan/features/restock/domain/entities/restock_item_entity.dart';

/// Helper function to check if an exception is a UNIQUE constraint violation.
/// Works across both native SQLite and web platforms.
bool _isUniqueConstraintViolation(Object e) {
  final message = e.toString().toLowerCase();
  return message.contains('unique constraint failed') ||
      message.contains('constraint failed') ||
      message.contains('2067') ||
      message.contains('sqlite3_result_code: 19');
}

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

  /// Ajoute un item au réapprovisionnement en utilisant le CIP.
  /// Si l'item existe déjà, incrémente stock_count.
  Future<void> addToRestock(Cip13 cip) async {
    final cipString = cip.toString();

    // Récupérer les infos du médicament depuis la DB
    final medicamentInfo = await customSelect(
      '''
      SELECT m.cis_code, ms.nom_canonique, ms.is_princeps, 
             ms.princeps_de_reference, ms.forme_pharmaceutique,
             ms.voies_administration, ms.formatted_dosage, ms.representative_cip
      FROM medicaments m
      LEFT JOIN medicament_summary ms ON m.cis_code = ms.cis_code
      WHERE m.code_cip = ?
      LIMIT 1
      ''',
      variables: [Variable<String>(cipString)],
      readsFrom: {},
    ).getSingleOrNull();

    if (medicamentInfo == null) {
      // Si le médicament n'existe pas dans la DB, créer un item minimal
      // Check if item already exists
      final existing = await customSelect(
        'SELECT stock_count FROM restock_items WHERE cip_code = ? LIMIT 1',
        variables: [Variable<String>(cipString)],
        readsFrom: {},
      ).getSingleOrNull();

      if (existing != null) {
        // Update existing item
        final currentCount = existing.readNullable<int>('stock_count') ?? 0;
        await customUpdate(
          "UPDATE restock_items SET stock_count = ?, updated_at = datetime('now') WHERE cip_code = ?",
          variables: [
            Variable<int>(currentCount + 1),
            Variable<String>(cipString),
          ],
          updates: {},
        );
      } else {
        // Insert new item
        await customUpdate(
          '''
          INSERT INTO restock_items (
            cip_code, cis_code, nom_canonique, is_princeps, stock_count, created_at, updated_at
          ) VALUES (?, ?, ?, 0, 1, datetime('now'), datetime('now'))
          ''',
          variables: [
            Variable<String>(cipString),
            const Variable<String>(''),
            const Variable<String>(Strings.unknown),
          ],
          updates: {},
        );
      }
      return;
    }

    final cisCode = medicamentInfo.readNullable<String>('cis_code') ?? '';
    final nomCanonique =
        medicamentInfo.readNullable<String>('nom_canonique') ?? Strings.unknown;
    final isPrinceps =
        (medicamentInfo.readNullable<int>('is_princeps') ?? 0) == 1;
    final princepsDeReference = medicamentInfo.readNullable<String>(
      'princeps_de_reference',
    );
    final formePharmaceutique = medicamentInfo.readNullable<String>(
      'forme_pharmaceutique',
    );
    final voiesAdministration = medicamentInfo.readNullable<String>(
      'voies_administration',
    );
    final formattedDosage = medicamentInfo.readNullable<String>(
      'formatted_dosage',
    );
    final representativeCip = medicamentInfo.readNullable<String>(
      'representative_cip',
    );

    // Check if item already exists
    final existing = await customSelect(
      'SELECT stock_count FROM restock_items WHERE cip_code = ? LIMIT 1',
      variables: [Variable<String>(cipString)],
      readsFrom: {},
    ).getSingleOrNull();

    if (existing != null) {
      // Update existing item
      final currentCount = existing.readNullable<int>('stock_count') ?? 0;
      await customUpdate(
        '''
        UPDATE restock_items SET 
          stock_count = ?,
          updated_at = datetime('now')
        WHERE cip_code = ?
        ''',
        variables: [
          Variable<int>(currentCount + 1),
          Variable<String>(cipString),
        ],
        updates: {},
      );
    } else {
      // Insert new item
      await customUpdate(
        '''
        INSERT INTO restock_items (
          cip_code, cis_code, nom_canonique, is_princeps, princeps_de_reference,
          forme_pharmaceutique, voies_administration, formatted_dosage,
          representative_cip, stock_count, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 1, datetime('now'), datetime('now'))
        ''',
        variables: [
          Variable<String>(cipString),
          Variable<String>(cisCode),
          Variable<String>(nomCanonique),
          Variable<int>(isPrinceps ? 1 : 0),
          Variable<String>(princepsDeReference),
          Variable<String>(formePharmaceutique),
          Variable<String>(voiesAdministration),
          Variable<String>(formattedDosage),
          Variable<String>(representativeCip),
        ],
        updates: {},
      );
    }
  }

  /// Met à jour la quantité d'un item.
  Future<void> updateQuantity(
    Cip13 cip,
    int delta, {
    bool allowZero = false,
  }) async {
    final cipString = cip.toString();

    final existing = await customSelect(
      'SELECT stock_count FROM restock_items WHERE cip_code = ?',
      variables: [Variable<String>(cipString)],
      readsFrom: {},
    ).getSingleOrNull();

    if (existing == null) return;

    final currentCount = existing.readNullable<int>('stock_count') ?? 0;
    final newQuantity = currentCount + delta;
    final shouldDelete = allowZero ? newQuantity < 0 : newQuantity <= 0;

    if (shouldDelete) {
      await deleteRestockItemFully(cip);
    } else {
      await customUpdate(
        "UPDATE restock_items SET stock_count = ?, updated_at = datetime('now') WHERE cip_code = ?",
        variables: [
          Variable<int>(newQuantity),
          Variable<String>(cipString),
        ],
        updates: {},
      );
    }
  }

  /// Supprime complètement un item du réapprovisionnement.
  Future<void> deleteRestockItemFully(Cip13 cip) async {
    final cipString = cip.toString();
    await customUpdate(
      'DELETE FROM restock_items WHERE cip_code = ?',
      variables: [Variable<String>(cipString)],
      updates: {},
    );
    // Supprimer aussi les scans associés
    await customUpdate(
      'DELETE FROM scanned_boxes WHERE cip_code = ?',
      variables: [Variable<String>(cipString)],
      updates: {},
    );
  }

  /// Toggle l'état "checked" d'un item (utilise la colonne notes pour stocker l'état)
  Future<void> toggleCheck(Cip13 cip) async {
    final cipString = cip.toString();
    // Utiliser notes pour stocker l'état checked (JSON: {"checked": true/false})
    final current = await customSelect(
      'SELECT notes FROM restock_items WHERE cip_code = ?',
      variables: [Variable<String>(cipString)],
      readsFrom: {},
    ).getSingleOrNull();

    final isChecked =
        current != null &&
        (current.readNullable<String>('notes')?.contains('"checked":true') ??
            false);

    await customUpdate(
      "UPDATE restock_items SET notes = ?, updated_at = datetime('now') WHERE cip_code = ?",
      variables: [
        Variable<String>('{"checked":${!isChecked}}'),
        Variable<String>(cipString),
      ],
      updates: {},
    );
  }

  /// Supprime tous les items checked.
  Future<void> clearChecked() async {
    await customUpdate(
      'DELETE FROM restock_items WHERE notes LIKE \'%"checked":true%\'',
      updates: {},
    );
  }

  /// Supprime tous les items de réapprovisionnement.
  Future<void> clearAll() async {
    await customUpdate('DELETE FROM restock_items', updates: {});
    await customUpdate('DELETE FROM scanned_boxes', updates: {});
  }

  /// Vérifie si un scan est un doublon (basé sur box_label dans le schéma SQL)
  Future<bool> isDuplicate({
    required String cip,
    required String serial,
  }) async {
    // Dans le schéma SQL, scanned_boxes utilise box_label qui peut contenir le serial
    final rows = await customSelect(
      'SELECT 1 FROM scanned_boxes WHERE cip_code = ? AND box_label LIKE ? LIMIT 1',
      variables: [
        Variable<String>(cip),
        Variable<String>('%$serial%'),
      ],
      readsFrom: {},
    ).get();
    return rows.isNotEmpty;
  }

  /// Force la mise à jour de la quantité.
  Future<void> forceUpdateQuantity({
    required String cip,
    required int newQuantity,
  }) async {
    if (newQuantity < 0) {
      await deleteRestockItemFully(Cip13.validated(cip));
      return;
    }

    final existing = await customSelect(
      'SELECT cip_code FROM restock_items WHERE cip_code = ?',
      variables: [Variable<String>(cip)],
      readsFrom: {},
    ).getSingleOrNull();

    if (existing != null) {
      await customUpdate(
        "UPDATE restock_items SET stock_count = ?, updated_at = datetime('now') WHERE cip_code = ?",
        variables: [
          Variable<int>(newQuantity),
          Variable<String>(cip),
        ],
        updates: {},
      );
    } else {
      // Créer un nouvel item si il n'existe pas
      await addToRestock(Cip13.validated(cip));
      if (newQuantity != 1) {
        await forceUpdateQuantity(cip: cip, newQuantity: newQuantity);
      }
    }
  }

  /// Récupère la quantité d'un item.
  Future<int?> getRestockQuantity(String cip) async {
    final row = await customSelect(
      'SELECT stock_count FROM restock_items WHERE cip_code = ?',
      variables: [Variable<String>(cip)],
      readsFrom: {},
    ).getSingleOrNull();
    return row?.readNullable<int>('stock_count');
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
      final medicament = await customSelect(
        'SELECT cis_code FROM medicaments WHERE code_cip = ? LIMIT 1',
        variables: [Variable<String>(cip.toString())],
        readsFrom: {},
      ).getSingleOrNull();

      final cisCode = medicament?.readNullable<String>('cis_code');
      final boxLabel = serial != null
          ? '${cip}_$serial${batchNumber != null ? '_$batchNumber' : ''}'
          : cip.toString();

      await customUpdate(
        '''
        INSERT INTO scanned_boxes (box_label, cis_code, cip_code, scan_timestamp)
        VALUES (?, ?, ?, datetime('now'))
        ''',
        variables: [
          Variable<String>(boxLabel),
          Variable<String>(cisCode),
          Variable<String>(cip.toString()),
        ],
        updates: {},
      );
      return ScanOutcome.added;
    } catch (e) {
      if (_isUniqueConstraintViolation(e)) {
        return ScanOutcome.duplicate;
      }
      rethrow;
    }
  }

  /// Stream des items de réapprovisionnement avec jointures vers medicament_summary
  Stream<List<RestockItemEntity>> watchRestockItems() {
    return customSelect(
      '''
      SELECT 
        ri.cip_code,
        ri.stock_count,
        ri.notes,
        ms.nom_canonique,
        ms.princeps_de_reference,
        ms.is_princeps,
        ms.forme_pharmaceutique,
        s.forme_pharmaceutique AS specialite_forme
      FROM restock_items ri
      LEFT JOIN medicaments m ON m.code_cip = ri.cip_code
      LEFT JOIN medicament_summary ms ON ms.cis_code = m.cis_code
      LEFT JOIN specialites s ON s.cis_code = m.cis_code
      ORDER BY ri.updated_at DESC
      ''',
      readsFrom: {},
    ).watch().map((rows) {
      return rows.map((row) {
        final cip = Cip13.validated(
          row.readNullable<String>('cip_code') ?? '',
        );
        final label =
            row.readNullable<String>('nom_canonique') ?? Strings.unknown;
        final princepsLabel = row.readNullable<String>('princeps_de_reference');
        final isPrinceps = (row.readNullable<int>('is_princeps') ?? 0) == 1;
        final form =
            row.readNullable<String>('forme_pharmaceutique') ??
            row.readNullable<String>('specialite_forme');
        final quantity = row.readNullable<int>('stock_count') ?? 1;
        final notes = row.readNullable<String>('notes') ?? '';
        final isChecked = notes.contains('"checked":true');

        return RestockItemEntity(
          cip: cip,
          label: label,
          princepsLabel: princepsLabel,
          quantity: quantity,
          isChecked: isChecked,
          isPrinceps: isPrinceps,
          form: form,
        );
      }).toList();
    });
  }

  /// Ajoute une boîte unique avec gestion des doublons
  Future<ScanOutcome> addUniqueBox({
    required Cip13 cip,
    String? serial,
    String? batchNumber,
    DateTime? expiryDate,
  }) async {
    if (serial == null || serial.isEmpty) {
      await addToRestock(cip);
      return ScanOutcome.added;
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
      return ScanOutcome.added;
    } catch (e) {
      if (_isUniqueConstraintViolation(e)) {
        return ScanOutcome.duplicate;
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
    await customUpdate('DELETE FROM scanned_boxes', updates: {});
  }

  /// Stream des totaux de scans par CIP
  Stream<List<({Cip13 cip, int quantity})>> watchScannedBoxTotals() {
    return customSelect(
      'SELECT cip_code AS cip, COUNT(*) AS quantity FROM scanned_boxes GROUP BY cip_code',
      readsFrom: {},
    ).watch().map((rows) {
      return rows.map((row) {
        final cip = Cip13.validated(row.readNullable<String>('cip') ?? '');
        final quantity = row.readNullable<int>('quantity') ?? 0;
        return (cip: cip, quantity: quantity);
      }).toList();
    });
  }
}
