import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/presentation/hooks/use_scanner_input.dart';

class _ScannerHookHarness extends HookWidget {
  const _ScannerHookHarness({required this.onSubmitted});

  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final scanner = useScannerInput(onSubmitted: onSubmitted);
    final otherFocus = useFocusNode();

    useListenable(scanner.focusNode);

    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            TextField(
              key: const Key('scanner-input'),
              controller: scanner.controller,
              focusNode: scanner.focusNode,
              onSubmitted: scanner.submit,
            ),
            Text(
              scanner.focusNode.hasFocus ? 'focused' : 'blurred',
              key: const Key('focus-state'),
            ),
            TextField(
              key: const Key('other-input'),
              focusNode: otherFocus,
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('useScannerInput', () {
    testWidgets('keeps focus and trims/clears on submit', (tester) async {
      String? submitted;

      await tester.pumpWidget(
        _ScannerHookHarness(
          onSubmitted: (value) => submitted = value,
        ),
      );
      await tester.pump();

      final focusLabel = tester
          .widget<Text>(find.byKey(const Key('focus-state')))
          .data;
      expect(focusLabel, 'focused');

      await tester.tap(find.byKey(const Key('other-input')));
      await tester.pump();
      final refocusLabel = tester
          .widget<Text>(find.byKey(const Key('focus-state')))
          .data;
      expect(refocusLabel, 'focused');

      await tester.enterText(find.byKey(const Key('scanner-input')), ' 123 ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(submitted, '123');

      final scannerField = tester.widget<TextField>(
        find.byKey(const Key('scanner-input')),
      );
      expect(scannerField.controller?.text, '');
      expect(scannerField.focusNode?.hasFocus, isTrue);
    });
  });
}
