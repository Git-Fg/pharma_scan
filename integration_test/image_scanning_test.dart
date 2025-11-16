import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pharma_scan/core/locator.dart';
import 'package:pharma_scan/core/services/database_service.dart';
import 'package:pharma_scan/core/utils/gs1_parser.dart';
import 'package:pharma_scan/features/scanner/models/scan_result_model.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    setupLocator();
  });

  testWidgets(
    'devrait extraire le rawValue depuis une image, le parser et trouver le médicament',
    (WidgetTester tester) async {
      // --- PARTIE 1: EXTRACTION DEPUIS L'IMAGE ---

      // GIVEN: L'image de test `image_test_1.png`
      const imagePath = 'assets/test_images/image_test_1.png';
      final byteData = await rootBundle.load(imagePath);
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/temp_image.png');
      await file.writeAsBytes(
        byteData.buffer.asUint8List(
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        ),
      );

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
        reason: "La capture ne contient aucun code-barres.",
      );
      final rawValueFromImage = capture.barcodes.first.rawValue;
      expect(rawValueFromImage, isNotNull);

      // --- PARTIE 2: LOGIQUE DE L'APPLICATION ---

      // GIVEN: Le rawValue extrait et une base de données de test
      // La valeur attendue est '01034009303026132132780924334799 10MA00614A 17270430'
      // ou une variante avec des caractères de contrôle.
      final dbService = sl<DatabaseService>();
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
      await dbService.insertBatchData(
        specialites: [
          {
            'cis_code': 'CIS_TEST',
            'nom_specialite': 'MEDICAMENT DE TEST 100mg',
            'procedure_type': 'Autorisation',
          },
        ],
        medicaments: [
          {
            'code_cip': expectedCip,
            'nom': 'MEDICAMENT DE TEST 100mg',
            'cis_code': 'CIS_TEST',
          },
        ],
        principes: [
          {'code_cip': expectedCip, 'principe': 'TESTOLOL'},
        ],
        generiqueGroups: [
          {'group_id': 'TEST_GROUP_1', 'libelle': 'TEST GROUP'},
        ],
        groupMembers: [
          {'code_cip': expectedCip, 'group_id': 'TEST_GROUP_1', 'type': 1},
        ], // Le marquer comme générique
      );

      // AND WHEN: On teste la méthode unifiée
      final scanResult = await dbService.getScanResultByCip(expectedCip);

      // AND THEN: Le résultat est un GenericScanResult
      expect(
        scanResult,
        isNotNull,
        reason: "Le scanResult n'a pas été trouvé dans la base de données",
      );
      scanResult!.when(
        generic: (medicament, associatedPrinceps, groupId) {
          expect(medicament.nom, 'MEDICAMENT DE TEST 100mg');
          expect(medicament.principesActifs, contains('TESTOLOL'));
          expect(associatedPrinceps, isA<List>());
        },
        princeps: (princeps, moleculeName, genericLabs, groupId) {
          fail("Le résultat devrait être un GenericScanResult");
        },
      );
    },
  );
}
