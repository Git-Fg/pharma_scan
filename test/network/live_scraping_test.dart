@Tags(['integration', 'network'])
library;

import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/features/home/providers/sync_provider.dart';

import '../mocks.dart';

class MockAppDatabase extends Mock implements AppDatabase {}

void main() {
  group('Live Network Scraping Tests', () {
    late ProviderContainer container;
    late MockAppDatabase mockDb;
    late MockDataInitializationService mockInitService;

    setUp(() {
      mockDb = MockAppDatabase();
      mockInitService = MockDataInitializationService();

      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(mockDb),
          dataInitializationServiceProvider.overrideWithValue(mockInitService),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('Should successfully scrape dates from live BDPM website', () async {
      developer.log(
        '--- Connecting to base-donnees-publique.medicaments.gouv.fr ---',
        name: 'LiveScrapingTest',
      );

      final controller = container.read(syncControllerProvider.notifier);
      final dates = await controller.fetchRemoteDates();

      developer.log(
        'Found dates for ${dates.length} files:\n${dates.entries.map((e) => '  - ${e.key}: ${e.value.toIso8601String().split('T').first}').join('\n')}',
        name: 'LiveScrapingTest',
      );

      expect(
        dates,
        isNotEmpty,
        reason:
            'Scraping returned no dates. HTML structure might have changed.',
      );

      expect(
        dates.containsKey('specialites'),
        isTrue,
        reason: 'Failed to find date for CIS_bdpm.txt',
      );
      expect(
        dates.containsKey('medicaments'),
        isTrue,
        reason: 'Failed to find date for CIS_CIP_bdpm.txt',
      );
      expect(
        dates.containsKey('generiques'),
        isTrue,
        reason: 'Failed to find date for CIS_GENER_bdpm.txt',
      );

      final sanityDate = DateTime(2020);
      for (final date in dates.values) {
        expect(
          date.isAfter(sanityDate),
          isTrue,
          reason: 'Parsed date is suspiciously old: $date',
        );
      }
    });
  });
}
