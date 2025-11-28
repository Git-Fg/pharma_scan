// lib/core/logic/sanitizer.dart

import 'dart:convert';

import 'package:diacritic/diacritic.dart';
import 'package:pharma_scan/core/constants/dosage_constants.dart';
import 'package:pharma_scan/core/constants/parsing_constants.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/utils/strings.dart';

String findCommonPrincepsName(List<String> names) {
  if (names.isEmpty) return 'N/A';

  if (names.length == 1) return names.first;

  final List<String> prefixWords = names.first.split(' ');

  for (int i = 1; i < names.length; i++) {
    final currentWords = names[i].split(' ');
    int commonLength = 0;
    while (commonLength < prefixWords.length &&
        commonLength < currentWords.length &&
        prefixWords[commonLength] == currentWords[commonLength]) {
      commonLength++;
    }

    if (commonLength < prefixWords.length) {
      prefixWords.removeRange(commonLength, prefixWords.length);
    }
  }

  if (prefixWords.isEmpty) {
    return names.reduce((a, b) => a.length < b.length ? a : b);
  }

  return prefixWords.join(' ').trim().replaceAll(RegExp(r'[,.]\s*$'), '');
}

List<String> decodePrincipesFromJson(String? jsonString) {
  if (jsonString == null || jsonString.isEmpty) return const <String>[];
  try {
    final decoded = jsonDecode(jsonString);
    if (decoded is List) {
      return decoded
          .map((value) => (value?.toString() ?? '').trim())
          .where((value) => value.isNotEmpty)
          .cast<String>()
          .toList();
    }
    return const <String>[];
  } catch (_) {
    return const <String>[];
  }
}

String formatCommonPrincipesFromList(List<String>? principles) {
  if (principles == null || principles.isEmpty) return '';
  final sanitized = principles
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList();
  if (sanitized.isEmpty) return '';
  return sanitized.join(', ');
}

String formatCommonPrincipes(String? rawJson) {
  final principles = decodePrincipesFromJson(rawJson);
  return formatCommonPrincipesFromList(principles);
}

String extractPrincepsLabel(String rawLabel) {
  final trimmed = rawLabel.trim();
  if (trimmed.isEmpty) return trimmed;

  if (trimmed.contains(' - ')) {
    final parts = trimmed.split(' - ');
    return parts.last.trim();
  }

  return trimmed;
}

String deriveGroupTitleFromName(String name) {
  if (name.contains(' + ')) {
    final segments = name.split(' + ');

    final cleanedSegments = segments
        .map((segment) {
          return _deriveSingleMoleculeName(segment.trim());
        })
        .where((cleaned) => cleaned.isNotEmpty)
        .toList();

    return cleanedSegments.join(' + ');
  }

  return _deriveSingleMoleculeName(name);
}

String _deriveSingleMoleculeName(String name) {
  final parts = name.split(' ');
  final stopIndex = parts.indexWhere(
    (part) => double.tryParse(part.replaceAll(',', '.')) != null,
  );

  if (stopIndex != -1) {
    return parts
        .sublist(0, stopIndex)
        .join(' ')
        .replaceAll(RegExp(r'\s*,$'), '');
  }

  return name.split(',').first.trim();
}

String getDisplayTitle(MedicamentSummaryData summary) {
  if (summary.isPrinceps) {
    return extractPrincepsLabel(summary.princepsDeReference);
  }

  if (!summary.isPrinceps && summary.groupId != null) {
    final parts = summary.nomCanonique.split(' - ');
    return parts.first.trim();
  }

  return summary.nomCanonique;
}

