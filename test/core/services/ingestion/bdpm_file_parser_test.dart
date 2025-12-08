import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/services/ingestion/bdpm_file_parser.dart'
    show BdpmFileParser;
import 'package:pharma_scan/core/utils/strings.dart';

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
        ifLeft: (error) => fail('Expected success but got error: $error'),
        ifRight: (value) => value,
      );

      expect(result.specialites, hasLength(2));
      expect(result.seenCis, contains('123456'));
      expect(result.seenCis, contains('654321'));
      expect(
        result.specialites.first.statutAdministratif.value,
        equals('Autorisation active'),
      );
      expect(
        result.specialites.last.statutAdministratif.value,
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
        ifLeft: (error) => fail('Expected success but got error: $error'),
        ifRight: (value) => value,
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
        ifLeft: (error) => fail('Expected success but got error: $error'),
        ifRight: (value) => value,
      );

      expect(result.specialites, hasLength(1));
      expect(result.seenCis, contains('123456'));
      expect(
        result.specialites.first.formePharmaceutique.value,
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
        ifLeft: (error) => fail('Expected success but got error: $error'),
        ifRight: (value) => value,
      );

      expect(result.specialites, hasLength(1));
      expect(result.seenCis, contains('123456'));
      expect(result.labIdsByName.keys, contains('Lab Homeo'));
      final labId = result.labIdsByName['Lab Homeo'];
      expect(labId, isNotNull);
      expect(
        result.specialites.first.titulaireId.value,
        equals(labId),
      );
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

      final resultEither = await BdpmFileParser.parsePrincipesActifs(
        _streamFromContent(content),
        cisToCip13,
      );

      final result = resultEither.fold(
        ifLeft: (error) => fail('Expected success but got error: $error'),
        ifRight: (value) => value,
      );

      expect(result, hasLength(1));
      final entry = result.first;
      expect(entry.principe.value, equals('Metformine'));
      expect(entry.dosage.value, equals('500'));
      expect(entry.dosageUnit.value, equals('mg base'));
    });

    test('falls back to SA data when FT row missing', () async {
      const content = '''
123456\tfield1\tfield2\tMetformine chlorhydrate\t850 mg\tfield5\tSA\tL2
''';
      final cisToCip13 = {
        '123456': ['111111111'],
      };

      final resultEither = await BdpmFileParser.parsePrincipesActifs(
        _streamFromContent(content),
        cisToCip13,
      );

      final result = resultEither.fold(
        ifLeft: (error) => fail('Expected success but got error: $error'),
        ifRight: (value) => value,
      );

      expect(result, hasLength(1));
      final entry = result.first;
      expect(entry.principe.value, equals('Metformine chlorhydrate'));
      expect(entry.dosage.value, equals('850'));
      expect(entry.dosageUnit.value, equals('mg'));
    });
  });

  group('BdpmFileParser.parseGeneriques', () {
    // Salt-stripping cases removed; relational and split tiers are covered in
    // hybrid_parsing_test.dart.

    test('extracts princeps label from two-segment label', () async {
      const content = '''
GROUP5\tMETFORMINE - GLUCOPHAGE\t123456\t0
''';
      final cisToCip13 = {
        '123456': ['888888888'],
      };
      final medicamentCips = {'888888888'};
      final compositionMap = {'123456': 'METFORMINE'};
      final specialitesMap = {'123456': 'GLUCOPHAGE'};

      final resultEither = await BdpmFileParser.parseGeneriques(
        _streamFromContent(content),
        cisToCip13,
        medicamentCips,
        compositionMap,
        specialitesMap,
      );

      final result = resultEither.fold(
        ifLeft: (error) => fail('Expected success but got error: $error'),
        ifRight: (value) => value,
      );

      expect(result.generiqueGroups, hasLength(1));
      final group = result.generiqueGroups.first;
      expect(group.groupId.value, equals('GROUP5'));
      expect(group.libelle.value, equals('METFORMINE'));
      expect(group.princepsLabel.value, equals('GLUCOPHAGE'));
    });

    test('extracts princeps label from multiple-segment label', () async {
      const content = '''
GROUP6\tPERINDOPRIL ARGININE - PERINDOPRIL TOSILATE - COVERSYL\t123456\t0
''';
      final cisToCip13 = {
        '123456': ['999999999'],
      };
      final medicamentCips = {'999999999'};
      final compositionMap = {'123456': 'PERINDOPRIL ARGININE'};
      final specialitesMap = {'123456': 'COVERSYL'};

      final resultEither = await BdpmFileParser.parseGeneriques(
        _streamFromContent(content),
        cisToCip13,
        medicamentCips,
        compositionMap,
        specialitesMap,
      );

      final result = resultEither.fold(
        ifLeft: (error) => fail('Expected success but got error: $error'),
        ifRight: (value) => value,
      );

      expect(result.generiqueGroups, hasLength(1));
      final group = result.generiqueGroups.first;
      expect(group.groupId.value, equals('GROUP6'));
      expect(group.libelle.value, equals('PERINDOPRIL ARGININE'));
      expect(group.princepsLabel.value, equals('COVERSYL'));
    });

    test('sets princeps label to null for single-segment label', () async {
      const content = '''
GROUP7\tMETFORMINE\t123456\t0
''';
      final cisToCip13 = {
        '123456': ['111111111'],
      };
      final medicamentCips = {'111111111'};
      final compositionMap = <String, String>{};
      final specialitesMap = <String, String>{};

      final resultEither = await BdpmFileParser.parseGeneriques(
        _streamFromContent(content),
        cisToCip13,
        medicamentCips,
        compositionMap,
        specialitesMap,
      );

      final result = resultEither.fold(
        ifLeft: (error) => fail('Expected success but got error: $error'),
        ifRight: (value) => value,
      );

      expect(result.generiqueGroups, hasLength(1));
      final group = result.generiqueGroups.first;
      expect(group.groupId.value, equals('GROUP7'));
      expect(group.libelle.value, equals('METFORMINE'));
      expect(group.princepsLabel.value, equals(Strings.unknownReference));
    });
  });

  group('BdpmFileParser.parseMedicaments', () {
    test('captures agrement collectivites in lowercase', () async {
      const content = '''
123456\tcode7\tlibelle\tstatut admin\tDéclaration de commercialisation\t19/09/2011\t3400949497706\tOui\t65%\t1 226,20
''';
      final specialitesResult = (
        specialites: <SpecialitesCompanion>[
          const SpecialitesCompanion(
            cisCode: Value('123456'),
            nomSpecialite: Value('TEST'),
            procedureType: Value(''),
            statutAdministratif: Value(''),
            formePharmaceutique: Value(''),
            voiesAdministration: Value(''),
            etatCommercialisation: Value(''),
            titulaireId: Value(null),
            conditionsPrescription: Value(null),
            dateAmm: Value(null),
            atcCode: Value(null),
            isSurveillance: Value(false),
          ),
        ],
        namesByCis: {'123456': 'TEST'},
        seenCis: {'123456'},
        labIdsByName: <String, int>{},
        laboratories: <LaboratoriesCompanion>[],
      );

      final resultEither = await BdpmFileParser.parseMedicaments(
        _streamFromContent(content),
        specialitesResult,
      );

      final result = resultEither.fold(
        ifLeft: (error) => fail('Expected success but got error: $error'),
        ifRight: (value) => value,
      );

      expect(result.medicaments, hasLength(1));
      final entry = result.medicaments.first;
      expect(entry.agrementCollectivites.value, equals('oui'));
      expect(entry.prixPublic.value, equals(1226.20));
      expect(entry.presentationLabel.value, equals('libelle'));
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
        ifLeft: (error) => fail('Expected success but got error: $error'),
        ifRight: (value) => value,
      );

      expect(result, hasLength(1));
      final entry = result.first;
      expect(entry.codeCip.value, equals('3400933333333'));
      expect(entry.statut.value, equals('Rupture de stock'));
      expect(entry.dateDebut.value, equals(DateTime.utc(2024, 2, 12)));
      expect(entry.dateFin.value, equals(DateTime.utc(2024, 2, 15)));
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
        ifLeft: (error) => fail('Expected success but got error: $error'),
        ifRight: (value) => value,
      );

      expect(result, hasLength(2));
      expect(
        result.map((entry) => entry.codeCip.value),
        containsAll(['3400911111111', '3400922222222']),
      );
      for (final entry in result) {
        expect(entry.statut.value, equals('Tension nationale'));
        expect(entry.dateDebut.value, equals(DateTime.utc(2024, 3, 5)));
        expect(entry.dateFin.value, isNull);
      }
    });
  });
}
