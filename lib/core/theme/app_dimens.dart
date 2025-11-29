class AppDimens {
  AppDimens._();

  // Spacing (Gaps & Padding)
  static const double spacing2xs = 4;
  static const double spacingXs = 8;
  static const double spacingSm = 12;
  static const double spacingMd = 16; // Standard content padding
  static const double spacingLg = 20;
  static const double spacingXl = 24;
  static const double spacing2xl = 32;
  static const double spacing3xl = 48;

  // Icon Sizes
  static const double iconXs = 14;
  static const double iconSm = 16;
  static const double iconMd = 20;
  static const double iconLg = 24;
  static const double iconXl = 32;
  static const double icon2xl = 48; // Status views

  // Input Field Heights
  /// Standard height for input fields (ShadInput, ShadInputFormField).
  ///
  /// Matches the minimum touch target size (48px) for accessibility compliance.
  static const double inputFieldHeight = 48;

  // Header Heights
  /// Standard height for section headers in sliver lists.
  ///
  /// Calculated based on actual measured content:
  /// - Padding (top: 24px + bottom: 8px = 32px)
  /// - xl2 typography: fontSize 22px × height 2.0 = 44px line height (actual measured)
  /// - Small buffer for system text scaling (4px)
  /// Total: 32px + 44px + 4px = 80px
  ///
  /// Note: This must match or slightly exceed the actual content height to avoid
  /// "layoutExtent exceeds paintExtent" errors in SliverPersistentHeader.
  static const double headerHeight = 76;

  /// Standard height for search bar header in sliver lists.
  ///
  /// Calculated based on actual measured ExplorerSearchBar render tree:
  /// - Padding: top (spacingXs = 8px) + bottom (spacingSm + 1px border adjustment = 13px)
  /// - Row height: inputFieldHeight (48px)
  /// - Total measured: 8 + 48 + 13 = 69px
  ///
  /// IMPORTANT: For SliverPersistentHeader, the header extent MUST NOT exceed
  /// the actual paint extent. If layoutExtent > paintExtent, Flutter throws
  /// "SliverGeometry is not valid: layoutExtent exceeds paintExtent".
  ///
  /// We therefore set the header height to exactly match the measured
  /// paintExtent (69px) with no extra buffer.
  ///
  /// Note: This must match or slightly exceed the actual content height to avoid
  /// "layoutExtent exceeds paintExtent" errors in SliverPersistentHeader.
  /// The actual paintExtent is 69px, so the header must be 69px or less.
  /// The bottom padding includes spacingSm plus 1px for border space.
  static const double searchBarHeaderHeight =
      spacingXs + inputFieldHeight + spacingSm + 1.0; // 69px
}
