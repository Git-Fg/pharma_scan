import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/services/ingestion/bdpm_file_parser.dart';

Stream<String> _streamFromContent(String content) =>
    Stream<String>.value(content).transform(const LineSplitter());

void main() {
  group('BdpmFileParser.parseSpecialites', () {
    test('keeps all statuses including archived/suspended', () async {
      const content = '''
123456\tSPECIALITE ACTIVE\tComprimé\torale\tAutorisation active\tProcédure A\tCommercialisé\t01/01/2024\tstatutbdm\tEU9999\tLab Active\tNon
654321\tSPECIALITE ARCHIVE\tComprimé\torale\tAutorisation suspendue\tProcédure B\tCommercialisé\t01/02/2024\tstatutbdm\tEU8888\tLab Old\tNon
''';

      final resultEither = await BdpmFileParser.parseSpecialites(
        _streamFromContent(content),
        const <String, String>{},
        const <String, String>{},
      );

      final result = resultEither.fold(
        (error) => fail('Expected success but got error: $error'),
        (value) => value,
      );

      expect(result.specialites, hasLength(2));
      expect(result.seenCis, contains('123456'));
      expect(result.seenCis, contains('654321'));
      expect(
        result.specialites.first['statut_administratif'],
        equals('Autorisation active'),
      );
      expect(
        result.specialites.last['statut_administratif'],
        equals('Autorisation suspendue'),
      );
    });

    test('should exclude products from BOIRON laboratory', () async {
      const content = '''
123456\tSPECIALITE BOIRON\tComprimé\torale\tAutorisation active\tProcédure A\tCommercialisé\t01/01/2024\tstatutbdm\tEU9999\tLABORATOIRES BOIRON\tNon
''';

      final resultEither = await BdpmFileParser.parseSpecialites(
        _streamFromContent(content),
        const <String, String>{},
        const <String, String>{},
      );

      final result = resultEither.fold(
        (error) => fail('Expected success but got error: $error'),
        (value) => value,
      );

      expect(result.specialites, isEmpty);
      expect(result.seenCis, isEmpty);
    });

    test('should include previously excluded forms such as Gaz', () async {
      const content = '''
123456\tGAZ MEDICINAL\tGaz médicinal\tinhalation\tAutorisation active\tProcédure Gaz\tCommercialisé\t01/01/2024\tstatutbdm\tEU7777\tAIR LIQUIDE\tNon
''';

      final resultEither = await BdpmFileParser.parseSpecialites(
        _streamFromContent(content),
        const <String, String>{},
        const <String, String>{},
      );

      final result = resultEither.fold(
        (error) => fail('Expected success but got error: $error'),
        (value) => value,
      );

      expect(result.specialites, hasLength(1));
      expect(result.seenCis, contains('123456'));
      expect(
        result.specialites.first['forme_pharmaceutique'],
        equals('Gaz médicinal'),
      );
    });

    test('accepts homéopathique procedure when titulaire not BOIRON', () async {
      const content = '''
123456\tSPECIALITE HOMEOPATHIQUE\tComprimé\torale\tAutorisation active\tProcédure homéopathique\tCommercialisé\t01/01/2024\tstatutbdm\tEU9999\tLab Homeo\tNon
''';

      final resultEither = await BdpmFileParser.parseSpecialites(
        _streamFromContent(content),
        const <String, String>{},
        const <String, String>{},
      );

      final result = resultEither.fold(
        (error) => fail('Expected success but got error: $error'),
        (value) => value,
      );

      expect(result.specialites, hasLength(1));
      expect(result.seenCis, contains('123456'));
      expect(result.specialites.first['titulaire'], equals('Lab Homeo'));
    });
  });

  group('BdpmFileParser.parseCompositions', () {
    test('uses FT rows to resolve principle name and dosage', () async {
      const content = '''
123456\tfield1\tfield2\tMetformine chlorhydrate\t500 mg\tfield5\tSA\tL1
123456\tfield1\tfield2\tMetformine\t500 mg base\tfield5\tFT\tL1
''';
      final cisToCip13 = {
        '123456': ['987654321'],
      };

      final resultEither = await BdpmFileParser.parseCompositions(
        _streamFromContent(content),
        cisToCip13,
      );

      final result = resultEither.fold(
        (error) => fail('Expected success but got error: $error'),
        (value) => value,
      );

      expect(result, hasLength(1));
      final entry = result.first;
      expect(entry['principe'], equals('Metformine'));
      expect(entry['dosage'], equals('500'));
      expect(entry['dosage_unit'], equals('mg base'));
    });

    test('falls back to SA data when FT row missing', () async {
      const content = '''
123456\tfield1\tfield2\tMetformine chlorhydrate\t850 mg\tfield5\tSA\tL2
''';
      final cisToCip13 = {
        '123456': ['111111111'],
      };

      final resultEither = await BdpmFileParser.parseCompositions(
        _streamFromContent(content),
        cisToCip13,
      );

      final result = resultEither.fold(
        (error) => fail('Expected success but got error: $error'),
        (value) => value,
      );

      expect(result, hasLength(1));
      final entry = result.first;
      expect(entry['principe'], equals('Metformine chlorhydrate'));
      expect(entry['dosage'], equals('850'));
      expect(entry['dosage_unit'], equals('mg'));
    });

    test('transforms salt prefix to suffix in parentheses', () async {
      const content = '''
123456\tfield1\tfield2\tCHLORHYDRATE DE METFORMINE\t500 mg\tfield5\tSA\tL3
''';
      final cisToCip13 = {
        '123456': ['222222222'],
      };

      final resultEither = await BdpmFileParser.parseCompositions(
        _streamFromContent(content),
        cisToCip13,
      );

      final result = resultEither.fold(
        (error) => fail('Expected success but got error: $error'),
        (value) => value,
      );

      expect(result, hasLength(1));
      final entry = result.first;
      expect(entry['principe'], equals('METFORMINE (CHLORHYDRATE DE)'));
      expect(entry['dosage'], equals('500'));
      expect(entry['dosage_unit'], equals('mg'));
    });

    test('preserves salt suffix unchanged', () async {
      const content = '''
123456\tfield1\tfield2\tMETFORMINE CHLORHYDRATE\t850 mg\tfield5\tSA\tL4
''';
      final cisToCip13 = {
        '123456': ['333333333'],
      };

      final resultEither = await BdpmFileParser.parseCompositions(
        _streamFromContent(content),
        cisToCip13,
      );

      final result = resultEither.fold(
        (error) => fail('Expected success but got error: $error'),
        (value) => value,
      );

      expect(result, hasLength(1));
      final entry = result.first;
      expect(entry['principe'], equals('METFORMINE CHLORHYDRATE'));
      expect(entry['dosage'], equals('850'));
      expect(entry['dosage_unit'], equals('mg'));
    });

    test('handles mixed case salt prefixes', () async {
      const content = '''
123456\tfield1\tfield2\tChlorhydrate de Metformine\t500 mg\tfield5\tSA\tL5
''';
      final cisToCip13 = {
        '123456': ['444444444'],
      };

      final resultEither = await BdpmFileParser.parseCompositions(
        _streamFromContent(content),
        cisToCip13,
      );

      final result = resultEither.fold(
        (error) => fail('Expected success but got error: $error'),
        (value) => value,
      );

      expect(result, hasLength(1));
      final entry = result.first;
      expect(entry['principe'], equals('Metformine (Chlorhydrate de)'));
      expect(entry['dosage'], equals('500'));
      expect(entry['dosage_unit'], equals('mg'));
    });

    test("transforms salt prefix with elision (D')", () async {
      const content = '''
123456\tfield1\tfield2\tCHLORHYDRATE D'ALFUZOSINE\t10 mg\tfield5\tSA\tL6
''';
      final cisToCip13 = {
        '123456': ['999999999'],
      };

      final resultEither = await BdpmFileParser.parseCompositions(
        _streamFromContent(content),
        cisToCip13,
      );

      final result = resultEither.fold(
        (error) => fail('Expected success but got error: $error'),
        (value) => value,
      );

      expect(result, hasLength(1));
      final entry = result.first;
      expect(entry['principe'], equals("ALFUZOSINE (CHLORHYDRATE D')"));
      expect(entry['dosage'], equals('10'));
      expect(entry['dosage_unit'], equals('mg'));
    });
  });

  group('BdpmFileParser.parseGeneriques', () {
    test('transforms salt prefix in group libelle', () async {
      const content = '''
GROUP1\tCHLORHYDRATE DE METFORMINE\t123456\t0
''';
      final cisToCip13 = {
        '123456': ['555555555'],
      };
      final medicamentCips = {'555555555'};

      final resultEither = await BdpmFileParser.parseGeneriques(
        _streamFromContent(content),
        cisToCip13,
        medicamentCips,
      );

      final result = resultEither.fold(
        (error) => fail('Expected success but got error: $error'),
        (value) => value,
      );

      expect(result.generiqueGroups, hasLength(1));
      final group = result.generiqueGroups.first;
      expect(group['group_id'], equals('GROUP1'));
      expect(group['libelle'], equals('METFORMINE (CHLORHYDRATE DE)'));
      expect(result.groupMembers, hasLength(1));
    });

    test('preserves group libelle without salt prefix', () async {
      const content = '''
GROUP2\tMETFORMINE\t123456\t0
''';
      final cisToCip13 = {
        '123456': ['666666666'],
      };
      final medicamentCips = {'666666666'};

      final resultEither = await BdpmFileParser.parseGeneriques(
        _streamFromContent(content),
        cisToCip13,
        medicamentCips,
      );

      final result = resultEither.fold(
        (error) => fail('Expected success but got error: $error'),
        (value) => value,
      );

      expect(result.generiqueGroups, hasLength(1));
      final group = result.generiqueGroups.first;
      expect(group['group_id'], equals('GROUP2'));
      expect(group['libelle'], equals('METFORMINE'));
    });

    test('handles different salt types in group libelle', () async {
      const content = '''
GROUP3\tSULFATE DE MORPHINE\t123456\t0
GROUP4\tMALÉATE DE DIPHENHYDRAMINE\t123456\t1
''';
      final cisToCip13 = {
        '123456': ['777777777'],
      };
      final medicamentCips = {'777777777'};

      final resultEither = await BdpmFileParser.parseGeneriques(
        _streamFromContent(content),
        cisToCip13,
        medicamentCips,
      );

      final result = resultEither.fold(
        (error) => fail('Expected success but got error: $error'),
        (value) => value,
      );

      expect(result.generiqueGroups, hasLength(2));
      final group1 = result.generiqueGroups.firstWhere(
        (g) => g['group_id'] == 'GROUP3',
      );
      expect(group1['libelle'], equals('MORPHINE (SULFATE DE)'));

      final group2 = result.generiqueGroups.firstWhere(
        (g) => g['group_id'] == 'GROUP4',
      );
      expect(group2['libelle'], equals('DIPHENHYDRAMINE (MALÉATE DE)'));
    });
  });

  group('BdpmFileParser.parseMedicaments', () {
    test('captures agrement collectivites in lowercase', () async {
      const content = '''
123456\tcode7\tlibelle\tstatut admin\tDéclaration de commercialisation\t19/09/2011\t3400949497706\tOui\t65%\t1 226,20
''';
      final specialitesResult = (
        specialites: <Map<String, dynamic>>[
          {'cis_code': '123456'},
        ],
        namesByCis: {'123456': 'TEST'},
        seenCis: {'123456'},
      );

      final resultEither = await BdpmFileParser.parseMedicaments(
        _streamFromContent(content),
        specialitesResult,
      );

      final result = resultEither.fold(
        (error) => fail('Expected success but got error: $error'),
        (value) => value,
      );

      expect(result.medicaments, hasLength(1));
      final entry = result.medicaments.first;
      expect(entry['agrement_collectivites'], equals('oui'));
      expect(entry['prix_public'], equals(1226.20));
      expect(entry['presentation_label'], equals('libelle'));
    });
  });

  group('BdpmFileParser.parseAvailability', () {
    test('retains rupture/tension rows and parses dates', () async {
      const content = '''
123456\t3400933333333\t1\tRupture de stock\t12/02/2024\t15/02/2024
123456\t3400944444444\t3\tArrêt\t01/01/2024
123456\t\t1\tRupture sans CIP\t01/02/2024
''';

      final resultEither = await BdpmFileParser.parseAvailability(
        _streamFromContent(content),
        const {},
      );

      final result = resultEither.fold(
        (error) => fail('Expected success but got error: $error'),
        (value) => value,
      );

      expect(result, hasLength(1));
      final entry = result.first;
      expect(entry['code_cip'], equals('3400933333333'));
      expect(entry['statut'], equals('Rupture de stock'));
      expect(entry['date_debut'], equals(DateTime.utc(2024, 2, 12)));
      expect(entry['date_fin'], equals(DateTime.utc(2024, 2, 15)));
    });

    test('expands CIS-level shortages to every CIP', () async {
      const content = '''
123456\t\t2\tTension nationale\t05/03/2024\t
''';
      final cisToCip13 = {
        '123456': ['3400911111111', '3400922222222'],
      };

      final resultEither = await BdpmFileParser.parseAvailability(
        _streamFromContent(content),
        cisToCip13,
      );

      final result = resultEither.fold(
        (error) => fail('Expected success but got error: $error'),
        (value) => value,
      );

      expect(result, hasLength(2));
      expect(
        result.map((entry) => entry['code_cip']),
        containsAll(['3400911111111', '3400922222222']),
      );
      for (final entry in result) {
        expect(entry['statut'], equals('Tension nationale'));
        expect(entry['date_debut'], equals(DateTime.utc(2024, 3, 5)));
        expect(entry['date_fin'], isNull);
      }
    });
  });

  group('BdpmFileParser.parseRegulatoryFlags', () {
    test('detects hospital and list flags with accents removed', () {
      const raw = "Réservé à l'usage hospitalier - Liste I";
      final flags = BdpmFileParser.parseRegulatoryFlags(raw);
      expect(flags.isHospitalOnly, isTrue);
      expect(flags.isList1, isTrue);
      expect(flags.isList2, isFalse);
      expect(flags.isOtc, isFalse);
    });

    test('falls back to OTC when no restriction found', () {
      const raw = 'Sans prescription';
      final flags = BdpmFileParser.parseRegulatoryFlags(raw);
      expect(flags.isOtc, isTrue);
      expect(flags.isHospitalOnly, isFalse);
      expect(flags.isNarcotic, isFalse);
    });

    test('detects stupéfiant even without diacritics', () {
      const raw = 'Stupefiant - Exception';
      final flags = BdpmFileParser.parseRegulatoryFlags(raw);
      expect(flags.isNarcotic, isTrue);
      expect(flags.isException, isTrue);
      expect(flags.isOtc, isFalse);
    });

    test('detects restricted and surveillance indicators', () {
      const raw =
          'Prescription hospitaliere reservee aux specialistes avec carnet de suivi';
      final flags = BdpmFileParser.parseRegulatoryFlags(raw);
      expect(flags.isRestricted, isTrue);
      expect(flags.isSurveillance, isTrue);
      expect(flags.isOtc, isFalse);
    });
  });
}
