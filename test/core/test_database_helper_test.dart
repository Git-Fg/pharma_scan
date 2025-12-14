import 'dart:io';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:pharma_scan/core/config/database_config.dart';
import '../../patrol_test/helpers/test_database_helper.dart';
import '../helpers/fake_path_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PathProviderPlatform? previous;
  setUp(() {
    previous = PathProviderPlatform.instance;
  });
  tearDown(() {
    if (previous != null) PathProviderPlatform.instance = previous!;
    // Clear any mock handlers
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
  });

  // Provide a basic mock for asset loading used by TestDatabaseHelper
  ByteData _makeAssetBytes() {
    final bytes = List<int>.filled(128, 0);
    return ByteData.view(Uint8List.fromList(bytes).buffer);
  }

  Future<void> _mockAssetBundle() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (ByteData? message) async {
      final key = utf8.decode(message!.buffer.asUint8List());
      if (key == 'assets/test/reference.db') return _makeAssetBytes();
      return null;
    });
  }

  test('injectTestDatabase writes files when PathProvider returns a valid dir',
      () async {
    final tmp = await Directory.systemTemp.createTemp('pharma_scan_test_unit_');
    PathProviderPlatform.instance =
        FakePathProviderPlatform(documentsPath: tmp.path);

    await _mockAssetBundle();

    await TestDatabaseHelper.injectTestDatabase();

    final refDb = File('${tmp.path}/${DatabaseConfig.dbFilename}');
    expect(await refDb.exists(), isTrue);

    await tmp.delete(recursive: true);
  });

  test(
      'injectTestDatabase falls back to temp dir when PathProvider plugin is missing',
      () async {
    PathProviderPlatform.instance =
        FakePathProviderPlatform(documentsPath: '', throwOnGet: true);

    await _mockAssetBundle();

    // Should not throw even when PathProvider throws
    await TestDatabaseHelper.injectTestDatabase();

    // Ensure a reference.db exists under system temp somewhere
    File? found;
    await for (final e in Directory.systemTemp.list(recursive: true)) {
      if (e is File && e.path.endsWith(DatabaseConfig.dbFilename)) {
        found = e;
        break;
      }
    }

    expect(found, isNotNull,
        reason: 'expected to find a reference DB in system temp');
  });
}
