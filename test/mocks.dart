import 'package:mocktail/mocktail.dart';
import 'package:pharma_scan/core/database/daos/catalog_dao.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';

// Core services
class MockDataInitializationService extends Mock
    implements DataInitializationService {}

// DAOs
class MockCatalogDao extends Mock implements CatalogDao {}

// Register fallback values here when using any() with custom types.
void registerCommonFallbackValues() {}
