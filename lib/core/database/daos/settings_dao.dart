// lib/core/database/daos/settings_dao.dart
import 'dart:convert';

import 'package:dart_either/dart_either.dart';
import 'package:drift/drift.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/database/tables/settings.dart';
import 'package:pharma_scan/core/errors/failures.dart';
import 'package:pharma_scan/core/services/logger_service.dart';

part 'settings_dao.g.dart';

@DriftAccessor(tables: [AppSettings])
class SettingsDao extends DatabaseAccessor<AppDatabase>
    with _$SettingsDaoMixin {
  SettingsDao(super.attachedDatabase);

  Future<Either<Failure, AppSetting>> getSettings() {
    return Either.catchFutureError(
      (e, stackTrace) {
        LoggerService.error(
          '[SettingsDao] Error in getSettings',
          e,
          stackTrace,
        );
        return DatabaseFailure(e.toString(), stackTrace);
      },
      () async {
        final row = await (select(
          appSettings,
        )..where((tbl) => tbl.id.equals(1))).getSingleOrNull();
        if (row != null) return row;

        await into(appSettings).insert(
          const AppSettingsCompanion(id: Value(1)),
          mode: InsertMode.insertOrIgnore,
        );

        final settings = await (select(
          appSettings,
        )..where((tbl) => tbl.id.equals(1))).getSingle();
        return settings;
      },
    );
  }

  Stream<Either<Failure, AppSetting>> watchSettings() {
    try {
      final selectSettings = (select(appSettings)
        ..where((tbl) => tbl.id.equals(1)));

      return selectSettings
          .watchSingleOrNull()
          .asyncMap((row) async {
            if (row != null) return Either<Failure, AppSetting>.right(row);

            await into(appSettings).insert(
              const AppSettingsCompanion(id: Value(1)),
              mode: InsertMode.insertOrIgnore,
            );
            final settings = await (select(
              appSettings,
            )..where((tbl) => tbl.id.equals(1))).getSingle();
            return Either<Failure, AppSetting>.right(settings);
          })
          .handleError(
            (Object e, StackTrace stackTrace) {
              LoggerService.error(
                '[SettingsDao] Error in watchSettings',
                e,
                stackTrace,
              );
              return Either<Failure, AppSetting>.left(
                DatabaseFailure(e.toString(), stackTrace),
              );
            },
          );
    } on Exception catch (e, stackTrace) {
      LoggerService.error(
        '[SettingsDao] Error setting up watchSettings',
        e,
        stackTrace,
      );
      return Stream<Either<Failure, AppSetting>>.value(
        Either<Failure, AppSetting>.left(
          DatabaseFailure(e.toString(), stackTrace),
        ),
      );
    }
  }

  Future<Either<Failure, String?>> getBdpmVersion() async {
    final settingsEither = await getSettings();
    return settingsEither.fold(
      ifLeft: Either.left,
      ifRight: (settings) => Either.right(settings.bdpmVersion),
    );
  }

  Future<Either<Failure, void>> updateBdpmVersion(String? version) {
    return Either.catchFutureError(
      (e, stackTrace) {
        LoggerService.error(
          '[SettingsDao] Error in updateBdpmVersion',
          e,
          stackTrace,
        );
        return DatabaseFailure(e.toString(), stackTrace);
      },
      () async {
        await (update(appSettings)..where((tbl) => tbl.id.equals(1))).write(
          AppSettingsCompanion(bdpmVersion: Value(version)),
        );
      },
    );
  }

  Future<Either<Failure, DateTime?>> getLastSyncTime() async {
    final settingsEither = await getSettings();
    return settingsEither.fold(
      ifLeft: Either.left,
      ifRight: (settings) {
        final millis = settings.lastSyncEpoch;
        if (millis == null) return const Either.right(null);
        return Either.right(DateTime.fromMillisecondsSinceEpoch(millis));
      },
    );
  }

  Future<Either<Failure, void>> updateTheme(String mode) {
    return Either.catchFutureError(
      (e, stackTrace) {
        LoggerService.error(
          '[SettingsDao] Error in updateTheme',
          e,
          stackTrace,
        );
        return DatabaseFailure(e.toString(), stackTrace);
      },
      () async {
        await (update(appSettings)..where((tbl) => tbl.id.equals(1))).write(
          AppSettingsCompanion(themeMode: Value(mode)),
        );
      },
    );
  }

  Future<Either<Failure, void>> updateSyncFrequency(String frequency) {
    return Either.catchFutureError(
      (e, stackTrace) {
        LoggerService.error(
          '[SettingsDao] Error in updateSyncFrequency',
          e,
          stackTrace,
        );
        return DatabaseFailure(e.toString(), stackTrace);
      },
      () async {
        await (update(appSettings)..where((tbl) => tbl.id.equals(1))).write(
          AppSettingsCompanion(updateFrequency: Value(frequency)),
        );
      },
    );
  }

  Future<Either<Failure, void>> updateSyncTimestamp(int epochMillis) {
    return Either.catchFutureError(
      (e, stackTrace) {
        LoggerService.error(
          '[SettingsDao] Error in updateSyncTimestamp',
          e,
          stackTrace,
        );
        return DatabaseFailure(e.toString(), stackTrace);
      },
      () async {
        await (update(appSettings)..where((tbl) => tbl.id.equals(1))).write(
          AppSettingsCompanion(lastSyncEpoch: Value(epochMillis)),
        );
      },
    );
  }

  Future<Either<Failure, Map<String, String>>> getSourceHashes() async {
    final settingsEither = await getSettings();
    return settingsEither.fold(
      ifLeft: Either.left,
      ifRight: (settings) =>
          Either.right(_decodeStringMap(settings.sourceHashes)),
    );
  }

  Future<Either<Failure, void>> saveSourceHashes(
    Map<String, String> hashes,
  ) {
    return Either.catchFutureError(
      (e, stackTrace) {
        LoggerService.error(
          '[SettingsDao] Error in saveSourceHashes',
          e,
          stackTrace,
        );
        return DatabaseFailure(e.toString(), stackTrace);
      },
      () async {
        await (update(appSettings)..where((tbl) => tbl.id.equals(1))).write(
          AppSettingsCompanion(sourceHashes: Value(jsonEncode(hashes))),
        );
      },
    );
  }

  Future<Either<Failure, Map<String, DateTime>>> getSourceDates() async {
    final settingsEither = await getSettings();
    return settingsEither.fold(
      ifLeft: Either.left,
      ifRight: (settings) {
        final raw = _decodeStringMap(settings.sourceDates);
        final result = <String, DateTime>{};
        for (final entry in raw.entries) {
          final parsed = DateTime.tryParse(entry.value);
          if (parsed != null) {
            result[entry.key] = parsed;
          }
        }
        return Either.right(result);
      },
    );
  }

  Future<Either<Failure, void>> saveSourceDates(
    Map<String, DateTime> dates,
  ) {
    return Either.catchFutureError(
      (e, stackTrace) {
        LoggerService.error(
          '[SettingsDao] Error in saveSourceDates',
          e,
          stackTrace,
        );
        return DatabaseFailure(e.toString(), stackTrace);
      },
      () async {
        final encoded = dates.map(
          (key, value) => MapEntry(key, value.toIso8601String()),
        );
        await (update(appSettings)..where((tbl) => tbl.id.equals(1))).write(
          AppSettingsCompanion(sourceDates: Value(jsonEncode(encoded))),
        );
      },
    );
  }

  Future<Either<Failure, void>> clearSourceMetadata() {
    return Either.catchFutureError(
      (e, stackTrace) {
        LoggerService.error(
          '[SettingsDao] Error in clearSourceMetadata',
          e,
          stackTrace,
        );
        return DatabaseFailure(e.toString(), stackTrace);
      },
      () async {
        await (update(appSettings)..where((tbl) => tbl.id.equals(1))).write(
          const AppSettingsCompanion(
            sourceHashes: Value('{}'),
            sourceDates: Value('{}'),
          ),
        );
      },
    );
  }

  Future<Either<Failure, void>> resetSettingsMetadata() {
    return Either.catchFutureError(
      (e, stackTrace) {
        LoggerService.error(
          '[SettingsDao] Error in resetSettingsMetadata',
          e,
          stackTrace,
        );
        return DatabaseFailure(e.toString(), stackTrace);
      },
      () async {
        await (update(appSettings)..where((tbl) => tbl.id.equals(1))).write(
          const AppSettingsCompanion(
            bdpmVersion: Value(null),
            lastSyncEpoch: Value(null),
          ),
        );
      },
    );
  }

  Map<String, String> _decodeStringMap(String raw) {
    if (raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map(
          (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
        );
      }
    } on Object catch (_) {
      return {};
    }
    return {};
  }
}
