// test/test_utils.dart
// Test utilities for external DB-driven architecture - companion types from generated code

import 'dart:io';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/logic/sanitizer.dart';

export 'helpers/pump_app.dart';
export 'test_compatibility.dart';

class FakePathProviderPlatform extends PathProviderPlatform {
  FakePathProviderPlatform(this._documentsPath);

  final String _documentsPath;
  String? _tempPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => _documentsPath;

  @override
  Future<String?> getTemporaryPath() async {
    if (_tempPath == null) {
      _tempPath = p.join(_documentsPath, 'temp');
      final tempDir = Directory(_tempPath!);
      if (!tempDir.existsSync()) {
        await tempDir.create(recursive: true);
      }
    }
    return _tempPath;
  }
}

/// Sets principe_normalized for all principles in the database.
/// This is used in tests to ensure principe_normalized is populated before aggregation.
Future<void> setPrincipeNormalizedForAllPrinciples(AppDatabase database) async {
  final allPrincipes = await database.select(database.principesActifs).get();

  for (final principe in allPrincipes) {
    if (principe.principeNormalized == null) {
      // Use normalizeForSearch to set principe_normalized
      final normalized = normalizeForSearch(principe.principe);
      // Use raw SQL update to avoid dependency on generated companion types
      await database.customUpdate(
        'UPDATE principes_actifs SET principe_normalized = ? WHERE id = ?',
        variables: [
          Variable.withString(normalized),
          Variable.withInt(principe.id),
        ],
        updates: {database.principesActifs},
      );
    }
  }
}

// All buildXCompanion helper functions and IngestionBatch have been removed.
// Tests should use raw SQL inserts (customInsert/customUpdate) instead.
// See docs/TESTING.md for SQL-first testing patterns.

/// Generates a GS1 DataMatrix string for testing.
/// Format: 01{gtin}21{serial}10{lot}17{expDate}
/// Uses space separators for readability in tests.
/// GS1 AI 01 expects a 14-digit GTIN, so 13-digit CIPs are padded with leading 0.
String generateGs1String(
  String gtin, {
  String? serial,
  String? lot,
  String? expDate,
}) {
  final buffer = StringBuffer();
  // GS1 AI 01 requires 14 digits. If gtin is 13 digits (CIP), prepend 0.
  final gtin14 = gtin.length == 13 ? '0$gtin' : gtin;
  buffer.write('01$gtin14');
  if (serial != null) {
    buffer.write(' 21$serial');
  }
  if (lot != null) {
    buffer.write(' 10$lot');
  }
  if (expDate != null) {
    buffer.write(' 17$expDate');
  }
  return buffer.toString();
}

/// Generates a simple GS1 string with just GTIN (no serial/lot/expDate).
String generateSimpleGs1String(String gtin) {
  return '01$gtin';
}
