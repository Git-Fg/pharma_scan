// test/test_utils.dart
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/logic/sanitizer.dart';

export 'helpers/pump_app.dart';

/// Fake PathProvider platform implementation for testing.
/// Provides a controlled documents path and temporary path for test isolation.
class FakePathProviderPlatform extends PathProviderPlatform {
  FakePathProviderPlatform(this._documentsPath);

  final String _documentsPath;
  String? _tempPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => _documentsPath;

  @override
  Future<String?> getTemporaryPath() async {
    // WHY: Return a fixed temporary path based on documents path to avoid
    // creating multiple temp directories that could cause infinite loops.
    // Create it once and reuse it for all subsequent calls.
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
/// This is required for aggregation to work correctly.
/// Call this after inserting batch data and before running aggregation.
Future<void> setPrincipeNormalizedForAllPrinciples(AppDatabase database) async {
  final allPrincipes = await (database.select(database.principesActifs)).get();
  for (final principe in allPrincipes) {
    final normalized = normalizePrincipleOptimal(principe.principe);
    await (database.update(database.principesActifs)..where(
          (tbl) =>
              tbl.codeCip.equals(principe.codeCip) &
              tbl.principe.equals(principe.principe),
        ))
        .write(
      PrincipesActifsCompanion(
        principeNormalized: Value(normalized),
      ),
    );
  }
}
