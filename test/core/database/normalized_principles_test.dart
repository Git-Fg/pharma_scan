// test/integration/normalized_principles_test.dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/logic/sanitizer.dart';

void main() {
  group('Normalized Principles Integration', () {
    test('should store normalized principles correctly', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());

      // Insérer un principe avec normalisation
      await db
          .into(db.principesActifs)
          .insert(
            PrincipesActifsCompanion.insert(
              codeCip: 'TEST001',
              principe: 'MÉMANTINE BASE',
              principeNormalized: Value(
                normalizePrincipleOptimal('MÉMANTINE BASE'),
              ),
            ),
          );

      // Vérifier que le principe normalisé est stocké
      final query = db.selectOnly(db.principesActifs)
        ..addColumns([
          db.principesActifs.principe,
          db.principesActifs.principeNormalized,
        ])
        ..where(db.principesActifs.codeCip.equals('TEST001'));

      final result = await query.getSingle();
      final principe = result.read(db.principesActifs.principe);
      final normalized = result.read(db.principesActifs.principeNormalized);

      expect(principe, equals('MÉMANTINE BASE'));
      expect(
        normalized,
        equals('MEMANTINE'),
        reason: 'MÉMANTINE BASE should be normalized to MEMANTINE',
      );

      await db.close();
    });
  });
}
