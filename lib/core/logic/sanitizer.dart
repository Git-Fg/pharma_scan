// lib/core/logic/sanitizer.dart

import 'dart:convert';

import 'package:pharma_scan/core/constants/dosage_constants.dart';
import 'package:pharma_scan/core/constants/parsing_constants.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/utils/strings.dart';

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

  const knownNumberedMolecules = DosageConstants.knownNumberedMolecules;

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

  final parts = rawTitulaire.split(RegExp('[;/]'));

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
