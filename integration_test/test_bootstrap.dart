import 'package:pharma_scan/core/locator.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import 'package:pharma_scan/core/services/database_service.dart';

bool _locatorReady = false;
bool _databaseSeeded = false;

Future<void> ensureIntegrationTestDatabase() async {
  if (!_locatorReady) {
    await setupLocator();
    _locatorReady = true;
  }
  if (_databaseSeeded) return;

  final dbService = sl<DatabaseService>();
  await dbService.clearDatabase();
  await sl<DataInitializationService>().initializeDatabase();
  _databaseSeeded = true;
}
