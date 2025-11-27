import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/widgets/ui_kit/product_card.dart';
import '../../../helpers/pump_app.dart';

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
      atcCode: null,
      status: null,
      priceMin: null,
      priceMax: null,
      aggregatedConditions: null,
      ansmAlertUrl: null,
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
        ProductCard(
          summary: buildSummary(),
          cip: '3400000000012',
          availabilityStatus: 'Rupture de stock',
        ),
      );

      // FAlert renders the text, so we can find it directly
      expect(find.text(Strings.stockAlert('Rupture de stock')), findsOneWidget);
    },
  );
}
