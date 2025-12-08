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
    final cols = _bdpmParser.splitLine(line, 8);
    if (cols.isEmpty) continue;
    final cis = cols[0];
    final substanceCode = cols[2].trim();
    if (cis.isEmpty || substanceCode.isEmpty) continue;

    final denominationSubst = cols[3];
    final dosage = cols[4];
    final natureComposant = cols[6];

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
    final cols = _bdpmParser.splitLine(line, 8);
    if (cols.isEmpty) continue;
    final cis = cols[0];
    final codeSubstance = cols[2].trim();
    final denominationSubst = cols[3];
    if (cis.isEmpty || codeSubstance.isEmpty || denominationSubst.isEmpty) {
      continue;
    }
    if (!cisToCip13.containsKey(cis)) continue;

    final normalizedDenomination = _normalizeSaltPrefix(denominationSubst);

    final compositionRow = _CompositionRow(
      cis: cis,
      substanceCode: codeSubstance,
      denomination: normalizedDenomination,
      dosage: cols[4].trim(),
      nature: cols[6],
    );
    final key = '${compositionRow.cis}_${compositionRow.substanceCode}';
    final group = rowsByKey.putIfAbsent(key, _CompositionGroup.new);
    group.rows.add(compositionRow);
  }

  for (final group in rowsByKey.values) {
    if (group.rows.isEmpty) continue;

    _CompositionRow? winner;
    for (final row in group.rows) {
      if (row.nature.toUpperCase() == 'FT') {
        winner = row;
        break;
      }
      if (winner == null && row.nature.toUpperCase() == 'SA') {
        winner = row;
      }
    }

    final selectedRow = winner ?? group.rows.first;
    final cip13s = cisToCip13[selectedRow.cis];
    if (cip13s == null) continue;

    final (dosageValue, dosageUnit) = _parseDosage(selectedRow.dosage);
    final normalizedPrinciple = selectedRow.denomination.isNotEmpty
        ? normalizePrincipleOptimal(selectedRow.denomination)
        : null;

    for (final cip13 in cip13s) {
      principes.add(
        PrincipesActifsCompanion(
          codeCip: Value(cip13),
          principe: Value(selectedRow.denomination),
          principeNormalized: Value(normalizedPrinciple),
          dosage: Value(dosageValue?.toString()),
          dosageUnit: Value(dosageUnit),
        ),
      );
    }
  }

  return Right(principes);
}
