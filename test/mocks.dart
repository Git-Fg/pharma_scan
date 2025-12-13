import 'package:mocktail/mocktail.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import 'package:pharma_scan/core/services/preferences_service.dart';

// Core services
class MockDataInitializationService extends Mock
    implements DataInitializationService {}

class MockPreferencesService extends Mock implements PreferencesService {}
