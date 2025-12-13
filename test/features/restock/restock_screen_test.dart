import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../robots/restock_robot.dart';

void main() {
  testWidgets('Restock screen shows clear buttons', (tester) async {
    // 1. Init Robot
    final robot = RestockRobot(tester);

    // 2. Setup with default providers
    await robot.pumpScreen(overrides: []);

    // 3. Vérification que les boutons sont présents
    expect(robot.clearAllButton, findsOneWidget);
    expect(find.byIcon(LucideIcons.check), findsOneWidget);
  });

  testWidgets('Clear All button shows confirmation dialog', (tester) async {
    // 1. Init Robot
    final robot = RestockRobot(tester);

    // 2. Setup with default providers
    await robot.pumpScreen(overrides: []);

    // 3. Interaction - click Clear All button
    await robot.tapClearAll();

    // 4. Vérification que le dialogue apparaît
    expect(find.byType(ShadDialog), findsOneWidget);
    expect(robot.hasDialog(), true);
  });
}
