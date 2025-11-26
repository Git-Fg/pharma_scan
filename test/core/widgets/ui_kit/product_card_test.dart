import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/widgets/ui_kit/product_card.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  MedicamentSummaryData buildSummary() {
    return const MedicamentSummaryData(
      cisCode: '123456',
      nomCanonique: 'Test Médicament',
      isPrinceps: false,
      groupId: null,
      principesActifsCommuns: ['Test'],
      princepsDeReference: 'Test Princeps',
      formePharmaceutique: 'Comprimé',
      princepsBrandName: 'Test Brand',
      procedureType: 'Procédure',
      titulaire: 'Test Lab',
      conditionsPrescription: null,
      isSurveillance: false,
      formattedDosage: null,
    );
  }

  testWidgets(
    'shows destructive availability alert when availabilityStatus is set',
    (tester) async {
      await tester.pumpWidget(
        ShadApp(
          home: Scaffold(
            body: ProductCard(
              summary: buildSummary(),
              cip: '3400000000012',
              availabilityStatus: 'Rupture de stock',
            ),
          ),
        ),
      );

      expect(find.text(Strings.stockAlert('Rupture de stock')), findsOneWidget);
    },
  );
}
