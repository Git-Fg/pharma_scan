import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/services/ingestion/bdpm_file_parser.dart';

Stream<String> _streamFromContent(String content) =>
    Stream<String>.value(content).transform(const LineSplitter());

void main() {
  group('Hybrid parsing tiers', () {
    test('Tier 1 uses relational data when available', () async {
      const content = 'GROUP1\tSOME RAW - LABEL\t123456\t0';
      final cisToCip13 = {
        '123456': ['1111111111111'],
      };
      final medicamentCips = {'1111111111111'};
      final compositionMap = {'123456': 'REL_MOLECULE'};
      final specialitesMap = {'123456': 'REL_PRINCEPS'};

      final resultEither = await BdpmFileParser.parseGeneriques(
        _streamFromContent(content),
        cisToCip13,
        medicamentCips,
        compositionMap,
        specialitesMap,
      );

      final result = resultEither.fold(
        ifLeft: (error) => fail('Expected success but got $error'),
        ifRight: (value) => value,
      );

      expect(result.generiqueGroups, hasLength(1));
      final group = result.generiqueGroups.first;
      expect(group.parsingMethod.value, equals('relational'));
      expect(group.libelle.value, equals('REL_MOLECULE'));
      expect(group.princepsLabel.value, equals('REL_PRINCEPS'));
      expect(group.rawLabel.value, equals('SOME RAW - LABEL'));
    });

    test('Tier 2 splits on " - " when relational data is missing', () async {
      const content = 'GROUP2\tMOLECULE A - MARQUE\t222222\t0';
      final cisToCip13 = {
        '222222': ['2222222222222'],
      };
      final medicamentCips = {'2222222222222'};

      final resultEither = await BdpmFileParser.parseGeneriques(
        _streamFromContent(content),
        cisToCip13,
        medicamentCips,
        const {},
        const {},
      );

      final result = resultEither.fold(
        ifLeft: (error) => fail('Expected success but got $error'),
        ifRight: (value) => value,
      );

      final group = result.generiqueGroups.firstWhere(
        (g) => g.groupId.value == 'GROUP2',
      );

      expect(group.parsingMethod.value, equals('text_split'));
      expect(group.libelle.value, equals('MOLECULE A'));
      expect(group.princepsLabel.value, equals('MARQUE'));
      expect(group.rawLabel.value, equals('MOLECULE A - MARQUE'));
    });

    test('Tier 3 smart split fixes dirty dash spacing', () async {
      const content = 'GROUP3\tMOLECULE Amg-MARQUE\t333333\t0';
      final cisToCip13 = {
        '333333': ['3333333333333'],
      };
      final medicamentCips = {'3333333333333'};

      final resultEither = await BdpmFileParser.parseGeneriques(
        _streamFromContent(content),
        cisToCip13,
        medicamentCips,
        const {},
        const {},
      );

      final result = resultEither.fold(
        ifLeft: (error) => fail('Expected success but got $error'),
        ifRight: (value) => value,
      );

      final group = result.generiqueGroups.firstWhere(
        (g) => g.groupId.value == 'GROUP3',
      );

      expect(group.parsingMethod.value, equals('text_smart_split'));
      expect(group.libelle.value, equals('MOLECULE Amg'));
      expect(group.princepsLabel.value, equals('MARQUE'));
      expect(group.rawLabel.value, equals('MOLECULE Amg-MARQUE'));
    });
  });
}
