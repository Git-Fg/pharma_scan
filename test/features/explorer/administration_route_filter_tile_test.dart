import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/features/explorer/models/search_filters_model.dart';
import 'package:pharma_scan/features/explorer/providers/pharmaceutical_forms_provider.dart';
import 'package:pharma_scan/features/explorer/widgets/filters/administration_route_filter_tile.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets('shows loading tile while routes load', (tester) async {
    final completer = Completer<List<String>>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          administrationRoutesProvider.overrideWith((ref) => completer.future),
        ],
        child: ShadApp.custom(
          theme: ShadThemeData(
            brightness: Brightness.light,
            colorScheme: const ShadGreenColorScheme.light(),
          ),
          appBuilder: (context) {
            return MaterialApp(
              theme: Theme.of(context),
              builder: (context, child) => ShadAppBuilder(child: child),
              home: const Scaffold(
                body: AdministrationRouteFilterTile(
                  currentFilters: SearchFilters(),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows error tile when loading routes fails', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          administrationRoutesProvider.overrideWith(
            (ref) => Future<List<String>>.error('boom'),
          ),
        ],
        child: ShadApp.custom(
          theme: ShadThemeData(
            brightness: Brightness.light,
            colorScheme: const ShadGreenColorScheme.light(),
          ),
          appBuilder: (context) {
            return MaterialApp(
              theme: Theme.of(context),
              builder: (context, child) => ShadAppBuilder(child: child),
              home: const Scaffold(
                body: AdministrationRouteFilterTile(
                  currentFilters: SearchFilters(),
                ),
              ),
            );
          },
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
        child: ShadApp.custom(
          theme: ShadThemeData(
            brightness: Brightness.light,
            colorScheme: const ShadGreenColorScheme.light(),
          ),
          appBuilder: (context) {
            return MaterialApp(
              theme: Theme.of(context),
              builder: (context, child) => ShadAppBuilder(child: child),
              home: const Scaffold(
                body: AdministrationRouteFilterTile(
                  currentFilters: SearchFilters(
                    voieAdministration: 'Orale',
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify the filter label is displayed (Shadcn widgets provide accessibility automatically)
    expect(find.text(Strings.administrationRouteFilter), findsOneWidget);

    // Verify the selected value is displayed
    // Note: The value may be displayed in the details section of the tile
    expect(find.text('Orale'), findsOneWidget);
  });
}
