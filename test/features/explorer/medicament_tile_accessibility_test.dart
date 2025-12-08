// test/features/explorer/medicament_tile_accessibility_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/domain/types/ids.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/features/explorer/domain/entities/medicament_entity.dart';
import 'package:pharma_scan/features/explorer/domain/models/search_result_item_model.dart';
import 'package:pharma_scan/features/explorer/presentation/widgets/medicament_tile.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../helpers/pump_app.dart';

MedicamentEntity _buildSummary({
  required String name,
  bool isPrinceps = false,
}) {
  return MedicamentEntity.fromData(
    MedicamentSummaryData(
      cisCode: '123456',
      nomCanonique: name,
      isPrinceps: isPrinceps,
      formePharmaceutique: 'Comprimé',
      principesActifsCommuns: const ['Test'],
      groupId: GroupId.validated('group1'),
      memberType: isPrinceps ? 0 : 1,
      princepsDeReference: '',
      princepsBrandName: '',
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

void main() {
  testWidgets(
    'MedicamentTile has semantic label for princeps result',
    (tester) async {
      final item = PrincepsResult(
        princeps: _buildSummary(name: 'Doliprane', isPrinceps: true),
        generics: const <MedicamentEntity>[],
        groupId: GroupId.validated('group1'),
        commonPrinciples: 'Paracétamol',
      );

      await tester.pumpApp(MedicamentTile(item: item, onTap: () {}));
      await tester.pump();

      final tileFinder = find.byType(MedicamentTile);
      expect(tileFinder, findsOneWidget);

      final expectedLabel = Strings.searchResultSemanticsForPrinceps(
        'Doliprane',
        0,
      );
      final semanticsWidget =
          find
                  .descendant(
                    of: tileFinder,
                    matching: find.byWidgetPredicate(
                      (widget) =>
                          widget is Semantics &&
                          widget.properties.label != null,
                    ),
                  )
                  .evaluate()
                  .first
                  .widget
              as Semantics;
      expect(semanticsWidget.properties.label, expectedLabel);
      expect(semanticsWidget.properties.hint, Strings.medicationTileHint);
    },
    semanticsEnabled: false,
  );

  testWidgets(
    'MedicamentTile has semantic label for generic result',
    (tester) async {
      final item = GenericResult(
        generic: _buildSummary(name: 'Paracétamol Biogaran'),
        princeps: const <MedicamentEntity>[],
        groupId: GroupId.validated('group1'),
        commonPrinciples: 'Paracétamol',
      );

      await tester.pumpApp(MedicamentTile(item: item, onTap: () {}));
      await tester.pump();

      final tileFinder = find.byType(MedicamentTile);
      expect(tileFinder, findsOneWidget);

      final expectedLabel = Strings.searchResultSemanticsForGeneric(
        'Paracétamol Biogaran',
        0,
      );
      final semanticsWidget =
          find
                  .descendant(
                    of: tileFinder,
                    matching: find.byWidgetPredicate(
                      (widget) =>
                          widget is Semantics &&
                          widget.properties.label != null,
                    ),
                  )
                  .evaluate()
                  .first
                  .widget
              as Semantics;
      expect(semanticsWidget.properties.label, expectedLabel);
      expect(semanticsWidget.properties.hint, Strings.medicationTileHint);
    },
    semanticsEnabled: false,
  );

  testWidgets(
    'MedicamentTile decorative chevron is excluded from semantics',
    (tester) async {
      final item = PrincepsResult(
        princeps: _buildSummary(name: 'Doliprane', isPrinceps: true),
        generics: const <MedicamentEntity>[],
        groupId: GroupId.validated('group1'),
        commonPrinciples: 'Paracétamol',
      );

      await tester.pumpApp(MedicamentTile(item: item, onTap: () {}));
      await tester.pump();

      // Verify chevron icon is wrapped in ExcludeSemantics
      final chevronFinder = find.byWidgetPredicate(
        (widget) => widget is Icon && widget.icon == LucideIcons.chevronRight,
      );
      expect(chevronFinder, findsOneWidget);
      final semanticsWrapper = find.ancestor(
        of: chevronFinder,
        matching: find.byType(ExcludeSemantics),
      );
      expect(semanticsWrapper, findsAtLeastNWidgets(1));
    },
    semanticsEnabled: false,
  );
}
