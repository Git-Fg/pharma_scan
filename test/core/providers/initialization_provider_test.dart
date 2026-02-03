@Tags(['providers'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/core/providers/initialization_provider.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import 'package:riverpod/riverpod.dart';

class MockDataInitializationService extends Mock
    implements DataInitializationService {}

void main() {
  group('InitializationNotifier', () {
    late MockDataInitializationService mockInitService;
    late ProviderContainer container;

    setUp(() {
      mockInitService = MockDataInitializationService();
      when(() => mockInitService.initializeDatabase())
          .thenAnswer((_) async {});
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state is AsyncLoading', () async {
      container = ProviderContainer(
        overrides: [
          dataInitializationServiceProvider.overrideWith((_) => mockInitService),
        ],
      );

      final state = container.read(initializationProvider);
      expect(state.isLoading, true);
    });

    test('transitions to AsyncData on successful initialization', () async {
      container = ProviderContainer(
        overrides: [
          dataInitializationServiceProvider.overrideWith((_) => mockInitService),
        ],
      );

      await container.read(initializationProvider.future);
      final state = container.read(initializationProvider);
      expect(state.hasValue, true);
    });
  });

  group('InitializationState enum', () {
    test('has expected values', () {
      expect(InitializationState.values, contains(InitializationState.initial));
      expect(InitializationState.values, contains(InitializationState.initializing));
      expect(InitializationState.values, contains(InitializationState.ready));
      expect(InitializationState.values, contains(InitializationState.success));
      expect(InitializationState.values, contains(InitializationState.error));
    });

    test('enum values are distinct', () {
      final values = InitializationState.values;
      expect(values.toSet().length, equals(values.length));
    });
  });
}
