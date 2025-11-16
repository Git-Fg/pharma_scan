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

  // Nettoyer et réinitialiser la base de données avant chaque test
  setUp(() async {
    await sl<DatabaseService>().clearDatabase();
  });

  testWidgets(
    'Pipeline de données complet',
    (WidgetTester tester) async {
      // GIVEN: Une base de données vide et un service d'initialisation
      final dataService = sl<DataInitializationService>();
      final dbService = sl<DatabaseService>();
      final db = sl<AppDatabase>();

      // WHEN: On exécute le processus d'initialisation complet
      // Cela va télécharger les fichiers TXT, parser et insérer les données.
      await dataService.initializeDatabase();

      // THEN: On vérifie que les données ont été correctement insérées

      // Vérifier d'abord que des données ont été insérées en utilisant drift
      final medicamentCountResult = await db
          .customSelect('SELECT COUNT(*) as count FROM medicaments')
          .getSingle();
      final count = medicamentCountResult.read<int>('count');
      expect(
        count,
        greaterThan(0),
        reason: "Aucun médicament n'a été inséré dans la base de données",
      );

      // Vérifier qu'il y a des groupes génériques
      final groupCountResult = await db
          .customSelect('SELECT COUNT(*) as count FROM generique_groups')
          .getSingle();
      final grpCount = groupCountResult.read<int>('count');
      expect(
        grpCount,
        greaterThan(0),
        reason: "Aucun groupe générique n'a été inséré dans la base de données",
      );

      // Trouver un générique quelconque pour vérifier que la requête fonctionne
      final generiquesResult = await db
          .customSelect(
            'SELECT gm.code_cip FROM group_members gm WHERE gm.type = 1 LIMIT 1',
          )
          .getSingleOrNull();
      if (generiquesResult != null) {
        final codeCipGenerique = generiquesResult.read<String>('code_cip');

        // Tester la méthode unifiée
        final scanResult = await dbService.getScanResultByCip(codeCipGenerique);
        expect(
          scanResult,
          isNotNull,
          reason:
              "Le scanResult n'a pas été trouvé pour le générique: $codeCipGenerique",
        );
        scanResult!.when(
          generic: (medicament, associatedPrinceps, groupId) {
            expect(medicament.codeCip, codeCipGenerique);
            expect(medicament.nom, isNotEmpty);
            // Vérifier que associatedPrinceps est une liste (peut être vide si le groupe n'a pas de princeps)
            expect(associatedPrinceps, isA<List>());
            // Vérifier que chaque élément a les propriétés d'un Medicament
            for (final princeps in associatedPrinceps) {
              expect(princeps.codeCip, isA<String>());
              expect(princeps.codeCip, isNotEmpty);
              expect(princeps.nom, isA<String>());
              expect(princeps.nom, isNotEmpty);
            }
          },
          princeps: (princeps, moleculeName, genericLabs, groupId) {
            fail("Le résultat devrait être un GenericScanResult");
          },
        );
      }

      // Vérifier qu'un médicament qui n'est pas dans un groupe retourne null
      final nonGroupedResult = await db
          .customSelect(
            'SELECT m.code_cip FROM medicaments m LEFT JOIN group_members gm ON m.code_cip = gm.code_cip WHERE gm.code_cip IS NULL LIMIT 1',
          )
          .getSingleOrNull();
      if (nonGroupedResult != null) {
        final codeCipStandalone = nonGroupedResult.read<String>('code_cip');

        // NOTE: Standalone medicaments without group membership now return null
        final standaloneScanResult = await dbService.getScanResultByCip(
          codeCipStandalone,
        );
        expect(
          standaloneScanResult,
          isNull,
          reason:
              "Le médicament standalone sans groupe devrait retourner null avec getScanResultByCip: $codeCipStandalone",
        );
      }

      // Vérifier qu'un princeps dans un groupe retourne un PrincepsScanResult avec des génériques associés
      final princepsResult = await db
          .customSelect(
            'SELECT gm.code_cip FROM group_members gm WHERE gm.type = 0 LIMIT 1',
          )
          .getSingleOrNull();
      if (princepsResult != null) {
        final codeCipPrinceps = princepsResult.read<String>('code_cip');

        // La méthode devrait retourner un PrincepsScanResult
        final princepsScanResult = await dbService.getScanResultByCip(
          codeCipPrinceps,
        );
        expect(
          princepsScanResult,
          isNotNull,
          reason:
              "Le princeps devrait être trouvé avec getScanResultByCip: $codeCipPrinceps",
        );
        princepsScanResult!.when(
          generic: (medicament, associatedPrinceps, groupId) {
            fail("Le résultat devrait être un PrincepsScanResult");
          },
          princeps: (princeps, moleculeName, genericLabs, groupId) {
            expect(princeps.codeCip, codeCipPrinceps);
            expect(moleculeName, isNotEmpty);
            expect(genericLabs, isA<List<String>>());
          },
        );
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
  ); // Augmenter le timeout car le téléchargement peut être long
}
