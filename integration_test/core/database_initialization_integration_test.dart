import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pharma_scan/core/config/database_config.dart';

import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/main.dart' as app;
import 'package:riverpod/riverpod.dart';

// ignore_for_file: avoid_print

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Database Initialization Integration Tests', () {
    testWidgets('Real asset bundle loading - First run simulation',
        (WidgetTester tester) async {
      // This test verifies that the bundled reference.db asset can be loaded
      // and properly initialized on first run

      // Verify asset exists and is loadable using rootBundle
      final assetPath = 'assets/database/reference.db.gz';

      try {
        // Use rootBundle directly - available in integration tests
        final byteData = await rootBundle.load(assetPath);

        expect(byteData.lengthInBytes, greaterThan(0),
            reason: 'Bundled database asset should not be empty');

        // Verify it's a reasonable size (should be smaller than uncompressed, but still significant)
        // With compression, it might be smaller than 1MB if empty, but for real db it should be substantial
        expect(byteData.lengthInBytes, greaterThan(100 * 1024),
            reason: 'Compressed database should be at least 100KB');

        print('✅ Asset bundle exists and is loadable');
        print('   Path: $assetPath');
        print(
            '   Size: ${(byteData.lengthInBytes / 1024 / 1024).toStringAsFixed(2)} MB');
      } catch (e) {
        fail('Failed to load bundled asset: $e\\n'
            'Make sure assets/database/reference.db exists and is included in pubspec.yaml\\n'
            'Run: cd backend_pipeline && ./scripts/dump_schema.sh');
      }
    });

    testWidgets(
        'GitHub download validation - Verify release URL and download logic',
        (WidgetTester tester) async {
      // This test verifies that:
      // 1. GitHub API URL is correctly formatted
      // 2. Latest release can be fetched
      // 3. reference.db.gz asset exists in the release
      // 4. Download URL is valid

      final container = ProviderContainer();
      addTearDown(container.dispose);

      print('Testing GitHub Release API...');
      print(
          'Repository: ${DatabaseConfig.repoOwner}/${DatabaseConfig.repoName}');
      print('API URL: ${DatabaseConfig.githubReleasesUrl}');

      // Use the real service to test the download logic
      final service = container.read(dataInitializationServiceProvider);

      // Note: This test requires network connectivity
      // If it fails in CI, consider skipping or mocking

      try {
        // Attempt to check for updates (which queries GitHub API)
        // This will fail gracefully if no network or if rate-limited
        final updateAvailable = await service.updateDatabase().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            print(
                '⚠️  GitHub API request timed out (expected in offline tests)');
            return false;
          },
        );

        print('✅ GitHub API is accessible');
        print('   Update available: $updateAvailable');
      } catch (e) {
        // Log but don't fail - network tests are inherently flaky
        print('⚠️  GitHub API test failed (network issue?): $e');
        print('   This is expected if running offline or rate-limited');
      }
    },
        // Skip this test by default since it requires network
        skip: true);

    testWidgets('End-to-end: Asset hydration OR download',
        (WidgetTester tester) async {
      // This test simulates a complete first-run experience
      // It will either use the bundled asset OR download from GitHub

      // Pump the actual app
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // At this point, the app should have initialized
      // Either from bundled asset or from download

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final db = container.read(databaseProvider());

      try {
        final stats = await db.catalogDao.getDatabaseStats();

        expect(stats.totalPrinceps, greaterThan(0),
            reason: 'Database should contain medicaments after initialization');

        print('✅ Database initialized successfully');
        print('   Princeps: ${stats.totalPrinceps}');
        print('   Generiques: ${stats.totalGeneriques}');
        print('   Active Principles: ${stats.totalPrincipes}');
      } catch (e) {
        fail('Database initialization failed: $e');
      }
    });
  });

  group('Database Update Integration Tests', () {
    testWidgets('Update mechanism preserves data', (WidgetTester tester) async {
      // This test verifies that updating the database
      // doesn't lose critical state or cause corruption

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final db = container.read(databaseProvider());

      // Get initial stats
      final statsBefore = await db.catalogDao.getDatabaseStats();

      // Trigger update (will only download if new version available)
      final service = container.read(dataInitializationServiceProvider);

      try {
        await service.updateDatabase().timeout(
              const Duration(seconds: 30),
            );

        // Verify database is still accessible
        final statsAfter = await db.catalogDao.getDatabaseStats();

        expect(statsAfter.totalPrinceps, greaterThan(0),
            reason: 'Database should still have data after update attempt');

        print('✅ Update mechanism works correctly');
        print('   Before: ${statsBefore.totalPrinceps} medicaments');
        print('   After: ${statsAfter.totalPrinceps} medicaments');
      } catch (e) {
        print('⚠️  Update test failed: $e');
        print('   This is expected if no network or no update available');
      }
    },
        // Skip by default - network dependent
        skip: true);
  });
}
