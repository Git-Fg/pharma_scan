part of 'package:pharma_scan/core/services/ingestion/bdpm_file_parser.dart';

class _CompositionRow {
  const _CompositionRow({
    required this.cis,
    required this.substanceCode,
    required this.denomination,
    required this.dosage,
    required this.nature,
  });

  final String cis;
  final String substanceCode;
  final String denomination;
  final String dosage;
  final String nature;
}

class _CompositionGroup {
  _CompositionGroup();

  final List<_CompositionRow> rows = [];
}

Future<Map<String, String>> parseCompositionsImpl(
  Stream<String>? lines,
) async {
  final compositionMap = <String, Map<String, _CompositionRow>>{};

  if (lines == null) {
    return {};
  }

  await for (final line in lines) {
    if (line.trim().isEmpty) continue;
    final parsed = _bdpmParser
        .parseRow<
          (
            String cis,
            String substanceCode,
            String denominationSubst,
            String dosage,
            String nature,
          )
        >(
          line,
          8,
          (cols) => (
            cols[0],
            cols[2],
            cols[3],
            cols[4],
            cols[6],
          ),
        );
    if (parsed == null) continue;
    final (cis, substanceCodeRaw, denominationSubst, dosage, natureComposant) =
        parsed;
    final substanceCode = substanceCodeRaw.trim();
    if (cis.isEmpty || substanceCode.isEmpty) continue;

    final normalizedDenomination = _normalizeSaltPrefix(denominationSubst);
    final compositionRow = _CompositionRow(
      cis: cis,
      substanceCode: substanceCode,
      denomination: normalizedDenomination,
      dosage: dosage.trim(),
      nature: natureComposant,
    );

    final cisRows = compositionMap.putIfAbsent(cis, () => {});
    final existing = cisRows[compositionRow.substanceCode];
    final isExistingFt =
        existing != null && existing.nature.toUpperCase() == 'FT';
    final isNewFt = compositionRow.nature.toUpperCase() == 'FT';

    if (isExistingFt) {
      continue;
    }
    if (existing == null || isNewFt) {
      cisRows[compositionRow.substanceCode] = compositionRow;
    }
  }

  final flattened = <String, String>{};
  for (final entry in compositionMap.entries) {
    final rows = entry.value.values.toList()
      ..sort((a, b) => a.substanceCode.compareTo(b.substanceCode));
    final parts = rows.map((r) {
      final dosage = r.dosage.isNotEmpty ? ' ${r.dosage.trim()}' : '';
      return '${r.denomination}$dosage'.trim();
    }).toList();
    flattened[entry.key] = parts.join(' + ');
  }

  return flattened;
}

Future<Either<ParseError, List<PrincipesActifsCompanion>>>
parsePrincipesActifsImpl(
  Stream<String>? lines,
  Map<String, List<String>> cisToCip13,
) async {
  final principes = <PrincipesActifsCompanion>[];

  if (lines == null) {
    return Either.right(principes);
  }

  final rowsByKey = <String, _CompositionGroup>{};

  await for (final line in lines) {
    if (line.trim().isEmpty) continue;
    final parsed = _bdpmParser
        .parseRow<
          (
            String cis,
            String codeSubstance,
            String denominationSubst,
            String dosage,
            String nature,
          )
        >(
          line,
          8,
          (cols) => (
            cols[0],
            cols[2],
            cols[3],
            cols[4],
            cols[6],
          ),
        );
    if (parsed == null) continue;
    final (cis, codeSubstanceRaw, denominationSubst, dosageRaw, natureRaw) =
        parsed;
    final codeSubstance = codeSubstanceRaw.trim();
    if (cis.isEmpty || codeSubstance.isEmpty || denominationSubst.isEmpty) {
      continue;
    }
    if (!cisToCip13.containsKey(cis)) continue;

    final normalizedDenomination = _normalizeSaltPrefix(denominationSubst);

    final compositionRow = _CompositionRow(
      cis: cis,
      substanceCode: codeSubstance,
      denomination: normalizedDenomination,
      dosage: dosageRaw.trim(),
      nature: natureRaw,
    );
    final key = '${compositionRow.cis}_${compositionRow.substanceCode}';
    final group = rowsByKey.putIfAbsent(key, _CompositionGroup.new);
    group.rows.add(compositionRow);
  }

  int naturePriority(String nature) {
    final upper = nature.toUpperCase();
    if (upper == 'FT') return 0;
    if (upper == 'SA') return 1;
    return 2;
  }

  _CompositionRow? pickWinner(_CompositionGroup group) {
    _CompositionRow? winner;
    for (final row in group.rows) {
      final nature = row.nature.toUpperCase();
      if (nature == 'FT') {
        winner = row;
        break;
      }
      if (winner == null && nature == 'SA') {
        winner = row;
      }
    }
    return winner ?? (group.rows.isNotEmpty ? group.rows.first : null);
  }

  final selectedRows =
      rowsByKey.values.map(pickWinner).whereType<_CompositionRow>().toList()
        ..sort(
          (a, b) {
            final priority = naturePriority(
              a.nature,
            ).compareTo(naturePriority(b.nature));
            if (priority != 0) return priority;
            final cisCompare = a.cis.compareTo(b.cis);
            if (cisCompare != 0) return cisCompare;
            return a.substanceCode.compareTo(b.substanceCode);
          },
        );

  String stripBaseSuffix(String value) =>
      value.replaceAll(RegExp(r'\s+BASE$', caseSensitive: false), '').trim();

  for (final selectedRow in selectedRows) {
    final cip13s = cisToCip13[selectedRow.cis];
    if (cip13s == null) continue;

    final (dosageValue, dosageUnit) = _parseDosage(selectedRow.dosage);
    final principle = stripBaseSuffix(selectedRow.denomination);
    final normalizedPrinciple = principle.isNotEmpty
        ? normalizePrincipleOptimal(principle)
        : null;

    for (final cip13 in cip13s) {
      principes.add(
        PrincipesActifsCompanion(
          codeCip: Value(cip13),
          principe: Value(principle),
          principeNormalized: Value(normalizedPrinciple),
          dosage: Value(dosageValue?.toString()),
          dosageUnit: Value(dosageUnit),
        ),
      );
    }
  }

  return Right(principes);
}
