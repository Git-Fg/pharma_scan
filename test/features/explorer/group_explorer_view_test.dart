import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pharma_scan/core/providers/repositories_providers.dart';
import 'package:pharma_scan/features/explorer/models/grouped_by_product_model.dart';
import 'package:pharma_scan/features/explorer/models/product_group_classification_model.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/features/explorer/screens/database_search_view.dart';
import 'package:pharma_scan/features/explorer/screens/group_explorer_view.dart';
import 'package:pharma_scan/features/scanner/models/medicament_model.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockExplorerRepository mockRepository;

  setUp(() {
    mockRepository = MockExplorerRepository();
  });

  testWidgets('expands generic accordion to reveal medicament cards', (
    WidgetTester tester,
  ) async {
    final princeps = const Medicament(
      nom: 'Princeps One',
      codeCip: 'CIP-PRINCEPS',
      principesActifs: ['Substance P'],
      titulaire: 'Lab Princeps',
    );

    final genericVariantA = Medicament(
      nom: 'Generic Product 500 mg comprimé',
      codeCip: 'CIP-GEN-001',
      principesActifs: const ['Substance P'],
      titulaire: 'Lab Generic A',
      dosage: Decimal.fromInt(500),
      dosageUnit: 'mg',
    );

    final genericVariantB = genericVariantA.copyWith(
      codeCip: 'CIP-GEN-002',
      titulaire: 'Lab Generic B',
    );

    final classification = ProductGroupClassification(
      groupId: 'group-001',
      syntheticTitle: 'Princeps One',
      commonActiveIngredients: const ['Substance P'],
      distinctDosages: const ['500 mg'],
      distinctFormulations: const ['Comprimé'],
      princeps: [
        GroupedByProduct(
          productName: 'Princeps One',
          dosage: Decimal.fromInt(500),
          dosageUnit: 'mg',
          laboratories: const ['Lab Princeps'],
          medicaments: [princeps],
        ),
      ],
      generics: [
        GroupedByProduct(
          productName: 'Generic Product',
          dosage: Decimal.fromInt(500),
          dosageUnit: 'mg',
          laboratories: const ['Lab Generic A', 'Lab Generic B'],
          medicaments: [genericVariantA, genericVariantB],
        ),
      ],
      relatedPrinceps: const [],
    );

    when(
      () => mockRepository.classifyProductGroup(any()),
    ).thenAnswer((_) async => classification);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          explorerRepositoryProvider.overrideWithValue(mockRepository),
        ],
        child: ShadTheme(
          data: ShadThemeData(
            brightness: Brightness.light,
            colorScheme: const ShadZincColorScheme.light(),
          ),
          child: const MaterialApp(
            home: GroupExplorerView(groupId: 'group-001'),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final accordionTitleFinder = find.text('Generic Product');
    expect(accordionTitleFinder, findsOneWidget);

    // WHY: Use Strings.cip for consistency with UI, even for test data
    expect(find.text('${Strings.cip} CIP-GEN-001'), findsNothing);
    expect(find.text('${Strings.cip} CIP-GEN-002'), findsNothing);

    await tester.tap(accordionTitleFinder);
    await tester.pumpAndSettle();

    expect(find.text('${Strings.cip} CIP-GEN-001'), findsOneWidget);
    expect(find.text('${Strings.cip} CIP-GEN-002'), findsOneWidget);
  });

  testWidgets(
    'groups generics sharing canonical name and dosage across laboratories',
    (WidgetTester tester) async {
      final princeps = const Medicament(
        nom: 'Princeps One',
        codeCip: 'CIP-PRINCEPS',
        principesActifs: ['Substance P'],
        titulaire: 'Lab Princeps',
      );

      final genericBase = Medicament(
        nom: 'Generic Product 500 mg, comprimé',
        codeCip: 'CIP-GEN-010',
        principesActifs: const ['Substance P'],
        titulaire: 'Lab Generic A',
        dosage: Decimal.fromInt(500),
        dosageUnit: 'mg',
      );

      final texturedVariant = genericBase.copyWith(
        nom: 'Generic Product 500 mg, comprimé pelliculé',
        codeCip: 'CIP-GEN-011',
        titulaire: 'Lab Generic B',
      );

      final classification = ProductGroupClassification(
        groupId: 'group-002',
        syntheticTitle: 'Princeps One',
        commonActiveIngredients: const ['Substance P'],
        distinctDosages: const ['500 mg'],
        distinctFormulations: const ['Comprimé'],
        princeps: [
          GroupedByProduct(
            productName: 'Princeps One',
            laboratories: const ['Lab Princeps'],
            medicaments: [princeps],
          ),
        ],
        generics: [
          GroupedByProduct(
            productName: 'Generic Product',
            dosage: Decimal.fromInt(500),
            dosageUnit: 'mg',
            laboratories: const ['Lab Generic A', 'Lab Generic B'],
            medicaments: [genericBase, texturedVariant],
          ),
        ],
        relatedPrinceps: const [],
      );

      when(
        () => mockRepository.classifyProductGroup(any()),
      ).thenAnswer((_) async => classification);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            explorerRepositoryProvider.overrideWithValue(mockRepository),
          ],
          child: ShadTheme(
            data: ShadThemeData(
              brightness: Brightness.light,
              colorScheme: const ShadZincColorScheme.light(),
            ),
            child: const MaterialApp(
              home: GroupExplorerView(groupId: 'group-002'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final accordionTitleFinder = find.text('Generic Product');
      expect(accordionTitleFinder, findsOneWidget);

      await tester.tap(accordionTitleFinder);
      await tester.pumpAndSettle();

      // WHY: Use Strings.cip for consistency with UI, even for test data
      expect(find.text('${Strings.cip} CIP-GEN-010'), findsOneWidget);
      expect(find.text('${Strings.cip} CIP-GEN-011'), findsOneWidget);
    },
  );

  test('summarizeGenericsByName aggregates identical normalized names', () {
    final generics = [
      const Medicament(
        nom: 'AMOXICILLINE',
        codeCip: 'AMOX-001',
        principesActifs: ['Substance P'],
        titulaire: 'Lab A',
      ),
      const Medicament(
        nom: 'AMOXICILLINE',
        codeCip: 'AMOX-002',
        principesActifs: ['Substance P'],
        titulaire: 'Lab B',
      ),
      const Medicament(
        nom: 'AMODEX',
        codeCip: 'AMOD-001',
        principesActifs: ['Substance P'],
        titulaire: 'Lab C',
      ),
    ];

    final summary = summarizeGenericsByName(generics);

    expect(summary, hasLength(2));
    expect(summary.first.key, 'AMOXICILLINE');
    expect(summary.first.value, 2);
    expect(summary.last.key, 'AMODEX');
    expect(summary.last.value, 1);
  });
}
