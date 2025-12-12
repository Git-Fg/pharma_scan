// Test file uses generated data types from Drift

import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/database/models/medicament_summary_data.dart';
import 'package:pharma_scan/core/domain/types/ids.dart';
import 'package:pharma_scan/core/widgets/ui_kit/product_badges.dart';
import 'package:pharma_scan/features/explorer/domain/entities/medicament_entity.dart';
import 'package:pharma_scan/features/scanner/presentation/widgets/scanner_result_card.dart';

import '../../../helpers/pump_app.dart';

void main() {
  MedicamentEntity buildSummary() {
    return MedicamentEntity.fromData(
      MedicamentSummaryData(
        cisCode: '123456',
        nomCanonique: 'Test Médicament',
        isPrinceps: false,
        memberType: 1,
        principesActifsCommuns: ['Test'],
        princepsDeReference: 'Test Princeps',
        formePharmaceutique: 'Comprimé',
        princepsBrandName: 'Test Brand',
        procedureType: 'Procédure',
        isSurveillance: false,
        isHospitalOnly: false,
        isDental: false,
        isList1: false,
        isList2: false,
        isNarcotic: false,
        isException: false,
        isRestricted: false,
        isOtc: true,
      ),
    );
  }

  testWidgets(
    'shows destructive availability alert when availabilityStatus is set',
    (tester) async {
      await tester.pumpApp(
        ScannerResultCard(
          summary: buildSummary(),
          cip: Cip13.validated('3400000000012'),
          badges: const [
            ProductTypeBadge(memberType: 0, compact: true),
          ],
          subtitle: const ['Test subtitle'],
          onClose: () {},
          availabilityStatus: 'Rupture de stock',
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
