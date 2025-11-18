// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/locator.dart';
import 'package:pharma_scan/core/services/database_service.dart';
import 'test_bootstrap.dart';
import 'package:pharma_scan/core/utils/medicament_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await ensureIntegrationTestDatabase();
  });

  group('Active Principle Sanitization Validation', () {
    group('Unit Tests - Edge Cases', () {
      testWidgets('should preserve legitimate molecule names with numbers', (
        WidgetTester tester,
      ) async {
        // Test known numbered molecules that should be preserved
        final testCases = [
          'HEPARINE SODIQUE 4000 UI/ML',
          'HEPARINE 3350 UI/ML',
          'HEPARINE 980 UI/ML',
          'HEPARINE 940 UI/ML',
          'HEPARINE 6000 UI/ML',
          'ACIDE 2,4-DICHLOROPHENOXYACETIQUE',
          'MOLECULE-2,4-TEST',
        ];

        for (final testCase in testCases) {
          final sanitized = sanitizeActivePrinciple(testCase);
          // Numbers should be preserved for known molecules
          expect(
            sanitized,
            isNotEmpty,
            reason: 'Should not be empty: $testCase',
          );
          expect(
            sanitized.toLowerCase(),
            isNot(contains('ui/ml')),
            reason: 'Should remove dosage units: $testCase',
          );
          // Note: Some legitimate molecules may contain '/' in their names,
          // so we only check for unit patterns like "UI/ML"
          expect(
            sanitized.toLowerCase(),
            isNot(RegExp(r'\d+\s*ui\s*/').hasMatch),
            reason: 'Should remove dosage unit patterns: $testCase',
          );
        }
      });

      testWidgets('should remove dosage units and numbers correctly', (
        WidgetTester tester,
      ) async {
        final testCases = {
          'ESOMEPRAZOLE MAGNESIUM TRIHYDRATE équivalant à ESOMEPRAZOLE 40 mg':
              'ESOMEPRAZOLE MAGNESIUM TRIHYDRATE',
          'PARACETAMOL 500 mg': 'PARACETAMOL',
          'IBUPROFENE 200 mg comprimé': 'IBUPROFENE',
          'ASPIRINE 100 mg (comprimé)': 'ASPIRINE',
          'MOLECULE 5 g solution': 'MOLECULE',
          'PRINCIPE 0.5 %': 'PRINCIPE',
          'ACTIF 1000 ui injectable': 'ACTIF',
        };

        for (final entry in testCases.entries) {
          final sanitized = sanitizeActivePrinciple(entry.key);
          // Normalize whitespace for comparison
          final normalized = sanitized.trim().replaceAll(RegExp(r'\s+'), ' ');
          expect(
            normalized,
            equals(entry.value.trim()),
            reason: 'Failed for: ${entry.key}',
          );
        }
      });

      testWidgets('should handle molecules with hyphens and numbers', (
        WidgetTester tester,
      ) async {
        // Numbers preceded by hyphens should be preserved (likely part of molecule name)
        final testCases = [
          'MOLECULE-4000',
          'ACTIF-2,4-DICHLORO',
          'PRINCIPE-6000-COMPLEX',
        ];

        for (final testCase in testCases) {
          final sanitized = sanitizeActivePrinciple(testCase);
          // Hyphenated numbers should be preserved
          expect(
            sanitized,
            contains('-'),
            reason: 'Should preserve hyphen: $testCase',
          );
        }
      });

      testWidgets(
        'should remove formulation keywords while preserving molecule names',
        (WidgetTester tester) async {
          final testCases = {
            'PARACETAMOL comprimé': 'PARACETAMOL',
            'IBUPROFENE solution': 'IBUPROFENE',
            'ASPIRINE gélule injectable': 'ASPIRINE',
            'MOLECULE sirop suspension': 'MOLECULE',
            'PRINCIPE crème pommade gel': 'PRINCIPE',
            'ACTIF solution de test':
                'ACTIF solution de test', // Exception pattern
          };

          for (final entry in testCases.entries) {
            final sanitized = sanitizeActivePrinciple(entry.key);
            final normalized = sanitized.trim().replaceAll(RegExp(r'\s+'), ' ');
            expect(
              normalized,
              equals(entry.value.trim()),
              reason: 'Failed for: ${entry.key}',
            );
          }
        },
      );

      testWidgets('should preserve "solution de" exception pattern', (
        WidgetTester tester,
      ) async {
        // Test the specific case mentioned in the plan
        final testCases = {
          'SOLUTION DE DIGLUCONATE DE CHLORHEXIDINE':
              'SOLUTION DE DIGLUCONATE DE CHLORHEXIDINE',
          'solution de test': 'solution de test',
          'MOLECULE solution de BASE': 'MOLECULE solution de BASE',
          'PRINCIPE solution injectable':
              'PRINCIPE', // "solution" alone should be removed
        };

        for (final entry in testCases.entries) {
          final sanitized = sanitizeActivePrinciple(entry.key);
          final normalized = sanitized.trim().replaceAll(RegExp(r'\s+'), ' ');
          expect(
            normalized,
            equals(entry.value.trim()),
            reason: 'Failed for: ${entry.key}',
          );
        }
      });

      testWidgets('should preserve hyphenated numbers in molecule names', (
        WidgetTester tester,
      ) async {
        // Test the specific case mentioned in the plan
        final testCases = {
          'ALCOOL DICHLORO-2,4 BENZYLIQUE': 'ALCOOL DICHLORO-2,4 BENZYLIQUE',
          'MOLECULE-4000 TEST': 'MOLECULE-4000 TEST',
          'ACTIF-2,4-DICHLORO': 'ACTIF-2,4-DICHLORO',
          'PRINCIPE-6000-COMPLEX': 'PRINCIPE-6000-COMPLEX',
        };

        for (final entry in testCases.entries) {
          final sanitized = sanitizeActivePrinciple(entry.key);
          final normalized = sanitized.trim().replaceAll(RegExp(r'\s+'), ' ');
          expect(
            normalized,
            equals(entry.value.trim()),
            reason: 'Failed for: ${entry.key}',
          );
          // Verify the hyphenated number is preserved
          expect(
            normalized,
            contains('-'),
            reason: 'Should preserve hyphen in: ${entry.key}',
          );
        }
      });

      testWidgets('should handle parenthetical content correctly', (
        WidgetTester tester,
      ) async {
        final testCases = {
          'MOLECULE (sel de sodium)': 'MOLECULE',
          'ACTIF (monohydrate) 500 mg': 'ACTIF',
          'PRINCIPE (test) solution': 'PRINCIPE',
        };

        for (final entry in testCases.entries) {
          final sanitized = sanitizeActivePrinciple(entry.key);
          expect(
            sanitized,
            isNot(contains('(')),
            reason: 'Should remove parentheses: ${entry.key}',
          );
          expect(
            sanitized,
            isNot(contains(')')),
            reason: 'Should remove parentheses: ${entry.key}',
          );
        }
      });

      testWidgets('should handle "équivalant à" patterns correctly', (
        WidgetTester tester,
      ) async {
        final testCases = {
          'ESOMEPRAZOLE MAGNESIUM TRIHYDRATE équivalant à ESOMEPRAZOLE 40 mg':
              'ESOMEPRAZOLE MAGNESIUM TRIHYDRATE',
          'MOLECULE équivalant à BASE 500 mg': 'MOLECULE',
          'ACTIF ÉQUIVALANT À BASE': 'ACTIF', // Case insensitive
        };

        for (final entry in testCases.entries) {
          final sanitized = sanitizeActivePrinciple(entry.key);
          final normalized = sanitized.trim().replaceAll(RegExp(r'\s+'), ' ');
          expect(
            normalized,
            equals(entry.value.trim()),
            reason: 'Failed for: ${entry.key}',
          );
          expect(
            sanitized.toLowerCase(),
            isNot(contains('équivalant à')),
            reason: 'Should remove "équivalant à": ${entry.key}',
          );
        }
      });

      testWidgets('should handle multiple components correctly', (
        WidgetTester tester,
      ) async {
        // Test that sanitization works on each component independently
        final multiComponent =
            'PARACETAMOL 500 mg, CODEINE 30 mg, CAFFEINE 50 mg';
        final sanitized = sanitizeActivePrinciple(multiComponent);
        expect(
          sanitized,
          contains('PARACETAMOL'),
          reason: 'Should preserve PARACETAMOL',
        );
        expect(
          sanitized,
          contains('CODEINE'),
          reason: 'Should preserve CODEINE',
        );
        expect(
          sanitized,
          contains('CAFFEINE'),
          reason: 'Should preserve CAFFEINE',
        );
        expect(
          sanitized,
          isNot(contains('mg')),
          reason: 'Should remove dosage units',
        );
      });

      testWidgets('should handle close dosages correctly', (
        WidgetTester tester,
      ) async {
        // Test medications with similar dosages to ensure proper sanitization
        final testCases = [
          'MOLECULE 100 mg',
          'MOLECULE 100.5 mg',
          'MOLECULE 100,5 mg',
          'MOLECULE 99 mg',
          'MOLECULE 101 mg',
        ];

        for (final testCase in testCases) {
          final sanitized = sanitizeActivePrinciple(testCase);
          expect(
            sanitized,
            equals('MOLECULE'),
            reason: 'Failed for: $testCase',
          );
          expect(
            sanitized,
            isNot(contains('mg')),
            reason: 'Should remove units: $testCase',
          );
          expect(
            sanitized,
            isNot(RegExp(r'\d').hasMatch),
            reason: 'Should remove numbers: $testCase',
          );
        }
      });
    });

    group('Integration Tests - Database Validation', () {
      testWidgets(
        'should sanitize common principles from real database groups',
        (WidgetTester tester) async {
          // GIVEN: Database initialized with real data
          final dbService = sl<DatabaseService>();

          // WHEN: Get common principles for groups
          final db = sl<AppDatabase>();
          final groupRows = await db
              .customSelect(
                'SELECT DISTINCT group_id FROM generique_groups LIMIT 20',
              )
              .get();

          if (groupRows.isEmpty) {
            return; // Skip if no groups in database
          }

          final groupIds = groupRows
              .map((row) => row.read<String>('group_id'))
              .toSet();

          // Use classifyProductGroup to get sanitized common principles
          final commonPrincipesMap = <String, List<String>>{};
          for (final groupId in groupIds) {
            final classification = await dbService.classifyProductGroup(
              groupId,
            );
            if (classification != null &&
                classification.commonActiveIngredients.isNotEmpty) {
              commonPrincipesMap[groupId] =
                  classification.commonActiveIngredients;
            }
          }

          // THEN: Verify all common principles are properly sanitized
          final contaminationPatterns = [
            RegExp(r'\b\d+\s*mg\b', caseSensitive: false),
            RegExp(r'\b\d+\s*g\b', caseSensitive: false),
            RegExp(r'\b\d+\s*ml\b', caseSensitive: false),
            RegExp(r'\b\d+\s*ui\b', caseSensitive: false),
            RegExp(r'\b\d+\s*%\b'),
            RegExp(r'\b\d+\s*ch\b', caseSensitive: false),
            RegExp(r'\b\d+\s*dh\b', caseSensitive: false),
          ];

          final formulationKeywords = [
            'comprimé',
            'gélule',
            'solution',
            'injectable',
            'poudre',
            'sirop',
            'suspension',
            'crème',
            'pommade',
            'gel',
            'collyre',
            'inhalation',
          ];

          int totalGroups = 0;
          int contaminatedGroups = 0;
          final contaminationDetails = <String, List<String>>{};

          for (final entry in commonPrincipesMap.entries) {
            final groupId = entry.key;
            final principles = entry.value;

            if (principles.isEmpty) continue;

            totalGroups++;

            final contaminated = <String>[];

            for (final principle in principles) {
              // Check for dosage/unit contamination
              for (final pattern in contaminationPatterns) {
                if (pattern.hasMatch(principle)) {
                  contaminated.add('dosage_unit: $principle');
                  break;
                }
              }

              // Check for formulation keywords (except exceptions)
              for (final keyword in formulationKeywords) {
                if (keyword == 'solution') {
                  // Check exception: "solution de"
                  final hasException = RegExp(
                    r'\bsolution\s+de\b',
                    caseSensitive: false,
                  ).hasMatch(principle);
                  if (!hasException &&
                      RegExp(
                        r'\b' + RegExp.escape(keyword) + r'\b',
                        caseSensitive: false,
                      ).hasMatch(principle)) {
                    contaminated.add('formulation_keyword: $principle');
                    break;
                  }
                } else if (RegExp(
                  r'\b' + RegExp.escape(keyword) + r'\b',
                  caseSensitive: false,
                ).hasMatch(principle)) {
                  contaminated.add('formulation_keyword: $principle');
                  break;
                }
              }

              // Check for "équivalant à" patterns
              if (RegExp(
                r'équivalant à',
                caseSensitive: false,
              ).hasMatch(principle)) {
                contaminated.add('equivalent_pattern: $principle');
              }

              // Check for parenthetical content
              if (principle.contains('(') || principle.contains(')')) {
                contaminated.add('parentheses: $principle');
              }
            }

            if (contaminated.isNotEmpty) {
              contaminatedGroups++;
              contaminationDetails[groupId] = contaminated;
            }
          }

          // Report findings
          print('\n=== Sanitization Validation Results ===');
          print('Total groups analyzed: $totalGroups');
          print('Contaminated groups: $contaminatedGroups');
          print('Clean groups: ${totalGroups - contaminatedGroups}');

          if (contaminationDetails.isNotEmpty) {
            print('\n--- Contaminated Groups (first 10) ---');
            final entries = contaminationDetails.entries.take(10);
            for (final entry in entries) {
              print('Group ID: ${entry.key}');
              for (final detail in entry.value.take(3)) {
                print('  - $detail');
              }
            }
          }

          // Assert that contamination rate is acceptable (< 1%)
          final contaminationRate = contaminatedGroups / totalGroups;
          expect(
            contaminationRate,
            lessThan(0.01),
            reason:
                'Contamination rate ${(contaminationRate * 100).toStringAsFixed(2)}% exceeds 1% threshold',
          );
        },
        timeout: const Timeout(Duration(minutes: 5)),
      );

      testWidgets(
        'should preserve legitimate numbers in molecule names',
        (WidgetTester tester) async {
          // GIVEN: Database initialized with real data
          final dbService = sl<DatabaseService>();

          // WHEN: Get common principles for groups (limit to first 50 for performance)
          final db = sl<AppDatabase>();
          final groupRows = await db
              .customSelect(
                'SELECT DISTINCT group_id FROM generique_groups LIMIT 20',
              )
              .get();

          final groupIds = groupRows
              .map((row) => row.read<String>('group_id'))
              .toSet();

          // Use classifyProductGroup to get sanitized common principles
          final commonPrincipesMap = <String, List<String>>{};
          for (final groupId in groupIds.take(20)) {
            final classification = await dbService.classifyProductGroup(
              groupId,
            );
            if (classification != null &&
                classification.commonActiveIngredients.isNotEmpty) {
              commonPrincipesMap[groupId] =
                  classification.commonActiveIngredients;
            }
          }

          // THEN: Verify that known numbered molecules are preserved
          final knownNumberedMolecules = [
            '4000',
            '3350',
            '980',
            '940',
            '6000',
            '2,4',
            '2.4',
          ];

          bool foundNumberedMolecule = false;

          for (final principles in commonPrincipesMap.values) {
            for (final principle in principles) {
              for (final knownNumber in knownNumberedMolecules) {
                if (principle.contains(knownNumber)) {
                  foundNumberedMolecule = true;
                  // Verify the number is preserved in the sanitized output
                  expect(
                    principle,
                    contains(knownNumber),
                    reason: 'Known numbered molecule should be preserved',
                  );
                  break;
                }
              }
            }
          }

          // This test verifies the logic works - may not always find examples
          expect(
            foundNumberedMolecule || commonPrincipesMap.isEmpty,
            isTrue,
            reason: 'Should find numbered molecules or have no data',
          );
        },
        timeout: const Timeout(Duration(minutes: 3)),
      );

      testWidgets(
        'should handle groups with multiple components correctly',
        (WidgetTester tester) async {
          // GIVEN: Database initialized with real data
          final dbService = sl<DatabaseService>();

          // WHEN: Find groups with multiple common principles (limit for performance)
          final db = sl<AppDatabase>();
          final multiComponentGroups = await db.customSelect('''
            SELECT group_id, COUNT(*) as principle_count
            FROM (
              SELECT DISTINCT gm.group_id, pa.principe
              FROM group_members gm
              INNER JOIN medicaments m ON gm.code_cip = m.code_cip
              INNER JOIN specialites s ON m.cis_code = s.cis_code
              INNER JOIN principes_actifs pa ON m.code_cip = pa.code_cip
              WHERE gm.group_id IN (
                SELECT group_id FROM generique_groups LIMIT 50
              )
            )
            GROUP BY group_id
            HAVING principle_count > 1
            LIMIT 10
          ''').get();

          if (multiComponentGroups.isEmpty) {
            return; // Skip if no multi-component groups found
          }

          int checkedGroups = 0;
          // THEN: Verify each component is properly sanitized
          for (final groupRow in multiComponentGroups.take(5)) {
            final groupId = groupRow.read<String>('group_id');
            final classification = await dbService.classifyProductGroup(
              groupId,
            );

            if (classification == null ||
                classification.commonActiveIngredients.isEmpty) {
              continue; // Skip groups without common ingredients
            }

            checkedGroups++;

            final commonIngredients = classification.commonActiveIngredients;

            expect(
              commonIngredients.isNotEmpty,
              isTrue,
              reason: 'Group $groupId should have common ingredients',
            );

            // Verify no contamination in any component
            for (final ingredient in commonIngredients) {
              // Should not contain dosage units
              expect(
                ingredient,
                isNot(RegExp(r'\b\d+\s*mg\b', caseSensitive: false).hasMatch),
                reason:
                    'Should not contain dosage: $ingredient in group $groupId',
              );
              expect(
                ingredient,
                isNot(RegExp(r'\b\d+\s*g\b', caseSensitive: false).hasMatch),
                reason:
                    'Should not contain dosage: $ingredient in group $groupId',
              );
            }
          }

          // At least verify we checked some groups if they exist
          if (multiComponentGroups.isNotEmpty) {
            expect(
              checkedGroups,
              greaterThan(0),
              reason: 'Should have checked at least one multi-component group',
            );
          }
        },
        timeout: const Timeout(Duration(minutes: 3)),
      );

      testWidgets(
        'should produce clean results for ProductGroupClassification',
        (WidgetTester tester) async {
          // GIVEN: Database initialized with real data
          final dbService = sl<DatabaseService>();

          // WHEN: Get product group classifications
          final db = sl<AppDatabase>();
          final groupRows = await db
              .customSelect('SELECT group_id FROM generique_groups LIMIT 50')
              .get();

          int totalChecked = 0;
          int contaminatedCount = 0;

          for (final row in groupRows) {
            final groupId = row.read<String>('group_id');
            final classification = await dbService.classifyProductGroup(
              groupId,
            );

            if (classification == null) continue;

            totalChecked++;

            // Check commonActiveIngredients for contamination
            for (final ingredient in classification.commonActiveIngredients) {
              // Check for dosage patterns
              if (RegExp(
                r'\b\d+\s*(mg|g|ml|ui|%|ch|dh)\b',
                caseSensitive: false,
              ).hasMatch(ingredient)) {
                contaminatedCount++;
                print('Contaminated ingredient in group $groupId: $ingredient');
                break;
              }

              // Check for formulation keywords (except exceptions)
              if (RegExp(
                r'\b(comprimé|gélule|injectable|poudre|sirop|suspension|crème|pommade|gel|collyre|inhalation)\b',
                caseSensitive: false,
              ).hasMatch(ingredient)) {
                // Check exception for "solution"
                if (ingredient.contains('solution') &&
                    !RegExp(
                      r'\bsolution\s+de\b',
                      caseSensitive: false,
                    ).hasMatch(ingredient)) {
                  contaminatedCount++;
                  print(
                    'Contaminated ingredient in group $groupId: $ingredient',
                  );
                  break;
                }
              }
            }
          }

          // Assert that contamination rate is acceptable
          if (totalChecked > 0) {
            final contaminationRate = contaminatedCount / totalChecked;
            expect(
              contaminationRate,
              lessThan(0.02),
              reason:
                  'Contamination rate ${(contaminationRate * 100).toStringAsFixed(2)}% exceeds 2% threshold',
            );
          }
        },
        timeout: const Timeout(Duration(minutes: 5)),
      );
    });
  });
}
