import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pharma_scan/core/utils/gs1_parser.dart';
import 'package:pharma_scan/core/services/logger_service.dart';

void main() {
  // 1. Initialize IntegrationBindings to allow native plugin calls
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Initialize logger service
  final logger = LoggerService();

  group('Mobile Scanner + GS1 Parser Integration Tests', () {
    testWidgets('Verify image_test_1.png contains CIP 3400930302613',
        (tester) async {
      // -----------------------------------------------------------------------
      // SETUP: Extract Asset to File
      // MobileScanner needs a filesystem path, but assets are bundled in the APK/IPA.
      // We must copy the asset to a temporary file first.
      // -----------------------------------------------------------------------

      logger.info('📋 Setting up test image asset...');

      final byteData =
          await rootBundle.load('assets/test_images/image_test_1.png');
      expect(byteData, isNotNull,
          reason: 'Could not load test image from assets');
      expect(byteData.lengthInBytes, greaterThan(0),
          reason: 'Test image is empty');

      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/image_test_1.png');
      await tempFile.writeAsBytes(byteData.buffer.asUint8List());

      logger.info('📁 Test image copied to: ${tempFile.path}');
      expect(await tempFile.exists(), isTrue,
          reason: 'Failed to copy test image to temporary directory');

      // -----------------------------------------------------------------------
      // ACTION: Analyze Image via Native Plugin
      // -----------------------------------------------------------------------

      logger.info('📷 Initializing MobileScanner controller...');
      final controller = MobileScannerController();

      try {
        // Attempt to analyze the image
        logger.info('🔍 Analyzing image with MobileScanner...');
        final BarcodeCapture? capture =
            await controller.analyzeImage(tempFile.path);

        // Clean up resources
        controller.dispose();
        await tempFile.delete();

        // -----------------------------------------------------------------------
        // VERIFICATION: Check Raw Data & GS1 Parsing
        // -----------------------------------------------------------------------

        // 1. Verify mobile_scanner found something
        expect(capture, isNotNull,
            reason: 'MobileScanner returned null - could not analyze image');
        expect(capture!.barcodes, isNotEmpty,
            reason: 'No barcodes detected in image_test_1.png');

        logger.info('📊 Found ${capture.barcodes.length} barcode(s) in image');

        final rawValue = capture.barcodes.first.rawValue;
        logger.info('📷 Detected Raw Barcode: "$rawValue"');

        // 2. Verify it's not empty
        expect(rawValue, isNotNull,
            reason: 'MobileScanner returned null raw value');
        expect(rawValue!.isNotEmpty, true,
            reason: 'MobileScanner returned empty raw value');
        expect(rawValue.contains('0103400930302613'), true,
            reason: 'Raw barcode should contain the expected GTIN-14');

        // 3. Verify GS1 Parser Logic
        // We pass the raw string from the scanner into your parser
        logger.info('🧠 Parsing GS1 data with custom parser...');
        final gs1Data = Gs1Parser.parse(rawValue);

        logger.info('✅ GS1 Parsing Results:');
        logger.info('   GTIN (CIP): ${gs1Data.gtin}');
        logger.info('   Serial: ${gs1Data.serial}');
        logger.info('   Lot: ${gs1Data.lot}');
        logger.info('   Exp Date: ${gs1Data.expDate}');
        logger.info('   Manufacturing Date: ${gs1Data.manufacturingDate}');

        // 4. Assert the specific CIP (Code CIP is the GTIN without leading zero)
        expect(gs1Data.gtin, '3400930302613',
            reason:
                'GS1 Parser failed to extract the correct CIP from the barcode. '
                'Expected: 3400930302613, Got: ${gs1Data.gtin}');

        // Additional verification - check if expiration date was parsed correctly
        expect(gs1Data.expDate, isNotNull,
            reason:
                'GS1 Parser should have parsed expiration date from AI(17)');

        // Verify the date is April 30, 2027 (from 17270430)
        final expectedDate = DateTime.utc(2027, 4, 30);
        expect(gs1Data.expDate?.year, expectedDate.year,
            reason: 'Expiration year should be 2027');
        expect(gs1Data.expDate?.month, expectedDate.month,
            reason: 'Expiration month should be April');
        expect(gs1Data.expDate?.day, expectedDate.day,
            reason: 'Expiration day should be 30');

        logger.info('🎉 SUCCESS: All assertions passed for image_test_1.png!');
      } catch (e) {
        // Clean up on error
        controller.dispose();
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
        rethrow;
      }
    });

    testWidgets('Verify complete GS1 DataMatrix parsing with all fields',
        (tester) async {
      logger.info(
          '🧪 Testing complete GS1 DataMatrix with all critical fields...');

      // Complete GS1 DataMatrix code with all fields separated by GS characters
      // AI(01)03400930302613 + AI(21)32780924334799 + <GS> + AI(10)MA00614A + <GS> + AI(17)270430
      const completeGs1Code =
          '01034009303026132132780924334799\u001d10MA00614A\u001d17270430';

      final gs1Data = Gs1Parser.parse(completeGs1Code);

      logger.info('📦 Complete GS1 Parsing Results:');
      logger.info('   Raw Value: "$completeGs1Code"');
      logger.info('   GTIN (CIP): ${gs1Data.gtin}');
      logger.info('   Serial: ${gs1Data.serial}');
      logger.info('   Lot (Batch): ${gs1Data.lot}');
      logger.info('   Exp Date: ${gs1Data.expDate}');
      logger.info('   Manufacturing Date: ${gs1Data.manufacturingDate}');

      // A. Verify CIP/GTIN extraction (Standard)
      // Raw: "0103400930302613" → "3400930302613" (leading zero stripped from GTIN-14)
      expect(gs1Data.gtin, '3400930302613',
          reason:
              'CIP extraction failed - expected 3400930302613, got ${gs1Data.gtin}');

      // B. Verify Serial Number (AI 21)
      // Raw: "2132780924334799" → "32780924334799"
      expect(gs1Data.serial, '32780924334799',
          reason:
              'Serial number extraction failed - expected 32780924334799, got ${gs1Data.serial}');

      // C. Verify Lot/Batch Number (AI 10)
      // Raw: "10MA00614A" → "MA00614A"
      expect(gs1Data.lot, 'MA00614A',
          reason:
              'Lot number extraction failed - expected MA00614A, got ${gs1Data.lot}');

      // D. Verify Expiration Date (AI 17)
      // Raw: "17270430" (YYMMDD) → 30/04/2027
      expect(gs1Data.expDate, isNotNull,
          reason:
              'Expiration date not found - should be parsed from AI(17)270430');

      final expectedExpDate = DateTime.utc(2027, 4, 30); // 30 Avril 2027
      expect(gs1Data.expDate, expectedExpDate,
          reason:
              'Expiration date parsing failed - expected 2027-04-30, got ${gs1Data.expDate}');

      // E. Verify GS Group Separator handling
      // Ensure no FNC1/GS separator characters remain in parsed data
      expect(gs1Data.serial, isNot(contains('\u001d')),
          reason:
              'GS separator <GS> (\\u001d) not properly cleaned from serial number');
      expect(gs1Data.lot, isNot(contains('\u001d')),
          reason:
              'GS separator <GS> (\\u001d) not properly cleaned from lot number');

      // F. Verify field completeness
      // All critical fields should be extracted from this complete GS1 code
      expect(
          [gs1Data.gtin, gs1Data.serial, gs1Data.lot, gs1Data.expDate]
              .every((field) => field != null),
          isTrue,
          reason:
              'Some critical fields are missing - all fields should be parsed from complete GS1 code');

      logger.info('✅ Complete GS1 DataMatrix parsing verified successfully!');
    });

    testWidgets('Verify GS1 parser handles edge cases correctly',
        (tester) async {
      logger.info('🧪 Testing GS1 parser edge cases...');

      // Test with null input
      final nullResult = Gs1Parser.parse(null);
      expect(nullResult.gtin, isNull);
      expect(nullResult.serial, isNull);
      expect(nullResult.lot, isNull);

      // Test with empty input
      final emptyResult = Gs1Parser.parse('');
      expect(emptyResult.gtin, isNull);
      expect(emptyResult.serial, isNull);
      expect(emptyResult.lot, isNull);

      // Test with known GS1 format for the target CIP
      final testGs1String = '010340093030261317311231';
      final result = Gs1Parser.parse(testGs1String);

      expect(result.gtin, '3400930302613');
      expect(result.expDate?.year, 2031);
      expect(result.expDate?.month, 12);
      expect(result.expDate?.day, 31);

      logger.info('✅ GS1 parser edge cases handled correctly');
    });
  });
}
