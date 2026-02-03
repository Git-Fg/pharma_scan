import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pharma_scan/core/database/daos/app_settings_dao.dart';
import 'package:pharma_scan/core/domain/models/sync_state.dart';
import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/core/providers/sync_provider.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import 'package:pharma_scan/core/services/logger_service.dart';
import 'package:riverpod/riverpod.dart';

// Mocks
class MockDataInitializationService extends Mock
    implements DataInitializationService {}

class MockLoggerService extends Mock implements LoggerService {}

class MockAppSettingsDao extends Mock implements AppSettingsDao {}

class MockUpdateFrequencyNotifier extends UpdateFrequencyNotifier {
  @override
  Future<String?> build() async => 'daily';
}

void main() {
  late MockDataInitializationService mockDataInitService;
  late MockLoggerService mockLogger;
  late MockAppSettingsDao mockAppSettings;
  late ProviderContainer container;

  setUp(() {
    mockDataInitService = MockDataInitializationService();
    mockLogger = MockLoggerService();
    mockAppSettings = MockAppSettingsDao();

    registerFallbackValue(InitializationStep.idle);

    when(() => mockLogger.info(any())).thenReturn(null);
    when(() => mockLogger.error(any(), any(), any())).thenReturn(null);
    when(() => mockAppSettings.lastSyncTime).thenAnswer((_) async => null);
    when(() => mockAppSettings.setLastSyncTime(any())).thenAnswer((_) async {});

    container = ProviderContainer(
      overrides: [
        dataInitializationServiceProvider
            .overrideWithValue(mockDataInitService),
        loggerProvider.overrideWithValue(mockLogger),
        appSettingsDaoProvider.overrideWithValue(mockAppSettings),
        // Mock dependencies of SyncController if any other
        updateFrequencyProvider
            .overrideWith(() => MockUpdateFrequencyNotifier()),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  test('startSync detects update and waits for user', () async {
    // Arrange
    final versionResult = VersionCheckResult(
      updateAvailable: true,
      remoteTag: 'v2.0.0',
      blockedByPolicy: false,
    );
    when(() => mockDataInitService.checkVersionStatus())
        .thenAnswer((_) async => versionResult);

    // Act
    final controller = container.read(syncControllerProvider.notifier);
    final result = await controller.startSync();

    // Assert
    expect(result, false); // Returns false because it's waiting
    final state = container.read(syncControllerProvider);
    expect(state.phase, SyncPhase.waitingUser);
    expect(state.pendingUpdate, versionResult);
  });

  test('confirmUpdate triggers update', () async {
    // Arrange: Put in waiting state
    final versionResult = VersionCheckResult(
      updateAvailable: true,
      remoteTag: 'v2.0.0',
      blockedByPolicy: false,
    );
    when(() => mockDataInitService.checkVersionStatus())
        .thenAnswer((_) async => versionResult);
    when(() => mockDataInitService.updateDatabase(force: true))
        .thenAnswer((_) async => true);

    final controller = container.read(syncControllerProvider.notifier);
    await controller.startSync();

    // Act
    await controller.confirmUpdate();

    // Assert
    // Should have transitioned to downloading/success steps (SyncController logic handles this)
    // We can verify mock call
    verify(() => mockDataInitService.updateDatabase(force: true)).called(1);
  });

  test('cancelUpdate resets to idle', () async {
    // Arrange
    final versionResult = VersionCheckResult(
      updateAvailable: true,
      remoteTag: 'v2.0.0',
      blockedByPolicy: false,
    );
    when(() => mockDataInitService.checkVersionStatus())
        .thenAnswer((_) async => versionResult);

    final controller = container.read(syncControllerProvider.notifier);
    await controller.startSync();
    expect(container.read(syncControllerProvider).phase, SyncPhase.waitingUser);

    // Act
    await controller.cancelUpdate();

    // Assert
    expect(container.read(syncControllerProvider).phase, SyncPhase.idle);
  });
}
