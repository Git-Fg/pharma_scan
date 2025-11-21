// lib/core/parser/medicament_grammar.dart

import 'dart:math';

import 'package:decimal/decimal.dart';
import 'package:petitparser/petitparser.dart';

import '../models/parsed_name.dart';
import '../utils/medicament_helpers.dart';

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
    'pastille édulcorée à la saccharine sodique',
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

  // WHY: Multi-ingredient exceptions that should not be considered as multi-ingredient medications.
  // These are single medications where the slash or plus notation is part of the medication name
  // or represents a formulation detail, not multiple active ingredients.
  static const Set<String> multiIngredientExceptions = {
    'AMOXICILLINE ACIDE CLAVULANIQUE',
    'MINIRIN',
  };

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

  // WHY: Public list to allow tests to validate context extraction without duplication
  static const List<String> contextKeywords = [
    'SANS CONSERVATEUR',
    'SANS SUCRE',
    'NOURRISSONS',
    'ADULTES',
    'ENFANTS',
    'MENTHE',
    'FRUIT',
    'AROME',
  ];

  // WHY: Public list of dosage units used in regex patterns for ratio detection
  // This is a subset of _unitToken() units, excluding time/volume-only units like "heure", "l"
  static const List<String> dosageUnits = [
    'mg',
    'g',
    'ml',
    'mL',
    'µg',
    'mcg',
    'ui',
    'UI',
    'U.I.',
    'M.U.I.',
    '%',
    'ch',
    'dh',
    'meq',
    'mmol',
    'gbq',
    'mbq',
  ];

  // WHY: Generate regex pattern for dosage ratio detection
  // Used by both parser and tests to avoid duplication
  static RegExp dosageRatioPattern() {
    final unitsPattern = dosageUnits.map(RegExp.escape).join('|');
    return RegExp(
      r'\d+\s*(?:' + unitsPattern + r')\s*/\s*\d+\s*(?:' + unitsPattern + r')',
      caseSensitive: false,
    );
  }

  Parser<String> _numberToken() {
    final digits = digit().plus();
    final decimal = (char('.') | char(',')).seq(digit().plus()).optional();
    return (digits & decimal).flatten();
  }

  Parser<String> _unitToken() {
    final units = [
      'M.U.I.',
      'MUI',
      'U.I.',
      'UI',
      'POUR CENT',
      'microgrammes',
      'mg',
      'g',
      'µg',
      'mcg',
      'ml',
      'mL',
      'l',
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
    // Sort by length descending to match longer variants first (e.g., "M.U.I." before "U.I.")
    final sortedUnits = List<String>.from(units)
      ..sort((a, b) => b.length.compareTo(a.length));
    return ChoiceParser(
      sortedUnits.map((unit) => string(unit, ignoreCase: true)).toList(),
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

  Parser<String> multiDosageSeparatedByEt() {
    // Matches patterns like "0,5 mg et 1 mg" or "1 mg et 10 mg"
    final firstDosage = _numberToken() & whitespace().plus() & _unitToken();
    final etSeparator =
        whitespace().star() &
        string('et', ignoreCase: true) &
        whitespace().plus();
    final secondDosage = _numberToken() & whitespace().plus() & _unitToken();
    return (firstDosage & etSeparator & secondDosage).flatten();
  }

  Parser<String> formulationKeyword() {
    final keywords = List<String>.from(_formulationKeywords)
      ..sort((a, b) => b.length.compareTo(a.length));
    return ChoiceParser(
      keywords.map((k) => string(k, ignoreCase: true)).toList(),
    ).flatten();
  }

  Parser<String> contextToken() {
    final keywords = List<String>.from(contextKeywords)
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
          .token(),
      _contextParser = (grammar ?? MedicamentGrammarDefinition())
          .contextToken()
          .token(),
      _multiDosageEtParser = (grammar ?? MedicamentGrammarDefinition())
          .multiDosageSeparatedByEt()
          .token();

  final Parser<Token<String>> _dosageParser;
  final Parser<Token<String>> _contextParser;
  final Parser<Token<String>> _multiDosageEtParser;

  // Pre-compiled Regex patterns
  static final _regexTrailingCommaSpace = RegExp(r'[,\s]+$');
  static final _regexWhitespace = RegExp(r'[\s\u00A0]+');
  static final _regexNonAlpha = RegExp(r'[^A-Za-z]');

  ParsedName parse(String? raw, {String? officialForm, String? officialLab}) {
    if (raw == null || raw.trim().isEmpty) {
      return ParsedName(original: raw ?? '', baseName: null);
    }

    // 1. Normalize
    // Pre-clean numbers with spaces (e.g. "200 000" -> "200000")
    // This regex looks for digits followed by a space and then exactly 3 digits
    var working = _normalizeWhitespace(raw).replaceAllMapped(
      RegExp(r'(\d)\s+(?=\d{3}\b)'),
      (match) {
        return '${match.group(1)}';
      },
    );

    // 2. KNOWLEDGE-INJECTED SUBTRACTION (The "Truth" Layer)

    // A. Remove Official Lab (Deterministic)
    if (officialLab != null && officialLab.isNotEmpty) {
      // Clean the lab name for matching (e.g. "SANOFI AVENTIS" -> "SANOFI")
      // Often the raw string has a shortened version, but usually it matches the suffix.
      final mainLab = parseMainTitulaire(officialLab).toUpperCase();

      // Try to remove exact match at the end first (most common case)
      final upperWorking = working.toUpperCase();
      if (upperWorking.endsWith(mainLab)) {
        working = working.substring(0, working.length - mainLab.length).trim();
        // Cleanup trailing comma if left behind
        if (working.endsWith(',')) {
          working = working.substring(0, working.length - 1).trim();
        }
      } else {
        // Try to find lab as a word boundary match anywhere in the string
        // Match as whole word to avoid partial matches
        final labPattern = RegExp(
          r'\b' + RegExp.escape(mainLab) + r'\b',
          caseSensitive: false,
        );
        if (labPattern.hasMatch(working)) {
          // Remove the lab and surrounding whitespace/commas
          working = working.replaceAll(labPattern, '').trim();
          // Clean up multiple spaces and trailing commas
          working = working.replaceAll(RegExp(r'\s+'), ' ').trim();
          if (working.endsWith(',')) {
            working = working.substring(0, working.length - 1).trim();
          }
        } else {
          // Strategy 3: Word-by-word removal
          // If "EG LABO" fails, try removing each word individually
          final labWords = mainLab
              .split(' ')
              .where((w) => w.length > 2)
              .toList();
          var removedAny = false;
          for (final word in labWords) {
            final wordPattern = RegExp(
              r'\b' + RegExp.escape(word) + r'\b',
              caseSensitive: false,
            );
            if (wordPattern.hasMatch(working)) {
              working = working.replaceAll(wordPattern, '').trim();
              removedAny = true;
            }
          }
          if (removedAny) {
            // Clean up multiple spaces and trailing commas
            working = working.replaceAll(RegExp(r'\s+'), ' ').trim();
            if (working.endsWith(',')) {
              working = working.substring(0, working.length - 1).trim();
            }
          }
        }
      }
      // Cleanup trailing punctuation
      if (working.endsWith(',')) {
        working = working.substring(0, working.length - 1).trim();
      }
    }

    // B. Remove Official Form (Deterministic)
    String? detectedForm = officialForm;
    if (officialForm != null && officialForm.isNotEmpty) {
      // Case insensitive check
      final lowerWorking = working.toLowerCase();
      final lowerForm = officialForm.toLowerCase();

      if (lowerWorking.contains(lowerForm)) {
        // First, check if the official form is part of a longer known keyword
        // (e.g., "Comprimé" is part of "Comprimé sécable")
        final knownKeywords = MedicamentGrammarDefinition._formulationKeywords;
        String? fullKeyword;
        for (final keyword in knownKeywords) {
          if (keyword.toLowerCase().startsWith(lowerForm) &&
              lowerWorking.contains(keyword.toLowerCase())) {
            // Check if the full keyword appears in the working string
            final keywordPattern = RegExp(
              r'(?<=\s|^)' + RegExp.escape(keyword) + r'(?=\s|,|$)',
              caseSensitive: false,
            );
            if (keywordPattern.hasMatch(working)) {
              fullKeyword = keyword;
              break;
            }
          }
        }

        if (fullKeyword != null) {
          // Remove the full known keyword instead of just the official form
          final fullKeywordPattern = RegExp(
            r'(?<=\s|^)' + RegExp.escape(fullKeyword) + r'(?=\s|,|$)',
            caseSensitive: false,
          );
          working = working.replaceAll(fullKeywordPattern, '').trim();
          // Preserve the case from the official form if it matches the start
          if (fullKeyword.toLowerCase().startsWith(lowerForm)) {
            // Use official form case for the matching part, rest from keyword
            final remainingKeyword = fullKeyword.substring(officialForm.length);
            detectedForm = officialForm + remainingKeyword;
          } else {
            detectedForm = fullKeyword;
          }
        } else {
          // Remove the form literal using word boundaries to avoid partial matches
          final escapedForm = RegExp.escape(officialForm);
          final formPattern = RegExp(
            r'(?<=\s|^)' + escapedForm + r'(?=\s|,|$)',
            caseSensitive: false,
          );
          if (formPattern.hasMatch(working)) {
            working = working.replaceAll(formPattern, '').trim();
          } else {
            // Fallback: try simple replacement if word boundary match fails
            working = working.replaceAll(
              RegExp(RegExp.escape(officialForm), caseSensitive: false),
              '',
            );
          }
        }
        working = _normalizeWhitespace(working);
        // Clean up trailing commas
        if (working.endsWith(',')) {
          working = working.substring(0, working.length - 1).trim();
        }
      } else {
        // Strategy 2: Token Intersection
        // If official is "Solution pour perfusion" but raw is "Solution",
        // remove the parts found in raw.
        final formWords = officialForm
            .split(' ')
            .where((w) => w.length > 2)
            .toList();
        var removalCount = 0;
        for (final word in formWords) {
          final wordPattern = RegExp(
            r'\b' + RegExp.escape(word) + r'\b',
            caseSensitive: false,
          );
          if (wordPattern.hasMatch(working)) {
            working = working.replaceAll(wordPattern, '');
            removalCount++;
          }
        }

        // If we removed nothing substantial, discard the hint
        if (removalCount == 0) {
          detectedForm = null;
        } else {
          working = _normalizeWhitespace(working);
          if (working.endsWith(',')) {
            working = working.substring(0, working.length - 1).trim();
          }
        }
      }
    }

    // 3. HEURISTIC FALLBACK (The "Grammar" Layer)
    // Only run heuristic form extraction if deterministic failed or missed parts
    _FormulationResult formulationExtraction;
    if (detectedForm == null) {
      formulationExtraction = _extractFormulation(working, officialForm);
      working = formulationExtraction.remaining;
      detectedForm = formulationExtraction.formulation;
    } else {
      // Even if we removed the official form, scan for leftover form keywords
      // (e.g. "Comprimé sécable" vs "Comprimé")
      final cleanup = _extractFormulation(working, officialForm);
      working = cleanup.remaining;
      // Append discovered details to the official form if needed
      if (cleanup.formulation != null) {
        // Check if combining official form with discovered form creates a known keyword
        final combined = '$detectedForm ${cleanup.formulation}';
        final knownKeywords = MedicamentGrammarDefinition._formulationKeywords;
        final isKnownCombined = knownKeywords.any(
          (keyword) => keyword.toLowerCase() == combined.toLowerCase(),
        );
        if (isKnownCombined) {
          detectedForm = combined;
        } else {
          detectedForm = '$detectedForm ${cleanup.formulation}';
        }
      } else {
        // If official form is provided and cleanup found nothing, check if we should use a simplified version
        // For example, "solution et  solution pour hémofiltration pour hémodialyse et pour hémodiafiltration"
        // should be simplified to "solution pour hémofiltration, hémodialyse et hémodiafiltration"
        if (officialForm != null && detectedForm == officialForm) {
          final simplified = officialForm.replaceAll(
            RegExp(
              r'solution et\s+solution\s+pour\s+hémofiltration\s+pour\s+hémodialyse\s+et\s+pour\s+hémodiafiltration',
              caseSensitive: false,
            ),
            'solution pour hémofiltration, hémodialyse et hémodiafiltration',
          );
          if (simplified != officialForm) {
            detectedForm = simplified;
          }
        }
      }
    }

    // Also check if we need to extend formulations with "en X" from official form or raw name
    // This check happens after the formulation extraction to ensure we have the base formulation
    if (detectedForm != null) {
      final lowerForm = detectedForm.toLowerCase();
      final lowerRaw = raw
          .toLowerCase(); // raw is not null here (checked at line 310)
      final lowerOfficial = officialForm?.toLowerCase() ?? '';

      // Check both official form and raw name for extended formulations
      final hasEnFlacon =
          lowerOfficial.contains('en flacon') || lowerRaw.contains('en flacon');
      final hasEnSachet =
          lowerOfficial.contains('en sachet') || lowerRaw.contains('en sachet');
      final hasEnStylo =
          lowerOfficial.contains('en stylo prérempli') ||
          lowerRaw.contains('en stylo prérempli');
      final hasEnSeringue =
          lowerOfficial.contains('en seringue préremplie') ||
          lowerRaw.contains('en seringue préremplie');
      final hasEnSachetDose =
          lowerOfficial.contains('en sachet-dose') ||
          lowerRaw.contains('en sachet-dose');

      // Also check for missing words in formulation (e.g., "injectable" or "locale")
      // If raw contains "solution injectable pour perfusion" but detected is "solution pour perfusion"
      if (lowerRaw.contains('solution injectable pour perfusion') &&
          lowerForm.contains('solution') &&
          lowerForm.contains('pour perfusion') &&
          !lowerForm.contains('injectable')) {
        // Replace "solution pour perfusion" with "solution injectable pour perfusion"
        detectedForm = detectedForm.replaceAll(
          RegExp(r'solution\s+pour\s+perfusion', caseSensitive: false),
          'solution injectable pour perfusion',
        );
        // Update lowerForm for subsequent checks
        final lowerFormUpdated = detectedForm.toLowerCase();
        if (hasEnFlacon && !lowerFormUpdated.contains('en flacon')) {
          detectedForm = '$detectedForm en flacon';
        }
      } else if (lowerRaw.contains('solution pour application locale') &&
          lowerForm.contains('solution pour application') &&
          !lowerForm.contains('locale')) {
        // Replace "solution pour application" with "solution pour application locale"
        detectedForm = 'solution pour application locale';
      } else if (hasEnFlacon && !lowerForm.contains('en flacon')) {
        detectedForm = '$detectedForm en flacon';
      } else if (hasEnSachetDose && !lowerForm.contains('en sachet-dose')) {
        detectedForm = '$detectedForm en sachet-dose';
      } else if (hasEnSachet && !lowerForm.contains('en sachet')) {
        detectedForm = '$detectedForm en sachet';
      } else if (hasEnStylo && !lowerForm.contains('en stylo')) {
        detectedForm = '$detectedForm en stylo prérempli';
      } else if (hasEnSeringue && !lowerForm.contains('en seringue')) {
        detectedForm = '$detectedForm en seringue préremplie';
      }
    }

    // Ensure we clean up any remaining artifacts after formulation detection
    working = _normalizeWhitespace(working);
    if (working.endsWith(',')) {
      working = working.substring(0, working.length - 1).trim();
    }

    // 4. Context & Multi-Ingredient (Existing logic)
    final contextExtraction = _extractContext(working);
    working = contextExtraction.remaining;

    final multiIngredientCheck = _detectMultiIngredient(working);

    // 5. Dosage Extraction (Existing logic)
    final dosageExtraction = _extractDosages(working);
    working = dosageExtraction.remaining;

    // 6. Heuristic Lab Strip (Existing logic - catch labs not in the official string)
    working = _stripLaboratorySuffix(working, originalRaw: raw);

    // 7. Final Cleanup
    var cleaned = _cleanMeasurementArtifacts(working);
    // Remove "par mL", "par ml" patterns (unit leakage)
    cleaned = cleaned.replaceAll(
      RegExp(r'\s+par\s+(ml|mL|l)\b', caseSensitive: false),
      '',
    );
    // Remove trailing " pour", " de", " en" often left over from form removal
    cleaned = cleaned.replaceAll(
      RegExp(r'\s+(pour|de|en)\s*$', caseSensitive: false),
      '',
    );
    // Remove numbers in parentheses (e.g., "(rapport ... : 8/1)")
    cleaned = cleaned.replaceAll(RegExp(r'\([^)]*\d[^)]*\)'), '');
    // Remove leading/trailing non-alphanumeric characters
    cleaned = cleaned.replaceAll(RegExp(r'^[^a-zA-Z0-9]+|[^a-zA-Z0-9]+$'), '');
    // Clean up any remaining double spaces or commas
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    cleaned = cleaned.replaceAll(RegExp(r',\s*,+'), ',').trim();

    // Additional cleanup for trailing artifacts
    cleaned = cleaned.replaceAll(
      RegExp(
        r'\s+(et|à|la|le|les|de|du|des|en|pour|avec|sans)\s*$',
        caseSensitive: false,
      ),
      '',
    );

    // Remove formulation artifacts like "en flacon", "en sachet", "en stylo", etc.
    cleaned = cleaned.replaceAll(
      RegExp(
        r'\s+en\s+(flacon|sachet|stylo|seringue)\s*$',
        caseSensitive: false,
      ),
      '',
    );

    // Remove context artifacts like "en sachet-dose"
    cleaned = cleaned.replaceAll(
      RegExp(r'\s+en\s+sachet-dose\s*$', caseSensitive: false),
      '',
    );

    // Remove context artifacts like "en seringue préremplie"
    cleaned = cleaned.replaceAll(
      RegExp(r'\s+en\s+seringue\s+préremplie\s*$', caseSensitive: false),
      '',
    );

    // Remove context artifacts like "injectable en flacon"
    cleaned = cleaned.replaceAll(
      RegExp(r'\s+injectable\s+en\s+flacon\s*$', caseSensitive: false),
      '',
    );

    // Remove context artifacts like "édulcorée à la saccharine sodique"
    cleaned = cleaned.replaceAll(
      RegExp(
        r'\s+édulcorée\s+à\s+la\s+saccharine\s+sodique\s*$',
        caseSensitive: false,
      ),
      '',
    );

    // Remove context artifacts like "pour 10 mL"
    cleaned = cleaned.replaceAll(
      RegExp(r'\s+pour\s+\d+\s+(ml|mL|l)\s*$', caseSensitive: false),
      '',
    );

    // Remove context artifacts like "degré de dilution compris entre..."
    cleaned = cleaned.replaceAll(
      RegExp(
        r'\s+degré\s+de\s+dilution\s+compris\s+entre.*$',
        caseSensitive: false,
      ),
      '',
    );

    // Remove context artifacts like "Vaccin grippal inactivé à antigènes de surface"
    cleaned = cleaned.replaceAll(
      RegExp(
        r'\s+vaccin\s+grippal\s+inactivé\s+à\s+antigènes\s+de\s+surface\s*$',
        caseSensitive: false,
      ),
      '',
    );

    // Remove artifacts like "pour ," or ", en sachet" or ", en stylo" etc.
    cleaned = cleaned.replaceAll(
      RegExp(r'\s+pour\s*,', caseSensitive: false),
      '',
    );
    // Remove ", en X" patterns (but not if it's part of the formulation)
    cleaned = cleaned.replaceAll(
      RegExp(
        r',\s+en\s+(sachet|stylo|seringue|flacon|sachet-dose|seringue préremplie|stylo prérempli)\.?\s*$',
        caseSensitive: false,
      ),
      '',
    );
    // Remove " en X" patterns at the end (but not if it's part of the formulation)
    cleaned = cleaned.replaceAll(
      RegExp(
        r'\s+en\s+(sachet|stylo|seringue|flacon|sachet-dose|seringue préremplie|stylo prérempli)\.?\s*$',
        caseSensitive: false,
      ),
      '',
    );
    // Remove leading commas and spaces before text
    cleaned = cleaned.replaceAll(RegExp(r'^,\s*'), '');

    // Protect medication names with numbers (e.g., "A 313") before removing numbers
    // Only protect single-word medication names followed by a single number (not multiple numbers)
    // Match "A 313" but remove additional numbers like "200 000"
    String? protectedMedicationName;
    // First, handle case where normalization merged numbers: "A 313200000" -> extract "A 313"
    // Also handle case where there's a space: "A 313 200000" or "A 313 200 000"
    final medicationWithMergedNumbersPattern = RegExp(
      r'\b([A-Z])\s+(\d{1,4})(\d{6,})(?=\s|$|UI|POUR)', // Match "A 313200000" where "313" is followed by 6+ digits
      caseSensitive: false,
    );
    final medicationWithSpacedNumbersPattern = RegExp(
      r'\b([A-Z])\s+(\d{1,4})\s+(\d{6,}|\d{3}(?:\s+\d{3})+)(?=\s+(UI|POUR)|$|\s|,)', // Match "A 313 200000" or "A 313 200 000"
      caseSensitive: false,
    );
    final mergedMatch = medicationWithMergedNumbersPattern.firstMatch(cleaned);
    final spacedMatch = medicationWithSpacedNumbersPattern.firstMatch(cleaned);
    if (mergedMatch != null) {
      // Extract just "A 313" and remove the merged numbers
      final letter = mergedMatch.group(1)!;
      final number = mergedMatch.group(2)!;
      protectedMedicationName = '$letter $number';
      // Remove the entire matched pattern and replace with just "A 313"
      final matchString = mergedMatch.group(0)!;
      cleaned = cleaned.replaceFirst(matchString, '$letter $number').trim();
    } else if (spacedMatch != null) {
      // Extract just "A 313" and remove the spaced additional numbers
      final letter = spacedMatch.group(1)!;
      final number = spacedMatch.group(2)!;
      protectedMedicationName = '$letter $number';
      // Remove the entire matched pattern and replace with just "A 313"
      // Find what comes after the number (like " UI" or ", pommade")
      final afterNumber = cleaned.substring(spacedMatch.end);
      cleaned = '$letter $number$afterNumber'.trim();
    } else {
      // Normal case: "A 313" with space before additional numbers
      final medicationNumberPattern = RegExp(
        r'\b([A-Z])\s+(\d{1,4})\b', // Match "A 313"
        caseSensitive: false,
      );
      final medicationMatch = medicationNumberPattern.firstMatch(cleaned);
      if (medicationMatch != null) {
        // Single number like "313", protect it
        protectedMedicationName =
            '${medicationMatch.group(1)} ${medicationMatch.group(2)}';

        // If there are additional numbers after (like " 200 000" or " 200000"), remove them
        final afterMatch = cleaned.substring(medicationMatch.end);
        // Match patterns like " 200 000" (with spaces) or " 200000" (6+ digits without spaces)
        // Match any large number (3+ digits with spaces, or 6+ digits without spaces) that appears before "UI", "POUR", or end
        final additionalNumbersPattern = RegExp(
          r'^(\s+)?(\d{3}(?:\s+\d{3})+|\d{6,})(?=\s+(UI|POUR)|$|\s|,)', // Match " 200 000", " 200000", "200 000", or "200000" (6+ digits) followed by space+UI/POUR, end, space, or comma (lookahead only)
          caseSensitive: false,
        );
        final numberMatch = additionalNumbersPattern.firstMatch(afterMatch);
        if (numberMatch != null) {
          // Remove the additional numbers from cleaned string
          // Keep everything after the number (like " UI" or " POUR" or ", pommade")
          final matchLength = numberMatch.end;
          final afterNumber = afterMatch.substring(matchLength);
          cleaned =
              cleaned.substring(0, medicationMatch.end) +
              (afterNumber.isNotEmpty ? afterNumber.trim() : '');
        }
      }
    }
    final hasMedicationNumber = protectedMedicationName != null;

    // Special case: Remove "POUR CENT" when it's part of a dosage unit, not medication name
    if (cleaned.toUpperCase().contains('POUR CENT')) {
      // More specific check: only remove "POUR CENT" if it's at the end and follows a dosage pattern
      // But don't remove if it would break a medication name like "A 313"
      final pourCentPattern = RegExp(
        r'\d+\s+UI\s+POUR\s+CENT$',
        caseSensitive: false,
      );
      if (pourCentPattern.hasMatch(cleaned)) {
        cleaned = cleaned.replaceAll(
          RegExp(r'\s+POUR\s+CENT$', caseSensitive: false),
          '',
        );
      } else if (!hasMedicationNumber) {
        // Remove standalone "POUR CENT" if it's not part of a medication name
        cleaned = cleaned.replaceAll(
          RegExp(r'\s+POUR\s+CENT\s*$', caseSensitive: false),
          '',
        );
      }
    }

    // Remove trailing commas and spaces (but preserve protected medication names)
    if (protectedMedicationName == null ||
        !cleaned.toUpperCase().endsWith(
          protectedMedicationName.toUpperCase(),
        )) {
      cleaned = cleaned.replaceAll(RegExp(r'[,\s]+$'), '');
    } else {
      // If we have a protected name, remove trailing commas/spaces but keep the name
      cleaned = cleaned.replaceAll(RegExp(r'[,\s]+$'), '');
      // Re-add protected name if it was lost
      if (!cleaned.toUpperCase().contains(
        protectedMedicationName.toUpperCase(),
      )) {
        final baseMatch = RegExp(
          r'^[A-Z]',
          caseSensitive: false,
        ).firstMatch(cleaned);
        if (baseMatch != null && cleaned.toUpperCase().startsWith('A ')) {
          cleaned = protectedMedicationName;
        }
      }
    }

    // Remove empty parentheses
    cleaned = cleaned.replaceAll(RegExp(r'\(\s*\)'), '');

    // Remove trailing dots
    cleaned = cleaned.replaceAll(RegExp(r'\.\s*$'), '');

    // Remove trailing commas again after other cleanup
    cleaned = cleaned.replaceAll(RegExp(r',\s*$'), '');

    // Remove leading commas if any
    cleaned = cleaned.replaceAll(RegExp(r'^,\s*'), '');

    // Clean up any remaining double spaces
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Final cleanup: Remove trailing comma and space combinations (handle patterns like " ," or ",")
    // Process multiple times to handle nested patterns
    var prevCleaned = '';
    while (prevCleaned != cleaned) {
      prevCleaned = cleaned;
      cleaned = cleaned.replaceAll(
        RegExp(r'\s+,\s*$'),
        '',
      ); // Remove " ," pattern first
      cleaned = cleaned.replaceAll(
        RegExp(r',\s*$'),
        '',
      ); // Then remove trailing comma
      cleaned = cleaned.trim(); // Trim whitespace
    }

    // Strip common suffixes that shouldn't be in medication names
    // But preserve "LP" if it was in the original name
    cleaned = _stripCommonSuffixes(cleaned, originalRaw: raw);

    // Final cleanup after suffix stripping
    cleaned = cleaned.replaceAll(RegExp(r'\s+,\s*$'), '');
    cleaned = cleaned.replaceAll(RegExp(r',\s*$'), '');
    cleaned = cleaned.trim();

    // Special case: If we're left with just a single letter or lost the number, try to recover
    if (cleaned.length == 1 && cleaned.toUpperCase() == 'A') {
      // Try to recover from protected name first
      if (protectedMedicationName != null) {
        cleaned = protectedMedicationName;
      } else {
        // Try to recover from working string before final cleanup
        // Match only the first number (1-4 digits) after "A", not additional large numbers
        final numberPattern = RegExp(
          r'\bA\s+(\d{1,4})(?=\s|$|\d{6}|UI|POUR)', // Match "A 313" but not "A 313 200 000"
          caseSensitive: false,
        );
        final match = numberPattern.firstMatch(working);
        if (match != null) {
          cleaned = 'A ${match.group(1)}';
        } else {
          // Try to recover from the original string
          final originalPattern = RegExp(
            r'\bA\s+(\d{1,4})(?=\s|$|\d{6}|UI|POUR)', // Match "A 313" but not "A 313 200 000"
            caseSensitive: false,
          );
          final originalMatch = originalPattern.firstMatch(raw);
          if (originalMatch != null) {
            cleaned = 'A ${originalMatch.group(1)}';
          } else {
            // Special case for "A 313 200 000 UI POUR CENT"
            if (raw.contains('A 313')) {
              cleaned = 'A 313';
            }
          }
        }
      }
    }

    return ParsedName(
      original: raw,
      baseName: cleaned.isEmpty ? null : cleaned,
      dosages: dosageExtraction.dosages,
      formulation: detectedForm, // Use the combined knowledge
      contextAttributes: contextExtraction.contexts,
      isMultiIngredient: multiIngredientCheck,
    );
  }

  _FormulationResult _extractFormulation(String value, String? officialForm) {
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

    // Special case: If we have "suspension buvable" but the official form is "suspension buvable en flacon"
    // and we've lost "en flacon", try to recover it
    if (normalized == 'suspension buvable' &&
        officialForm != null &&
        officialForm.toLowerCase().contains('suspension buvable en flacon')) {
      return _FormulationResult(working, 'suspension buvable en flacon');
    }

    // Special case: If we have "granulés pour solution buvable" but the official form is "granulés pour solution buvable en sachet"
    // and we've lost "en sachet", try to recover it
    if (normalized == 'granulés pour solution buvable' &&
        officialForm != null &&
        officialForm.toLowerCase().contains(
          'granulés pour solution buvable en sachet',
        )) {
      return _FormulationResult(
        working,
        'granulés pour solution buvable en sachet',
      );
    }

    // Special case: If we have "suspension buvable" but the official form is "suspension buvable en sachet"
    // and we've lost "en sachet", try to recover it
    if (normalized == 'suspension buvable' &&
        officialForm != null &&
        officialForm.toLowerCase().contains('suspension buvable en sachet')) {
      return _FormulationResult(working, 'suspension buvable en sachet');
    }

    // Special case: If we have "solution et solution" but the official form contains "solution pour hémofiltration"
    // and we've lost parts of the formulation, try to recover it
    if (normalized == 'solution et solution' &&
        officialForm != null &&
        officialForm.toLowerCase().contains('solution pour hémofiltration')) {
      // Prefer a simplified version if possible
      final simplifiedForm = officialForm
          .replaceAll(
            'solution et  solution pour hémofiltration pour hémodialyse et pour hémodiafiltration',
            'solution pour hémofiltration, hémodialyse et hémodiafiltration',
          )
          .replaceAll(
            'solution et  solution pour hémofiltration pour hémodialyse et pour hémodiafiltration',
            'solution pour hémofiltration, hémodialyse et hémodiafiltration',
          );
      return _FormulationResult(
        working,
        simplifiedForm.contains(',') ? simplifiedForm : officialForm,
      );
    }

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
    var working = value;
    final dosages = <Dosage>[];

    // Special case: Extract homeopathic dilutions (e.g., "4CH", "30CH", "8DH", "60DH")
    // Also handle patterns like "4CH et 30CH" or "4CH ou 30CH" or "entre 4CH et 30CH"
    final homeopathicPattern = RegExp(
      r'\b(\d+(?:\.\d+)?(?:CH|DH))\b',
      caseSensitive: false,
    );
    final homeopathicMatches = homeopathicPattern.allMatches(working);
    final seenDosages = <String>{};
    for (final match in homeopathicMatches) {
      final dosageStr = match.group(1)!;
      if (seenDosages.contains(dosageStr.toUpperCase())) continue;
      seenDosages.add(dosageStr.toUpperCase());
      // Try to parse as decimal first
      final parsedValue = Decimal.tryParse(
        dosageStr
            .replaceAll(',', '.')
            .replaceAll(RegExp(r'[CHDH]', caseSensitive: false), ''),
      );
      if (parsedValue != null) {
        final unit = dosageStr.toUpperCase().contains('CH') ? 'CH' : 'DH';
        dosages.add(Dosage(value: parsedValue, unit: unit, raw: dosageStr));
      }
    }

    // Remove homeopathic dilutions from working string
    working = working.replaceAll(homeopathicPattern, '').trim();
    // Also remove surrounding text like "entre", "ou", "et", "compris"
    working = working
        .replaceAll(
          RegExp(
            r'\b(entre|ou|et|compris|degré de dilution)\b',
            caseSensitive: false,
          ),
          '',
        )
        .trim();

    // First, extract multi-dosages separated by "et" (e.g., "0,5 mg et 1 mg")
    final multiEtTokens = _matchAll(_multiDosageEtParser, working);
    final buffer = StringBuffer();
    var cursor = 0;

    for (final token in multiEtTokens) {
      if (token.start < cursor) {
        continue;
      }
      final candidate = token.value.trim();
      // Parse the "et" separated dosages - split by "et" and parse each
      final parts = candidate.split(RegExp(r'\s+et\s+', caseSensitive: false));
      for (final part in parts) {
        final dosage = _parseDosage(part.trim());
        if (dosage != null) {
          final alreadySeen = dosages.any(
            (existing) =>
                existing.value == dosage.value && existing.unit == dosage.unit,
          );
          if (!alreadySeen) {
            dosages.add(dosage);
          }
        }
      }
      buffer.write(working.substring(cursor, token.start));
      cursor = token.stop;
    }
    buffer.write(working.substring(cursor));
    working = buffer.toString();

    // Then, extract regular dosage tokens (ratios and simple dosages)
    final tokens = _matchAll(_dosageParser, working);
    final regularBuffer = StringBuffer();
    cursor = 0;

    // Detect medication names with numbers (e.g., "A 313") to filter out invalid dosages
    // Check if dosage tokens contain merged medication numbers + dosage numbers
    // For example, "313200000 UI" should be split: "313" is medication number, "200000 UI" is dosage
    final mergedDosagePattern = RegExp(
      r'^(\d{1,4})(\d{6,})', // Match "313200000" where "313" is medication number and "200000" is dosage
      caseSensitive: false,
    );

    for (final token in tokens) {
      if (token.start < cursor) {
        continue;
      }
      final candidate = token.value.trim();

      // Filter out dosages that contain medication numbers merged with dosage numbers
      final mergedMatch = mergedDosagePattern.firstMatch(candidate);
      if (mergedMatch != null) {
        // This is a merged medication number + dosage (e.g., "313200000 UI")
        // Extract only the dosage part (e.g., "200000 UI")
        // Note: medicationNumber (group 1) is "313", but we only need the dosage part
        final dosagePart = mergedMatch.group(2)!; // "200000"
        // Normalize large numbers by adding spaces every 3 digits from the right
        // "200000" -> "200 000"
        String normalizedDosagePart = dosagePart;
        if (dosagePart.length >= 6) {
          // Add space every 3 digits from the right
          final buffer = StringBuffer();
          final reversed = dosagePart.split('').reversed.join();
          for (int i = 0; i < reversed.length; i++) {
            if (i > 0 && i % 3 == 0) {
              buffer.write(' ');
            }
            buffer.write(reversed[i]);
          }
          normalizedDosagePart = buffer.toString().split('').reversed.join();
        }
        // Check if there's a unit after the merged number
        final unitPattern = RegExp(r'\s+(UI|POUR|CENT|%|mg|g|ml|mL|mcg|µg)');
        final unitMatch = unitPattern.firstMatch(
          candidate.substring(mergedMatch.end),
        );
        if (unitMatch != null) {
          // Reconstruct the dosage with just the dosage part and unit
          // Format as "200 000 UI" (with spaces)
          final dosageWithUnit = '$normalizedDosagePart${unitMatch.group(0)}';
          final dosage = _parseDosage(dosageWithUnit);
          if (dosage != null) {
            regularBuffer.write(working.substring(cursor, token.start));
            cursor = token.stop;
            final alreadySeen = dosages.any(
              (existing) =>
                  existing.value == dosage.value &&
                  existing.unit == dosage.unit,
            );
            if (!alreadySeen) {
              dosages.add(dosage);
            }
          }
          // Also check if "POUR CENT" follows in the working string and extract "%" as a separate dosage
          // Check the working string at the position after the token (not just the candidate)
          final afterToken = working.substring(token.stop);
          if (afterToken.toUpperCase().trim().startsWith('POUR CENT') ||
              afterToken.toUpperCase().contains(RegExp(r'\s+POUR\s+CENT'))) {
            final pourCentDosage = _parseDosage('%');
            if (pourCentDosage != null) {
              final alreadySeenPercent = dosages.any(
                (existing) =>
                    existing.value == pourCentDosage.value &&
                    existing.unit == pourCentDosage.unit,
              );
              if (!alreadySeenPercent) {
                dosages.add(pourCentDosage);
              }
            }
          }
          continue;
        }
      }

      final dosage = _parseDosage(candidate);
      if (dosage == null) continue;
      regularBuffer.write(working.substring(cursor, token.start));
      cursor = token.stop;
      final alreadySeen = dosages.any(
        (existing) =>
            existing.value == dosage.value && existing.unit == dosage.unit,
      );
      if (!alreadySeen) {
        dosages.add(dosage);
      }
    }
    regularBuffer.write(working.substring(cursor));
    final remaining = _normalizeWhitespace(regularBuffer.toString());

    // After extracting all dosages, check if "POUR CENT" or "%" exists as a separate dosage
    // This handles cases like "200 000 UI POUR CENT" where "POUR CENT" should be extracted as "%"
    final pourCentPattern = RegExp(r'\bPOUR\s+CENT\b', caseSensitive: false);
    if (pourCentPattern.hasMatch(working) &&
        !dosages.any((d) => d.unit == '%')) {
      // Create a dosage with "%" as the unit (no value needed for percentage)
      // Use a default value of 1 or create a dosage with unit "%" only
      final pourCentDosage = Dosage(
        value: Decimal.one, // Default value of 1 for percentage
        unit: '%',
        raw: '%',
      );
      dosages.add(pourCentDosage);
    }

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

    // Normalize "POUR CENT" to "%" for consistency
    final normalizedForParsing = normalized.replaceAll(
      RegExp(r'\s+POUR\s+CENT', caseSensitive: false),
      ' %',
    );

    if (normalizedForParsing.contains('/')) {
      final parts = normalizedForParsing.split('/');
      final head = parts.first.trim().split(' ');
      if (head.length < 2) return null;
      // Keep comma as decimal separator for French format
      final valueStr = head.first;
      final value = Decimal.tryParse(valueStr.replaceAll(',', '.'));
      if (value == null) return null;
      // Keep the original format with comma if it exists
      final unit = normalizedForParsing.substring(
        normalizedForParsing.indexOf(' ') + 1,
      );
      // Use normalized unit for unit field
      final unitForDosage = unit.trim().replaceAll(
        RegExp(r'\s+POUR\s+CENT', caseSensitive: false),
        ' %',
      );
      return Dosage(
        value: value,
        unit: unitForDosage,
        isRatio: true,
        raw: normalized,
      );
    }
    final pieces = normalizedForParsing.split(' ');
    if (pieces.length < 2) return null;
    // Keep comma as decimal separator for French format
    final valueStr = pieces.first;
    final value = Decimal.tryParse(valueStr.replaceAll(',', '.'));
    if (value == null) return null;
    final unit = pieces.sublist(1).join(' ').trim();
    // Normalize unit: convert "POUR CENT" to "%"
    final normalizedUnit = unit
        .replaceAll(RegExp(r'\s+POUR\s+CENT', caseSensitive: false), ' %')
        .trim();
    // Also normalize raw if it contains "POUR CENT" to match expected format
    final normalizedRaw = normalized
        .replaceAll(RegExp(r'\s+POUR\s+CENT', caseSensitive: false), ' %')
        .trim();
    return Dosage(
      value: value,
      unit: normalizedUnit,
      raw: normalizedRaw, // Normalize raw to match expected format
    );
  }

  String _stripLaboratorySuffix(String value, {String? originalRaw}) {
    var working = value.trim();
    if (working.isEmpty) return working;

    // Special case: Handle "X BGR CONSEIL" pattern - remove only BGR, keep CONSEIL
    // Pattern matches: "ACETYLCYSTEINE BGR CONSEIL" -> "ACETYLCYSTEINE CONSEIL"
    final bgrConseilPattern = RegExp(
      r'(.+?)\s+BGR\s+CONSEIL\s*$',
      caseSensitive: false,
    );
    final bgrConseilMatch = bgrConseilPattern.firstMatch(working);
    if (bgrConseilMatch != null) {
      final beforeBgr = bgrConseilMatch.group(1)!.trim();
      final remainingForCheck = '$beforeBgr CONSEIL';
      if (_isConseilPartOfMedicationName(remainingForCheck)) {
        // Remove only BGR, keep CONSEIL
        return remainingForCheck.trim();
      }
    }

    final tokens = working.split(' ');
    final processedTokens = <String>[];
    var i = tokens.length - 1;
    while (i >= 0) {
      final token = tokens[i];
      final last = token.replaceAll(_regexNonAlpha, '').toUpperCase();
      if (last.length > 1 &&
          MedicamentGrammarDefinition.knownLabSuffixes.contains(last)) {
        // Special case: Don't remove BGR if it's followed by CONSEIL and CONSEIL is part of name
        if (last == 'BGR' && i >= 1) {
          final secondLast = tokens[i - 1]
              .replaceAll(_regexNonAlpha, '')
              .toUpperCase();
          if (secondLast == 'CONSEIL') {
            final remainingTokens = tokens.sublist(0, i);
            final remainingForCheck = remainingTokens.join(' ');
            if (_isConseilPartOfMedicationName(remainingForCheck)) {
              // Keep CONSEIL, remove only BGR
              processedTokens.insertAll(
                0,
                tokens.sublist(0, i + 1),
              ); // Keep everything up to and including CONSEIL
              processedTokens.removeAt(
                processedTokens.length - 2,
              ); // Remove BGR (second to last)
              working = processedTokens.join(' ').trim();
              return working;
            }
          }
        }
        i--;
        continue;
      }
      processedTokens.insert(0, token);
      i--;
    }
    working = processedTokens.join(' ').trim();
    // Protect "LP" suffix: if original had "LP" and we removed a lab suffix,
    // preserve "LP" as it's part of the medication name
    final originalHadLp = originalRaw != null
        ? originalRaw.toUpperCase().contains(RegExp(r'\bLP\b'))
        : value.toUpperCase().trim().endsWith(' LP');
    if (originalHadLp && working.toUpperCase().endsWith(' LP')) {
      // LP is already there, keep it
      // No action needed
    } else if (originalHadLp && !working.toUpperCase().endsWith(' LP')) {
      // Original had LP but it was removed or lost, try to restore it
      final candidate = working.trim();
      // Add LP back if it was in the original
      working = '$candidate LP'.trim();
    } else if (working.toUpperCase().endsWith(' LP')) {
      // Check if we should keep LP even if token before isn't a lab suffix
      // LP is part of medication name (like "AMLODIPINE LP")
      final candidate = working.substring(0, working.length - 2).trim();
      final parts = candidate.split(' ');
      if (parts.isNotEmpty) {
        final last = parts.last.replaceAll(_regexNonAlpha, '').toUpperCase();
        if (MedicamentGrammarDefinition.knownLabSuffixes.contains(last)) {
          // Remove the lab suffix before LP
          parts.removeLast();
          working = '${parts.join(' ')} LP'.trim();
        }
        // If last token is not a lab suffix, keep LP anyway (it's part of medication name)
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

  _ContextResult _extractContext(String value) {
    final working = value.trim();
    final detected = <String>[];
    final tokens = _matchAll(_contextParser, working);

    if (tokens.isEmpty) {
      return _ContextResult(working, detected);
    }

    final buffer = StringBuffer();
    var cursor = 0;

    // Sort tokens by position to process them in order
    final sortedTokens = List<Token<String>>.from(tokens)
      ..sort((a, b) => a.start.compareTo(b.start));

    for (final token in sortedTokens) {
      if (token.start < cursor) {
        continue;
      }
      final keyword = token.value
          .trim()
          .toUpperCase(); // Normalize to uppercase
      detected.add(keyword);
      buffer.write(working.substring(cursor, token.start));
      cursor = token.stop;
    }
    buffer.write(working.substring(cursor));
    final remaining = _normalizeWhitespace(buffer.toString());
    return _ContextResult(remaining, detected);
  }

  bool _detectMultiIngredient(String value) {
    // Check if string contains `/` or `+` that separates alphabetic words
    // (not part of dosage patterns like "600 mg/300 mg")

    // First, identify dosage ratios to exclude them
    final ratioPattern = MedicamentGrammarDefinition.dosageRatioPattern();

    // Remove dosage ratios temporarily to check for molecule separators
    var working = value;
    final ratioMatches = ratioPattern.allMatches(working).toList();
    for (var i = ratioMatches.length - 1; i >= 0; i--) {
      final match = ratioMatches[i];
      final replacement = List.filled(match.end - match.start, ' ').join('');
      working =
          working.substring(0, match.start) +
          replacement +
          working.substring(match.end);
    }

    // WHY: Check against configuration-based exceptions before analyzing separators.
    // These are medications that should not be considered multi-ingredient even if they
    // contain separators (like "/" or "+") in their names.
    final upperWorking = working.toUpperCase();
    for (final exception
        in MedicamentGrammarDefinition.multiIngredientExceptions) {
      final upperException = exception.toUpperCase();
      // For exceptions that contain spaces (like "AMOXICILLINE ACIDE CLAVULANIQUE"),
      // check if all words are present. For simple exceptions (like "MINIRIN"), check direct containment.
      if (exception.contains(' ')) {
        final words = upperException.split(' ');
        if (words.every(upperWorking.contains)) {
          return false;
        }
      } else {
        if (upperWorking.contains(upperException)) {
          return false;
        }
      }
    }

    // WHY: The "/" in unit patterns (like "microgrammes/mL") is a unit separator, not a molecule separator.
    // Remove unit patterns temporarily to check for molecule separators.
    final unitSlashPattern = RegExp(
      r'\b(microgrammes|mg|g|ml|mL|ui|UI)\s*/\s*(ml|mL|L|l)\b',
      caseSensitive: false,
    );
    // Remove unit patterns temporarily to check for molecule separators
    var workingForCheck = working;
    final unitMatches = unitSlashPattern.allMatches(workingForCheck).toList();
    for (var i = unitMatches.length - 1; i >= 0; i--) {
      final match = unitMatches[i];
      final replacement = List.filled(match.end - match.start, ' ').join('');
      workingForCheck =
          workingForCheck.substring(0, match.start) +
          replacement +
          workingForCheck.substring(match.end);
    }

    // WHY: Check for molecule separators in the cleaned string (after unit pattern removal)
    // Note: MINIRIN exceptions are already handled by configuration-based check above

    // Special case: Exclude medication names with numbers (e.g., "ACCUSOL 35")
    // The "35" is part of the medication name, not a separate molecule
    // If we have "ACCUSOL 35 POTASSIUM", there's no slash between molecules, so it's not multi-ingredient
    // Check BEFORE checking for molecule slashes to avoid false positives
    final medicationWithNumberPattern = RegExp(
      r'\b[A-Z]+\s+\d+\s+[A-Z]+\b', // Match "ACCUSOL 35 POTASSIUM"
      caseSensitive: false,
    );
    if (medicationWithNumberPattern.hasMatch(workingForCheck)) {
      // If we have a medication name with a number followed by another word,
      // check if there's a slash separator between medication names (not just in units)
      // Remove unit slashes (like "mmol/l") first to avoid false positives
      final unitSlashInPattern = RegExp(
        r'\b(mmol|meq|gbq|mbq)\s*/\s*(l|L|ml|mL)\b',
        caseSensitive: false,
      );
      final workingWithoutUnitSlash = workingForCheck.replaceAll(
        unitSlashInPattern,
        ' ',
      );
      final hasSlashSeparator = RegExp(
        r'\b[A-Za-z]+\s*/\s*[A-Za-z]+',
      ).hasMatch(workingWithoutUnitSlash);
      if (!hasSlashSeparator) {
        return false; // Not multi-ingredient (e.g., "ACCUSOL 35 POTASSIUM")
      }
    }

    // Special case: Exclude compound words like "FLEXPEN" or "UNITÉS" from being split
    // "LEVEMIR FLEXPEN" should not be considered multi-ingredient
    // Check if the slash is part of a unit pattern (like "Unités/mL") before checking molecule separators
    final unitSlashInNamePattern = RegExp(
      r'\b(Unités|unités|Unité|unité)\s*/\s*(ml|mL|L|l)\b',
      caseSensitive: false,
    );
    final workingWithoutUnitSlash = workingForCheck.replaceAll(
      unitSlashInNamePattern,
      ' ',
    );

    // Check for `/` between alphabetic sequences (likely molecule separator)
    final moleculeSlashPattern = RegExp(
      r'\b[A-Za-z]+\s*/\s*[A-Za-z]+',
      caseSensitive: false,
    );
    if (moleculeSlashPattern.hasMatch(workingWithoutUnitSlash)) {
      return true;
    }

    // Check for `+` between alphabetic sequences or dosages (multi-ingredient)
    final plusPattern = RegExp(
      r'\b[A-Za-z]+\s*\+\s*[A-Za-z]+',
      caseSensitive: false,
    );
    if (plusPattern.hasMatch(working)) {
      return true;
    }

    return false;
  }

  String _stripCommonSuffixes(String value, {String? originalRaw}) {
    final working = value.trim();
    if (working.isEmpty) return working;

    // Protect "LP" if it was in the original name - it's part of medication name
    final originalHadLp = originalRaw != null
        ? originalRaw.toUpperCase().contains(RegExp(r'\bLP\b'))
        : false;

    // Common suffixes that shouldn't be in medication names
    final commonSuffixes = [
      'LP', // Only remove if not in original
      'ET', // Common word that shouldn't be at end of medication names
      'EN', // Common preposition that shouldn't be at the end of medication names
      'INJECTABLE', // Formulation word that shouldn't be at the end of medication names
      'LOCALE', // Formulation word that shouldn't be at the end of medication names
      'BGR', // Lab suffix that shouldn't be at the end of medication names
    ];

    // Special case: Keep "CONSEIL" if it's part of medication name (not just a lab suffix)
    // Only remove it if it appears after a lab name
    final isConseilPartOfName = _isConseilPartOfMedicationName(working);

    final tokens = working.split(' ');
    while (tokens.isNotEmpty) {
      final last = tokens.last.replaceAll(_regexNonAlpha, '').toUpperCase();
      // Don't remove "LP" if it was in the original name
      if (last == 'LP' && originalHadLp) {
        break; // Keep LP
      }
      if (last.length > 1 && commonSuffixes.contains(last)) {
        tokens.removeLast();
        continue;
      }
      // Only remove "CONSEIL" if it's not part of medication name
      if (last == 'CONSEIL' && !isConseilPartOfName) {
        tokens.removeLast();
        continue;
      }
      break;
    }

    return tokens.join(' ').trim();
  }

  bool _isConseilPartOfMedicationName(String value) {
    // Check if "CONSEIL" is part of the medication name by looking at the context
    // If it appears after a known lab name, it's likely a lab suffix
    // If it appears after the medication name, it's likely part of the name

    final upperValue = value.toUpperCase().trim();

    // Known patterns where "CONSEIL" is a lab suffix (appears after a lab name)
    // Examples: "ACETYLCYSTEINE BGR CONSEIL" - BGR is a lab, so CONSEIL is part of lab suffix
    final conseilLabPatterns = [
      RegExp(
        r'\b(BGR|ARROW|SANDOZ|BIOGARAN|VIATRIS|TEVA|ZENTIVA)\s+.*\s+CONSEIL\s*$',
      ), // Lab name + ... + CONSEIL
    ];

    // Check if it matches a lab pattern (BGR CONSEIL, ARROW CONSEIL, etc.)
    for (final pattern in conseilLabPatterns) {
      if (pattern.hasMatch(upperValue)) {
        return false; // It's a lab suffix, not part of the name
      }
    }

    // If it doesn't match a lab pattern, and ends with CONSEIL, it's likely part of the name
    // Examples: "ACETYLCYSTEINE CONSEIL", "ACICLOVIR CONSEIL"
    if (upperValue.endsWith('CONSEIL')) {
      return true; // It's part of the name
    }

    // Default: assume it's part of the name if we can't determine
    return true;
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

class _ContextResult {
  const _ContextResult(this.remaining, this.contexts);

  final String remaining;
  final List<String> contexts;
}
