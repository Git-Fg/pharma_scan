import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/providers/navigation_provider.dart';
import 'package:riverpod/riverpod.dart';

void main() {
  test('TabReselection increments tick and updates tabIndex', () {
    final container = ProviderContainer();
    final notifier = container.read(tabReselectionProvider.notifier);

    final first = container.read(tabReselectionProvider);
    notifier.ping(1);
    final second = container.read(tabReselectionProvider);
    notifier.ping(2);
    final third = container.read(tabReselectionProvider);

    expect(first.tabIndex, -1);
    expect(second, (tabIndex: 1, tick: first.tick + 1));
    expect(third, (tabIndex: 2, tick: second.tick + 1));
  });
}
