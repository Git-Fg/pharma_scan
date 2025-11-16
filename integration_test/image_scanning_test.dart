import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pharma_scan/core/services/database_service.dart';
import 'package:pharma_scan/core/utils/gs1_parser.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  
  testWidgets('devrait extraire le rawValue depuis une image, le parser et trouver le médicament', (WidgetTester tester) async {
    // --- PARTIE 1: EXTRACTION DEPUIS L'IMAGE ---
    
    // GIVEN: L'image de test `image_test_1.png`
    const imagePath = 'assets/test_images/image_test_1.png';
    final byteData = await rootBundle.load(imagePath);
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/temp_image.png');
    await file.writeAsBytes(byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));

    final inputImage = InputImage.fromFilePath(file.path);
    final barcodeScanner = BarcodeScanner(formats: [BarcodeFormat.dataMatrix]);
    
    // WHEN: On scanne l'image pour obtenir le `rawValue`
    final barcodes = await barcodeScanner.processImage(inputImage);
    await barcodeScanner.close();

    // THEN: On vérifie que ML Kit a bien lu le code
    expect(barcodes, isNotEmpty, reason: "Aucun code-barres détecté dans l'image.");
    final rawValueFromImage = barcodes.first.rawValue;
    expect(rawValueFromImage, isNotNull);

    // --- PARTIE 2: LOGIQUE DE L'APPLICATION ---

    // GIVEN: Le rawValue extrait et une base de données de test
    // La valeur attendue est '01034009303026132132780924334799 10MA00614A 17270430'
    // ou une variante avec des caractères de contrôle.
    DatabaseService.resetDatabase();
    final dbService = DatabaseService.instance;
    await dbService.clearDatabase();
    
    // WHEN: On parse le `rawValue` avec notre parser optimisé
    final parsedData = Gs1Parser.parse(rawValueFromImage);
    final foundCip = parsedData.gtin;

    // THEN: Le CIP est correctement extrait
    expect(foundCip, isNotNull, reason: "Le GTIN n'a pas pu être extrait du rawValue: '$rawValueFromImage'");
    
    final expectedCip = foundCip!;
    
    // AND WHEN: On insère des données de test correspondant au CIP détecté
    await dbService.insertBatchData(
      [{'code_cip': expectedCip, 'nom': 'MEDICAMENT DE TEST 100mg'}],
      [{'code_cip': expectedCip, 'principe': 'TESTOLOL'}],
      [{'code_cip': expectedCip}], // Le marquer comme générique
    );

    // AND WHEN: On interroge la base de données avec ce CIP
    final medicamentResult = await dbService.getGenericMedicamentByCip(expectedCip);

    // AND THEN: Le bon médicament est trouvé avec ses informations
    expect(medicamentResult, isNotNull, reason: "Le médicament n'a pas été trouvé dans la base de données");
    expect(medicamentResult!.nom, 'MEDICAMENT DE TEST 100mg');
    expect(medicamentResult.principesActifs, contains('TESTOLOL'));
  });
}
