/// Centralized test tag identifiers for E2E testing.
///
/// All test tags use ID-based matching via Semantics.identifier.
/// This ensures stable test selectors that don't break when UI text changes.
class TestTags {
  TestTags._();

  // Navigation
  static const String navScanner = 'test_nav_scanner';
  static const String navExplorer = 'test_nav_explorer';
  static const String navRestock = 'test_nav_restock';
  static const String navSettings = 'test_nav_settings';

  // Scanner buttons
  static const String scanStartBtn = 'test_scan_start_btn';
  static const String scanStopBtn = 'test_scan_stop_btn';
  static const String scanGalleryBtn = 'test_scan_gallery_btn';
  static const String scanManualBtn = 'test_scan_manual_btn';
  static const String scannerTorch = 'test_scanner_torch';

  // Explorer search controls
  static const String searchInput = 'test_search_input';
  static const String filterBtn = 'test_filter_btn';
  static const String searchClearBtn = 'test_search_clear_btn';
  static const String explorerResetFilters = 'test_explorer_reset_filters';

  // Settings actions
  static const String settingsThemeToggle = 'test_settings_theme_toggle';
  static const String settingsCheckUpdates = 'test_settings_check_updates';
  static const String settingsForceReset = 'test_settings_force_reset';
  static const String settingsShowLogs = 'test_settings_show_logs';
}
