import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/presentation/hooks/use_debounced_controller.dart';
import '../../../robots/debounce_robot.dart';

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

      final robot = DebounceRobot(tester)
      ..expectDebouncedValue('');

      await robot.enterText('abc');
      await robot.pumpDuration(const Duration(milliseconds: 100));

      robot.expectDebouncedValue('');

      await robot.pumpDuration(const Duration(milliseconds: 300));
      robot.expectDebouncedValue('abc');

      await robot.enterText('abcd');
      await robot.pumpDuration(const Duration(milliseconds: 200));
      robot.expectDebouncedValue('abc');

      await robot.pumpDuration(const Duration(milliseconds: 100));
      robot.expectDebouncedValue('abcd');
    });
  });
}
