import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/widgets/ui_kit/product_badges.dart';

import '../../../helpers/pump_app.dart';

void main() {
  testWidgets('renders complementary badge label for type 2', (tester) async {
    await tester.pumpApp(
      const Scaffold(
        body: ProductTypeBadge(memberType: 2),
      ),
    );

    expect(find.text(Strings.badgeGenericComplementary), findsOneWidget);
  });

  testWidgets('renders substitutable badge label for type 4', (tester) async {
    await tester.pumpApp(
      const Scaffold(
        body: ProductTypeBadge(memberType: 4),
      ),
    );

    expect(find.text(Strings.badgeGenericSubstitutable), findsOneWidget);
  });
}
