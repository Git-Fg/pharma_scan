// test/features/explorer/medicament_tile_layout_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/domain/types/ids.dart';
import 'package:pharma_scan/features/explorer/domain/entities/medicament_entity.dart';
import 'package:pharma_scan/features/explorer/domain/models/search_result_item_model.dart';
import 'package:pharma_scan/features/explorer/presentation/widgets/medicament_tile.dart';

import '../../helpers/pump_app.dart';

MedicamentEntity _buildSummary({
  required String name,
  String? form,
  List<String> principles = const [],
  bool isPrinceps = false,
}) {
  return MedicamentEntity.fromData(
    MedicamentSummaryData(
      cisCode: '12345678',
      nomCanonique: name,
      isPrinceps: isPrinceps,
      formePharmaceutique: form ?? 'Comprimé',
      principesActifsCommuns: principles,
      groupId: 'group1',
      princepsDeReference: '',
      princepsBrandName: '',
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
    ),
  );
}

void main() {
  group('MedicamentTile Layout Safety', () {
    testWidgets(
      'prevents overflow with very long medication name on narrow screen',
      (tester) async {
        final view = tester.view
          ..devicePixelRatio = 1.0
          ..physicalSize = const Size(300, 800);
        addTearDown(() {
          view
            ..resetPhysicalSize()
            ..resetDevicePixelRatio();
        });

        final item = PrincepsResult(
          princeps: _buildSummary(
            name:
                'VERY LONG MEDICATION NAME THAT SHOULD TRUNCATE PROPERLY WITHOUT CAUSING OVERFLOW ERRORS',
            isPrinceps: true,
          ),
          generics: const <MedicamentEntity>[],
          groupId: GroupId.validated('group1'),
          commonPrinciples: 'PARACETAMOL',
        );

        await tester.pumpApp(
          SizedBox(
            width: 300,
            child: MedicamentTile(item: item, onTap: () {}),
          ),
        );

        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(MedicamentTile), findsOneWidget);

        // Verify text is truncated (no overflow)
        final textWidgets = find.byType(Text);
        expect(textWidgets, findsWidgets);
      },
    );

    testWidgets(
      'prevents overflow with very long active principles text',
      (tester) async {
        final view = tester.view
          ..devicePixelRatio = 1.0
          ..physicalSize = const Size(300, 800);
        addTearDown(() {
          view
            ..resetPhysicalSize()
            ..resetDevicePixelRatio();
        });

        final summary = _buildSummary(
          name: 'Test Medication',
          form: 'Comprimé',
          principles: [
            'VERY LONG ACTIVE PRINCIPLE NAME ONE',
            'VERY LONG ACTIVE PRINCIPLE NAME TWO',
            'VERY LONG ACTIVE PRINCIPLE NAME THREE',
          ],
        );
        final item = StandaloneResult(
          cisCode: summary.cisCode,
          summary: summary,
          representativeCip: Cip13.validated('3400934056781'),
          commonPrinciples:
              'VERY LONG ACTIVE PRINCIPLE NAME ONE + VERY LONG ACTIVE PRINCIPLE NAME TWO + VERY LONG ACTIVE PRINCIPLE NAME THREE',
        );

        await tester.pumpApp(
          SizedBox(
            width: 300,
            child: MedicamentTile(item: item, onTap: () {}),
          ),
        );

        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(MedicamentTile), findsOneWidget);
      },
    );

    testWidgets(
      'prevents overflow with long subtitle and details text',
      (tester) async {
        final view = tester.view
          ..devicePixelRatio = 1.0
          ..physicalSize = const Size(300, 800);
        addTearDown(() {
          view
            ..resetPhysicalSize()
            ..resetDevicePixelRatio();
        });

        final item = GenericResult(
          generic: _buildSummary(
            name: 'Generic Medication',
            form: 'Comprimé pelliculé sécable',
            principles: ['PARACETAMOL'],
          ),
          princeps: List.generate(
            10,
            (index) => _buildSummary(
              name: 'Princeps $index',
              isPrinceps: true,
            ),
          ).toList(),
          groupId: GroupId.validated('group1'),
          commonPrinciples: 'PARACETAMOL',
        );

        await tester.pumpApp(
          SizedBox(
            width: 300,
            child: MedicamentTile(item: item, onTap: () {}),
          ),
        );

        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(MedicamentTile), findsOneWidget);

        // Verify tile renders correctly (details text may be truncated if needed)
        // The tile should display the generic name and princeps count
        expect(find.text('Generic Medication'), findsOneWidget);
      },
    );

    testWidgets(
      'adapts to wider screen without layout issues',
      (tester) async {
        final view = tester.view
          ..devicePixelRatio = 1.0
          ..physicalSize = const Size(1000, 800);
        addTearDown(() {
          view
            ..resetPhysicalSize()
            ..resetDevicePixelRatio();
        });

        final item = PrincepsResult(
          princeps: _buildSummary(
            name: 'Test Medication',
            isPrinceps: true,
          ),
          generics: const <MedicamentEntity>[],
          groupId: GroupId.validated('group1'),
          commonPrinciples: 'PARACETAMOL',
        );

        await tester.pumpApp(
          SizedBox(
            width: 1000,
            child: MedicamentTile(item: item, onTap: () {}),
          ),
        );

        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(MedicamentTile), findsOneWidget);
      },
    );
  });
}
