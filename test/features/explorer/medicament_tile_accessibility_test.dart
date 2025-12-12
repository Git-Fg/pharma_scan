import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/database/dbschema.drift.dart';
import 'package:pharma_scan/core/domain/types/ids.dart';
import 'package:pharma_scan/features/explorer/domain/entities/medicament_entity.dart';
import 'package:pharma_scan/features/explorer/domain/models/search_result_item_model.dart';
import 'package:pharma_scan/features/explorer/presentation/widgets/medicament_tile.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

MedicamentEntity _buildSummary({
  required String name,
  bool isPrinceps = false,
}) {
  return MedicamentEntity.fromData(
    MedicamentSummaryData(
      cisCode: '123456',
      nomCanonique: name,
      princepsDeReference: '',
      isPrinceps: isPrinceps,
      groupId: 'group1',
      principesActifsCommuns: '["Test"]', // JSON string as expected by Drift
      formePharmaceutique: 'Comprimé',
      memberType: isPrinceps ? 0 : 1,
      princepsBrandName: '',
      procedureType: 'Procédure',
      isSurveillance: false,
      isHospital: false,
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

void main() {
  testWidgets(
    'MedicamentTile has semantic label for princeps result',
    (tester) async {
      final item = PrincepsResult(
        princeps: _buildSummary(name: 'Doliprane', isPrinceps: true),
        generics: const [],
        groupId: GroupId('group1'),
        commonPrinciples: 'Paracétamol',
      );

      await tester.pumpWidget(
        ShadApp(
          home: Scaffold(
            body: MedicamentTile(
              item: item,
              onTap: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MedicamentTile), findsOneWidget);
    },
  );
}
