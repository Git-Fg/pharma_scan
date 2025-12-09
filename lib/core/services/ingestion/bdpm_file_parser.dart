import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_either/dart_either.dart';
import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:enough_convert/enough_convert.dart';
import 'package:pharma_scan/core/constants/chemical_constants.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/logic/sanitizer.dart';
import 'package:pharma_scan/core/services/ingestion/schema/bdpm_parsers.dart';
import 'package:pharma_scan/core/utils/strings.dart';

part 'parsers/compositions_parser.dart';
part 'parsers/generiques_parser.dart';
part 'parsers/medicaments_parser.dart';
part 'parsers/misc_parsers.dart';
part 'parsers/parser_models.dart';
part 'parsers/parser_utils.dart';
part 'parsers/specialites_parser.dart';

class BdpmFileParser {
  BdpmFileParser._();

  static Stream<String>? openLineStream(String? path) {
    if (path == null || path.isEmpty) return null;
    final file = File(path);
    if (!file.existsSync()) return null;

    Encoding codec = const Windows1252Codec();

    try {
      final raf = file.openSync();
      try {
        final preview = raf.readSync(4096);
        if (preview.isNotEmpty) {
          final decoded = const Utf8Decoder(allowMalformed: true).convert(
            preview,
          );
          final hasReplacement = decoded.contains('\uFFFD');
          if (!hasReplacement) {
            codec = utf8;
          }
        }
      } finally {
        raf.closeSync();
      }
    } on Exception {
      codec = const Windows1252Codec();
    }

    return file
        .openRead()
        .transform(codec.decoder)
        .transform(
          const LineSplitter(),
        );
  }

  static Future<Either<ParseError, SpecialitesParseResult>> parseSpecialites(
    Stream<String>? lines,
    Map<String, String> conditionsByCis,
    Map<String, String> mitmMap,
  ) => parseSpecialitesImpl(lines, conditionsByCis, mitmMap);

  static Future<Either<ParseError, MedicamentsParseResult>> parseMedicaments(
    Stream<String>? lines,
    SpecialitesParseResult specialitesResult,
  ) => parseMedicamentsImpl(lines, specialitesResult);

  static Future<Map<String, String>> parseCompositions(
    Stream<String>? lines,
  ) => parseCompositionsImpl(lines);

  static Future<Either<ParseError, List<PrincipesActifsCompanion>>>
  parsePrincipesActifs(
    Stream<String>? lines,
    Map<String, List<String>> cisToCip13,
  ) => parsePrincipesActifsImpl(lines, cisToCip13);

  static Future<Either<ParseError, GeneriquesParseResult>> parseGeneriques(
    Stream<String>? lines,
    Map<String, List<String>> cisToCip13,
    Set<String> medicamentCips,
    Map<String, String> compositionMap,
    Map<String, String> specialitesMap,
  ) => parseGeneriquesImpl(
    lines,
    cisToCip13,
    medicamentCips,
    compositionMap,
    specialitesMap,
  );

  static Future<Map<String, String>> parseConditions(
    Stream<String>? lines,
  ) => parseConditionsImpl(lines);

  static Future<Map<String, String>> parseMitm(Stream<String>? lines) =>
      parseMitmImpl(lines);

  static Future<Either<ParseError, List<MedicamentAvailabilityCompanion>>>
  parseAvailability(
    Stream<String>? lines,
    Map<String, List<String>> cisToCip13,
  ) => parseAvailabilityImpl(lines, cisToCip13);
}
