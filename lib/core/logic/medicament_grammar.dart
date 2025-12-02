import 'package:petitparser/petitparser.dart';

class MedicamentGrammarDefinition extends GrammarDefinition {
  @override
  Parser start() => ref0(baseName).end();

  /// Entry point: attempt to extract a clean base name.
  Parser baseName() {
    return (ref0(specialToken) | ref0(invertedFormatBase) | ref0(standardBase))
        .map((value) => (value as String).trim());
  }

  /// Handle special cases that map to a fixed canonical token.
  Parser specialToken() {
    final word = letter().plus().flatten();
    final token = word.plusSeparated(whitespace().plus()).flatten();
    return token.map((value) {
      final v = value.trim();
      if (v.contains('OMEGA-3') || v.contains('OMEGA 3')) {
        return 'OMEGA-3';
      }
      if (v.contains('CALCITONINE')) {
        return 'CALCITONINE';
      }
      if (v.contains('PERINDOPRIL')) {
        return 'PERINDOPRIL';
      }
      if (v.contains('RISEDRON')) {
        return 'RISEDRONATE';
      }
      if (v.contains('ALENDRONATE') || v.contains('ALENDRONIQUE')) {
        return 'ALENDRONATE';
      }
      if (v.contains('PENTAMIDINE')) {
        return 'PENTAMIDINE';
      }
      if (v == 'PHOSPHATE MONOSODIQUE') {
        return 'PHOSPHATE';
      }
      if (v.contains('GADOLINIUM') || v.contains('GADOTER') || v == 'DOTA') {
        return 'GADOTERIQUE';
      }
      return v;
    });
  }

  /// Handle inverted formats: "SODIUM (BICARBONATE DE)" -> "BICARBONATE".
  Parser invertedFormatBase() {
    final saltWord = letter().plus().flatten();
    final inner =
        (letter().plus() & (char(' ').plus() & letter().plus()).star())
            .flatten();
    return (saltWord &
            whitespace().star() &
            char('(') &
            whitespace().star() &
            inner &
            whitespace().plus() &
            string('DE') &
            whitespace().star() &
            char(')'))
        .map((values) {
          final innerText = values[4] as String;
          final index = innerText.indexOf(' DE');
          if (index == -1) return innerText;
          return innerText.substring(0, index).trim();
        });
  }

  /// Standard pattern with optional salt prefix / suffix, dosage and garbage.
  Parser standardBase() {
    return (ref0(saltPrefix).optional() &
            ref0(coreName) &
            ref0(saltSuffix).star() &
            ref0(dosage).star() &
            ref0(parenGarbage).star())
        .pick(1);
  }

  /// Salt prefixes like "CHLORHYDRATE DE", "MALÉATE DE", "FUMARATE ACIDE DE".
  Parser saltPrefix() {
    final prefixes = [
      'FUMARATE ACIDE DE',
      'HEMIFUMARATE DE',
      "MALÉATE D'",
      "MALEATE D'",
      "TARTRATE D'",
      "FUMARATE D'",
      "SUCCINATE D'",
      "ACETATE D'",
      "ACÉTATE D'",
      "LACTATE D'",
      "GLUCONATE D'",
      "BENZOATE D'",
      "CITRATE D'",
      "PIVALATE D'",
      "VALERATE D'",
      "PALMITATE D'",
      "STEARATE D'",
      "OLEATE D'",
      'MALÉATE DE',
      'MALEATE DE',
      'MALATE DE',
      "MALATE D'",
      'TARTRATE DE',
      'FUMARATE DE',
      'SUCCINATE DE',
      'ACETATE DE',
      'ACÉTATE DE',
      'LACTATE DE',
      'GLUCONATE DE',
      'BENZOATE DE',
      'CITRATE DE',
      'PIVALATE DE',
      'VALERATE DE',
      'PALMITATE DE',
      'STEARATE DE',
      'OLEATE DE',
      "CHLORHYDRATE D'",
      "DICHLORHYDRATE D'",
      "HYDROCHLORURE D'",
      "BROMURE D'",
      "IODURE D'",
      "FLUORURE D'",
      "PHOSPHATE D'",
      "SULFATE D'",
      "NITRATE D'",
      "CARBONATE D'",
      "BICARBONATE D'",
      "HYDROXYDE D'",
      "OXIDE D'",
      "PEROXIDE D'",
      'CHLORHYDRATE DE',
      'DICHLORHYDRATE DE',
      'HYDROCHLORURE DE',
      'BROMURE DE',
      'IODURE DE',
      'FLUORURE DE',
      'PHOSPHATE DE',
      'SULFATE DE',
      'NITRATE DE',
      'CARBONATE DE',
      'HYDROXYDE DE',
      'OXIDE DE',
      'PEROXIDE DE',
      'BESILATE DE',
      "BESILATE D'",
      'BESYLATE DE',
      "BESYLATE D'",
      'MESILATE DE',
      "MESILATE D'",
      'MESYLATE DE',
      'TOSILATE DE',
      'TOSYLATE DE',
      'HYDROGENOSUCCINATE DE',
      'HYDROGENOSULFATE DE',
      'DITARTRATE DE',
      'HEMITARTRATE DE',
      "LACTOBIONATE D'",
      'LACTOBIONATE DE',
      "LYSINATE D'",
      'LYSINATE DE',
      "OXALATE D'",
      'OXALATE DE',
      'ETHANOLATE DE',
      "D,L-HYDROGENOMALATE D'",
      'D,L-HYDROGENOMALATE DE',
      'BROMHYDRATE DE',
      "BROMHYDRATE D'",
      'HEMISUCCINATE DE',
      "HEMISUCCINATE D'",
      'ENANTATE DE',
      "ENANTATE D'",
      'CATIORESINE CARBOXYLATE DE',
      'RESINATE DE',
      "RESINATE D'",
      'DIGLUCONATE DE',
      "DIGLUCONATE D'",
      'SEL DE',
      'TERT-BUTYLAMINE DE',
      'TERT BUTYLAMINE DE',
      'ISETHIONATE DE',
      'DIISETHIONATE DE',
    ];
    final parsers = prefixes
        .map<Parser<String>>(
          (p) => (string(p).trim() & whitespace().plus()).flatten(),
        )
        .toList();
    Parser combined = failure<String>();
    for (final parser in parsers) {
      combined = combined | parser;
    }
    return combined.cast<String>();
  }

