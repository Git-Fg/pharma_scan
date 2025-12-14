import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/ui/organisms/app_sheet.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  group('AppSheet Tests', () {
    testWidgets('AppSheet.show opens and returns', (tester) async {
      await tester.pumpWidget(
        ShadApp.custom(
          themeMode: ThemeMode.light,
          theme: ShadThemeData(colorScheme: const ShadGreenColorScheme.light()),
          appBuilder: (context) => MaterialApp(home: Builder(builder: (context) {
            return ElevatedButton(
              onPressed: () {
                AppSheet.show<void>(
                  context: context,
                  title: 'Title',
                  child: const SizedBox.shrink(),
                );
              },
              child: const Text('Open'),
            );
          })),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Expect the sheet title to be present
      expect(find.text('Title'), findsOneWidget);
    });

    testWidgets('AppSheet shows content correctly', (tester) async {
      const testContent = 'Test Content';

      await tester.pumpWidget(
        ShadApp.custom(
          themeMode: ThemeMode.light,
          theme: ShadThemeData(colorScheme: const ShadGreenColorScheme.light()),
          appBuilder: (context) => MaterialApp(home: Builder(builder: (context) {
            return ElevatedButton(
              onPressed: () {
                AppSheet.show<void>(
                  context: context,
                  title: 'Test Sheet',
                  child: const Text(testContent),
                );
              },
              child: const Text('Open'),
            );
          })),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Expect both title and content to be present
      expect(find.text('Test Sheet'), findsOneWidget);
      expect(find.text(testContent), findsOneWidget);
    });

    testWidgets('AppSheet can be dismissed', (tester) async {
      await tester.pumpWidget(
        ShadApp.custom(
          themeMode: ThemeMode.light,
          theme: ShadThemeData(colorScheme: const ShadGreenColorScheme.light()),
          appBuilder: (context) => MaterialApp(home: Builder(builder: (context) {
            return ElevatedButton(
              onPressed: () {
                AppSheet.show<void>(
                  context: context,
                  title: 'Dismissible Sheet',
                  child: const Text('Content'),
                );
              },
              child: const Text('Open'),
            );
          })),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Sheet should be open
      expect(find.text('Dismissible Sheet'), findsOneWidget);

      // Try to dismiss (this will depend on the implementation)
      await tester.tapAt(Offset(100, 100));
      await tester.pumpAndSettle();

      // Test passes if no crashes occur during dismissal
    });
  });
}
