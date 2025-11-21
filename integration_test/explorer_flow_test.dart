// integration_test/explorer_flow_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import 'package:pharma_scan/core/services/drift_database_service.dart';
import 'package:pharma_scan/features/explorer/repositories/explorer_repository.dart';
import 'package:pharma_scan/features/explorer/widgets/medicament_card.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/features/scanner/models/medicament_model.dart';
import 'package:pharma_scan/features/scanner/models/scan_result_model.dart';
import 'package:pharma_scan/features/scanner/repositories/scanner_repository.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../test/fixtures/data_factory.dart';
import '../test/robots/explorer_robot.dart';
import 'test_bootstrap.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late DriftDatabaseService dbService;
  late DataInitializationService dataInitializationService;

  setUpAll(() async {
    final container = await ensureIntegrationTestContainer();
    dbService = container.read(driftDatabaseServiceProvider);
    dataInitializationService = container.read(
      dataInitializationServiceProvider,
    );
  });

  // Nettoyer et réinitialiser la base de données avant chaque test
  setUp(() async {
    await dbService.clearDatabase();
  });

  group('Explorer Flow Integration Tests', () {
    testWidgets(
      'should correctly classify product groups with princeps and generics',
      (WidgetTester tester) async {
        // GIVEN: Database with a complete group (princeps + generics)
        final batch = DataFactory.createBasicGroup(
          groupId: 'GROUP_1',
          princepsCip: 'PRINCEPS_CIP',
          genericCip: 'GENERIC_CIP',
          princepsCis: 'CIS_PRINCEPS',
          genericCis: 'CIS_GENERIC',
          princepsName: 'PRINCEPS DRUG',
          genericName: 'GENERIC DRUG',
          princepsLab: 'PRINCEPS LAB',
          genericLab: 'GENERIC LAB',
          molecule: 'ACTIVE_PRINCIPLE',
          dosage: '500',
          dosageUnit: 'mg',
        );
        await dbService.insertBatchData(
          specialites: batch.specialites,
          medicaments: batch.medicaments,
          principes: batch.principes,
          generiqueGroups: batch.generiqueGroups,
          groupMembers: batch.groupMembers,
        );

        // Populate medicament_summary table
        await dataInitializationService.runSummaryAggregationForTesting();

        // WHEN: Classify the group
        final explorerRepository = ExplorerRepository(dbService);
        final classification = await explorerRepository.classifyProductGroup(
          'GROUP_1',
        );

        // THEN: Verify classification logic correctly identifies and groups medicaments
        final princepsList = classification!.princeps
            .expand((bucket) => bucket.medicaments)
            .toList();
        final genericsList = classification.generics
            .expand((bucket) => bucket.medicaments)
            .toList();

        expect(princepsList, hasLength(1));
        expect(princepsList.first.codeCip, 'PRINCEPS_CIP');
        // Parser strips lab name "PRINCEPS LAB" from "PRINCEPS DRUG", leaving "DRUG"
        expect(princepsList.first.nom, 'DRUG');

        expect(genericsList, hasLength(1));
        expect(genericsList.first.codeCip, 'GENERIC_CIP');
        // Parser strips lab name "GENERIC LAB" from "GENERIC DRUG", leaving "DRUG"
        expect(genericsList.first.nom, 'DRUG');

        // Verify scan result correctly identifies princeps type
        final scannerRepository = ScannerRepository(dbService);
        final scanResult = await scannerRepository.getScanResult(
          'PRINCEPS_CIP',
        );
        switch (scanResult!) {
          case GenericScanResult():
            fail('Expected PrincepsScanResult but got GenericScanResult');
          case PrincepsScanResult(
            princeps: final princeps,
            groupId: final groupId,
          ):
            expect(princeps.codeCip, 'PRINCEPS_CIP');
            expect(groupId, 'GROUP_1');
          case StandaloneScanResult():
            fail('Expected PrincepsScanResult but got StandaloneScanResult');
        }
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    testWidgets(
      'should correctly group multiple princeps by dosage',
      (WidgetTester tester) async {
        // GIVEN: Database with a group containing multiple princeps with different dosages
        final batch = DataFactory.createPrincepsOnlyGroup(
          groupId: 'GROUP_1',
          molecule: 'ACTIVE_PRINCIPLE',
          princepsDefinitions: [
            (
              cip: 'CIP1',
              cis: 'CIS_1',
              name: 'MEDICAMENT 100mg',
              dosage: '100',
            ),
            (cip: 'CIP2', cis: 'CIS_2', name: 'MEDICAMENT 50mg', dosage: '50'),
            (
              cip: 'CIP3',
              cis: 'CIS_3',
              name: 'MEDICAMENT 200mg',
              dosage: '200',
            ),
          ],
        );
        await dbService.insertBatchData(
          specialites: batch.specialites,
          medicaments: batch.medicaments,
          principes: batch.principes,
          generiqueGroups: batch.generiqueGroups,
          groupMembers: batch.groupMembers,
        );

        // Populate medicament_summary table
        await dataInitializationService.runSummaryAggregationForTesting();

        // WHEN: Classify the group
        final explorerRepository = ExplorerRepository(dbService);
        final classification = await explorerRepository.classifyProductGroup(
          'GROUP_1',
        );

        // THEN: Verify all princeps are correctly identified and grouped
        final princepsList = classification!.princeps
            .expand((bucket) => bucket.medicaments)
            .toList();
        expect(princepsList, hasLength(3));
        expect(princepsList.map((m) => m.codeCip).toSet(), {
          'CIP1',
          'CIP2',
          'CIP3',
        });
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    testWidgets('ExplorerRobot drives a simple search flow', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ShadApp(
          debugShowCheckedModeBanner: false,
          themeMode: ThemeMode.light,
          theme: ShadThemeData(
            brightness: Brightness.light,
            colorScheme: const ShadZincColorScheme.light(),
          ),
          darkTheme: ShadThemeData(
            brightness: Brightness.dark,
            colorScheme: const ShadSlateColorScheme.dark(),
          ),
          home: const _ExplorerSearchHarness(
            medicaments: _robotMedicamentFixtures,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final robot = ExplorerRobot(tester);
      await robot.searchFor('doli');
      robot.expectResultCount(2);

      await robot.searchFor('efferalgan');
      robot.expectResultCount(1);

      await robot.tapResult('Efferalgan 1000mg');
      expect(find.text('Selected: Efferalgan 1000mg'), findsOneWidget);
    });
  });
}

const List<Medicament> _robotMedicamentFixtures = [
  Medicament(
    nom: 'Doliprane 500mg',
    codeCip: 'CIP_DOLI_500',
    titulaire: 'Sanofi',
    conditionsPrescription: 'OTC',
  ),
  Medicament(
    nom: 'Doliprane 1000mg',
    codeCip: 'CIP_DOLI_1000',
    titulaire: 'Sanofi',
    conditionsPrescription: 'OTC',
  ),
  Medicament(
    nom: 'Efferalgan 1000mg',
    codeCip: 'CIP_EFF_1000',
    titulaire: 'UPSA',
    conditionsPrescription: 'OTC',
  ),
];

class _ExplorerSearchHarness extends StatefulWidget {
  const _ExplorerSearchHarness({required this.medicaments});

  final List<Medicament> medicaments;

  @override
  State<_ExplorerSearchHarness> createState() => _ExplorerSearchHarnessState();
}

class _ExplorerSearchHarnessState extends State<_ExplorerSearchHarness> {
  late final TextEditingController _controller;
  String _query = '';
  String _selectedName = 'None';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController()..addListener(_handleQueryChanged);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleQueryChanged)
      ..dispose();
    super.dispose();
  }

  void _handleQueryChanged() {
    setState(() {
      _query = _controller.text.trim();
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.medicaments.where((medicament) {
      final normalizedQuery = _query.toLowerCase();
      if (normalizedQuery.isEmpty) return true;
      return medicament.nom.toLowerCase().contains(normalizedQuery);
    }).toList();

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Semantics(
              textField: true,
              label: Strings.searchLabel,
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  labelText: Strings.searchLabel,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Selected: $_selectedName'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final medicament = filtered[index];
                  return MedicamentCard(
                    medicament: medicament,
                    onTap: () {
                      setState(() => _selectedName = medicament.nom);
                    },
                  );
                },
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
