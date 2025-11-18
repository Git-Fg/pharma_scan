// lib/core/parser/medicament_grammar.dart

import 'dart:math';

import 'package:decimal/decimal.dart';
import 'package:petitparser/petitparser.dart';

import '../models/parsed_name.dart';

class MedicamentGrammarDefinition {
  MedicamentGrammarDefinition();

  static const List<String> _formulationKeywords = [
    'solution pour lavage ophtalmique en récipient unidose',
    'solution pour lavage ophtalmique en récipient-unidose',
    'solution pour bain de bouche',
    'gomme à mâcher médicamenteuse',
    'gomme à sucer',
    'spray buccal',
    'spray nasal',
    'spray pour application buccale',
    'spray pour application nasale',
    'dispositif transdermique',
    'patch transdermique',
    'comprimé sublingual',
    'poudre pour solution à diluer pour perfusion',
    'solution à diluer pour perfusion',
    'système de diffusion vaginal',
    "pastille édulcorée à l'acésulfame potassique",
    "pastille édulcorée à la saccharine sodique",
    'pastille',
    'pansement adhésif cutané',
    'suspension pour pulvérisation nasale',
    'émulsion fluide pour application cutanée',
    'émulsion pour application cutanée',
    'bain de bouche',
    'solution injectable/pour perfusion',
    'solution pour perfusion en poche',
    'solution pour pulvérisation',
    'solution pour inhalation',
    'suspension pour inhalation',
    'poudre pour suspension buvable en flacon',
    'poudre pour suspension buvable',
    'poudre pour solution injectable (iv)',
    'poudre pour solution injectable',
    'microgranules à libération prolongée en gélule',
    'microgranules en comprimé',
    'gélule gastro-résistante',
    'gélule à libération prolongée',
    'comprimé à libération prolongée',
    'comprimé pelliculé sécable',
    'solution injectable en flacon',
    'solution injectable en poche',
    'solution buvable en flacon',
    'comprimé orodispersible',
    'comprimé effervescent',
    'comprimé enrobé',
    'suspension buvable',
    'comprimé sécable',
    'solution injectable',
    'solution buvable',
    'collyre en solution',
    'comprimé',
    'gélule',
    'capsule molle',
    'capsule',
    'solution',
    'poudre',
    'granulés',
    'lyophilisat',
    'gel',
    'pommade',
    'crème',
    'collyre',
    'ovule',
    'suppositoire',
    'mousse',
  ];

  static const Set<String> knownLabSuffixes = {
    'ACCORD',
    'ACCORDHEALTHCARE',
    'ACTAVIS',
    'AGUETTANT',
    'ALMUS',
    'ALTER',
    'ARROW',
    'ARROWGENERIQUE',
    'ARROWLAB',
    'AUTRICHE',
    'BGR',
    'BELGIQUE',
    'BIOGARAN',
    'BIOGARANCONSEIL',
    'BIOGARANSANTE',
    'BOUCHARARECORDATI',
    'CRISTERS',
    'CRISTERSPHARMA',
    'EG',
    'EGLABOLABORATOIRESEUROGENERICS',
    'EGLABOLABORATOIRES',
    'ENFANTS',
    'ESPAGNE',
    'EUROGENERICS',
    'EUGIA',
    'EUGIAPHARMA',
    'EVOLUGEN',
    'EVOLUGENPHARMA',
    'FRESENIUS',
    'FRESENIUSKABI',
    'FRANCE',
    'GNR',
    'RENAUDIN',
    'HCS',
    'HEALTHCARE',
    'HOSPIRA',
    'IRLANDE',
    'KABI',
    'KRKA',
    'LAB',
    'LABO',
    'LABOLABORATOIRES',
    'LABORATOIRES',
    'LABORATOIRE',
    'LABS',
    'MALTE',
    'MYLAN',
    'PANPHARMA',
    'PAYSBAS',
    'PHARMA',
    'PHARMACEUTICALS',
    'REF',
    'SANDOZ',
    'SANTE',
    'SUN',
    'SUNPHARMA',
    'TEVA',
    'TEVASANTE',
    'UPSA',
    'VIATRIS',
    'VIATRISPHARMA',
    'ZENTIVA',
    'ZENTIVAFRANCE',
    'ZENTIVALAB',
    'ZYDUS',
  };

