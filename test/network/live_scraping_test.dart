import 'dart:developer' as developer;

import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/services/sync_service.dart';

import '../mocks.dart';

void main() {
  group('Live Network Scraping Tests', () {
    late SyncService syncService;
    late MockDriftDatabaseService mockDb;
    late MockDataInitializationService mockInitService;

    setUp(() {
      mockDb = MockDriftDatabaseService();
      mockInitService = MockDataInitializationService();

      syncService = SyncService(
        databaseService: mockDb,
        dataInitializationService: mockInitService,
      );
    });

    test('Should successfully scrape dates from live BDPM website', () async {
      developer.log(
        '--- Connecting to base-donnees-publique.medicaments.gouv.fr ---',
        name: 'LiveScrapingTest',
      );

      final dates = await syncService.fetchRemoteDates();

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

      final sanityDate = DateTime(2020, 1, 1);
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
