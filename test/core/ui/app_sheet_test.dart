import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/ui/organisms/app_sheet.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
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
}
