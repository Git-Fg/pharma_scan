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

  Future<AppSetting> getSettings() async {
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
  }

  Stream<AppSetting> watchSettings() {
    final selectSettings = (select(appSettings)
      ..where((tbl) => tbl.id.equals(1)));

    return selectSettings.watchSingleOrNull().asyncExpand((row) async* {
      if (row != null) {
        yield row;
        return;
      }

      try {
        await into(appSettings).insert(
          const AppSettingsCompanion(id: Value(1)),
          mode: InsertMode.insertOrIgnore,
        );
        final settings = await (select(
          appSettings,
        )..where((tbl) => tbl.id.equals(1))).getSingle();
        yield settings;
      } catch (e, stackTrace) {
        LoggerService.error(
          '[SettingsDao] Error in watchSettings',
          e,
          stackTrace,
        );
        rethrow;
      }
    });
  }

  Future<String?> getBdpmVersion() async {
    final settings = await getSettings();
    return settings.bdpmVersion;
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

  Future<DateTime?> getLastSyncTime() async {
    final settings = await getSettings();
    final millis = settings.lastSyncEpoch;
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
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

  Future<Map<String, String>> getSourceHashes() async {
    final settings = await getSettings();
    return _decodeStringMap(settings.sourceHashes);
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

  Future<Map<String, DateTime>> getSourceDates() async {
    final settings = await getSettings();
    final raw = _decodeStringMap(settings.sourceDates);
    final result = <String, DateTime>{};
    for (final entry in raw.entries) {
      final parsed = DateTime.tryParse(entry.value);
      if (parsed != null) {
        result[entry.key] = parsed;
      }
    }
    return result;
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
    } on Exception catch (_) {
      return {};
    }
    return {};
  }
}
