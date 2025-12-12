import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/services/preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PreferencesService', () {
    late PreferencesService service;
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      service = PreferencesService(prefs);
    });

    test('Source Hashes (JSON Map<String, String>)', () async {
      // Test default
      expect(service.getSourceHashes(), isEmpty);

      // Test set and get
      final hashes = {'src1': 'hash1', 'src2': 'hash2'};
      await service.setSourceHashes(hashes);
      expect(service.getSourceHashes(), equals(hashes));

      // Test persistence
      final stored = prefs.getString(PrefKeys.sourceHashes);
      expect(stored, contains('"src1":"hash1"'));
    });

    test('Source Dates (JSON Map<String, DateTime>)', () async {
      // Test default
      expect(service.getSourceDates(), isEmpty);

      // Test set and get
      final now = DateTime.utc(2023);
      final dates = {'src1': now};
      await service.setSourceDates(dates);

      final retrieved = service.getSourceDates();
      expect(retrieved['src1'], equals(now));

      // Test persistence
      final stored = prefs.getString(PrefKeys.sourceDates);
      expect(stored, contains('"src1":"${now.toIso8601String()}"'));
    });

    test('Last Sync Time', () async {
      expect(service.getLastSyncTime(), isNull);

      await service.setLastSyncTime(123456789);
      expect(
        service.getLastSyncTime(),
        equals(DateTime.fromMillisecondsSinceEpoch(123456789)),
      );

      await service.remove(PrefKeys.lastSyncEpoch);
      expect(service.getLastSyncTime(), isNull);
    });

    test('DB Version Tag', () async {
      expect(service.getDbVersionTag(), isNull);

      await service.setDbVersionTag('v1.0.0');
      expect(service.getDbVersionTag(), equals('v1.0.0'));

      await service.setDbVersionTag(null);
      expect(service.getDbVersionTag(), isNull);
    });

    test('Helper methods: clear', () async {
      await service.setLastSyncTime(123);
      await service.setString(PrefKeys.themeMode, 'dark');

      await service.clear();

      expect(service.getLastSyncTime(), isNull);
      expect(service.getString(PrefKeys.themeMode), isNull);
    });

    test('Reset Sync Metadata', () async {
      await service.setDbVersionTag('v1.0.0');
      await service.setLastSyncTime(12345);
      await service.setSourceHashes({'a': 'b'}); // Should NOT be cleared

      await service.resetSyncMetadata();

      expect(service.getDbVersionTag(), isNull);
      expect(service.getLastSyncTime(), isNull);
      expect(service.getSourceHashes(), isNotEmpty);
    });
  });
}
