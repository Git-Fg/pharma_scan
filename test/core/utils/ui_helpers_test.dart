import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/utils/ui_helpers.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  test('getFormColor returns correct colors', () {
    const colors = ShadGreenColorScheme.light();

    expect(
      getFormColor(colors, 'Comprimé pelliculé'),
      equals(Colors.blue.shade600),
    );
    expect(
      getFormColor(colors, 'Sirop'),
      equals(Colors.orange.shade600),
    );
    expect(
      getFormColor(colors, null),
      equals(colors.muted),
    );
  });

  test('formatForClipboard creates correct string', () {
    final result = formatForClipboard(
      quantity: 5,
      label: 'DOLIPRANE',
      cip: '1234567890123',
    );

    expect(result, equals('5 x DOLIPRANE (CIP: 1234567890123)'));
  });
}
