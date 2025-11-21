// WHY: Centralized design tokens for spacing, radii, and icon sizing to avoid
// magic numbers across the UI layer.
class AppDimens {
  AppDimens._();

  // Spacing (Gaps & Padding)
  static const double spacing2xs = 4.0;
  static const double spacingXs = 8.0;
  static const double spacingSm = 12.0;
  static const double spacingMd = 16.0; // Standard content padding
  static const double spacingLg = 20.0;
  static const double spacingXl = 24.0;
  static const double spacing2xl = 32.0;
  static const double spacing3xl = 48.0;

  // Border Radius
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0; // Standard card radius
  static const double radiusLg = 16.0; // Bottom sheet / large containers
  static const double radiusFull = 999.0; // Capsule/Circle

  // Icon Sizes
  static const double iconXs = 14.0;
  static const double iconSm = 16.0;
  static const double iconMd = 20.0;
  static const double iconLg = 24.0;
  static const double iconXl = 32.0;
  static const double icon2xl = 48.0; // Status views
}
