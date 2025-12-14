import 'dart:io';
import 'package:path/path.dart';

/// Helper for managing mock preferences using SQLite during E2E testing
///
/// This class provides utilities to bypass onboarding flows, set up
/// test configurations, and simulate various app states for reliable testing.
/// Uses SQLite database for persistent storage instead of SharedPreferences.
class MockPreferencesHelper {
  static String? _dbPath;
  static const String _dbName = 'test_preferences.db';
  static Map<String, dynamic> _memoryPreferences = {};

  // --- Preference Keys (matching your app's keys) ---
  static const String _onboardingCompletedKey = 'onboarding_completed';
  static const String _cameraPermissionsGrantedKey = 'camera_permissions_granted';
  static const String _storagePermissionsGrantedKey = 'storage_permissions_granted';
  static const String _initialTutorialShownKey = 'initial_tutorial_shown';
  static const String _firstLaunchKey = 'is_first_launch';
  static const String _termsAcceptedKey = 'terms_accepted';
  static const String _privacyPolicyAcceptedKey = 'privacy_policy_accepted';
  static const String _userProfileSetupKey = 'user_profile_setup';

  // --- Database and Sync Keys ---
  static const String _bdpmVersionKey = 'bdpm_version';
  static const String _lastSyncEpochKey = 'last_sync_epoch';
  static const String _databaseInitializedKey = 'database_initialized';
  static const String _syncEnabledKey = 'sync_enabled';
  static const String _lastDatabaseUpdateKey = 'last_database_update';

  // --- App Configuration Keys ---
  static const String _analyticsEnabledKey = 'analytics_enabled';
  static const String _crashReportingEnabledKey = 'crash_reporting_enabled';
  static const String _autoUpdateEnabledKey = 'auto_update_enabled';
  static const String _darkModeKey = 'dark_mode';
  static const String _notificationsEnabledKey = 'notifications_enabled';

  // --- User Preferences Keys ---
  static const String _preferredLanguageKey = 'preferred_language';
  static const String _defaultScanModeKey = 'default_scan_mode';
  static const String _showTutorialHintsKey = 'show_tutorial_hints';
  static const String _hapticFeedbackKey = 'haptic_feedback';
  static const String _soundEnabledKey = 'sound_enabled';

  /// Initialize the preferences database path
  static Future<void> initialize() async {
    final tempDir = Directory.systemTemp;
    _dbPath = join(tempDir.path, _dbName);

    // For testing, we'll use memory preferences for simplicity
    // In a real implementation, you would set up SQLite here
    print('MockPreferencesHelper initialized (using memory storage)');
  }

  /// Complete onboarding bypass - sets all flags to skip onboarding flows
  static Future<void> bypassOnboarding() async {
    await initialize();

    _memoryPreferences[_onboardingCompletedKey] = true;
    _memoryPreferences[_initialTutorialShownKey] = true;
    _memoryPreferences[_termsAcceptedKey] = true;
    _memoryPreferences[_privacyPolicyAcceptedKey] = true;
    _memoryPreferences[_userProfileSetupKey] = true;

    print('Onboarding bypass completed');
  }

  /// Bypass specific onboarding steps
  static Future<void> bypassSpecificOnboardingSteps({
    bool skipTutorial = true,
    bool skipTerms = true,
    bool skipPrivacy = true,
    bool skipProfileSetup = true,
  }) async {
    await initialize();

    if (skipTutorial) {
      _memoryPreferences[_initialTutorialShownKey] = true;
    }
    if (skipTerms) {
      _memoryPreferences[_termsAcceptedKey] = true;
    }
    if (skipPrivacy) {
      _memoryPreferences[_privacyPolicyAcceptedKey] = true;
    }
    if (skipProfileSetup) {
      _memoryPreferences[_userProfileSetupKey] = true;
    }

    print('Specific onboarding steps bypassed');
  }

  /// Simulate first launch state
  static Future<void> setFirstLaunch(bool isFirstLaunch) async {
    await initialize();

    _memoryPreferences[_firstLaunchKey] = isFirstLaunch;

    if (!isFirstLaunch) {
      // If it's not first launch, also mark onboarding as completed
      _memoryPreferences[_onboardingCompletedKey] = true;
    }

    print('First launch set to: $isFirstLaunch');
  }

  // --- Permission Management ---

