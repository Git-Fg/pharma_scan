import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/core/providers/preferences_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Settings Persistence - User Preferences', () {
    late AppDatabase database;
    late ProviderContainer container;

    setUp(() async {
      database = AppDatabase.forTesting(
        NativeDatabase.memory(setup: configureAppSQLite),
      );

      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test(
      'default values check (Haptic=True, Sorting=Princeps)',
      () async {
        final settings = await database.settingsDao.getSettings();

        expect(
          settings.hapticFeedbackEnabled,
          isTrue,
          reason: 'Default haptic feedback should be enabled',
        );
        expect(
          settings.preferredSorting,
          equals('princeps'),
          reason: 'Default sorting preference should be princeps',
        );
      },
    );

    test(
      'update SortingPreference -> Read back from DB -> Verify persistence',
      () async {
        await database.settingsDao.getSettings();

        final mutation = container.read(
          sortingPreferenceMutationProvider.notifier,
        );
        await mutation.build();

        final mutationFuture = mutation.setSortingPreference(
          SortingPreference.generic,
        );
        await mutationFuture;

        var attempts = 0;
        var mutationState = container.read(sortingPreferenceMutationProvider);
        while (mutationState.isLoading && attempts < 20) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          mutationState = container.read(sortingPreferenceMutationProvider);
          attempts++;
        }

        mutationState.whenOrNull(
          error: (error, _) => throw Exception('Mutation failed: $error'),
        );

        if (mutationState.isLoading) {
          throw Exception('Mutation did not complete in time');
        }

        await Future<void>.delayed(const Duration(milliseconds: 100));

        final settings = await database.settingsDao.getSettings();
        expect(
          settings.preferredSorting,
          equals('generic'),
          reason: 'Sorting preference should persist to database',
        );
      },
    );

    test(
      'update BdpmVersion -> Verify persistence',
      () async {
        await database.settingsDao.getSettings();

        const testVersion = 'test-version-123';
        final updateEither = await database.settingsDao.updateBdpmVersion(
          testVersion,
        );

        expect(
          updateEither.isRight,
          isTrue,
          reason: 'Update BDPM version should succeed',
        );

        updateEither.fold(
          ifLeft: (failure) => throw Exception('Update failed: $failure'),
          ifRight: (_) {},
        );

        await Future<void>.delayed(const Duration(milliseconds: 100));

        final version = await database.settingsDao.getBdpmVersion();
        expect(
          version,
          equals(testVersion),
          reason: 'BDPM version should persist to database',
        );
      },
    );

    test(
      'update HapticFeedback -> Verify persistence',
      () async {
        await database.settingsDao.getSettings();

        final mutation = container.read(hapticMutationProvider.notifier);
        await mutation.build();

        final mutationFuture = mutation.setEnabled(enabled: false);
        await mutationFuture;

        var attempts = 0;
        var mutationState = container.read(hapticMutationProvider);
        while (mutationState.isLoading && attempts < 20) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          mutationState = container.read(hapticMutationProvider);
          attempts++;
        }

        mutationState.whenOrNull(
          error: (error, _) => throw Exception('Mutation failed: $error'),
        );

        if (mutationState.isLoading) {
          throw Exception('Mutation did not complete in time');
        }

        await Future<void>.delayed(const Duration(milliseconds: 100));

        final settings = await database.settingsDao.getSettings();
        expect(
          settings.hapticFeedbackEnabled,
          isFalse,
          reason: 'Haptic feedback setting should persist to database',
        );
      },
    );
  });
}
