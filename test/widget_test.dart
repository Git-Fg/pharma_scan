// Widget test for PharmaScan application
//
// This test verifies that the app can launch successfully with the test database.
// Note: The app initialization in main() attempts to download data files, which is skipped
// in the test environment. The test verifies that the UI can render without errors.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/locator.dart';
import 'package:pharma_scan/core/services/database_service.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import 'package:pharma_scan/main.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    // For each test, create a fresh in-memory database
    database = AppDatabase.forTesting(NativeDatabase.memory());

    // Register the test database and services with the locator
    sl.registerSingleton<AppDatabase>(database);
    sl.registerSingleton<DatabaseService>(DatabaseService());
    sl.registerSingleton<DataInitializationService>(
      DataInitializationService(),
    );
  });

  tearDown(() async {
    // Close the database and reset the locator after each test
    await database.close();
    await sl.reset();
  });

  testWidgets('App launches successfully', (WidgetTester tester) async {
    // WHY: The app initialization in main() calls DataInitializationService.initializeDatabase()
    // which attempts to download files. In the test environment, we verify the app can render
    // even with an empty database, which is the expected state after clearDatabase().

    // Build our app and trigger a frame
    await tester.pumpWidget(const PharmaScanApp());

    // Verify that the app launches
    expect(find.byType(PharmaScanApp), findsOneWidget);

    // Pump frames to allow any async initialization to complete
    // Using pump with limited duration to avoid waiting indefinitely for network calls
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify the app is still rendered after async operations
    expect(find.byType(PharmaScanApp), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 5)));
}
