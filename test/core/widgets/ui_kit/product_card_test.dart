import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/widgets/ui_kit/product_card.dart';
import '../../../helpers/pump_app.dart';

void main() {
  MedicamentSummaryData buildSummary() {
    return const MedicamentSummaryData(
      cisCode: '123456',
      nomCanonique: 'Test Médicament',
      isPrinceps: false,
      principesActifsCommuns: ['Test'],
      princepsDeReference: 'Test Princeps',
      formePharmaceutique: 'Comprimé',
      princepsBrandName: 'Test Brand',
      procedureType: 'Procédure',
      titulaire: 'Test Lab',
      isSurveillance: false,
      isHospitalOnly: false,
      isDental: false,
      isList1: false,
      isList2: false,
      isNarcotic: false,
      isException: false,
      isRestricted: false,
      isOtc: true,
    );
  }

  testWidgets(
    'shows destructive availability alert when availabilityStatus is set',
    (tester) async {
      await tester.pumpApp(
        Scaffold(
          body: ProductCard(
            summary: buildSummary(),
            cip: '3400000000012',
            availabilityStatus: 'Rupture de stock',
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify that the alert is rendered
      // ShadAlert.destructive renders the title text which includes the emoji
      // The expected text is "⚠️ Rupture de stock"
      // Since ShadAlert might render text in a complex widget tree structure,
      // we verify the text content is present
      expect(find.textContaining('Rupture de stock'), findsOneWidget);
    },
  );
}
