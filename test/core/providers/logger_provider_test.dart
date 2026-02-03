@Tags(['providers'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/providers/logger_provider.dart';
import 'package:riverpod/riverpod.dart';
import 'package:talker/talker.dart';

void main() {
  group('LoggerProvider', () {
    test('talker provider returns Talker instance', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final talker = container.read(talkerProvider);

      expect(talker, isA<Talker>());
    });

    test('talker provider is a singleton (keepAlive)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final talker1 = container.read(talkerProvider);
      final talker2 = container.read(talkerProvider);

      expect(talker1, isA<Talker>());
      expect(talker2, isA<Talker>());
      expect(talker1, same(talker2)); // Same instance
    });
  });
}
