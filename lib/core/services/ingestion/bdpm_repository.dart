import 'package:dart_either/dart_either.dart';
import 'package:drift/drift.dart';
import 'package:pharma_scan/core/config/app_config.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/errors/failures.dart';
import 'package:pharma_scan/core/services/logger_service.dart';

class BdpmRepository {
  const BdpmRepository(this._db);

  final AppDatabase _db;

  Future<Either<Failure, void>> insertDataWithRetry(
    IngestionBatch ingestionBatch,
  ) => _insertDataWithRetry(database: _db, ingestionBatch: ingestionBatch);

  Future<void> aggregateSummary() async {
    LoggerService.info('[BdpmRepository] Aggregating summary and FTS index');
    final recordCount = await _db.databaseDao.populateSummaryTable();
    await _db.databaseDao.populateFts5Index();
    LoggerService.db(
      'Aggregated $recordCount records into MedicamentSummary table using SQL aggregation.',
    );
  }
}

Future<Either<Failure, void>> _insertDataWithRetry({
  required AppDatabase database,
  required IngestionBatch ingestionBatch,
}) async {
  const maxRetries = 6;
  const busyTimeoutMs = 30000;
  const baseDelayMs = 800;
  const maxDelayMs = 6400;
  var retryCount = 0;
  var totalDelayMs = 0;
  Failure? lastFailure;

  while (retryCount < maxRetries) {
    final insertResult = await Either.catchFutureError<Failure, void>(
      (error, stackTrace) => DatabaseFailure(
        'Database insertion failed: $error',
        stackTrace,
      ),
      () async {
        await database.transaction(() async {
          if (ingestionBatch.laboratories.isNotEmpty) {
            await _insertChunked(
              database,
              (batch, chunk, mode) =>
                  batch.insertAll(database.laboratories, chunk, mode: mode),
              ingestionBatch.laboratories,
              mode: InsertMode.replace,
            );
          }

          await _insertChunked(
            database,
            (batch, chunk, mode) =>
                batch.insertAll(database.specialites, chunk, mode: mode),
            ingestionBatch.specialites,
            mode: InsertMode.replace,
          );

          await _insertChunked(
            database,
            (batch, chunk, mode) =>
                batch.insertAll(database.medicaments, chunk, mode: mode),
            ingestionBatch.medicaments,
            mode: InsertMode.replace,
          );

          await _insertChunked(
            database,
            (batch, chunk, mode) =>
                batch.insertAll(database.principesActifs, chunk, mode: mode),
            ingestionBatch.principes,
          );

          await _insertChunked(
            database,
            (batch, chunk, mode) =>
                batch.insertAll(database.generiqueGroups, chunk, mode: mode),
            ingestionBatch.generiqueGroups,
            mode: InsertMode.replace,
          );

          await _insertChunked(
            database,
            (batch, chunk, mode) =>
                batch.insertAll(database.groupMembers, chunk, mode: mode),
            ingestionBatch.groupMembers,
            mode: InsertMode.replace,
          );

          await database.batch((batch) {
            batch.deleteWhere(
              database.medicamentAvailability,
              (_) => const Constant(true),
            );
          });

          if (ingestionBatch.availability.isNotEmpty) {
            await _insertChunked(
              database,
              (batch, chunk, mode) => batch.insertAll(
                database.medicamentAvailability,
                chunk,
                mode: mode,
              ),
              ingestionBatch.availability,
              mode: InsertMode.replace,
            );
          }
        });
      },
    );

    if (insertResult.isRight) {
      return insertResult;
    }

    lastFailure = insertResult.fold(
      ifLeft: (failure) => failure,
      ifRight: (_) => throw StateError('Unreachable'),
    );

    retryCount++;
    if (retryCount >= maxRetries) {
      return Either<Failure, void>.left(lastFailure!);
    }

    final expDelay = baseDelayMs * (1 << (retryCount - 1));
    final delayMs = expDelay > maxDelayMs ? maxDelayMs : expDelay;
    totalDelayMs += delayMs;
    final remainingBudget = busyTimeoutMs - totalDelayMs;
    LoggerService.warning(
      '[BdpmRepository] Database lock error (attempt $retryCount/$maxRetries, '
      'busy_timeout=${busyTimeoutMs}ms, waited=${totalDelayMs}ms, '
      'nextDelay=${delayMs}ms, remainingBudget=${remainingBudget}ms): '
      '${lastFailure!.message}',
    );
    await Future<void>.delayed(Duration(milliseconds: delayMs));
  }

  return Either<Failure, void>.left(
    lastFailure ??
        const DatabaseFailure('Database insertion failed after retries'),
  );
}

Future<void> _insertChunked<T>(
  AppDatabase db,
  void Function(Batch batch, List<T> chunk, InsertMode mode) inserter,
  Iterable<T> items, {
  InsertMode mode = InsertMode.insert,
}) async {
  final itemsList = items.toList();
  if (itemsList.isEmpty) return;

  for (var i = 0; i < itemsList.length; i += AppConfig.batchSize) {
    final end = (i + AppConfig.batchSize < itemsList.length)
        ? i + AppConfig.batchSize
        : itemsList.length;
    final chunk = itemsList.sublist(i, end);

    await db.batch((batch) {
      inserter(batch, chunk, mode);
    });
  }
}
