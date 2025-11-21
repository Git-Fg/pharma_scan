import 'package:mocktail/mocktail.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import 'package:pharma_scan/core/services/drift_database_service.dart';
import 'package:pharma_scan/core/services/sync_service.dart';
import 'package:pharma_scan/features/explorer/repositories/explorer_repository.dart';
import 'package:pharma_scan/features/scanner/repositories/scanner_repository.dart';

// Core services
class MockDataInitializationService extends Mock
    implements DataInitializationService {}

class MockDriftDatabaseService extends Mock implements DriftDatabaseService {}

class MockSyncService extends Mock implements SyncService {}

// Repositories
class MockExplorerRepository extends Mock implements ExplorerRepository {}

class MockScannerRepository extends Mock implements ScannerRepository {}

// Register fallback values here when using any() with custom types.
void registerCommonFallbackValues() {
  // Example:
  // registerFallbackValue(FakeSomeCustomType());
}
