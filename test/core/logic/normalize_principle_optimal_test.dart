import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/logic/sanitizer.dart';

void main() {
  group('normalizePrincipleOptimal', () {
    test('should normalize inverted formats', () {
      expect(
        normalizePrincipleOptimal('SODIUM (BICARBONATE DE)'),
        'BICARBONATE',
      );
      expect(normalizePrincipleOptimal('SODIUM (ALGINATE DE)'), 'ALGINATE');
    });

    test('should remove salt prefixes', () {
      expect(normalizePrincipleOptimal('MALÉATE DE TIMOLOL'), 'TIMOLOL');
      expect(
        normalizePrincipleOptimal("CHLORHYDRATE D'AMIODARONE"),
        'AMIODARONE',
      );
      expect(
        normalizePrincipleOptimal('TOSILATE DE PÉRINDOPRIL'),
        'PERINDOPRIL',
      );
    });

    test('should remove form suffixes', () {
      expect(normalizePrincipleOptimal('TIMOLOL BASE'), 'TIMOLOL');
      expect(
        normalizePrincipleOptimal('RISÉDRONATE MONOSODIQUE ANHYDRE'),
        'RISEDRONATE',
      );
      expect(normalizePrincipleOptimal('ALENDRONATE DE SODIUM'), 'ALENDRONATE');
    });

    test('should handle special cases', () {
      expect(normalizePrincipleOptimal('ACIDE TRANEXAMIQUE'), 'TRANEXAMIQUE');
      expect(normalizePrincipleOptimal('ALENDRONIQUE (ACIDE)'), 'ALENDRONATE');
      expect(
        normalizePrincipleOptimal('FUMARATE ACIDE DE BISOPROLOL'),
        'BISOPROLOL',
      );
    });

    test('should normalize spelling variants', () {
      expect(normalizePrincipleOptimal('COLÉCALCIFÉROL'), 'CHOLECALCIFEROL');
      expect(
        normalizePrincipleOptimal('URSODÉSOXYCHOLIQUE'),
        'URSODEOXYCHOLIQUE',
      );
      expect(normalizePrincipleOptimal('CARBOCYSTEINE'), 'CARBOCISTEINE');
      expect(normalizePrincipleOptimal('SEVORANE'), 'SEVOFLURANE');
    });

    test('should handle complex forms', () {
      expect(
        normalizePrincipleOptimal('ÉSOMÉPRAZOLE MAGNÉSIQUE TRIHYDRATÉ'),
        'ESOMEPRAZOLE',
      );
      expect(
        normalizePrincipleOptimal('METHOTREXATE DISODIQUE'),
        'METHOTREXATE',
      );
      expect(
        normalizePrincipleOptimal('CHLORHYDRATE DIHYDRATE DE VALACICLOVIR'),
        'VALACICLOVIR',
      );
    });

    test('should handle gadolinium contrast agents', () {
      expect(normalizePrincipleOptimal('DOTA'), 'GADOTERIQUE');
      expect(
        normalizePrincipleOptimal('GADOTERATE DE MEGLUMINE'),
        'GADOTERIQUE',
      );
      expect(normalizePrincipleOptimal('OXYDE DE GADOLINIUM'), 'GADOTERIQUE');
    });

    test('should handle empty and edge cases', () {
      expect(normalizePrincipleOptimal(''), '');
      expect(normalizePrincipleOptimal('   '), '');
      expect(normalizePrincipleOptimal('BRINZOLAMIDE'), 'BRINZOLAMIDE');
    });

    test('should normalize PÉRINDOPRIL variants', () {
      expect(normalizePrincipleOptimal('PÉRINDOPRIL ARGININE'), 'PERINDOPRIL');
      expect(
        normalizePrincipleOptimal('PÉRINDOPRIL TERT-BUTYLAMINE'),
        'PERINDOPRIL',
      );
      expect(normalizePrincipleOptimal('PÉRINDOPRIL ERBUMINE'), 'PERINDOPRIL');
    });

    test('should handle additional salt-related cases', () {
      expect(
        normalizePrincipleOptimal('CHLORHYDRATE DE ROPINIROLE'),
        'ROPINIROLE',
      );
      expect(
        normalizePrincipleOptimal('MÉMANTINE (CHLORHYDRATE DE)'),
        'MEMANTINE',
      );
    });

    test('should handle solution descriptors', () {
      expect(
        normalizePrincipleOptimal('CHLORHEXIDINE, SOLUTION DE'),
        'CHLORHEXIDINE',
      );
      expect(
        normalizePrincipleOptimal('SOLUTION DE CHLORHEXIDINE'),
        'CHLORHEXIDINE',
      );
    });
  });
}
