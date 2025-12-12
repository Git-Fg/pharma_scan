import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pharma_scan/core/services/preferences_service.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/features/settings/screens/settings_screen.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Create a fake SharedPreferences for the providers
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('SettingsScreen Tests', () {
    testWidgets('should display app version correctly', (
      WidgetTester tester,
    ) async {
      // Increase surface size to avoid overflow
      tester.view.physicalSize = const Size(4000, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Arrange
      // Mock the PackageInfo.fromPlatform call
      PackageInfo.setMockInitialValues(
        appName: 'Test App',
        packageName: 'com.example.app',
        version: '1.0.0',
        buildNumber: '42',
        buildSignature: '',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // Add any necessary overrides if needed, e.g. persistence
            preferencesServiceProvider.overrideWith(
              (ref) => PreferencesService(prefs),
            ),
          ],
          child: const ShadApp(
            home: SettingsScreen(),
          ),
        ),
      );

      // Act
      await tester.pumpAndSettle();

      // Assert
      // Strings.appInfo and Strings.version both equal "Version", so we expect 2 widgets
      expect(find.text(Strings.appInfo), findsAtLeastNWidgets(1));
      expect(find.text('1.0.0'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      expect(find.text('com.example.app'), findsOneWidget);
    });
  });
}
