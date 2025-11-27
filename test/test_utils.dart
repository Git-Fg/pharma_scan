// test/test_utils.dart
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

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
