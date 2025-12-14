import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/database/daos/app_settings_dao.dart';
import 'package:pharma_scan/core/database/providers.dart';
import 'package:pharma_scan/core/providers/app_settings_provider.dart';
import '../../helpers/test_database.dart';

void main() {
  group('AppSettingsProvider Tests', () {
    late AppDatabase database;
    late ProviderContainer container;

    setUp(() async {
      database = createTestDatabase();
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWith((ref, path) => database),
        ],
      );
    });

    tearDown(() async {
      await database.close();
      container.dispose();
    });

    test('appSettingsDaoProvider provides app settings DAO', () async {
      final dao = container.read(appSettingsDaoProvider);
      expect(dao, isNotNull);
      expect(dao, isA<AppSettingsDao>());
    });

    test('lastSyncEpoch returns null initially', () async {
      final lastSync = await container.read(lastSyncEpochProvider.future);
      expect(lastSync, isNull);
    });

    test('lastSyncEpoch updates correctly', () async {
      final dao = container.read(appSettingsDaoProvider);

      // Set a sync epoch
      await dao.setLastSyncEpoch(1234567890);

      // Read the provider
      final lastSync = await container.read(lastSyncEpochProvider.future);
      expect(lastSync, 1234567890);
    });
  });
}