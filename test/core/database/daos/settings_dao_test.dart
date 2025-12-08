import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/database/database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsDao', () {
    late AppDatabase database;

    setUp(() async {
      database = AppDatabase.forTesting(
        NativeDatabase.memory(setup: configureAppSQLite),
      );
    });

    tearDown(() async {
      await database.close();
    });

    test('getSettings() creates default settings if none exist', () async {
      final settings = await database.settingsDao.getSettings();

      expect(settings.id, equals(1));
      expect(settings.hapticFeedbackEnabled, isTrue);
      expect(settings.preferredSorting, equals('princeps'));
    });

    test('getSettings() returns existing settings', () async {
      await database.settingsDao.getSettings();

      final settings = await database.settingsDao.getSettings();

      expect(settings.id, equals(1));
      expect(settings.hapticFeedbackEnabled, isTrue);
    });

    test('watchSettings() emits settings stream', () async {
      final stream = database.settingsDao.watchSettings().asBroadcastStream();
      final settings = await stream.first;

      expect(settings.id, equals(1));
      expect(settings.hapticFeedbackEnabled, isTrue);
    });

    test('getBdpmVersion() returns null initially', () async {
      final version = await database.settingsDao.getBdpmVersion();

      expect(version, isNull);
    });

    test('updateBdpmVersion() updates version correctly', () async {
      const testVersion = 'test-version-123';
      await database.settingsDao.updateBdpmVersion(
        testVersion,
      );

      final version = await database.settingsDao.getBdpmVersion();
      expect(version, equals(testVersion));
    });

    test('updateBdpmVersion() can set version to null', () async {
      await database.settingsDao.updateBdpmVersion('test');
      await database.settingsDao.updateBdpmVersion(null);

      final version = await database.settingsDao.getBdpmVersion();
      expect(version, isNull);
    });

    test('getLastSyncTime() returns null initially', () async {
      final syncTime = await database.settingsDao.getLastSyncTime();

      expect(syncTime, isNull);
    });

    test('updateSyncTimestamp() updates sync time correctly', () async {
      final testTime = DateTime(2024, 1, 1, 12);
      final epochMillis = testTime.millisecondsSinceEpoch;

      await database.settingsDao.updateSyncTimestamp(
        epochMillis,
      );

      final syncTime = await database.settingsDao.getLastSyncTime();
      expect(syncTime, isNotNull);
      expect(syncTime!.millisecondsSinceEpoch, equals(epochMillis));
    });

    test('updatePreferredSorting() updates sorting mode', () async {
      await database.settingsDao.updatePreferredSorting(
        'generic',
      );

      final settings = await database.settingsDao.getSettings();
      expect(settings.preferredSorting, equals('generic'));
    });

    test('updateTheme() updates theme mode', () async {
      await database.settingsDao.updateTheme('dark');

      final settings = await database.settingsDao.getSettings();
      expect(settings.themeMode, equals('dark'));
    });

    test('updateSyncFrequency() updates sync frequency', () async {
      await database.settingsDao.updateSyncFrequency(
        'daily',
      );

      final settings = await database.settingsDao.getSettings();
      expect(settings.updateFrequency, equals('daily'));
    });

    test('updateHapticFeedback() updates haptic setting', () async {
      await database.settingsDao.updateHapticFeedback(
        enabled: false,
      );

      final settings = await database.settingsDao.getSettings();
      expect(settings.hapticFeedbackEnabled, isFalse);
    });

    test('getSourceHashes() returns empty map initially', () async {
      final hashes = await database.settingsDao.getSourceHashes();

      expect(hashes, isEmpty);
    });

    test('saveSourceHashes() saves and retrieves hashes', () async {
      await database.settingsDao.getSettings();

      final testHashes = {
        'file1.txt': 'hash1',
        'file2.txt': 'hash2',
      };

      await database.settingsDao.saveSourceHashes(
        testHashes,
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));

      final retrieved = await database.settingsDao.getSourceHashes();
      expect(retrieved, equals(testHashes));
    });

    test('getSourceDates() returns empty map initially', () async {
      final dates = await database.settingsDao.getSourceDates();

      expect(dates, isEmpty);
    });

    test('saveSourceDates() saves and retrieves dates', () async {
      await database.settingsDao.getSettings();

      final testDates = {
        'file1.txt': DateTime(2024),
        'file2.txt': DateTime(2024, 1, 2),
      };

      await database.settingsDao.saveSourceDates(
        testDates,
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));

      final retrieved = await database.settingsDao.getSourceDates();
      expect(retrieved.length, equals(2));
      expect(retrieved['file1.txt'], equals(testDates['file1.txt']));
      expect(retrieved['file2.txt'], equals(testDates['file2.txt']));
    });

    test('clearSourceMetadata() clears hashes and dates', () async {
      await database.settingsDao.saveSourceHashes({'file1.txt': 'hash1'});
      await database.settingsDao.saveSourceDates({
        'file1.txt': DateTime(2024),
      });

      await database.settingsDao.clearSourceMetadata();

      final hashes = await database.settingsDao.getSourceHashes();
      final dates = await database.settingsDao.getSourceDates();

      expect(hashes, isEmpty);
      expect(dates, isEmpty);
    });

    test('resetSettingsMetadata() resets version and sync time', () async {
      await database.settingsDao.updateBdpmVersion('test-version');
      await database.settingsDao.updateSyncTimestamp(
        DateTime.now().millisecondsSinceEpoch,
      );

      await database.settingsDao.resetSettingsMetadata();

      final version = await database.settingsDao.getBdpmVersion();
      final syncTime = await database.settingsDao.getLastSyncTime();

      expect(version, isNull);
      expect(syncTime, isNull);
    });

    test('watchSettings() emits updated settings when changed', () async {
      final events = <AppSetting>[];
      late StreamSubscription<AppSetting> sub;

      final completer = Completer<void>();
      sub = database.settingsDao.watchSettings().listen((event) async {
        events.add(event);
        if (events.length == 1) {
          await database.settingsDao.updateHapticFeedback(
            enabled: !event.hapticFeedbackEnabled,
          );
          return;
        }
        if (events.length >= 2 && !completer.isCompleted) {
          completer.complete();
        }
      });

      await completer.future.timeout(const Duration(seconds: 10));
      await sub.cancel();

      expect(events.length, equals(2));
      expect(
        events.last.hapticFeedbackEnabled,
        isNot(events.first.hapticFeedbackEnabled),
      );
    });
  });
}