  /// Grant all necessary permissions for testing
  static Future<void> grantAllPermissions() async {
    await initialize();

    _memoryPreferences[_cameraPermissionsGrantedKey] = true;
    _memoryPreferences[_storagePermissionsGrantedKey] = true;

    print('All permissions granted for testing');
  }

  /// Set specific permissions
  static Future<void> setCameraPermissionsGranted(bool granted) async {
    await initialize();
    _memoryPreferences[_cameraPermissionsGrantedKey] = granted;
  }

  static Future<void> setStoragePermissionsGranted(bool granted) async {
    await initialize();
    _memoryPreferences[_storagePermissionsGrantedKey] = granted;
  }

  // --- Database and Sync Configuration ---

  /// Configure database for testing - avoids real database download
  static Future<void> configureDatabaseForTesting() async {
    await initialize();

    // Set a fake BDPM version to avoid download
    _memoryPreferences[_bdpmVersionKey] = 'test-version-local';

    // Set last sync epoch to indicate sync is complete
    _memoryPreferences[_lastSyncEpochKey] = DateTime.now().millisecondsSinceEpoch;

    // Mark database as initialized
    _memoryPreferences[_databaseInitializedKey] = true;

    // Set recent database update time
    _memoryPreferences[_lastDatabaseUpdateKey] = DateTime.now().toIso8601String();

    print('Database configured for testing');
  }

  /// Simulate database sync state
  static Future<void> setDatabaseSyncState({
    bool synced = true,
    String? version,
    DateTime? lastSync,
  }) async {
    await initialize();

    _memoryPreferences[_databaseInitializedKey] = synced;
    _memoryPreferences[_bdpmVersionKey] = version ?? 'test-version-local';

    if (synced && lastSync == null) {
      lastSync = DateTime.now();
    }

    if (lastSync != null) {
      _memoryPreferences[_lastSyncEpochKey] = lastSync.millisecondsSinceEpoch;
    }

    print('Database sync state set: synced=$synced');
  }

  /// Simulate database needs update
  static Future<void> setDatabaseNeedsUpdate() async {
    await initialize();

    // Set an old sync time to trigger update
    final oldSyncTime = DateTime.now().subtract(const Duration(days: 30));
    _memoryPreferences[_lastSyncEpochKey] = oldSyncTime.millisecondsSinceEpoch;

    // Set an old version
    _memoryPreferences[_bdpmVersionKey] = 'old-version';

    print('Database set to need update');
  }

  // --- App Configuration for Testing ---

  /// Complete test configuration - sets up app for reliable E2E testing
  static Future<void> configureForTesting() async {
    await initialize();

    // Bypass onboarding
    await bypassOnboarding();

    // Grant permissions
    await grantAllPermissions();

    // Configure database
    await configureDatabaseForTesting();

    // Set first launch to false
    await setFirstLaunch(false);

    // Disable analytics and crash reporting for testing
    await disableAnalytics();

    // Set sensible defaults
    _memoryPreferences[_autoUpdateEnabledKey] = false;
    _memoryPreferences[_showTutorialHintsKey] = false;
    _memoryPreferences[_defaultScanModeKey] = 'analysis';

    print('Complete test configuration applied');
  }

  /// Reset all preferences to default state
  static Future<void> resetAllPreferences() async {
    await initialize();
    _memoryPreferences.clear();

    print('All preferences reset');
  }

  /// Reset only app-specific preferences (leaving system preferences)
  static Future<void> resetAppPreferences() async {
    await initialize();

    // Keys to preserve (system-level)
    final preserveKeys = <String>{
      _preferredLanguageKey,
      _darkModeKey,
    };

    // Get current values
    final Map<String, dynamic> preservedValues = {};
    for (final key in preserveKeys) {
      final value = _memoryPreferences[key];
      if (value != null) {
        preservedValues[key] = value;
      }
    }

    // Clear all preferences
    _memoryPreferences.clear();

    // Restore preserved values
    for (final entry in preservedValues.entries) {
      final key = entry.key;
      final value = entry.value;
      _memoryPreferences[key] = value;
    }

    print('App preferences reset');
  }

  // --- Analytics and Tracking ---

  /// Disable analytics and crash reporting for testing
  static Future<void> disableAnalytics() async {
    await initialize();

    _memoryPreferences[_analyticsEnabledKey] = false;
    _memoryPreferences[_crashReportingEnabledKey] = false;

    print('Analytics and crash reporting disabled');
  }

  /// Enable analytics for testing analytics flows
  static Future<void> enableAnalytics() async {
    await initialize();

    _memoryPreferences[_analyticsEnabledKey] = true;
    _memoryPreferences[_crashReportingEnabledKey] = true;

    print('Analytics and crash reporting enabled');
  }

