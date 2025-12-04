class AppDimens {
  AppDimens._();

  static const double spacing2xs = 4;
  static const double spacingXs = 8;
  static const double spacingSm = 12;
  static const double spacingMd = 16;
  static const double spacingLg = 20;
  static const double spacingXl = 24;
  static const double spacing2xl = 32;
  static const double spacing3xl = 48;

  static const double iconXs = 14;
  static const double iconSm = 16;
  static const double iconMd = 20;
  static const double iconLg = 24;
  static const double iconXl = 32;
  static const double icon2xl = 48;

  /// Standard height for input fields (ShadInput, ShadInputFormField).
  ///
  /// Matches the minimum touch target size (48px) for accessibility compliance.
  static const double inputFieldHeight = 48;

  /// Height for the search bar sliver header; must match the measured content
  /// height to avoid `layoutExtent > paintExtent` errors.
  static const double searchBarHeaderHeight =
      spacingXs + inputFieldHeight + spacingSm + 1.0;

  static const double scannerWindowSize = 192;

  static const double scannerWindowBorderRadius = 14.4;

  static const double scannerWindowCornerLength = 20.8;

  static const double scannerWindowCornerThickness = 4;

  static const double scannerWindowIconSize = 51.2;

  static const double scannerWindowIconInnerSize = 22.4;
}
