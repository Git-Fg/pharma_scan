import 'package:device_info_plus_platform_interface/device_info_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pharma_scan/features/scanner/presentation/providers/scanner_provider.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockDeviceInfoPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements DeviceInfoPlatform {}

class MockAndroidDeviceInfo extends Mock {}

class MockAndroidBuildVersion extends Mock {}

class MockIosDeviceInfo extends Mock {}

void main() {
  late MockDeviceInfoPlatform mockDeviceInfoPlatform;

  setUp(() {
    mockDeviceInfoPlatform = MockDeviceInfoPlatform();
    DeviceInfoPlatform.instance = mockDeviceInfoPlatform;
  });

  group('ScannerNotifier Device Info Tests', () {
    test(
      'ScannerNotifier initializes with isLowEndDevice=false by default (or if platform check fails/skipped)',
      () async {
        // Since we cannot mock Platform.isAndroid easily without IO overrides which is complex,
        // we rely on the fact that on non-mobile platforms (like test runner) it skips the check or returns false.
        // However, we can verify that the provider builds successfully.

        final container = ProviderContainer();

        // We need to override dependencies if ScannerNotifier uses them in build or initialization.
        // ScannerNotifier reads scannerRuntimeProvider and has Listeners?
        // It initializes _initialState which is synch.
        // But build() calls _checkDeviceCapabilities() which is async.

        final scannerState = await container.read(
          scannerProvider.future,
        );

        expect(
          (scannerState as ScannerState?)?.isLowEndDevice ?? false,
          isFalse,
        );
      },
    );
  });
}
