import 'dart:async';

import 'package:dart_either/dart_either.dart';
import 'package:flutter/foundation.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/errors/failures.dart';
import 'package:pharma_scan/core/services/ingestion/bdpm_file_parser.dart'
    as parser;

class BdpmParserService {
  const BdpmParserService();

  Future<Either<Failure, IngestionBatch>> parseAll(
    Map<String, String> filePaths,
  ) async {
    final args = (filePaths: filePaths);
    final resultEither = await compute(_parseDataInBackground, args);

    return resultEither.mapLeft(_mapParseErrorToFailure);
  }
}

Failure _mapParseErrorToFailure(parser.ParseError error) {
  return switch (error) {
    parser.EmptyContentError(:final fileName) => ParsingFailure(
      'Failed to parse $fileName: file is empty or missing',
    ),
    parser.InvalidFormatError(:final fileName, :final details) =>
      ParsingFailure(
        'Failed to parse $fileName: $details',
      ),
  };
}

Future<Either<parser.ParseError, IngestionBatch>> _parseDataInBackground(
  ({Map<String, String> filePaths}) args,
) async {
  Stream<List<dynamic>>? streamForKey(String key) =>
      parser.BdpmFileParser.openRowStream(args.filePaths[key]);

  final conditionsMap = await parser.BdpmFileParser.parseConditions(
    streamForKey('conditions'),
  );
  final mitmMap = await parser.BdpmFileParser.parseMitm(streamForKey('mitm'));

  final specialitesEither = await parser.BdpmFileParser.parseSpecialites(
    streamForKey('specialites'),
    conditionsMap,
    mitmMap,
  );
  if (specialitesEither.isLeft) {
    return Either.left(
      specialitesEither.fold(
        ifLeft: (l) => l,
        ifRight: (_) => throw StateError('unreachable'),
      ),
    );
  }
  final specialitesResult = specialitesEither.fold(
    ifLeft: (_) => throw StateError('unreachable'),
    ifRight: (r) => r,
  );

  final medicamentsEither = await parser.BdpmFileParser.parseMedicaments(
    streamForKey('medicaments'),
    specialitesResult,
  );
  if (medicamentsEither.isLeft) {
    return Either.left(
      medicamentsEither.fold(
        ifLeft: (l) => l,
        ifRight: (_) => throw StateError('unreachable'),
      ),
    );
  }
  final medicamentsResult = medicamentsEither.fold(
    ifLeft: (_) => throw StateError('unreachable'),
    ifRight: (r) => r,
  );

  final compositionMap = await parser.BdpmFileParser.parseCompositions(
    streamForKey('compositions'),
  );

  final principesEither = await parser.BdpmFileParser.parsePrincipesActifs(
    streamForKey('compositions'),
    medicamentsResult.cisToCip13,
  );
  if (principesEither.isLeft) {
    return Either.left(
      principesEither.fold(
        ifLeft: (l) => l,
        ifRight: (_) => throw StateError('unreachable'),
      ),
    );
  }
  final principes = principesEither.fold(
    ifLeft: (_) => throw StateError('unreachable'),
    ifRight: (r) => r,
  );

  final generiqueEither = await parser.BdpmFileParser.parseGeneriques(
    streamForKey('generiques'),
    medicamentsResult.cisToCip13,
    medicamentsResult.medicamentCips,
    compositionMap,
    specialitesResult.namesByCis,
  );
  if (generiqueEither.isLeft) {
    return Either.left(
      generiqueEither.fold(
        ifLeft: (l) => l,
        ifRight: (_) => throw StateError('unreachable'),
      ),
    );
  }
  final generiqueResult = generiqueEither.fold(
    ifLeft: (_) => throw StateError('unreachable'),
    ifRight: (r) => r,
  );

  final availabilityEither = await parser.BdpmFileParser.parseAvailability(
    streamForKey('availability'),
    medicamentsResult.cisToCip13,
  );
  if (availabilityEither.isLeft) {
    return Either.left(
      availabilityEither.fold(
        ifLeft: (l) => l,
        ifRight: (_) => throw StateError('unreachable'),
      ),
    );
  }
  final availability = availabilityEither.fold(
    ifLeft: (_) => throw StateError('unreachable'),
    ifRight: (r) => r,
  );

  final laboratories = specialitesResult.laboratories;

  return Either.right(
    IngestionBatch(
      specialites: specialitesResult.specialites,
      medicaments: medicamentsResult.medicaments,
      principes: principes,
      generiqueGroups: generiqueResult.generiqueGroups,
      groupMembers: generiqueResult.groupMembers,
      laboratories: laboratories,
      availability: availability,
    ),
  );
}
