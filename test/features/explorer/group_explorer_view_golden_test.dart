import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/database/daos/library_dao.dart';
import 'package:pharma_scan/features/explorer/models/grouped_products_view_model.dart';
import 'package:pharma_scan/features/explorer/providers/group_classification_provider.dart';
import 'package:pharma_scan/features/explorer/screens/group_explorer_view.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'group_explorer_test_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('GroupExplorerView matches light mode golden', (
    WidgetTester tester,
  ) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.binding.platformDispatcher.clearPlatformBrightnessTestValue();
      tester.binding.platformDispatcher.clearTextScaleFactorTestValue();
    });

    tester.view.devicePixelRatio = 1.0;
    tester.binding.platformDispatcher.textScaleFactorTestValue = 1.0;
    tester.binding.platformDispatcher.platformBrightnessTestValue =
        Brightness.light;
    await tester.binding.setSurfaceSize(const Size(430, 1024));

    final baseGroup = createGroupExplorerTestData(
      groupId: 'GRP_GOLDEN',
      syntheticTitle: 'ELIQUIS',
      commonPrincipes: const ['APIXABAN'],
      members: [
        (
          codeCip: 'CIP_PRINCEPS',
          cisCode: 'CIS_PRINCEPS',
          nomCanonique: 'ELIQUIS',
          nomSpecialite: 'ELIQUIS 5 mg, comprimé',
          titulaire: 'BRISTOL-MYERS SQUIBB',
          formePharmaceutique: 'Comprimé',
          type: 0,
          principe: 'APIXABAN',
          dosage: '5',
          dosageUnit: 'mg',
        ),
        (
          codeCip: 'CIP_GENERIC_1',
          cisCode: 'CIS_GENERIC_1',
          nomCanonique: 'APIXABAN',
          nomSpecialite: 'APIXABAN ZYDUS 5 mg, comprimé',
          titulaire: 'ZYDUS FRANCE',
          formePharmaceutique: 'Comprimé',
          type: 1,
          principe: 'APIXABAN',
          dosage: '5',
          dosageUnit: 'mg',
        ),
        (
          codeCip: 'CIP_GENERIC_2',
          cisCode: 'CIS_GENERIC_2',
          nomCanonique: 'APIXABAN',
          nomSpecialite: 'APIXABAN CRISTERS 5 mg, comprimé pelliculé',
          titulaire: 'CRISTERS',
          formePharmaceutique: 'Comprimé pelliculé',
          type: 1,
          principe: 'APIXABAN',
          dosage: '5',
          dosageUnit: 'mg',
        ),
      ],
    );

    final relatedPrinceps = createGroupExplorerTestData(
      groupId: 'GRP_GOLDEN_RELATED',
      syntheticTitle: 'ELIQUIS 2.5 mg',
      commonPrincipes: const ['APIXABAN'],
      members: [
        (
          codeCip: 'CIP_RELATED',
          cisCode: 'CIS_RELATED',
          nomCanonique: 'ELIQUIS 2.5 mg',
          nomSpecialite: 'ELIQUIS 2.5 mg, comprimé',
          titulaire: 'BRISTOL-MYERS SQUIBB',
          formePharmaceutique: 'Comprimé',
          type: 0,
          principe: 'APIXABAN',
          dosage: '2.5',
          dosageUnit: 'mg',
        ),
      ],
    );

    final groupData = ProductGroupData(
      groupId: baseGroup.groupId,
      memberRows: baseGroup.memberRows,
      principesByCip: baseGroup.principesByCip,
      commonPrincipes: baseGroup.commonPrincipes,
      relatedPrincepsRows: relatedPrinceps.memberRows,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          groupDetailViewModelProvider(baseGroup.groupId).overrideWith(
            (ref) async => buildGroupedProductsViewModel(groupData),
          ),
        ],
        child: ShadApp(
          debugShowCheckedModeBanner: false,
          theme: ShadThemeData(
            brightness: Brightness.light,
            colorScheme: const ShadZincColorScheme.light(),
          ),
          home: const GroupExplorerView(groupId: 'GRP_GOLDEN'),
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(GroupExplorerView),
      matchesGoldenFile('goldens/group_explorer_view_light.png'),
    );
  });
}
