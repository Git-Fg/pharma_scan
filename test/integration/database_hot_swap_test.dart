import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/database/providers.dart';
import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:drift/native.dart';

void main() {
  testWidgets('Hot Swap: Database connection renews after file replacement',
      (tester) async {
    final tempDir = await Directory.systemTemp.createTemp('hot_swap_test');
    final dbPath = p.join(tempDir.path, 'app.db');

    final db1 = NativeDatabase(File(dbPath));
    final appDb1 = AppDatabase.forTesting(db1);
    await appDb1.customStatement(
        "CREATE TABLE IF NOT EXISTS test_marker (version INTEGER)");
    await appDb1.customStatement("INSERT INTO test_marker VALUES (1)");
    await appDb1.close();

    final container = ProviderContainer();

    // ignore: avoid_print
    print('Opening V1...');
    var currentDb = container.read(databaseProvider(overridePath: dbPath));
    final version1 = await currentDb
        .customSelect('SELECT version FROM test_marker')
        .getSingle();
    expect(version1.read<int>('version'), 1);

    // ignore: avoid_print
    print('Simulating Update...');
    container.invalidate(databaseProvider);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final db2 = NativeDatabase(File(dbPath));
    final appDb2 = AppDatabase.forTesting(db2);
    await appDb2.customStatement(
        "CREATE TABLE IF NOT EXISTS test_marker (version INTEGER)");
    await appDb2.customStatement("DELETE FROM test_marker");
    await appDb2.customStatement("INSERT INTO test_marker VALUES (2)");
    await appDb2.close();

    // ignore: avoid_print
    print('Re-opening V2...');
    currentDb = container.read(databaseProvider(overridePath: dbPath));
    try {
      final version2 = await currentDb
          .customSelect('SELECT version FROM test_marker')
          .getSingle();
      expect(version2.read<int>('version'), 2);
      // ignore: avoid_print
      print('✅ Success: Swapped from V1 to V2 without crash.');
    } catch (e) {
      fail('❌ Crash after swap: $e');
    }

    container.dispose();
  });
}
