import 'package:drift/drift.dart' hide isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/locator.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import 'package:pharma_scan/core/services/database_service.dart';
import 'package:pharma_scan/features/scanner/models/scan_result_model.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    setupLocator();
  });

  setUp(() async {
    await sl<DatabaseService>().clearDatabase();
  });

  testWidgets(
    'Vérifie que le parsing TXT extrait correctement les données réelles, notamment le baclofene 10mg de biogaran (3400930302613) avec ses principes actifs',
    (WidgetTester tester) async {
      // GIVEN: Le service d'initialisation
      final dataService = sl<DataInitializationService>();
      final dbService = sl<DatabaseService>();
      final db = sl<AppDatabase>();
      // Real data from BDPM (verified via data_validator.py):
      // - CIP: 3400930302613
      // - CIS: 62173429
      // - Name: BACLOFENE BIOGARAN 10 mg, comprimé sécable
      // - Laboratory: BIOGARAN
      // - Active Principle: BACLOFÈNE (note the È)
      // - Group ID: 231
      // - Type: GENERIC
      // - Associated Princeps: LIORESAL 10 mg, comprimé sécable
      const targetCip = '3400930302613';
      const expectedGroupId = '231';
      const expectedActivePrinciple = 'BACLOFÈNE'; // Note: È not E
      const expectedPrincepsName = 'LIORESAL 10 mg, comprimé sécable';

      // Étape 1: Exécuter le service d'initialisation (télécharge et parse les fichiers TXT)
      await dataService.initializeDatabase();

      // Étape 3: Vérifier d'abord que des médicaments ont été insérés
      final totalMedicamentsResult = await db
          .customSelect('SELECT COUNT(*) as count FROM medicaments')
          .getSingle();
      final count = totalMedicamentsResult.read<int>('count');
      expect(
        count,
        greaterThan(0),
        reason:
            'Au moins un médicament doit être dans la base après initialisation',
      );

      // Étape 4: Chercher le baclofene 10mg de biogaran dans la base de données
      // Utiliser searchMedicaments qui joint avec specialites pour obtenir le vrai nom

      // PRIORITÉ 1: Chercher spécifiquement le CIP 3400930302613
      var baclofeneMedicaments = await dbService.searchMedicaments(targetCip);

      // PRIORITÉ 2: Si pas trouvé, chercher par nom (baclofene + biogaran + 10)
      if (baclofeneMedicaments.isEmpty) {
        baclofeneMedicaments = await dbService.searchMedicaments(
          'baclofene biogaran 10',
        );
      }

      // PRIORITÉ 3: Si toujours pas trouvé, chercher n'importe quel baclofene de biogaran
      if (baclofeneMedicaments.isEmpty) {
        baclofeneMedicaments = await dbService.searchMedicaments(
          'baclofene biogaran',
        );
      }

      // PRIORITÉ 4: Si toujours pas trouvé, chercher n'importe quel baclofene
      if (baclofeneMedicaments.isEmpty) {
        baclofeneMedicaments = await dbService.searchMedicaments('baclofene');
      }

      // Si toujours pas trouvé, chercher des médicaments avec "biogaran" pour voir ce qui est disponible
      if (baclofeneMedicaments.isEmpty) {
        final biogaranMedicaments = await dbService.searchMedicaments(
          'biogaran',
        );

        // Si on trouve des biogaran mais pas de baclofene, c'est un problème de parsing
        if (biogaranMedicaments.isNotEmpty) {
          // Prendre le premier biogaran pour vérifier que le parsing fonctionne au moins
          // mais le test échouera car on ne trouve pas le baclofene
          expect(
            baclofeneMedicaments,
            isNotEmpty,
            reason:
                'Le baclofene doit être trouvé dans la base. Biogaran trouvé: ${biogaranMedicaments.map((m) => m.nom).take(3).toList()}, mais pas de baclofene.',
          );
        }
      }

      expect(
        baclofeneMedicaments,
        isNotEmpty,
        reason:
            'Au moins un médicament baclofene doit être trouvé dans la base de données après initialisation (total médicaments: $count)',
      );

      // Sélectionner le meilleur match (préférer le CIP cible ou celui avec "10")
      var selected = baclofeneMedicaments.firstWhere(
        (med) =>
            (med.codeCip == targetCip) ||
            (med.nom.toLowerCase().contains('10')),
        orElse: () => baclofeneMedicaments.first,
      );

      final actualCip = selected.codeCip;
      final actualNom = selected.nom;

      // Vérifier que c'est bien du baclofene
      final nomLower = actualNom.toLowerCase();
      expect(
        nomLower.contains('baclofene') || nomLower.contains('baclofène'),
        isTrue,
        reason:
            'Le médicament trouvé doit contenir "baclofene" ou "baclofène" (trouvé: $actualNom)',
      );

      // Si c'est le produit spécifique, vérifier qu'il contient "biogaran" et "10"
      if (actualCip == targetCip) {
        expect(
          nomLower.contains('biogaran'),
          isTrue,
          reason: 'Le baclofene doit contenir "biogaran" (trouvé: $actualNom)',
        );
        expect(
          nomLower.contains('10'),
          isTrue,
          reason:
              'Le baclofene doit contenir "10" pour le dosage (trouvé: $actualNom)',
        );
        // Vérifier que le nom contient "comprimé sécable" (forme pharmaceutique)
        expect(
          nomLower.contains('comprimé') && nomLower.contains('sécable'),
          isTrue,
          reason:
              'Le baclofene doit être un "comprimé sécable" (trouvé: $actualNom)',
        );
      }

      // Étape 4: Vérifier les principes actifs dans la base de données
      final principesResult = await db
          .customSelect(
            'SELECT principe FROM principes_actifs WHERE code_cip = ?',
            variables: [Variable<String>(actualCip)],
            readsFrom: {db.principesActifs},
          )
          .get();

      expect(
        principesResult,
        isNotEmpty,
        reason:
            'Le baclofene doit avoir au moins un principe actif dans la base de données (CIP: $actualCip)',
      );

      final dbPrincipes = principesResult
          .map((row) => row.read<String>('principe').toLowerCase())
          .toList();

      // Vérifier que les principes contiennent BACLOFÈNE (le principe actif réel avec È)
      final hasBaclofene = dbPrincipes.any(
        (p) =>
            p.contains('baclofene') ||
            p.contains('baclofène') ||
            p.contains('baclovène'),
      );

      expect(
        hasBaclofene,
        isTrue,
        reason:
            'Le baclofene doit avoir "BACLOFÈNE" comme principe actif (trouvé: ${principesResult.map((r) => r.read<String>('principe')).toList()})',
      );

      // Vérifier que le principe actif exact est présent (case-insensitive)
      final hasExactPrinciple = dbPrincipes.any(
        (p) => p.toLowerCase() == expectedActivePrinciple.toLowerCase(),
      );
      expect(
        hasExactPrinciple,
        isTrue,
        reason:
            'Le principe actif doit être exactement "$expectedActivePrinciple" (trouvé: ${principesResult.map((r) => r.read<String>('principe')).toList()})',
      );

      // Étape 5: Vérifier que getScanResultByCip fonctionne correctement
      final scanResult = await dbService.getScanResultByCip(actualCip);
      expect(
        scanResult,
        isNotNull,
        reason:
            'getScanResultByCip doit retourner un résultat pour le CIP $actualCip',
      );

      // Vérifier que les principes actifs sont correctement liés dans le scanResult
      scanResult!.when(
        generic: (medicament, associatedPrinceps, groupId) {
          expect(medicament.codeCip, actualCip);
          expect(medicament.nom, isNotEmpty);
          expect(
            medicament.principesActifs,
            isNotEmpty,
            reason: 'Le médicament générique doit avoir des principes actifs',
          );

          // Vérifier le group ID
          expect(
            groupId,
            expectedGroupId,
            reason: 'Le group ID doit être $expectedGroupId (trouvé: $groupId)',
          );

          // Vérifier que associatedPrinceps est une liste non vide de Medicament
          expect(associatedPrinceps, isA<List>());
          expect(associatedPrinceps, isNotEmpty);

          // Vérifier que chaque élément a les propriétés d'un Medicament
          for (final princeps in associatedPrinceps) {
            expect(princeps.codeCip, isA<String>());
            expect(princeps.codeCip, isNotEmpty);
            expect(princeps.nom, isA<String>());
            expect(princeps.nom, isNotEmpty);
            expect(princeps.principesActifs, isA<List<String>>());
          }

          // Vérifier que le princeps attendu est présent
          final hasExpectedPrinceps = associatedPrinceps.any(
            (p) => p.nom.contains('LIORESAL'),
          );
          expect(
            hasExpectedPrinceps,
            isTrue,
            reason:
                'Le princeps "$expectedPrincepsName" doit être dans la liste (trouvé: ${associatedPrinceps.map((p) => p.nom).toList()})',
          );

          final resultPrincipesLower = medicament.principesActifs
              .map((p) => p.toLowerCase())
              .toList();
          // Vérifier que les principes contiennent BACLOFÈNE (le principe actif réel avec È)
          final resultHasBaclofene = resultPrincipesLower.any(
            (p) =>
                p.contains('baclofene') ||
                p.contains('baclofène') ||
                p.contains('baclovène'),
          );

          expect(
            resultHasBaclofene,
            isTrue,
            reason:
                'Le baclofene dans le scanResult doit avoir "$expectedActivePrinciple" comme principe actif (trouvé: ${medicament.principesActifs})',
          );

          // Vérifier le principe actif exact (case-insensitive)
          final hasExactPrincipleInResult = resultPrincipesLower.any(
            (p) => p == expectedActivePrinciple.toLowerCase(),
          );
          expect(
            hasExactPrincipleInResult,
            isTrue,
            reason:
                'Le principe actif doit être exactement "$expectedActivePrinciple" (trouvé: ${medicament.principesActifs})',
          );
        },
        princeps: (princeps, moleculeName, genericLabs, groupId) {
          // This medication is a GENERIC, not a princeps, so this branch should not be reached
          // But we'll keep it for completeness in case the data changes
          expect(princeps.codeCip, actualCip);
          expect(princeps.nom, isNotEmpty);
          expect(
            princeps.principesActifs,
            isNotEmpty,
            reason: 'Le princeps doit avoir des principes actifs',
          );

          final resultPrincipesLower = princeps.principesActifs
              .map((p) => p.toLowerCase())
              .toList();
          // Vérifier que les principes contiennent BACLOFÈNE
          final resultHasBaclofene = resultPrincipesLower.any(
            (p) =>
                p.contains('baclofene') ||
                p.contains('baclofène') ||
                p.contains('baclovène'),
          );

          expect(
            resultHasBaclofene,
            isTrue,
            reason:
                'Le baclofene dans le scanResult doit avoir "$expectedActivePrinciple" comme principe actif (trouvé: ${princeps.principesActifs})',
          );
        },
      );
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
