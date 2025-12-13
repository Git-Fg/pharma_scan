import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/logic/sanitizer.dart';

void main() {
  group('normalizeForSearch parity with backend', () {
    late List<Map<String, dynamic>> fixtures;

    setUpAll(() async {
      final file = File('test/assets/normalization_fixtures.json');
      final content = await file.readAsString();
      final decoded = json.decode(content) as List;
      fixtures = decoded.cast<Map<String, dynamic>>();
    });

    test('Dart sanitizer matches backend for all tricky cases', () {
      for (final entry in fixtures) {
        final input = entry['input'] as String;
        final expected = entry['output'] as String;
        final result = normalizeForSearch(input);
        expect(result, expected, reason: 'Input: $input');
      }
    });
  });
}
