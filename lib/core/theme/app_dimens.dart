class AppDimens {
  AppDimens._();

  // Spacing constants
  static const double spacing2xs = 2.0;
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;
  static const double spacing2xl = 48.0;

  // Icon sizes
  static const double iconXs = 12.0;
  static const double iconSm = 16.0;
  static const double iconMd = 20.0;
  static const double iconLg = 24.0;
  static const double iconXl = 32.0;

  /// Minimum height for tappable list tiles to keep touch targets accessible
  /// Dense lists aim for 48–56px; use 56 for comfort.
  static const double listTileMinHeight = 56;

  /// Standard height for input fields (ShadInput, ShadInputFormField).
  ///
  /// Matches the minimum touch target size (48px) for accessibility compliance.
  static const double inputFieldHeight = 48;

  /// Height for the search bar sliver header; must match the measured content
  /// height to avoid `layoutExtent > paintExtent` errors.
  static const double searchBarHeaderHeight =
      spacingXs + inputFieldHeight + spacingSm + 1.0;

  static const double scannerWindowSize = 192;

  static const double scannerWindowCornerLength = 20.8;

  static const double scannerWindowCornerThickness = 4;

  static const double scannerWindowIconSize = 51.2;

  static const double scannerWindowIconInnerSize = 22.4;
}
