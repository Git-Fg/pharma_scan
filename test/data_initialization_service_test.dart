// test/data_initialization_service_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';

import 'test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late DataInitializationService dataInitializationService;
  late Directory documentsDir;

  setUp(() async {
    documentsDir = await Directory.systemTemp.createTemp('pharma_scan_test_');
    PathProviderPlatform.instance = FakePathProviderPlatform(documentsDir.path);

    // For each test, create a fresh in-memory database
    final dbFile = File(p.join(documentsDir.path, 'medicaments.db'));
    database = AppDatabase.forTesting(
      NativeDatabase(dbFile, setup: configureAppSQLite),
    );

    dataInitializationService = DataInitializationService(database: database);
  });

  tearDown(() async {
    // Close the database and reset the locator after each test
    await database.close();
    if (documentsDir.existsSync()) {
      await documentsDir.delete(recursive: true);
    }
  });

  group('DataInitializationService - Parsing Logic', () {
    test(
      'should correctly parse CIS_bdpm.txt for clean medication names',
      () async {
        const testContent = '''
60002283	ARIMIDEX 1 mg, comprimé
60004932	GLUCOPHAGE 500 mg, comprimé
60009111	RANITIDINE BIOGARAN 150 mg, comprimé
''';

        final tempDir = await Directory.systemTemp.createTemp(
          'pharma_scan_test',
        );
        final specialitesFile = File('${tempDir.path}/CIS_bdpm.txt');
        await specialitesFile.writeAsString(testContent, encoding: latin1);

        final specialites = <Map<String, dynamic>>[];
        final seenCis = <String>{};
        final content = latin1.decode(specialitesFile.readAsBytesSync());

        for (final line in content.split('\n')) {
          final parts = line.split('\t');
          if (parts.length >= 2) {
            final cis = parts[0].trim();
            final nom = parts[1].trim();
            if (cis.isNotEmpty && nom.isNotEmpty && seenCis.add(cis)) {
              specialites.add({'cis_code': cis, 'nom_specialite': nom});
            }
          }
        }

        // THEN: Verify clean names are correctly parsed
        expect(specialites.length, 3);
        expect(specialites.any((s) => s['cis_code'] == '60002283'), isTrue);
        expect(
          specialites.firstWhere(
            (s) => s['cis_code'] == '60002283',
          )['nom_specialite'],
          'ARIMIDEX 1 mg, comprimé',
        );
        expect(specialites.any((s) => s['cis_code'] == '60004932'), isTrue);
        expect(
          specialites.firstWhere(
            (s) => s['cis_code'] == '60004932',
          )['nom_specialite'],
          'GLUCOPHAGE 500 mg, comprimé',
        );

        // Cleanup
        await tempDir.delete(recursive: true);
      },
    );

    test('should correctly parse procedure type from CIS_bdpm.txt', () async {
      const testContent = '''
60002283	ARIMIDEX 1 mg, comprimé	Comprimé	Orale	Commercialisée	Enreg homéo (Proc. Nat.)
60004932	GLUCOPHAGE 500 mg, comprimé	Comprimé	Orale	Commercialisée	Autorisation
''';

      final tempDir = await Directory.systemTemp.createTemp('pharma_scan_test');
      final specialitesFile = File('${tempDir.path}/CIS_bdpm.txt');
      await specialitesFile.writeAsString(testContent, encoding: latin1);

      final specialites = <Map<String, dynamic>>[];
      final seenCis = <String>{};
      final content = latin1.decode(specialitesFile.readAsBytesSync());

      for (final line in content.split('\n')) {
        final parts = line.split('\t');
        // The procedure type is at column index 5
        if (parts.length >= 6) {
          final cis = parts[0].trim();
          final nom = parts[1].trim();
          final procedure = parts[5].trim();
          if (cis.isNotEmpty &&
              nom.isNotEmpty &&
              procedure.isNotEmpty &&
              seenCis.add(cis)) {
            specialites.add({
              'cis_code': cis,
              'nom_specialite': nom,
              'procedure_type': procedure,
            });
          }
        }
      }

      // THEN: Verify procedure types are correctly parsed
      expect(specialites.length, 2);

      final entry1 = specialites.firstWhere((s) => s['cis_code'] == '60002283');
      expect(entry1['procedure_type'], isNotNull);
      expect(entry1['procedure_type'].toString(), contains('homéo'));

      final entry2 = specialites.firstWhere((s) => s['cis_code'] == '60004932');
      expect(entry2['procedure_type'], isNotNull);
      expect(entry2['procedure_type'].toString(), 'Autorisation');

      // Cleanup
      await tempDir.delete(recursive: true);
    });

    test(
      'should correctly parse CIS_CIP_bdpm.txt with correct column indices',
      () async {
        const testContent = '''
60002283	4949729	plaquette(s) PVC... de 30 comprimé(s)	Présentation active	Déclaration de commercialisation	16/03/2011	3400949497294
60002283	4949770	autre présentation...	Présentation active	Déclaration	20/05/2011	3400949497706
60004932	1234567	comprimé...	Présentation active	Déclaration	01/01/2020	3400912345678
''';

        // Create a temporary file with test data
        final tempDir = await Directory.systemTemp.createTemp(
          'pharma_scan_test',
        );
        final medicamentsFile = File('${tempDir.path}/CIS_CIP_bdpm.txt');
        await medicamentsFile.writeAsString(testContent, encoding: latin1);

        // Mock the parsing logic by directly reading the test file
        final cisToCip13 = <String, List<String>>{};
        final medicaments = <Map<String, dynamic>>[];

        final content = latin1.decode(medicamentsFile.readAsBytesSync());
        for (final line in content.split('\n')) {
          final parts = line.split('\t');
          if (parts.length >= 7) {
            final cis = parts[0].trim();
            final nom = parts[2].trim(); // Index 2 for libellé
            final cip13 = parts[6].trim(); // Index 6 for CIP13

            if (cis.isNotEmpty && cip13.isNotEmpty && nom.isNotEmpty) {
              cisToCip13.putIfAbsent(cis, () => []).add(cip13);
              medicaments.add({'code_cip': cip13, 'cis_code': cis});
            }
          }
        }

        // THEN: Verify the parsing logic correctly extracts data
        expect(cisToCip13['60002283'], isNotNull);
        expect(
          cisToCip13['60002283']!.length,
          2,
        ); // Same CIS has 2 different CIP13s
        expect(cisToCip13['60002283'], contains('3400949497294'));
        expect(cisToCip13['60002283'], contains('3400949497706'));
        expect(cisToCip13['60004932']!.length, 1);
        expect(cisToCip13['60004932']!.first, '3400912345678');
        expect(medicaments.length, 3);

        // Cleanup
        await tempDir.delete(recursive: true);
      },
    );

    test(
      'should correctly parse CIS_COMPO_bdpm.txt filtering for SA only',
      () async {
        const testContent = '''
60002283	comprimé	42215	ANASTROZOLE	1,00 mg	un comprimé	SA	1
60004932	comprimé	12345	METFORMINE	500,00 mg	un comprimé	FT	1
60004932	comprimé	67890	CHLORHYDRATE DE METFORMINE	500,00 mg	un comprimé	SA	1
''';

        final tempDir = await Directory.systemTemp.createTemp(
          'pharma_scan_test',
        );
        final compositionsFile = File('${tempDir.path}/CIS_COMPO_bdpm.txt');
        await compositionsFile.writeAsString(testContent, encoding: latin1);

        final cisToCip13 = <String, List<String>>{
          '60002283': ['3400949497294'],
          '60004932': ['3400912345678'],
        };

        final principes = <Map<String, dynamic>>[];
        final content = latin1.decode(compositionsFile.readAsBytesSync());

        for (final line in content.split('\n')) {
          final parts = line.split('\t');
          if (parts.length >= 8 && parts[6].trim() == 'SA') {
            final cis = parts[0].trim();
            final principe = parts[3].trim(); // Index 3 for dénomination
            final cip13s = cisToCip13[cis];

            if (cip13s != null && principe.isNotEmpty) {
              for (final cip13 in cip13s) {
                principes.add({'code_cip': cip13, 'principe': principe});
              }
            }
          }
        }

        // THEN: Verify only SA substances are extracted (FT should be ignored)
        expect(principes.length, 2); // Only 2 SA substances
        expect(principes.any((p) => p['principe'] == 'ANASTROZOLE'), isTrue);
        expect(
          principes.any((p) => p['principe'] == 'CHLORHYDRATE DE METFORMINE'),
          isTrue,
        );
        expect(
          principes.any((p) => p['principe'] == 'METFORMINE'),
          isFalse,
        ); // FT should be filtered out

        // Cleanup
        await tempDir.delete(recursive: true);
      },
    );

    test(
      'should correctly parse CIS_GENER_bdpm.txt with group relationships',
      () async {
        const testContent = '''
1	CIMETIDINE 200 mg	60001234	0	1
1	CIMETIDINE 200 mg	60005678	1	2
7	RANITIDINE 150 mg	60009111	0	1
7	RANITIDINE 150 mg	60009222	0	2
7	RANITIDINE 150 mg	60009333	1	3
''';

        final tempDir = await Directory.systemTemp.createTemp(
          'pharma_scan_test',
        );
        final generiquesFile = File('${tempDir.path}/CIS_GENER_bdpm.txt');
        await generiquesFile.writeAsString(testContent, encoding: latin1);

        final cisToCip13 = <String, List<String>>{
          '60001234': ['3400912345678'],
          '60005678': ['3400956789012'],
          '60009111': ['3400991112223'], // First princeps in group 7
          '60009222': ['3400992223334'], // Second princeps in group 7
          '60009333': ['3400993334445'], // Generic in group 7
        };

        final generiqueGroups = <Map<String, dynamic>>[];
        final groupMembers = <Map<String, dynamic>>[];
        final seenGroups = <String>{};

        final content = latin1.decode(generiquesFile.readAsBytesSync());
        for (final line in content.split('\n')) {
          final parts = line.split('\t');
          if (parts.length >= 5) {
            final groupId = parts[0].trim();
            final libelle = parts[1].trim();
            final cis = parts[2].trim();
            final type = int.tryParse(parts[3].trim());

            final cip13s = cisToCip13[cis];
            // CORRECTED: A generic can be type 1, 2, or 4.
            final isPrinceps = type == 0;
            final isGeneric = type == 1 || type == 2 || type == 4;

            if (cip13s != null && (isPrinceps || isGeneric)) {
              if (seenGroups.add(groupId)) {
                generiqueGroups.add({'group_id': groupId, 'libelle': libelle});
              }

              // Store consistently as 0 for princeps and 1 for all generic types
              for (final cip13 in cip13s) {
                groupMembers.add({
                  'code_cip': cip13,
                  'group_id': groupId,
                  'type': isPrinceps ? 0 : 1,
                });
              }
            }
          }
        }

        // THEN: Verify groups and members are correctly parsed
        expect(generiqueGroups.length, 2);
        expect(groupMembers.length, 5); // All 5 entries

        // Group 1: 1 princeps + 1 generic (type 1 stored as 1)
        final group1Members = groupMembers
            .where((m) => m['group_id'] == '1')
            .toList();
        expect(group1Members.length, 2);
        expect(
          group1Members.where((m) => m['type'] == 0).length,
          1,
        ); // 1 princeps
        expect(
          group1Members.where((m) => m['type'] == 1).length,
          1,
        ); // 1 generic (type 1 stored as 1)

        // Group 7: 2 princeps + 1 generic (type 1 stored as 1)
        final group7Members = groupMembers
            .where((m) => m['group_id'] == '7')
            .toList();
        expect(group7Members.length, 3);
        expect(
          group7Members.where((m) => m['type'] == 0).length,
          2,
        ); // 2 princeps
        expect(
          group7Members.where((m) => m['type'] == 1).length,
          1,
        ); // 1 generic (type 1 stored as 1)

        // Cleanup
        await tempDir.delete(recursive: true);
      },
    );

    test(
      'should correctly parse generic types 2 and 4 from CIS_GENER_bdpm.txt',
      () async {
        const testContent = '''
10	MEDICAMENT TEST	60001000	0	1
10	MEDICAMENT TEST	60001001	1	2
10	MEDICAMENT TEST	60001002	2	3
10	MEDICAMENT TEST	60001003	4	4
''';

        final tempDir = await Directory.systemTemp.createTemp(
          'pharma_scan_test',
        );
        final generiquesFile = File('${tempDir.path}/CIS_GENER_bdpm.txt');
        await generiquesFile.writeAsString(testContent, encoding: latin1);

        final cisToCip13 = <String, List<String>>{
          '60001000': ['3400910000001'], // Princeps
          '60001001': ['3400910000002'], // Generic type 1
          '60001002': ['3400910000003'], // Generic type 2
          '60001003': ['3400910000004'], // Generic type 4
        };

        final generiqueGroups = <Map<String, dynamic>>[];
        final groupMembers = <Map<String, dynamic>>[];
        final seenGroups = <String>{};

        final content = latin1.decode(generiquesFile.readAsBytesSync());
        for (final line in content.split('\n')) {
          final parts = line.split('\t');
          if (parts.length >= 5) {
            final groupId = parts[0].trim();
            final libelle = parts[1].trim();
            final cis = parts[2].trim();
            final type = int.tryParse(parts[3].trim());

            final cip13s = cisToCip13[cis];
            // CORRECTED: A generic can be type 1, 2, or 4.
            final isPrinceps = type == 0;
            final isGeneric = type == 1 || type == 2 || type == 4;

            if (cip13s != null && (isPrinceps || isGeneric)) {
              if (seenGroups.add(groupId)) {
                generiqueGroups.add({'group_id': groupId, 'libelle': libelle});
              }

              // Store consistently as 0 for princeps and 1 for all generic types
              for (final cip13 in cip13s) {
                groupMembers.add({
                  'code_cip': cip13,
                  'group_id': groupId,
                  'type': isPrinceps ? 0 : 1,
                });
              }
            }
          }
        }

        // THEN: Verify that types 2 and 4 are correctly identified as generics and stored as type 1
        expect(generiqueGroups.length, 1);
        expect(groupMembers.length, 4); // Princeps + 3 generics (types 1, 2, 4)

        final group10Members = groupMembers
            .where((m) => m['group_id'] == '10')
            .toList();
        expect(group10Members.length, 4);
        expect(
          group10Members.where((m) => m['type'] == 0).length,
          1,
        ); // 1 princeps
        expect(
          group10Members.where((m) => m['type'] == 1).length,
          3,
        ); // 3 generics (types 1, 2, and 4 all stored as 1)

        // Verify that type 2 and 4 were included (they would be excluded if we only checked type == 1)
        expect(
          group10Members.where((m) => m['code_cip'] == '3400910000003').length,
          1,
        ); // Generic type 2 included
        expect(
          group10Members.where((m) => m['code_cip'] == '3400910000004').length,
          1,
        ); // Generic type 4 included

        // Cleanup
        await tempDir.delete(recursive: true);
      },
    );

    test(
      'should handle one-to-many CIS to CIP13 relationship correctly',
      () async {
        final cisToCip13 = <String, List<String>>{};
        final medicamentCips = <String>{};
        final medicaments = <Map<String, dynamic>>[];

        // Simulate parsing where same CIS appears with different CIP13s
        final testData = [
          {'cis': '60002283', 'cip13': '3400949497294'},
          {'cis': '60002283', 'cip13': '3400949497706'},
          {'cis': '60002283', 'cip13': '3400949497890'},
        ];

        for (final entry in testData) {
          final cis = entry['cis']!;
          final cip13 = entry['cip13']!;

          cisToCip13.putIfAbsent(cis, () => []).add(cip13);
          if (medicamentCips.add(cip13)) {
            medicaments.add({'code_cip': cip13});
          }
        }

        // THEN: All CIP13s should be associated with the same CIS
        expect(cisToCip13['60002283'], isNotNull);
        expect(cisToCip13['60002283']!.length, 3); // Three different packagings
        expect(medicaments.length, 3); // All three medicaments should be stored

        // WHEN: We associate this CIS with a group, all CIP13s should be included
        final groupMembers = <Map<String, dynamic>>[];
        final cip13s = cisToCip13['60002283']!;
        for (final cip13 in cip13s) {
          if (medicamentCips.contains(cip13)) {
            groupMembers.add({
              'code_cip': cip13,
              'group_id': 'TEST_GROUP',
              'type': 0, // All are princeps
            });
          }
        }

        // THEN: All three CIP13s should be group members
        expect(groupMembers.length, 3);
        expect(
          groupMembers.every((m) => m['group_id'] == 'TEST_GROUP'),
          isTrue,
        );
      },
    );
  });

  group('DataInitializationService - Aggregation & Parser', () {
    test('aggregates canonical names, brand names, and cluster keys', () async {
      await database.databaseDao.clearDatabase();

      await database.databaseDao.insertBatchData(
        specialites: [
          {
            'cis_code': 'CIS_PRINCEPS',
            'nom_specialite': 'CADUET 5 mg/10 mg, comprimé',
            'procedure_type': 'Autorisation',
            'forme_pharmaceutique': 'Comprimé',
            'etat_commercialisation': 'Commercialisé',
            'titulaire': 'PFIZER',
            'conditions_prescription': null,
          },
          {
            'cis_code': 'CIS_GENERIC',
            'nom_specialite': 'CADUET MYLAN 5 mg/10 mg, comprimé',
            'procedure_type': 'Autorisation',
            'forme_pharmaceutique': 'Comprimé',
            'etat_commercialisation': 'Commercialisé',
            'titulaire': 'MYLAN',
            'conditions_prescription': null,
          },
        ],
        medicaments: [
          {'code_cip': 'CIP_PRINCEPS', 'cis_code': 'CIS_PRINCEPS'},
          {'code_cip': 'CIP_GENERIC', 'cis_code': 'CIS_GENERIC'},
        ],
        principes: [
          {
            'code_cip': 'CIP_PRINCEPS',
            'principe': 'AMLODIPINE',
            'dosage': '5',
            'dosage_unit': 'mg',
          },
          {
            'code_cip': 'CIP_PRINCEPS',
            'principe': 'ATORVASTATINE',
            'dosage': '10',
            'dosage_unit': 'mg',
          },
          {
            'code_cip': 'CIP_GENERIC',
            'principe': 'AMLODIPINE',
            'dosage': '5',
            'dosage_unit': 'mg',
          },
          {
            'code_cip': 'CIP_GENERIC',
            'principe': 'ATORVASTATINE',
            'dosage': '10',
            'dosage_unit': 'mg',
          },
        ],
        generiqueGroups: [
          {
            'group_id': 'GROUP_CADUET',
            'libelle': 'CADUET 5 mg/10 mg, comprimé',
          },
        ],
        groupMembers: [
          {'code_cip': 'CIP_PRINCEPS', 'group_id': 'GROUP_CADUET', 'type': 0},
          {'code_cip': 'CIP_GENERIC', 'group_id': 'GROUP_CADUET', 'type': 1},
        ],
      );

      await dataInitializationService.runSummaryAggregationForTesting();

      final summaries = await database.select(database.medicamentSummary).get();
      expect(summaries.length, 2);

      final princepsSummary = summaries.firstWhere(
        (row) => row.cisCode == 'CIS_PRINCEPS',
      );
      expect(princepsSummary.nomCanonique, 'CADUET 5 mg/10 mg, comprimé');
      expect(princepsSummary.princepsBrandName, 'CADUET 5 mg/10 mg, comprimé');

      final genericSummary = summaries.firstWhere(
        (row) => row.cisCode == 'CIS_GENERIC',
      );
      expect(genericSummary.nomCanonique, 'CADUET 5 mg/10 mg, comprimé');
    });
  });
}
