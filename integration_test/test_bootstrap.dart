import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/providers/core_providers.dart';

ProviderContainer? _integrationTestContainer;
bool _databaseSeeded = false;

Future<ProviderContainer> _ensureContainer() async {
  if (_integrationTestContainer != null) return _integrationTestContainer!;

  final database = AppDatabase();

  _integrationTestContainer = ProviderContainer(
    overrides: [appDatabaseProvider.overrideWithValue(database)],
  );
  return _integrationTestContainer!;
}

Future<void> ensureIntegrationTestDatabase() async {
  final container = await _ensureContainer();
  if (_databaseSeeded) return;

  final db = container.read(appDatabaseProvider);
  await db.databaseDao.clearDatabase();
  await container.read(dataInitializationServiceProvider).initializeDatabase();
  _databaseSeeded = true;
}

Future<ProviderContainer> ensureIntegrationTestContainer() =>
    _ensureContainer();

ProviderContainer get integrationTestContainer =>
    _integrationTestContainer ??
    (throw StateError(
      'Integration test container not initialized. Call ensureIntegrationTestDatabase() first.',
    ));
