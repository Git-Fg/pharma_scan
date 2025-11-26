import 'package:mocktail/mocktail.dart';
import 'package:pharma_scan/core/database/daos/library_dao.dart';
import 'package:pharma_scan/core/database/daos/search_dao.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';

// Core services
class MockDataInitializationService extends Mock
    implements DataInitializationService {}

// DAOs
class MockLibraryDao extends Mock implements LibraryDao {}

class MockSearchDao extends Mock implements SearchDao {}

// Register fallback values here when using any() with custom types.
void registerCommonFallbackValues() {
  // Example:
  // registerFallbackValue(FakeSomeCustomType());
}
