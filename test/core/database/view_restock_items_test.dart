import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/domain/types/ids.dart';
import 'package:pharma_scan/core/database/daos/restock_dao.dart';
import '../../helpers/test_database.dart';

void main() {
  late AppDatabase database;
  late RestockDao dao;

  setUp(() {
    database = createTestDatabase(useRealReferenceDatabase: true);
    dao = database.restockDao;
  });

  tearDown(() => database.close());

  test('View view_restock_items should be created and functional', () async {
    // 1. Get a valid CIP from reference DB to ensure join works
    final cips = await database
        .customSelect('SELECT cip_code FROM reference_db.medicaments LIMIT 1')
        .get();

    if (cips.isEmpty) {
      // Fallback or fail if DB empty
      fail("reference_db.medicaments is empty!");
    }

    final cipCode = cips.isNotEmpty
        ? cips.first.read<String>('cip_code')
        : '3400934168322'; // detailed fallback

    final cip = Cip13.validated(cipCode);
    await dao.addToRestock(cip);

    // 2. Query the query directly via generated accessor
    final viewResult =
        await database.restockViewsDrift.restockItemsWithDetails().get();

    expect(viewResult, isNotEmpty, reason: "Query should return rows");
    final firstRow = viewResult.first;
    expect(firstRow.cipCode, cipCode);
    expect(firstRow.nomCanonique, isNotNull,
        reason: "Joined data from reference_db should be present");
    expect(firstRow.nomCanonique, isNotEmpty,
        reason: "Should contain real data");

    // 3. Verify DAO returns mapped entities
    final entities = await dao.watchRestockItems().first;
    expect(entities, isNotEmpty);
    expect(entities.first.cip.toString(), cipCode);
    expect(entities.first.label, isNotEmpty);
  });
}
