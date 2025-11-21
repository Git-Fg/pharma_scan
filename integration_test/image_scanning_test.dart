import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import 'package:pharma_scan/core/services/drift_database_service.dart';
import 'package:pharma_scan/core/utils/gs1_parser.dart';
import 'package:pharma_scan/features/scanner/models/scan_result_model.dart';
import 'package:pharma_scan/features/scanner/repositories/scanner_repository.dart';
import '../test/fixtures/data_factory.dart';
import 'test_bootstrap.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late DriftDatabaseService dbService;
  late DataInitializationService dataInitializationService;

  setUpAll(() async {
    final container = await ensureIntegrationTestContainer();
    dbService = container.read(driftDatabaseServiceProvider);
    dataInitializationService = container.read(
      dataInitializationServiceProvider,
    );
  });

  testWidgets(
    'devrait extraire le rawValue depuis une image, le parser et trouver le médicament',
    (WidgetTester tester) async {
      // --- PARTIE 1: EXTRACTION DEPUIS L'IMAGE ---

      // GIVEN: L'image de test `image_test_1.png`
      // WHY: Load test image from test assets directory programmatically
      // This prevents test assets from bloating the production app bundle
      final testImagePath = 'test/assets/test_images/image_test_1.png';
      final testImageFile = File(testImagePath);
      if (!await testImageFile.exists()) {
        // Fallback: try to find the image in the project root for CI/CD
        final altPath = File('assets/test_images/image_test_1.png');
        if (await altPath.exists()) {
          final tempDir = await getTemporaryDirectory();
          final file = File('${tempDir.path}/temp_image.png');
          await altPath.copy(file.path);
          final scannerController = MobileScannerController();
          final capture = await scannerController.analyzeImage(file.path);
          await scannerController.dispose();
          expect(
            capture,
            isNotNull,
            reason: "Aucun code-barres détecté dans l'image.",
          );
          expect(
            capture!.barcodes,
            isNotEmpty,
            reason: 'La capture ne contient aucun code-barres.',
          );
          final rawValueFromImage = capture.barcodes.first.rawValue;
          expect(rawValueFromImage, isNotNull);
          // Continue with parsing logic below...
          await dbService.clearDatabase();
          final parsedData = Gs1Parser.parse(rawValueFromImage);
          final foundCip = parsedData.gtin;
          expect(foundCip, isNotNull);
          return;
        }
        throw Exception(
          'Test image not found. Please ensure $testImagePath exists.',
        );
      }
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/temp_image.png');
      await testImageFile.copy(file.path);

      final scannerController = MobileScannerController();

      // WHEN: On scanne l'image pour obtenir le `rawValue`
      final capture = await scannerController.analyzeImage(file.path);
      await scannerController.dispose();

      // THEN: On vérifie que mobile_scanner a bien lu le code
      expect(
        capture,
        isNotNull,
        reason: "Aucun code-barres détecté dans l'image.",
      );
      expect(
        capture!.barcodes,
        isNotEmpty,
        reason: 'La capture ne contient aucun code-barres.',
      );
      final rawValueFromImage = capture.barcodes.first.rawValue;
      expect(rawValueFromImage, isNotNull);

      // --- PARTIE 2: LOGIQUE DE L'APPLICATION ---

      // GIVEN: Le rawValue extrait et une base de données de test
      // La valeur attendue est '01034009303026132132780924334799 10MA00614A 17270430'
      // ou une variante avec des caractères de contrôle.
      await dbService.clearDatabase();

      // WHEN: On parse le `rawValue` avec notre parser optimisé
      final parsedData = Gs1Parser.parse(rawValueFromImage);
      final foundCip = parsedData.gtin;

      // THEN: Le CIP est correctement extrait
      expect(
        foundCip,
        isNotNull,
        reason:
            "Le GTIN n'a pas pu être extrait du rawValue: '$rawValueFromImage'",
      );

      final expectedCip = foundCip!;

      // AND WHEN: On insère des données de test correspondant au CIP détecté
      final batch = DataFactory.createGroup(
        groupId: 'TEST_GROUP_1',
        libelle: 'TEST GROUP',
        members: [
          GroupMemberDefinition(
            cisCode: 'CIS_TEST',
            codeCip: expectedCip,
            nomSpecialite: 'MEDICAMENT DE TEST 100mg',
            type: 1, // generic
            molecule: 'TESTOLOL',
          ),
        ],
      );
      await dbService.insertBatchData(
        specialites: batch.specialites,
        medicaments: batch.medicaments,
        principes: batch.principes,
        generiqueGroups: batch.generiqueGroups,
        groupMembers: batch.groupMembers,
      );

      // Populate medicament_summary table
      await dataInitializationService.runSummaryAggregationForTesting();

      // AND WHEN: On teste la méthode unifiée
      final scannerRepository = ScannerRepository(dbService);
      final scanResult = await scannerRepository.getScanResult(expectedCip);

      // AND THEN: Le résultat est un GenericScanResult
      expect(
        scanResult,
        isNotNull,
        reason: "Le scanResult n'a pas été trouvé dans la base de données",
      );
      switch (scanResult!) {
        case GenericScanResult(
          medicament: final medicament,
          associatedPrinceps: final associatedPrinceps,
        ):
          expect(medicament.nom, 'MEDICAMENT DE TEST 100mg');
          expect(medicament.principesActifs, contains('TESTOLOL'));
          expect(associatedPrinceps, isA<List>());
        case PrincepsScanResult():
          fail('Le résultat devrait être un GenericScanResult');
        case StandaloneScanResult():
          fail('Le résultat devrait être un GenericScanResult');
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
