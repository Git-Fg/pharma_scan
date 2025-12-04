import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/database/daos/catalog_dao.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/domain/types/ids.dart';

void main() {
  late AppDatabase db;
  late CatalogDao scanDao;

  setUp(() {
    db = AppDatabase.forTesting(
      NativeDatabase.memory(setup: configureAppSQLite),
    );
    scanDao = db.catalogDao;
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seedData({
    String? agrement,
    double? price,
    String? availability,
  }) async {
    await db
        .into(db.specialites)
        .insert(
          SpecialitesCompanion.insert(
            cisCode: '123456',
            nomSpecialite: 'Test Specialite',
            procedureType: 'Procédure',
            formePharmaceutique: const Value('Comprimé'),
            etatCommercialisation: const Value('Commercialisée'),
          ),
        );

    await db
        .into(db.medicaments)
        .insert(
          MedicamentsCompanion.insert(
            codeCip: '3400000000012',
            cisCode: '123456',
            presentationLabel: const Value('Boîte de 30 gélules'),
            commercialisationStatut: const Value('Commercialisée'),
            tauxRemboursement: const Value('65%'),
            prixPublic: Value(price),
            agrementCollectivites: Value(agrement),
          ),
        );

    await db
        .into(db.medicamentSummary)
        .insert(
          MedicamentSummaryCompanion.insert(
            cisCode: '123456',
            nomCanonique: 'Test Médicament',
            isPrinceps: false,
            principesActifsCommuns: const ['Test'],
            princepsDeReference: 'Test Princeps',
            formePharmaceutique: const Value('Comprimé'),
            princepsBrandName: 'Test Brand',
            procedureType: const Value('Procédure'),
            titulaire: const Value('Test Lab'),
          ),
        );

    if (availability != null) {
      await db
          .into(db.medicamentAvailability)
          .insert(
            MedicamentAvailabilityCompanion.insert(
              codeCip: '3400000000012',
              statut: availability,
              dateDebut: Value(DateTime.utc(2025)),
            ),
          );
    }
  }

  test('returns availability status when shortage entry exists', () async {
    await seedData(
      agrement: 'non',
      price: 12.5,
      availability: 'Rupture de stock',
    );

    final result = await scanDao.getProductByCip(Cip13.validated('3400000000012'));

    expect(result, isNotNull);
    expect(result!.availabilityStatus, equals('Rupture de stock'));
    expect(result.isHospitalOnly, isFalse);
    expect(result.libellePresentation, equals('Boîte de 30 gélules'));
  });

  test(
    'flags hospital-only presentations with agrement and no price',
    () async {
      await seedData(agrement: 'oui');

      final result = await scanDao.getProductByCip(Cip13.validated('3400000000012'));
      expect(result, isNotNull);
      expect(result!.isHospitalOnly, isTrue);
      expect(result.availabilityStatus, isNull);
      expect(result.libellePresentation, equals('Boîte de 30 gélules'));
    },
  );
}
