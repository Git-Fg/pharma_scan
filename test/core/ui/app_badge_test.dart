import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/ui/atoms/app_badge.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets('AppBadge renders label and variant', (tester) async {
    await tester.pumpWidget(
      ShadApp.custom(
        themeMode: ThemeMode.light,
        theme: ShadThemeData(colorScheme: const ShadGreenColorScheme.light()),
        appBuilder: (context) => MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppBadge(label: 'Test', variant: BadgeVariant.success),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Test'), findsOneWidget);
  });
}