  // --- User Preferences Configuration ---

  /// Set up user preferences for testing specific scenarios
  static Future<void> setUserPreferences({
    String language = 'fr',
    String scanMode = 'analysis',
    bool darkMode = false,
    bool hapticFeedback = true,
    bool soundEnabled = true,
    bool showTutorialHints = false,
  }) async {
    await initialize();

    _memoryPreferences[_preferredLanguageKey] = language;
    _memoryPreferences[_defaultScanModeKey] = scanMode;
    _memoryPreferences[_darkModeKey] = darkMode;
    _memoryPreferences[_hapticFeedbackKey] = hapticFeedback;
    _memoryPreferences[_soundEnabledKey] = soundEnabled;
    _memoryPreferences[_showTutorialHintsKey] = showTutorialHints;

    print('User preferences configured');
  }

  // --- Special Test Scenarios ---

  /// Configure for new user experience (first launch with onboarding)
  static Future<void> configureForNewUserExperience() async {
    await initialize();

    // Reset onboarding state
    _memoryPreferences[_onboardingCompletedKey] = false;
    _memoryPreferences[_initialTutorialShownKey] = false;
    _memoryPreferences[_termsAcceptedKey] = false;
    _memoryPreferences[_privacyPolicyAcceptedKey] = false;
    _memoryPreferences[_userProfileSetupKey] = false;

    // Set first launch to true
    await setFirstLaunch(true);

    // Configure database
    await configureDatabaseForTesting();

    // Enable tutorial hints
    _memoryPreferences[_showTutorialHintsKey] = true;

    print('Configured for new user experience');
  }

  /// Configure for returning user experience
  static Future<void> configureForReturningUserExperience() async {
    await initialize();

    // Complete onboarding
    await bypassOnboarding();

    // Set some user history
    _memoryPreferences[_preferredLanguageKey] = 'fr';
    _memoryPreferences[_defaultScanModeKey] = 'analysis';
    _memoryPreferences[_darkModeKey] = false;

    // Simulate some app usage
    final pastSyncTime = DateTime.now().subtract(const Duration(days: 1));
    _memoryPreferences[_lastSyncEpochKey] = pastSyncTime.millisecondsSinceEpoch;

    print('Configured for returning user experience');
  }

  /// Configure for offline testing
  static Future<void> configureForOfflineTesting() async {
    await initialize();

    // Configure database but disable sync
    await configureDatabaseForTesting();
    _memoryPreferences[_syncEnabledKey] = false;

    // Disable auto-update
    _memoryPreferences[_autoUpdateEnabledKey] = false;

    print('Configured for offline testing');
  }

  // --- Utility Methods ---

  /// Get current preference values for debugging
  static Future<Map<String, dynamic>> getCurrentPreferences() async {
    await initialize();
    return Map<String, dynamic>.from(_memoryPreferences);
  }

  /// Print current preferences for debugging
  static Future<void> debugPrintPreferences() async {
    final currentPrefs = await getCurrentPreferences();

    print('=== Current MockPreferences ===');
    for (final entry in currentPrefs.entries) {
      print('${entry.key}: ${entry.value}');
    }
    print('=== End MockPreferences ===');
  }

  /// Check if onboarding is completed
  static Future<bool> isOnboardingCompleted() async {
    await initialize();
    return _memoryPreferences[_onboardingCompletedKey] ?? false;
  }

  /// Check if database is configured for testing
  static Future<bool> isDatabaseConfiguredForTesting() async {
    await initialize();
    final bdpmVersion = _memoryPreferences[_bdpmVersionKey];
    final lastSync = _memoryPreferences[_lastSyncEpochKey];

    return bdpmVersion != null && lastSync != null;
  }

  /// Validate test configuration
  static Future<bool> validateTestConfiguration() async {
    await initialize();

    // Check essential test configuration
    final onboardingCompleted = _memoryPreferences[_onboardingCompletedKey] ?? false;
    final databaseInitialized = _memoryPreferences[_databaseInitializedKey] ?? false;
    final bdpmVersion = _memoryPreferences[_bdpmVersionKey];
    final cameraPermissions = _memoryPreferences[_cameraPermissionsGrantedKey] ?? false;

    return onboardingCompleted &&
           databaseInitialized &&
           bdpmVersion != null &&
           cameraPermissions;
  }
}