String sanitizeActivePrinciple(String principle) {
  if (principle.isEmpty) return principle;

  var sanitized = principle;

  sanitized = sanitized.replaceAll(ParsingConstants.parentheses, '');

  final equivalentMatch = ParsingConstants.equivalentTo.firstMatch(sanitized);
  if (equivalentMatch != null) {
    sanitized = sanitized.substring(0, equivalentMatch.start).trim();
  }

  final knownNumberedMolecules = DosageConstants.knownNumberedMolecules;

  for (final knownNumber in knownNumberedMolecules) {
    final numberUpper = knownNumber.toUpperCase();
    sanitized = sanitized.replaceAll(
      RegExp(
        r'\b' + RegExp.escape(knownNumber) + r'\s+(ui|UI)/?(ml|ML)\b',
        caseSensitive: false,
      ),
      knownNumber,
    );
    sanitized = sanitized.replaceAll(
      RegExp(
        r'\b' + RegExp.escape(numberUpper) + r'\s+(ui|UI)/?(ml|ML)\b',
        caseSensitive: false,
      ),
      knownNumber,
    );
  }

  for (final pattern in ParsingConstants.dosageUnits) {
    sanitized = sanitized.replaceAll(pattern, '');
  }

  sanitized = sanitized.replaceAll(ParsingConstants.unitSlash, '');
  sanitized = sanitized.replaceAll(ParsingConstants.trailingSlash, '');

  sanitized = sanitized.trim().replaceAll(ParsingConstants.whitespace, ' ');

  sanitized = sanitized.replaceAllMapped(ParsingConstants.standaloneNumber, (
    match,
  ) {
    final number = match.group(1) ?? '';

    final matchStart = match.start;
    final matchEnd = match.end;
    final snippetStart = matchStart > 2 ? matchStart - 2 : 0;
    final snippetEnd = matchEnd + 2 < sanitized.length
        ? matchEnd + 2
        : sanitized.length;
    final snippetUpper = sanitized
        .substring(snippetStart, snippetEnd)
        .toUpperCase();

    final isKnownMolecule = knownNumberedMolecules.any(
      (known) => snippetUpper.contains(known.toUpperCase()),
    );

    if (isKnownMolecule) {
      return number;
    }

    if (matchStart > 0 && sanitized[matchStart - 1] == '-') {
      return number;
    }

    if (matchEnd < sanitized.length) {
      final afterNumber = sanitized.substring(matchEnd);
      if (ParsingConstants.spaceLetter.hasMatch(afterNumber)) {
        return '';
      }
    }

    return '';
  });

  sanitized = sanitized.trim().replaceAll(ParsingConstants.whitespace, ' ');

  for (final keyword in ParsingConstants.formulationKeywords) {
    final keywordPattern = RegExp(
      '(^|\\s)${RegExp.escape(keyword)}(\\s|\$)',
      caseSensitive: false,
    );

    sanitized = sanitized.replaceAllMapped(keywordPattern, (match) {
      if (keyword == 'solution') {
        final matchEnd = match.end;
        if (matchEnd < sanitized.length) {
          final afterMatch = sanitized.substring(matchEnd);
          if (ParsingConstants.deFollows.hasMatch(afterMatch)) {
            return match.group(0) ?? '';
          }
        }
      }
      final prefix = match.group(1) ?? '';
      return prefix == ' ' ? ' ' : '';
    });
  }

  return sanitized.trim().replaceAll(ParsingConstants.whitespace, ' ');
}

String parseMainTitulaire(String? rawTitulaire) {
  if (rawTitulaire == null || rawTitulaire.isEmpty) {
    return Strings.unknownLab;
  }

  final parts = rawTitulaire.split(RegExp(r'[;/]'));

  for (final part in parts) {
    final trimmed = part.trim();
    if (trimmed.isNotEmpty) {
      final cleaned = trimmed
          .replaceAll(
            RegExp(r'\s+(SAS|SA|SARL|GMBH|LTD|INC)$', caseSensitive: false),
            '',
          )
          .trim();

      if (cleaned.isNotEmpty) {
        return cleaned;
      }
    }
  }

  return Strings.unknownLab;
}

