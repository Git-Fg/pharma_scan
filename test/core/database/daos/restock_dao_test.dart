import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/database/daos/restock_dao.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/database/reference_schema.drift.dart';
import 'package:pharma_scan/core/domain/types/ids.dart';
import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase database;
  late RestockDao dao;

  setUp(() async {
    database = createTestDatabase();
    dao = database.restockDao;

    // Insérer des données de référence pour les tests
    await database.into(database.medicaments).insert(
          MedicamentsCompanion.insert(
            codeCip: '3400934056781',
            cisCode: '12345678',
            presentationLabel: const Value('Test Medicament'),
          ),
        );

    await database.into(database.medicamentSummary).insert(
          MedicamentSummaryCompanion.insert(
            cisCode: '12345678',
            nomCanonique: 'TEST MEDICAMENT',
            princepsDeReference: 'TEST',
            princepsBrandName: 'TEST BRAND',
            isPrinceps: const Value(true),
            formePharmaceutique: const Value('Comprimé'),
          ),
        );

    await database.into(database.specialites).insert(
          SpecialitesCompanion.insert(
            cisCode: '12345678',
            nomSpecialite: 'TEST MEDICAMENT',
            formePharmaceutique: const Value('Comprimé'),
          ),
        );
  });

  tearDown(() => database.close());

  test('addToRestock should increment quantity if item exists', () async {
    final cip = Cip13.validated('3400934056781');

    // 1. Premier ajout
    await dao.addToRestock(cip);

    // 2. Deuxième ajout (doublon métier)
    await dao.addToRestock(cip);

    final item = await dao.getRestockQuantity(cip);
    expect(item, 2); // Vérifie la logique "UPSERT"
  });

  test('updateQuantity should modify stock count correctly', () async {
    final cip = Cip13.validated('3400934056781');

    // Ajouter un item avec quantité initiale de 1
    await dao.addToRestock(cip);

    // Incrémenter de 3
    await dao.updateQuantity(cip, 3);

    final item = await dao.getRestockQuantity(cip);
    expect(item, 4); // 1 initial + 3 incrément = 4
  });

  test('deleteRestockItemFully should remove item completely', () async {
    final cip = Cip13.validated('3400934056781');

    // Ajouter un item
    await dao.addToRestock(cip);

    // Vérifier qu'il existe
    expect(await dao.getRestockQuantity(cip), 1);

    // Supprimer l'item
    await dao.deleteRestockItemFully(cip);

    // Vérifier qu'il n'existe plus
    expect(await dao.getRestockQuantity(cip), null);
  });

  test('clearAll should remove all items', () async {
    final cip1 = Cip13.validated('3400934056781');
    // Créer un second médicament pour le test
    await database.into(database.medicaments).insert(
          MedicamentsCompanion.insert(
            codeCip: '3400934056782',
            cisCode: '12345679',
            presentationLabel: const Value('Test Medicament 2'),
          ),
        );

    await database.into(database.medicamentSummary).insert(
          MedicamentSummaryCompanion.insert(
            cisCode: '12345679',
            nomCanonique: 'TEST MEDICAMENT 2',
            princepsDeReference: 'TEST 2',
            princepsBrandName: 'TEST BRAND 2',
            isPrinceps: const Value(true),
            formePharmaceutique: const Value('Gélule'),
          ),
        );

    await database.into(database.specialites).insert(
          SpecialitesCompanion.insert(
            cisCode: '12345679',
            nomSpecialite: 'TEST MEDICAMENT 2',
            formePharmaceutique: const Value('Gélule'),
          ),
        );

    final cip2 = Cip13.validated('3400934056782');

    // Ajouter deux items
    await dao.addToRestock(cip1);
    await dao.addToRestock(cip2);

    // Vérifier qu'ils existent
    expect(await dao.getRestockQuantity(cip1), 1);
    expect(await dao.getRestockQuantity(cip2), 1);

    // Effacer tous les items
    await dao.clearAll();

    // Vérifier qu'ils n'existent plus
    expect(await dao.getRestockQuantity(cip1), null);
    expect(await dao.getRestockQuantity(cip2), null);
  });

  test('toggleCheck should update checked state', () async {
    final cip = Cip13.validated('3400934056781');

    // Ajouter un item
    await dao.addToRestock(cip);

    // Basculer l'état (devrait être cochée)
    await dao.toggleCheck(cip);

    // Récupérer l'item pour vérifier l'état
    final item = await (database.select(database.restockItems)
          ..where((tbl) => tbl.cipCode.equals(cip.toString())))
        .getSingleOrNull();
    expect(item?.notes, '{"checked":true}');

    // Basculer à nouveau (devrait être décochée)
    await dao.toggleCheck(cip);

    // Récupérer à nouveau
    final item2 = await (database.select(database.restockItems)
          ..where((tbl) => tbl.cipCode.equals(cip.toString())))
        .getSingleOrNull();
    expect(item2?.notes, '{"checked":false}');
  });
}