  static const List<String> _bannedMeasurementSuffixes = [
    '/24 heures',
    '/ 24 heures',
    '/24h',
    '/dose',
    '/ dose',
  ];

  Parser<String> _numberToken() {
    final digits = digit().plus();
    final decimal = (char('.') | char(',')).seq(digit().plus()).optional();
    return (digits & decimal).flatten();
  }

  Parser<String> _unitToken() {
    final units = [
      'mg',
      'g',
      'µg',
      'mcg',
      'microgrammes',
      'ml',
      'mL',
      'l',
      'ui',
      'unités',
      '%',
      'ch',
      'dh',
      'meq',
      'mmol',
      'gbq',
      'mbq',
      'dose',
      'doses',
      'heure',
      'heures',
      'h',
    ];
    return ChoiceParser(
      units.map((unit) => string(unit, ignoreCase: true)).toList(),
    ).flatten();
  }

  Parser<String> dosageToken() {
    final slash = (char('/') & whitespace().star()).flatten();
    final ratioTail =
        (whitespace().star() &
                slash &
                _numberToken().optional() &
                whitespace().star() &
                _unitToken())
            .flatten()
            .optional();
    return (_numberToken() & whitespace().plus() & _unitToken() & ratioTail)
        .flatten();
  }

  Parser<String> formulationKeyword() {
    final keywords = List<String>.from(_formulationKeywords)
      ..sort((a, b) => b.length.compareTo(a.length));
    return ChoiceParser(
      keywords.map((k) => string(k, ignoreCase: true)).toList(),
    ).flatten();
  }
}

class MedicamentParser {
  MedicamentParser({MedicamentGrammarDefinition? grammar})
    : _dosageParser = (grammar ?? MedicamentGrammarDefinition())
          .dosageToken()
          .token();

  final Parser<Token<String>> _dosageParser;

  // Pre-compiled Regex patterns
  static final _regexTrailingCommaSpace = RegExp(r'[,\s]+$');
  static final _regexWhitespace = RegExp(r'\s+');
  static final _regexNonAlpha = RegExp(r'[^A-Za-z]');
  static final _regexComma = RegExp(r',');