String cleanStandaloneName({
  required String rawName,
  String? officialForm,
  String? officialLab,
}) {
  if (rawName.isEmpty) return rawName;

  var cleaned = rawName;

  if (officialForm != null && officialForm.trim().isNotEmpty) {
    cleaned = _removeOfficialForm(cleaned, officialForm);
  }

  if (officialLab != null && officialLab.trim().isNotEmpty) {
    final mainLab = parseMainTitulaire(officialLab);
    if (mainLab.isNotEmpty && mainLab != Strings.unknownLab) {
      cleaned = _removeNormalizedSubstring(cleaned, mainLab) ?? cleaned;
    }
  }

  cleaned = _finalizeStandaloneName(cleaned);

  if (cleaned.isEmpty || cleaned.length < 3) {
    return rawName;
  }

  return cleaned;
}

String _finalizeStandaloneName(String input) {
  var value = input
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'\s+,'), ',')
      .replaceAll(RegExp(r',\s+'), ', ')
      .replaceAll(RegExp(r'(,\s*){2,}'), ',')
      .trim();

  value = value.replaceAll(RegExp(r'^,+'), '').replaceAll(RegExp(r',+$'), '');

  value = value.replaceAll(RegExp(r'\s+,', caseSensitive: false), ', ');
  value = _stripTrailingPrepositions(value).trim();

  return value;
}

String _stripTrailingPrepositions(String input) {
  var value = input.trim();
  final trailingPattern = RegExp(
    r"(?:,?\s*)(?:pour|de|du|des|d'|\u00E0|au|aux)$",
    caseSensitive: false,
  );

  while (trailingPattern.hasMatch(value)) {
    value = value.replaceFirst(trailingPattern, '').trim();
  }

  return value;
}

String _removeOfficialForm(String source, String officialForm) {
  final variants = _buildFormVariants(officialForm);
  if (variants.isEmpty) return source;

  var updated = source;
  for (final variant in variants) {
    while (true) {
      final next = _removeNormalizedSubstring(updated, variant);
      if (next == null) break;
      updated = next;
    }
    if (updated != source) {
      break;
    }
  }

  return updated;
}

List<String> _buildFormVariants(String officialForm) {
  final normalized = _normalizeNeedle(officialForm);
  if (normalized.isEmpty) return const [];

  final parts = normalized.split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  final variants = <String>{normalized};
  final partsList = parts.toList();

  if (partsList.length > 1) {
    for (int len = partsList.length - 1; len >= 1; len--) {
      final candidate = partsList.take(len).join(' ');
      if (candidate.length > 2) {
        variants.add(candidate);
      }
    }
  }

  if (partsList.isNotEmpty) {
    variants.add(partsList.first);
  }

  final ordered = variants.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  return ordered;
}

String _normalizeNeedle(String value) {
  return removeDiacritics(value).toLowerCase().trim();
}

String? _removeNormalizedSubstring(String source, String rawNeedle) {
  final normalizedNeedle = _normalizeNeedle(rawNeedle);
  if (normalizedNeedle.isEmpty) return null;

  final normalizedSource = removeDiacritics(source).toLowerCase();
  final start = normalizedSource.indexOf(normalizedNeedle);
  if (start == -1) return null;

  final end = start + normalizedNeedle.length;
  final startOriginal = _mapNormalizedBoundaryToOriginalIndex(source, start);
  final endOriginal = _mapNormalizedBoundaryToOriginalIndex(source, end);

  if (startOriginal == null ||
      endOriginal == null ||
      startOriginal >= endOriginal) {
    return null;
  }

  final result = source.replaceRange(startOriginal, endOriginal, '');
  return result;
}

int? _mapNormalizedBoundaryToOriginalIndex(String source, int boundary) {
  if (boundary <= 0) {
    return 0;
  }

  int normalizedPos = 0;
  for (int i = 0; i < source.length; i++) {
    final normalizedChar = removeDiacritics(source[i]).toLowerCase();
    if (normalizedChar.isEmpty) continue;
    final length = normalizedChar.length;
    final nextPos = normalizedPos + length;

    if (boundary == normalizedPos) {
      return i;
    }
    if (boundary > normalizedPos && boundary < nextPos) {
      return i;
    }
    if (boundary == nextPos) {
      return i + 1;
    }

    normalizedPos = nextPos;
  }

  if (boundary == normalizedPos) {
    return source.length;
  }

  return null;
}
