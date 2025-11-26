import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/utils/gs1_parser.dart';
import '../test/fixtures/data_factory.dart';
import 'test_bootstrap.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late DataInitializationService dataInitializationService;

  setUpAll(() async {
    final container = await ensureIntegrationTestContainer();
    db = container.read(appDatabaseProvider);
    dataInitializationService = container.read(
      dataInitializationServiceProvider,
    );
  });

  testWidgets(
    'devrait extraire le rawValue depuis une image, le parser et trouver le médicament',
    (WidgetTester tester) async {
      // WHY: This test validates backend logic (barcode extraction and parsing).
      // For simple backend tests, direct assertions are sufficient.

      // --- PARTIE 1: EXTRACTION DEPUIS L'IMAGE ---

      // GIVEN: L'image de test `image_test_1.png`
      // WHY: Load test image from test assets directory programmatically
      // This prevents test assets from bloating the production app bundle
      final tempImage = await _writeScannerTestImageToTemp();

      final scannerController = MobileScannerController();

      // WHEN: On scanne l'image pour obtenir le `rawValue`
      final capture = await scannerController.analyzeImage(tempImage.path);
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
      await db.databaseDao.clearDatabase();

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
      await db.databaseDao.insertBatchData(
        specialites: batch.specialites,
        medicaments: batch.medicaments,
        principes: batch.principes,
        generiqueGroups: batch.generiqueGroups,
        groupMembers: batch.groupMembers,
      );

      // Populate medicament_summary table
      await dataInitializationService.runSummaryAggregationForTesting();

      // AND WHEN: On teste la méthode unifiée
      final scanDao = db.scanDao;
      final result = await scanDao.getProductByCip(expectedCip);

      // AND THEN: Le produit est trouvé
      expect(
        result,
        isNotNull,
        reason: "Le produit n'a pas été trouvé dans la base de données",
      );
      expect(result!.summary.nomCanonique, equals('TEST GROUP'));
      expect(result.summary.principesActifsCommuns, contains('TESTOLOL'));
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

Future<File> _writeScannerTestImageToTemp() async {
  final byteData = await rootBundle.load('assets/test_images/image_test_1.png');
  final tempDir = await getTemporaryDirectory();
  final tempPath = path.join(tempDir.path, 'image_test_1.png');
  final file = File(tempPath);
  await file.writeAsBytes(
    byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
    flush: true,
  );
  return file;
}
