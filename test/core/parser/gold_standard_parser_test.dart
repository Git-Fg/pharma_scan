import 'dart:convert';
import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/parser/medicament_grammar.dart';

void main() {
  final parser = MedicamentParser();

  group('Gold Standard Validation', () {
    late List<dynamic> testCases;

    setUpAll(() async {
      final file = File('test/fixtures/parsing_gold_standard.json');
      if (!await file.exists()) {
        fail('Gold standard file missing: ${file.path}');
      }
      final jsonString = await file.readAsString();
      testCases = jsonDecode(jsonString);
    });

    test('validates all entries against gold standard', () {
      final failures = <String>[];

      for (final testCase in testCases) {
        final rawName = testCase['raw_name'] as String;
        final officialForm = testCase['official_form'] as String?;
        final officialLab = testCase['official_lab'] as String?;
        final expected = testCase['expected'] as Map<String, dynamic>;

        try {
          final result = parser.parse(
            rawName,
            officialForm: officialForm,
            officialLab: officialLab,
          );

          // 1. Verify Base Name
          final expectedName = expected['base_name'] as String?;
          if (_normalize(result.baseName) != _normalize(expectedName)) {
            failures.add(
              '[$rawName] Name mismatch.\n   Expected: "$expectedName"\n   Actual:   "${result.baseName}"',
            );
            continue;
          }

          // 2. Verify Formulation
          final expectedForm = expected['formulation'] as String?;
          // Allow loose matching for formulation (contains) or exact match
          // We normalize both to lowercase and trim
          final actualForm = result.formulation?.toLowerCase().trim();
          final targetForm = expectedForm?.toLowerCase().trim();

          if (actualForm != targetForm) {
            // If strict match fails, check if one contains the other as a fallback validation
            // (e.g. "comprimé" vs "comprimé pelliculé")
            // But for Gold Standard, we prefer exact matches if possible.
            failures.add(
              '[$rawName] Formulation mismatch.\n   Expected: "$targetForm"\n   Actual:   "$actualForm"',
            );
            continue;
          }

          // 3. Verify Multi-Ingredient Flag
          final expectedMulti = expected['is_multi_ingredient'] as bool;
          if (result.isMultiIngredient != expectedMulti) {
            failures.add(
              '[$rawName] Multi-ingredient mismatch.\n   Expected: $expectedMulti\n   Actual:   ${result.isMultiIngredient}',
            );
            continue;
          }

          // 4. Verify Dosages
          final expectedDosages = (expected['dosages'] as List).cast<String>();
          final actualDosages = result.dosages.map((d) {
            if (d.isRatio && d.raw != null) {
              // Normalize spaces in ratio: "600 mg / 300 mg" -> "600 mg/300 mg"
              return d.raw!.replaceAll(' /', '/').replaceAll('/ ', '/').trim();
            }
            // Use the raw value if available to preserve comma format
            if (d.raw != null) {
              return d.raw!;
            }
            return '${_formatDecimal(d.value)} ${d.unit}';
          }).toList();

          // Sort both lists to ensure order doesn't cause failure
          expectedDosages.sort();
          actualDosages.sort();

          // Compare sets to ignore duplicates if the logic cleans them differently
          final expectedSet = expectedDosages.toSet();
          final actualSet = actualDosages.toSet();

          if (expectedSet.length != actualSet.length ||
              !expectedSet.containsAll(actualSet)) {
            failures.add(
              '[$rawName] Dosages mismatch.\n   Expected: $expectedDosages\n   Actual:   $actualDosages',
            );
            continue;
          }

          // 5. Verify Context
          final expectedContext = (expected['context'] as List).cast<String>();
          final actualContext = result.contextAttributes;

          // Compare sets
          final expCtxSet = expectedContext.toSet();
          final actCtxSet = actualContext.toSet();

          if (expCtxSet.length != actCtxSet.length ||
              !expCtxSet.containsAll(actCtxSet)) {
            failures.add(
              '[$rawName] Context mismatch.\n   Expected: $expectedContext\n   Actual:   $actualContext',
            );
            continue;
          }
        } catch (e, s) {
          failures.add('[$rawName] EXCEPTION: $e\n$s');
        }
      }

      if (failures.isNotEmpty) {
        fail(
          'Gold Standard Validation Failed on ${failures.length} cases:\n\n${failures.join('\n\n----------------\n\n')}',
        );
      }
    });
  });
}

String? _normalize(String? s) => s?.trim().toUpperCase();

String _formatDecimal(Decimal d) {
  // Remove trailing zeros (e.g. 200.0 -> 200)
  String s = d.toString();
  if (s.contains('.')) {
    s = s.replaceAll(RegExp(r'0*$'), '');
    if (s.endsWith('.')) s = s.substring(0, s.length - 1);
  }
  return s;
}
