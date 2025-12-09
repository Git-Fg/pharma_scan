import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/features/scanner/domain/logic/scan_traffic_control.dart';

void main() {
  group('ScanTrafficControl', () {
    late DateTime now;
    late ScanTrafficControl control;

    setUp(() {
      now = DateTime(2024, 1, 1, 12);
      control = ScanTrafficControl(
        now: () => now,
      );
    });

    test('allows first scan and blocks during cooldown', () {
      expect(control.shouldProcess('A'), isTrue);
      expect(control.shouldProcess('A'), isFalse);

      control.markProcessed('A');

      now = now.add(const Duration(seconds: 3));
      expect(control.shouldProcess('A'), isTrue);
    });

    test('prevents re-entry while processing until marked processed', () {
      expect(control.shouldProcess('B'), isTrue);
      expect(control.shouldProcess('B'), isFalse);

      control.markProcessed('B');
      now = now.add(const Duration(seconds: 3));
      expect(control.shouldProcess('B'), isTrue);
    });

    test('force bypasses cooldown and processing check', () {
      expect(control.shouldProcess('C'), isTrue);
      expect(control.shouldProcess('C', force: true), isTrue);
    });

    test('cleans up expired cooldowns', () {
      expect(control.shouldProcess('D'), isTrue);
      control.markProcessed('D');
      now = now.add(const Duration(minutes: 6));

      expect(control.shouldProcess('D'), isTrue);
    });

    test('reset clears processing and cooldowns', () {
      expect(control.shouldProcess('E'), isTrue);
      control.reset();
      expect(control.shouldProcess('E'), isTrue);
    });
  });
}
