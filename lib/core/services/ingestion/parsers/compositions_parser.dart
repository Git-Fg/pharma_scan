part of 'package:pharma_scan/core/services/ingestion/bdpm_file_parser.dart';

typedef CompositionRow = ({
  String cis,
  String substanceCode,
  String denomination,
  String dosage,
  String nature,
});

class _CompositionGroup {
  _CompositionGroup();

  final List<CompositionRow> rows = [];
}

class CompositionsParser implements FileParser<Map<String, String>> {
  @override
  Future<Map<String, String>> parse(Stream<List<dynamic>>? rows) async {
    final compositionMap = <String, Map<String, CompositionRow>>{};

    if (rows == null) {
      return {};
    }

    await for (final row in rows) {
      if (row.length < 8) continue;
      final cols = row.map(_cellAsString).toList(growable: false);
      final cis = cols[0];
      final substanceCodeRaw = cols[2];
      final denominationSubst = cols[3];
      final dosage = cols[4];
      final natureComposant = cols[6];
      final substanceCode = substanceCodeRaw.trim();
      if (cis.isEmpty || substanceCode.isEmpty) continue;

      final normalizedDenomination = _normalizeSaltPrefix(denominationSubst);
      final compositionRow = (
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
}

class PrincipesActifsParser
    implements FileParser<Either<ParseError, List<PrincipesActifsCompanion>>> {
  PrincipesActifsParser(this.cisToCip13);

  final Map<String, List<String>> cisToCip13;

  @override
  Future<Either<ParseError, List<PrincipesActifsCompanion>>> parse(
    Stream<List<dynamic>>? rows,
  ) async {
    final principes = <PrincipesActifsCompanion>[];

    if (rows == null) {
      return Either.right(principes);
    }

    final rowsByKey = <String, _CompositionGroup>{};

    await for (final row in rows) {
      if (row.length < 8) continue;
      final cols = row.map(_cellAsString).toList(growable: false);
      final cis = cols[0];
      final codeSubstanceRaw = cols[2];
      final denominationSubst = cols[3];
      final dosageRaw = cols[4];
      final natureRaw = cols[6];
      final codeSubstance = codeSubstanceRaw.trim();
      if (cis.isEmpty || codeSubstance.isEmpty || denominationSubst.isEmpty) {
        continue;
      }
      if (!cisToCip13.containsKey(cis)) continue;

      final normalizedDenomination = _normalizeSaltPrefix(denominationSubst);

      final compositionRow = (
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

    CompositionRow? pickWinner(_CompositionGroup group) {
      CompositionRow? winner;
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
        rowsByKey.values.map(pickWinner).whereType<CompositionRow>().toList()
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
      final dosageText = dosageValue?.toString();

      for (final cip13 in cip13s) {
        principes.add(
          PrincipesActifsCompanion(
            codeCip: Value(cip13),
            principe: Value(principle),
            principeNormalized: Value(normalizedPrinciple),
            dosage: Value(dosageText),
            dosageUnit: Value(dosageUnit),
          ),
        );
      }
    }

    return Either.right(principes);
  }
}
