import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/services/logger_service.dart';
import 'package:talker_flutter/talker_flutter.dart'; // Needed for Talker getter

class MockLogger implements LoggerService {
  @override
  void db(String message) {
    print('[DB] $message');
  }

  @override
  void debug(String message, [Object? error, StackTrace? stackTrace]) {
    print('[DEBUG] $message');
  }

  @override
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    print('[ERROR] $message');
  }

  @override
  void info(String message) {
    print('[INFO] $message');
  }

  @override
  void warning(String message, [Object? error, StackTrace? stackTrace]) {
    print('[WARN] $message');
  }

  @override
  void init() {}

  @override
  Talker get talker => TalkerFlutter.init(); // Dummy talker
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Debug Explorer Data', (tester) async {
    final logger = MockLogger();
    final db = AppDatabase(logger);
    final clusters =
        await db.explorerDao.watchAllClustersOrderedByPrinceps().first;

    print('--- CLUSTER DEBUG ---');
    for (var c in clusters.take(50)) {
      final sortKey = c.subtitle.isNotEmpty ? c.subtitle : c.title;
      print(
          'Title: "${c.title}", Subtitle: "${c.subtitle}", SortKey: "$sortKey"');
    }
  });
}
