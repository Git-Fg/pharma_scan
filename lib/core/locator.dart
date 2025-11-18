// lib/core/locator.dart
import 'package:get_it/get_it.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import 'package:pharma_scan/core/services/database_service.dart';
import 'package:pharma_scan/core/services/sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sl = GetIt.instance;

Future<void> setupLocator() async {
  // Shared Preferences
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerSingleton<SharedPreferences>(sharedPreferences);

  // Database Layer
  sl.registerLazySingleton(() => AppDatabase());

  // Service Layer
  sl.registerLazySingleton(() => DatabaseService());
  sl.registerLazySingleton(
    () => DataInitializationService(
      sharedPreferences: sl<SharedPreferences>(),
      databaseService: sl<DatabaseService>(),
    ),
  );
  sl.registerLazySingleton(
    () => SyncService(
      sharedPreferences: sl<SharedPreferences>(),
      dataInitializationService: sl<DataInitializationService>(),
    ),
  );
}
