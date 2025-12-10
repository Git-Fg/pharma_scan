import 'dart:async';
import 'dart:io';

import 'package:dart_either/dart_either.dart';
import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:pharma_scan/core/constants/chemical_constants.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/database/database.drift.dart';
import 'package:pharma_scan/core/logic/sanitizer.dart';
import 'package:pharma_scan/core/services/ingestion/bdpm_stream_factory.dart';
import 'package:pharma_scan/core/services/ingestion/schema/bdpm_parsers.dart';
import 'package:pharma_scan/core/utils/strings.dart';

part 'parsers/compositions_parser.dart';
part 'parsers/generiques_parser.dart';
part 'parsers/medicaments_parser.dart';
part 'parsers/misc_parsers.dart';
part 'parsers/parser_models.dart';
part 'parsers/parser_utils.dart';
part 'parsers/specialites_parser.dart';

abstract class FileParser<T> {
  Future<T> parse(Stream<List<dynamic>>? rows);
}

class BdpmFileParser {
  const BdpmFileParser();

  static final CompositionsParser _compositionsParser = CompositionsParser();

  static Stream<List<dynamic>>? openRowStream(String? path) {
    if (path == null || path.isEmpty) return null;
    final file = File(path);
    if (!file.existsSync()) return null;
    return createBdpmRowStream(path);
  }

  static Future<Either<ParseError, SpecialitesParseResult>> parseSpecialites(
    Stream<List<dynamic>>? rows,
    Map<String, String> conditionsByCis,
    Map<String, String> mitmMap,
  ) => SpecialitesParser(
    conditionsByCis: conditionsByCis,
    mitmMap: mitmMap,
  ).parse(rows);

  static Future<Either<ParseError, MedicamentsParseResult>> parseMedicaments(
    Stream<List<dynamic>>? rows,
    SpecialitesParseResult specialitesResult,
  ) => MedicamentsParser(specialitesResult).parse(rows);

  static Future<Map<String, String>> parseCompositions(
    Stream<List<dynamic>>? rows,
  ) => _compositionsParser.parse(rows);

  static Future<Either<ParseError, List<PrincipesActifsCompanion>>>
  parsePrincipesActifs(
    Stream<List<dynamic>>? rows,
    Map<String, List<String>> cisToCip13,
  ) => PrincipesActifsParser(cisToCip13).parse(rows);

  static Future<Either<ParseError, GeneriquesParseResult>> parseGeneriques(
    Stream<List<dynamic>>? rows,
    Map<String, List<String>> cisToCip13,
    Set<String> medicamentCips,
    Map<String, String> compositionMap,
    Map<String, String> specialitesMap,
  ) => GeneriquesParser(
    cisToCip13: cisToCip13,
    medicamentCips: medicamentCips,
    compositionMap: compositionMap,
    specialitesMap: specialitesMap,
  ).parse(rows);

  static Future<Map<String, String>> parseConditions(
    Stream<List<dynamic>>? rows,
  ) => const ConditionsParser().parse(rows);

  static Future<Map<String, String>> parseMitm(
    Stream<List<dynamic>>? rows,
  ) => const MitmParser().parse(rows);

  static Future<Either<ParseError, List<MedicamentAvailabilityCompanion>>>
  parseAvailability(
    Stream<List<dynamic>>? rows,
    Map<String, List<String>> cisToCip13,
  ) => AvailabilityParser(cisToCip13).parse(rows);
}
