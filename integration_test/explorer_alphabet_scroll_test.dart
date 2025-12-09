import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pharma_scan/core/domain/types/ids.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import 'package:pharma_scan/features/explorer/domain/models/generic_group_entity.dart';
import 'package:pharma_scan/features/explorer/presentation/providers/generic_groups_provider.dart';
import 'package:pharma_scan/features/explorer/presentation/providers/search_provider.dart';
import 'package:pharma_scan/features/explorer/presentation/screens/database_search_view.dart';
import 'package:pharma_scan/features/explorer/presentation/widgets/alphabet_sidebar.dart';
import 'package:pharma_scan/features/home/providers/initialization_provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'alphabet sidebar scrolls to the correct group',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 900));
      addTearDown(tester.view.resetPhysicalSize);

      final overrides = [
        genericGroupsProvider.overrideWith(_LongListGroupsNotifier.new),
        initializationStepProvider.overrideWith(
          (ref) => Stream<InitializationStep>.value(InitializationStep.ready),
        ),
        searchResultsProvider.overrideWith(
          (ref, query) => Stream.value(const []),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: ShadApp.custom(
            theme: ShadThemeData(
              brightness: Brightness.light,
              colorScheme: const ShadSlateColorScheme.light(),
            ),
            appBuilder: (shadContext) {
              return MaterialApp(
                theme: Theme.of(shadContext),
                builder: (context, child) => ShadAppBuilder(child: child),
                home: const DatabaseSearchView(),
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Mystic Molecule'), findsNothing);

      await tester.tap(
        find.descendant(
          of: find.byType(AlphabetSidebar),
          matching: find.text('M'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle(const Duration(milliseconds: 400));

      expect(find.text('Mystic Molecule'), findsOneWidget);
    },
    timeout: const Timeout(Duration(seconds: 90)),
  );
}

class _LongListGroupsNotifier extends GenericGroupsNotifier {
  @override
  Future<GenericGroupsState> build() async {
    return GenericGroupsState(items: _buildLongListGroups());
  }
}

List<GenericGroupEntity> _buildLongListGroups() {
  const letters = [
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
    'G',
    'H',
    'J',
    'K',
    'L',
    'M',
    'N',
    'P',
    'R',
    'S',
    'T',
    'U',
    'V',
    'W',
    'X',
    'Y',
    'Z',
  ];

  return [
    for (var i = 0; i < letters.length; i++)
      GenericGroupEntity(
        groupId: GroupId.validated('GRP_${letters[i]}_$i'),
        commonPrincipes: 'Principe ${letters[i]}',
        princepsReferenceName: letters[i] == 'M'
            ? 'Mystic Molecule'
            : 'Group ${letters[i]}',
      ),
    GenericGroupEntity(
      groupId: GroupId.validated('GRP_A_EXTRA'),
      commonPrincipes: 'Principe A2',
      princepsReferenceName: 'Alpha Extra',
    ),
    GenericGroupEntity(
      groupId: GroupId.validated('GRP_B_EXTRA'),
      commonPrincipes: 'Principe B2',
      princepsReferenceName: 'Beta Extra',
    ),
  ];
}
