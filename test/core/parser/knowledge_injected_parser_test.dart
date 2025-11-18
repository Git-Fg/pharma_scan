// test/core/parser/knowledge_injected_parser_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/parser/medicament_grammar.dart';

void main() {
  final parser = MedicamentParser();

  group('Knowledge-Injected Parser', () {
    test('Removes official form even if complex', () {
      // Raw name has form text inside it
      const raw = 'DOLIPRANE 1000 mg, comprimé';

      // We inject the knowledge
      const officialForm = 'Comprimé';

      final result = parser.parse(raw, officialForm: officialForm);

      expect(result.baseName, 'DOLIPRANE');
      // Formulation should contain the official form (case may vary)
      expect(result.formulation?.toLowerCase(), contains('comprimé'));
    });

    test('Removes official Lab even if not standard suffix', () {
      const raw = 'AMOXICILLINE SANDOZ 1 g, comprimé';
      const officialLab = 'SANDOZ'; // Official source says SANDOZ

      final result = parser.parse(raw, officialLab: officialLab);

      // SANDOZ should be removed, form should be extracted heuristically
      expect(result.baseName, contains('AMOXICILLINE'));
      expect(result.baseName, isNot(contains('SANDOZ')));
      // Form should be extracted heuristically
      expect(result.formulation, isNotNull);
    });

    test('Handles mismatch: Official form not in name', () {
      // Sometimes the official form is technical "Comprimé pelliculé"
      // but the name just says "Comprimé"
      const raw = 'CADUET 5 mg/10 mg, comprimé';
      const officialForm = 'Comprimé pelliculé'; // More specific than raw

      final result = parser.parse(raw, officialForm: officialForm);

      // The deterministic removal might fail (contains check),
      // but the heuristic fallback should catch "comprimé"
      expect(result.baseName, 'CADUET');
      // The parser should ideally combine or prefer the one it found if injection failed
      expect(result.formulation, contains('comprimé'));
    });

    test('Real world complex case: Dosage + Form + Lab', () {
      const raw =
          'AMOXICILLINE ACIDE CLAVULANIQUE ALMUS 1 g/125 mg ADULTES, poudre pour suspension buvable en sachet-dose';
      const officialForm =
          'Poudre pour suspension buvable'; // Note: "en sachet-dose" might be missing in official
      const officialLab = 'ALMUS';

      final result = parser.parse(
        raw,
        officialForm: officialForm,
        officialLab: officialLab,
      );

      // Lab and form should be removed, base name should be clean
      expect(result.baseName, contains('AMOXICILLINE ACIDE CLAVULANIQUE'));
      expect(result.baseName, isNot(contains('ALMUS')));
      // Dosages should be extracted (may be stored as ratio)
      expect(result.dosages, isNotEmpty);
      expect(result.contextAttributes, contains('ADULTES'));
    });

    test('Handles null hints gracefully', () {
      const raw = 'DOLIPRANE 500 mg, comprimé';

      final result = parser.parse(raw, officialForm: null, officialLab: null);

      // Should fall back to heuristic parsing
      expect(result.baseName, 'DOLIPRANE');
      expect(result.formulation, isNotNull);
    });

    test('Handles empty string hints gracefully', () {
      const raw = 'DOLIPRANE 500 mg, comprimé';

      final result = parser.parse(raw, officialForm: '', officialLab: '');

      // Should fall back to heuristic parsing
      expect(result.baseName, 'DOLIPRANE');
      expect(result.formulation, isNotNull);
    });

    test('Combines official form with discovered form keywords', () {
      const raw = 'DOLIPRANE 500 mg, comprimé sécable';
      const officialForm = 'Comprimé'; // Official says "Comprimé"

      final result = parser.parse(raw, officialForm: officialForm);

      // Should remove "comprimé sécable" as a full known keyword
      expect(result.baseName, 'DOLIPRANE');
      // Formulation should contain the full known keyword
      expect(result.formulation?.toLowerCase(), contains('comprimé'));
      expect(result.formulation?.toLowerCase(), contains('sécable'));
    });

    test('Removes lab with legal entity suffix', () {
      const raw = 'AMOXICILLINE SANOFI AVENTIS 1 g, comprimé';
      const officialLab = 'SANOFI AVENTIS SAS'; // Official has legal suffix

      final result = parser.parse(raw, officialLab: officialLab);

      // parseMainTitulaire should strip "SAS" and match "SANOFI AVENTIS"
      expect(result.baseName, contains('AMOXICILLINE'));
      expect(result.baseName, isNot(contains('SANOFI')));
    });

    test('Handles partial lab match at end', () {
      const raw = 'AMOXICILLINE SANDOZ 1 g, comprimé';
      const officialLab = 'NOVARTIS SANDOZ'; // Official has longer name

      final result = parser.parse(raw, officialLab: officialLab);

      // Should match "SANDOZ" at the end
      expect(result.baseName, 'AMOXICILLINE');
    });

    test('Official form removal is case-insensitive', () {
      const raw = 'DOLIPRANE 500 mg, COMPRIMÉ';
      const officialForm = 'comprimé'; // Official is lowercase

      final result = parser.parse(raw, officialForm: officialForm);

      expect(result.baseName, 'DOLIPRANE');
      expect(result.formulation, 'comprimé');
    });

    test('Official lab removal handles trailing comma', () {
      const raw = 'AMOXICILLINE SANDOZ, comprimé';
      const officialLab = 'SANDOZ';

      final result = parser.parse(raw, officialLab: officialLab);

      expect(result.baseName, 'AMOXICILLINE');
      expect(result.baseName, isNot(contains(',')));
    });

    test('Multiple form keywords in official form', () {
      const raw = 'DOLIPRANE 500 mg, comprimé pelliculé sécable';
      const officialForm = 'Comprimé pelliculé'; // Official has two words

      final result = parser.parse(raw, officialForm: officialForm);

      expect(result.baseName, 'DOLIPRANE');
      // Should remove "Comprimé pelliculé" and discover "sécable" if it's a known keyword
      expect(result.formulation?.toLowerCase(), contains('comprimé'));
      expect(result.formulation?.toLowerCase(), contains('pelliculé'));
    });
  });
}
