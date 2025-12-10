import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/presentation/hooks/use_debounced_controller.dart';

class _DebounceHarness extends HookWidget {
  const _DebounceHarness();

  @override
  Widget build(BuildContext context) {
    final hook = useDebouncedController();
    useListenable(hook.debouncedText);

    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            TextField(
              key: const Key('debounce-input'),
              controller: hook.controller,
            ),
            Text(
              hook.debouncedText.value,
              key: const Key('debounce-value'),
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('useDebouncedController', () {
    testWidgets('updates debounced text only after delay', (tester) async {
      await tester.pumpWidget(const _DebounceHarness());

      expect(
        tester.widget<Text>(find.byKey(const Key('debounce-value'))).data,
        '',
      );

      await tester.enterText(find.byKey(const Key('debounce-input')), 'abc');
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        tester.widget<Text>(find.byKey(const Key('debounce-value'))).data,
        '',
      );

      await tester.pump(const Duration(milliseconds: 300));
      expect(
        tester.widget<Text>(find.byKey(const Key('debounce-value'))).data,
        'abc',
      );

      await tester.enterText(find.byKey(const Key('debounce-input')), 'abcd');
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        tester.widget<Text>(find.byKey(const Key('debounce-value'))).data,
        'abc',
      );

      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester.widget<Text>(find.byKey(const Key('debounce-value'))).data,
        'abcd',
      );
    });
  });
}