  /// Core molecule name: run of letters and dashes separated by spaces.
  Parser coreName() {
    final word = pattern('A-Z0-9-').plus().flatten();
    return (word & (whitespace().plus() & word).star()).flatten();
  }

  /// Salt / form suffixes at the end of the name.
  Parser saltSuffix() {
    final suffixes = [
      'MAGNESIQUE DIHYDRATÉ',
      'MAGNESIQUE DIHYDRATEE',
      'MAGNESIQUE DIHYDRATE',
      'MAGNESIUM TRIHYDRATÉ',
      'MAGNESIUM TRIHYDRATEE',
      'MAGNESIUM TRIHYDRATE',
      'MONOSODIQUE HÉMIPENTAHYDRATÉ',
      'MONOSODIQUE HEMIPENTAHYDRATE',
      'MONOSODIQUE ANHYDRE',
      'MONOSODIQUE TRIHYDRATÉ',
      'MONOSODIQUE MONOHYDRATÉ',
      'DISODIQUE HEMIPENTAHYDRATE',
      'DISODIQUE',
      'MAGNESIQUE',
      'MAGNESIUM',
      'MONOSODIQUE',
      'BASE',
      'SESQUIHYDRATE',
      'MONOHYDRATE',
      'MONOHYDRATÉ',
      'MONOHYDRATEE',
      'DIHYDRATE',
      'DIHYDRATÉ',
      'DIHYDRATEE',
      'HEMIHYDRATE',
      'TRIHYDRATE',
      'TRIHYDRATÉ',
      'TRIHYDRATEE',
      'TETRAHYDRATE',
      'ANHYDRATE',
      'ANHYDRE',
      'HYDRATE',
      'SODIQUE',
      'POTASSIQUE',
      'MAGNESIEN',
      'CALCIQUE',
      'ZINCIQUE',
      'ACIDE',
      'LIQUIDE',
      'DE SODIUM',
      'DE POTASSIUM',
      'DE CALCIUM',
      'DE MAGNESIUM',
      'ARGININE',
      'TERT-BUTYLAMINE',
      'TERT BUTYLAMINE',
      'ERBUMINE',
    ];
    final parsers = suffixes
        .map<Parser<String>>(
          (s) => (whitespace().plus() & string(s).trim()).flatten(),
        )
        .toList();
    Parser combined = failure<String>();
    for (final parser in parsers) {
      combined = combined | parser;
    }
    return combined.cast<String>();
  }

  /// Dosage patterns like "500 MG", "10%", "1 MG/ML", etc.
  Parser dosage() {
    final number =
        digit().plus() & (char('.') | char(',')).optional() & digit().star();
    final unit =
        string('MG') |
        string('G') |
        string('ML') |
        string('M L') |
        string('µG') |
        string('MCG') |
        string('UI') |
        string('U.I.') |
        string('M.U.I.') |
        char('%') |
        string('MEQ') |
        string('MOL') |
        string('GBQ') |
        string('MBQ') |
        string('CH') |
        string('DH');
    final ratio =
        (whitespace().star() & char('/') & whitespace().star() & word()).star();
    final pour = string('POUR').trim() & whitespace().plus() & number & unit;
    return (whitespace().plus() &
            (number & whitespace().plus() & unit & ratio |
                number & unit & ratio |
                pour))
        .flatten();
  }

  /// Parenthesized segments that we can safely discard from the base name.
  Parser parenGarbage() {
    final inner = any().starLazy(char(')')).flatten(); // everything until ')'
    return (whitespace().star() & char('(') & inner & char(')'))
        .flatten()
        .trim();
  }

  Parser word() => pattern('A-Z0-9-').plus().flatten();
}

/// Build a parser that extracts the canonical base name for medicaments.
Parser<String> buildMedicamentBaseNameParser() {
  final definition = MedicamentGrammarDefinition();
  return definition.build().cast<String>();
}
