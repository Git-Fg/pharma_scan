// test/test_utils.dart
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

export 'helpers/pump_app.dart';

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