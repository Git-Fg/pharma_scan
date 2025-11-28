import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/features/explorer/models/search_filters_model.dart';
import 'package:pharma_scan/features/explorer/providers/pharmaceutical_forms_provider.dart';
import 'package:pharma_scan/features/explorer/widgets/filters/administration_route_filter_tile.dart';
import 'package:pharma_scan/theme/theme.dart';

void main() {
  testWidgets('shows loading tile while routes load', (tester) async {
    final completer = Completer<List<String>>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          administrationRoutesProvider.overrideWith((ref) => completer.future),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: '/',
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => FAnimatedTheme(
                  data: greenLight,
                  child: const Scaffold(
                    body: AdministrationRouteFilterTile(
                      currentFilters: SearchFilters(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.byType(FCircularProgress), findsOneWidget);
  });

  testWidgets('shows error tile when loading routes fails', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          administrationRoutesProvider.overrideWith(
            (ref) => Future<List<String>>.error('boom'),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: '/',
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => FAnimatedTheme(
                  data: greenLight,
                  child: const Scaffold(
                    body: AdministrationRouteFilterTile(
                      currentFilters: SearchFilters(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text(Strings.errorLoadingRoutes), findsOneWidget);
    expect(find.text('boom'), findsOneWidget);
  });

  testWidgets('filter tile displays selected value correctly', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          administrationRoutesProvider.overrideWith(
            (ref) => Future.value(['Orale', 'Intraveineuse']),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: '/',
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => FAnimatedTheme(
                  data: greenLight,
                  child: const Scaffold(
                    body: AdministrationRouteFilterTile(
                      currentFilters: SearchFilters(
                        voieAdministration: 'Orale',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify the filter label is displayed (Forui widgets provide accessibility automatically)
    expect(find.text(Strings.administrationRouteFilter), findsOneWidget);

    // Verify the selected value is displayed
    // Note: The value may be displayed in the details section of the tile
    expect(find.text('Orale'), findsOneWidget);
  });
}
