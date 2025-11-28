// test/features/explorer/medicament_tile_accessibility_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/features/explorer/models/search_result_item_model.dart';
import 'package:pharma_scan/features/explorer/widgets/medicament_tile.dart';
import 'package:pharma_scan/theme/theme.dart';
import '../../helpers/accessibility_test_helpers.dart';

MedicamentSummaryData _buildSummary({
  required String name,
  bool isPrinceps = false,
}) {
  return MedicamentSummaryData(
    cisCode: '123456',
    nomCanonique: name,
    isPrinceps: isPrinceps,
    formePharmaceutique: 'Comprimé',
    principesActifsCommuns: const ['Test'],
    groupId: 'group1',
    princepsDeReference: '',
    princepsBrandName: '',
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

void main() {
  testWidgets('MedicamentTile has semantic label for princeps result', (
    tester,
  ) async {
    final item = SearchResultItem.princepsResult(
      princeps: _buildSummary(name: 'Doliprane', isPrinceps: true),
      generics: [],
      groupId: 'group1',
      commonPrinciples: 'Paracétamol',
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: '/',
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => FAnimatedTheme(
                  data: greenLight,
                  child: Scaffold(
                    body: MedicamentTile(item: item, onTap: () {}),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final tileFinder = find.byType(FTile);
    expect(tileFinder, findsOneWidget);

    // Verify semantic label exists and contains medication information
    AccessibilityTestHelpers.expectHasSemanticLabel(tester, tileFinder);
  });

  testWidgets('MedicamentTile has semantic label for generic result', (
    tester,
  ) async {
    final item = SearchResultItem.genericResult(
      generic: _buildSummary(name: 'Paracétamol Biogaran', isPrinceps: false),
      princeps: [],
      groupId: 'group1',
      commonPrinciples: 'Paracétamol',
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: '/',
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => FAnimatedTheme(
                  data: greenLight,
                  child: Scaffold(
                    body: MedicamentTile(item: item, onTap: () {}),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final tileFinder = find.byType(FTile);
    expect(tileFinder, findsOneWidget);

    AccessibilityTestHelpers.expectHasSemanticLabel(tester, tileFinder);
  });

  testWidgets('MedicamentTile decorative chevron is excluded from semantics', (
    tester,
  ) async {
    final item = SearchResultItem.princepsResult(
      princeps: _buildSummary(name: 'Doliprane', isPrinceps: true),
      generics: [],
      groupId: 'group1',
      commonPrinciples: 'Paracétamol',
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: '/',
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => FAnimatedTheme(
                  data: greenLight,
                  child: Scaffold(
                    body: MedicamentTile(item: item, onTap: () {}),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify ExcludeSemantics is present (wrapping the chevron)
    expect(find.byType(ExcludeSemantics), findsOneWidget);
  });
}
