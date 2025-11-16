// lib/core/locator.dart
import 'package:get_it/get_it.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import 'package:pharma_scan/core/services/database_service.dart';

final sl = GetIt.instance;

void setupLocator() {
  // Database Layer
  sl.registerLazySingleton(() => AppDatabase());

  // Service Layer
  sl.registerLazySingleton(() => DatabaseService());
  sl.registerLazySingleton(() => DataInitializationService());
}