  ParsedName parse(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return ParsedName(original: raw ?? '', baseName: null);
    }
    final normalized = _normalizeWhitespace(raw);
    final formulationExtraction = _extractFormulation(normalized);
    final dosageExtraction = _extractDosages(formulationExtraction.remaining);
    final stripped = _stripLaboratorySuffix(dosageExtraction.remaining);
    final cleaned = _cleanMeasurementArtifacts(stripped);
    return ParsedName(
      original: raw,
      baseName: cleaned.isEmpty ? null : cleaned,
      dosages: dosageExtraction.dosages,
      formulation: formulationExtraction.formulation,
    );
  }

  _FormulationResult _extractFormulation(String value) {
    var working = value.trim();
    final detected = <String>[];
    while (true) {
      final match = _matchTrailingFormulation(working);
      if (match == null) break;
      detected.add(match.segment);
      working = match.remaining.trimRight();
    }
    final normalized = detected.isEmpty
        ? null
        : detected.reversed.map(_normalizeWhitespace).join(', ');
    working = working.replaceAll(_regexTrailingCommaSpace, '').trim();
    return _FormulationResult(working, normalized);
  }

  _FormulationMatch? _matchTrailingFormulation(String value) {
    final trimmed = value.trimRight();
    if (trimmed.isEmpty) return null;
    final lower = trimmed.toLowerCase();
    final keywords = List<String>.from(
      MedicamentGrammarDefinition._formulationKeywords,
    )..sort((a, b) => b.length.compareTo(a.length));
    for (final keyword in keywords) {
      final lowerKeyword = keyword.toLowerCase();
      if (lower.endsWith(lowerKeyword)) {
        final start = lower.lastIndexOf(lowerKeyword);
        var remaining = trimmed.substring(0, start).trimRight();
        if (remaining.endsWith(',')) {
          remaining = remaining.substring(0, remaining.length - 1).trimRight();
        }
        return _FormulationMatch(
          remaining: remaining,
          segment: trimmed.substring(start).trimLeft(),
        );
      }
    }
    return null;
  }

  _DosageResult _extractDosages(String value) {
    final tokens = _matchAll(_dosageParser, value);
    if (tokens.isEmpty) {
      return _DosageResult(value.trim(), const []);
    }
    final buffer = StringBuffer();
    var cursor = 0;
    final dosages = <Dosage>[];
    for (final token in tokens) {
      if (token.start < cursor) {
        continue;
      }
      final candidate = token.value.trim();
      final dosage = _parseDosage(candidate);
      if (dosage == null) continue;
      buffer.write(value.substring(cursor, token.start));
      cursor = token.stop;
      final alreadySeen = dosages.any(
        (existing) =>
            existing.value == dosage.value && existing.unit == dosage.unit,
      );
      if (!alreadySeen) {
        dosages.add(dosage);
      }
    }
    buffer.write(value.substring(cursor));
    final remaining = _normalizeWhitespace(buffer.toString());
    return _DosageResult(remaining, dosages);
  }

  List<Token<String>> _matchAll(Parser<Token<String>> parser, String input) {
    final matches = <Token<String>>[];
    var position = 0;
    while (position < input.length) {
      final context = Context(input, position);
      final result = parser.parseOn(context);
      if (result is Success) {
        final token = result.value;
        matches.add(token);
        position = max(position + 1, token.stop);
      } else {
        position += 1;
      }
    }
    return matches;
  }

  Dosage? _parseDosage(String candidate) {
    if (candidate.isEmpty) return null;
    final normalized = candidate.replaceAll(_regexWhitespace, ' ');
    if (normalized.contains('/')) {
      final parts = normalized.split('/');
      final head = parts.first.trim().split(' ');
      if (head.length < 2) return null;
      final value = Decimal.tryParse(head.first.replaceAll(_regexComma, '.'));
      final unit = normalized.substring(normalized.indexOf(' ') + 1);
      if (value == null) return null;
      return Dosage(
        value: value,
        unit: unit.trim(),
        isRatio: true,
        raw: normalized,
      );
    }
    final pieces = normalized.split(' ');
    if (pieces.length < 2) return null;
    final value = Decimal.tryParse(pieces.first.replaceAll(_regexComma, '.'));
    if (value == null) return null;
    final unit = pieces.sublist(1).join(' ').trim();
    return Dosage(value: value, unit: unit, raw: normalized);
  }

  String _stripLaboratorySuffix(String value) {
    var working = value.trim();
    if (working.isEmpty) return working;
    final tokens = working.split(' ');
    while (tokens.isNotEmpty) {
      final last = tokens.last.replaceAll(_regexNonAlpha, '').toUpperCase();
      if (last.length > 1 &&
          MedicamentGrammarDefinition.knownLabSuffixes.contains(last)) {
        tokens.removeLast();
        continue;
      }
      break;
    }
    working = tokens.join(' ').trim();
    if (working.toUpperCase().endsWith(' LP')) {
      final candidate = working.substring(0, working.length - 2).trim();
      final parts = candidate.split(' ');
      if (parts.isNotEmpty) {
        final last = parts.last.replaceAll(_regexNonAlpha, '').toUpperCase();
        if (MedicamentGrammarDefinition.knownLabSuffixes.contains(last)) {
          parts.removeLast();
          working = '${parts.join(' ')} LP'.trim();
        }
      }
    }
    return working.trim();
  }

  String _cleanMeasurementArtifacts(String value) {
    var cleaned = value;
    for (final suffix
        in MedicamentGrammarDefinition._bannedMeasurementSuffixes) {
      if (cleaned.toLowerCase().endsWith(suffix)) {
        cleaned = cleaned.substring(0, cleaned.length - suffix.length);
      }
    }
    cleaned = cleaned.replaceAll(_regexWhitespace, ' ');
    return cleaned.trim().replaceAll(_regexTrailingCommaSpace, '');
  }

  String _normalizeWhitespace(String value) {
    return value.replaceAll(_regexWhitespace, ' ').trim();
  }
}

class _FormulationResult {
  const _FormulationResult(this.remaining, this.formulation);

  final String remaining;
  final String? formulation;
}

class _FormulationMatch {
  const _FormulationMatch({required this.remaining, required this.segment});

  final String remaining;
  final String segment;
}

class _DosageResult {
  const _DosageResult(this.remaining, this.dosages);

  final String remaining;
  final List<Dosage> dosages;
}
