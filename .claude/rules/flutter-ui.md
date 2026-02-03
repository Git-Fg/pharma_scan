---
paths:
  - "lib/core/ui/**/*"
  - "lib/core/widgets/**/*"
  - "lib/features/**/widgets/**/*"
---

# Flutter UI Rules for PharmaScan

This document defines UI/UX standards for the PharmaScan Flutter app, following shadcn/ui principles and brand color integration patterns.

## Shadcn UI Patterns

### Core Principles
- **Component Composition Over Inheritance**: Build widgets by composing smaller, focused components rather than extending base classes
- **Design Tokens**: Use consistent spacing, colors, and typography from design tokens
- **Accessibility First**: All interactive elements must be accessible via keyboard and screen readers

### Color Usage
```dart
// CORRECT: Use context.shadColors or semantic extensions
context.shadColors.primary
context.shadColors.muted
context.colors.destructive

// INCORRECT: Never use hardcoded colors
Color(0xFF0F766E)  // Use brand colors from BrandColors
Colors.blue        // Never use Material colors directly
```

### Typography Tokens
- Access via `context.typo` extension on BuildContext
- `context.typo.h1, .h2, .h3, .h4, .h5` for headings
- `context.typo.large, .medium, .small` for body text

### Spacing Tokens
```dart
context.spacing.xxs   // 2px  (extra extra small)
context.spacing.xs    // 4px
context.spacing.sm    // 8px
context.spacing.md    // 16px
context.spacing.lg    // 24px
context.spacing.xl    // 32px
context.spacing.xxl   // 48px
```

### Border Radius Tokens
```dart
context.radiusSmall    // 4px
context.radiusMedium   // 8px
context.radiusLarge    // 12px
context.radiusXLarge   // 16px
context.radiusFull     // circular (full rounded)
```

### Shadcn Components
Use `shadcn_ui` package (^0.45.1) for base components:

**Form Components:**
- `ShadButton` - Primary, secondary, outline, ghost, destructive variants
- `ShadInput` / `ShadInputFormField` - Text fields
- `ShadTextarea` / `ShadTextareaFormField` - Multi-line text (v0.25.0+)
- `ShadSelect` / `ShadSelectFormField` - Dropdown selection
- `ShadSelect.multiple` - Multi-select (v0.11.0+)
- `ShadCheckbox` / `ShadCheckboxFormField` - Checkboxes
- `ShadRadio` / `ShadRadioGroup` - Radio buttons
- `ShadSwitch` / `ShadSwitchFormField` - Switches
- `ShadDatePicker` / `ShadDatePickerFormField` - Date selection (v0.15.0+)
- `ShadTimePicker` / `ShadTimePickerFormField` - Time selection (v0.16.0+)
- `ShadInputOTP` / `ShadInputOTPFormField` - OTP input (v0.17.0+)

**Display Components:**
- `ShadCard` - Card containers
- `ShadBadge` - Status badges
- `ShadAlert` - Alert banners
- `ShadAvatar` - User avatars
- `ShadCalendar` - Date calendar (v0.13.0+)
- `ShadAccordion` - Collapsible sections (v0.1.0+)
- `ShadBreadcrumb` - Navigation breadcrumbs (v0.40.0+)

**Navigation & Layout:**
- `ShadTabs` - Tab navigation
- `ShadDialog` / `showShadDialog` - Modal dialogs
- `ShadSheet` / `showShadSheet` - Bottom sheets
- `ShadPopover` - Popover menus
- `ShadTooltip` - Hover tooltips
- `ShadContextMenu` - Right-click context menus (v0.9.0+)
- `ShadMenubar` - Menu bar (v0.22.0+)

**Advanced Components:**
- `ShadResizable` - Resizable panels (v0.4.0+)
- `ShadTable` - Data tables (v0.3.0+)
- `ShadSlider` - Range sliders
- `ShadProgress` - Progress indicators
- `ShadSonner` - Toast notifications (v0.24.0+)
- `ShadSeparator` - Visual dividers (replaces ShadDivider)
- `ShadKeyboardToolbar` - Keyboard toolbar above input (v0.30.0+)
- `ShadRoundedSuperellipseBorder` - Superellipse border style (v0.27.1+)

## Shadcn v0.43 → v0.45 Breaking Changes

**Form API Changes (v0.42.0+):**
- `setValue()` → `setFieldValue()` for single field updates
- `setValue(Map)` for entire form value updates
- Form field IDs must be `String` type (v0.41.0)
- Use `fromValueTransformer` / `toValueTransformer` (v0.44.0)

**Component Renames:**
- `ShadButton.icon` → Use `ShadIconButton`
- `ShadDatePicker.icon` → `leading` (adds `trailing` too)
- `ShadDivider` → `ShadSeparator`
- `icon` / `iconSrc` parameters → `iconData` across components

**Dot Notation Support (v0.45.0):**
```dart
// Nested form values via dot notation
ShadFormField(
  id: 'user.email', // Automatically converted to nested map
  initialValue: {'user': {'email': 'test@example.com'}},
)

// Custom separator (v0.45.0)
ShadForm(
  fieldIdSeparator: '/',  // Use any string as separator, or null to disable
  child: ShadFormField(
    id: 'user/email',  // With custom separator
  ),
)

// Get raw values without transformations (v0.45.1)
final rawValues = formKey.currentState?.rawValue();
```

## Theme System

### Brand Colors (`lib/core/ui/theme/brand_colors.dart`)
Brand colors define the app's primary identity and should be used consistently:
```dart
abstract final class BrandColors {
  static const primaryLight = Color(0xFF0F766E);  // Light theme
  static const primaryDark = Color(0xFF14B8A6);   // Dark theme
}
```

### Semantic Colors (`lib/core/ui/theme/app_theme.dart`)
Semantic tokens provide context-aware colors for common use cases:
```dart
extension SemanticColors on BuildContext {
  // Surfaces - Material 3 surface container system (Flutter 3.22+)
  Color get surfacePrimary => Theme.of(this).colorScheme.surface;
  Color get surfaceSecondary => Theme.of(this).colorScheme.surfaceContainerHighest;
  Color get surfaceContainerLowest => Theme.of(this).colorScheme.surfaceContainerLowest;
  Color get surfaceContainerLow => Theme.of(this).colorScheme.surfaceContainerLow;
  Color get surfaceContainer => Theme.of(this).colorScheme.surfaceContainer;
  Color get surfaceContainerHigh => Theme.of(this).colorScheme.surfaceContainerHigh;
  Color get surfaceContainerHighest => Theme.of(this).colorScheme.surfaceContainerHighest;
  Color get surfacePositive => _SemanticColorTokens.surfacePositive;
  Color get surfaceWarning => _SemanticColorTokens.surfaceWarning;
  Color get surfaceNegative => _SemanticColorTokens.surfaceNegative;
  Color get surfaceInfo => _SemanticColorTokens.surfaceInfo;

  // Text
  Color get textPrimary => Theme.of(this).colorScheme.onSurface;
  Color get textSecondary => Theme.of(this).colorScheme.onSurfaceVariant;
  Color get textPositive => _SemanticColorTokens.textPositive;
  Color get textWarning => _SemanticColorTokens.textWarning;
  Color get textNegative => _SemanticColorTokens.textNegative;
}
```

### Shadows
```dart
extension ShadowTokens on BuildContext {
  List<BoxShadow> get shadowLight;    // Subtle elevation
  List<BoxShadow> get shadowMedium;   // Standard elevation
  List<BoxShadow> get shadowHeavy;    // High elevation
}

// Shadow colors MUST be theme-aware
extension SemanticShadows on BuildContext {
  List<BoxShadow> get shadowLight => [
    BoxShadow(
      color: colors.surface.withValues(alpha: 0.1),  // Semantic, not Colors.black
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];
}
```

### ColorScheme Completeness

Map all semantic states explicitly in theme configuration:
```dart
colorScheme: const ShadGreenColorScheme.light(
  primary: BrandColors.primaryLight,
  destructive: Color(0xFFC5221F),  // textNegative
  success: Color(0xFF137333),       // textPositive
  warning: Color(0xFFBF5700),       // textWarning
),

// Don't rely on shadcn defaults for semantic states
```

### Light/Dark Mode
- Theme mode managed via `ThemeMode` enum (light, dark, system)
- Brand colors automatically adjust based on brightness
- Use `context.shadTheme` to access theme data with brightness awareness

## Directory Structure

### `lib/core/ui/organisms/`
Compound UI components that combine multiple atoms/molecules:
- `AppHeader` - Standardized app bar with title, actions, and back button
- `AppSheet` - Sheet dialog wrapper with consistent styling

### `lib/core/widgets/ui_kit/`
Atomic UI components that are framework-agnostic:
- `ProductBadges` - Product type, financial, and regulatory badges
- `StatusView` - Empty, loading, and error states

### `lib/core/widgets/`
Shared reusable widgets across features:
- `ScaffoldShell` - App scaffold with navigation
- `AdaptiveBottomPanel` - Responsive bottom panel
- `UpdateDialog` - App update prompt

## Component Patterns

### Button Variants
```dart
// Primary action
ShadButton(onPressed: onPressed, child: Text('Confirm'))

// Secondary action
ShadButton.secondary(onPressed: onPressed, child: Text('Cancel'))

// Outline for less prominent actions
ShadButton.outline(onPressed: onPressed, child: Text('Learn More'))

// Ghost for tertiary actions
ShadButton.ghost(onPressed: onPressed, child: Text('Dismiss'))

// Destructive actions
ShadButton.destructive(onPressed: onPressed, child: Text('Delete'))
```

### Card Composition
```dart
ShadCard(
  title: Row(
    children: [
      Icon(icon, color: context.colors.mutedForeground),
      Gap(spacing.xs),
      Expanded(child: Text(title, style: context.typo.h4)),
    ],
  ),
  description: Text(description, style: context.typo.small),
  child: content,
)
```

### Sheet Dialogs
```dart
AppSheet.show(
  context: context,
  title: 'Confirm Action',
  child: Text('Are you sure you want to proceed?'),
  actions: [
    ShadButton.outline(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
    ShadButton(onPressed: onConfirm, child: Text('Confirm')),
  ],
)
```

### Badge System
```dart
// Product type badges
ProductTypeBadge(memberType: 0)  // Princeps
ProductTypeBadge(memberType: 1)  // Generic
ProductTypeBadge(memberType: 2)  // Complementary

// Financial badges
FinancialBadge(refundRate: '65%', price: 12.50)

// Regulatory badges
RegulatoryBadges(
  isNarcotic: true,
  isHospitalOnly: false,
  isOtc: true,
)
```

## Theme Extensions Pattern

For custom design tokens beyond Material's ThemeData, use Theme Extensions:

```dart
abstract final class _SemanticColorTokens {
  static const surfacePositive = Color(0xFFE6F4EA);
  static const surfaceWarning = Color(0xFFFFF4E6);
  static const surfaceNegative = Color(0xFFFCE8E6);
}

extension SemanticColors on BuildContext {
  Color get surfacePositive => _SemanticColorTokens.surfacePositive;
}
```

## Icons

Use `lucide_icons_flutter` consistently throughout the app. Never mix with Material Icons.

```dart
// CORRECT - LucideIcons
import 'package:lucide_icons_flutter/lucide_icons.dart';
Icon(LucideIcons.scanLine, color: context.colors.muted),
Icon(LucideIcons.settings, color: context.colors.mutedForeground),

// INCORRECT - Material Icons
Icon(Icons.qr_code_scanner, ...),
Icon(Icons.settings, ...),
```

### Icon Color
Always use semantic colors for icons:
```dart
context.colors.muted        // Muted/inactive
context.colors.mutedForeground
context.colors.primary      // Active/selected
context.colors.destructive  // Error/delete
```

## Best Practices

### Do
- Use `context.shadColors.*` instead of direct color values
- Prefer composition over inheritance for custom widgets
- Use semantic naming (surfacePositive, textWarning) over color names
- Use `Gap` widget for consistent spacing between elements
- Use `const` constructors for all widgets (performance)
- Map all semantic states (destructive, success, warning) in ColorScheme

### Don't
- Never use hardcoded color values in widgets
- Never extend StatelessWidget/StatefulWidget unnecessarily
- Never mix Material Design colors with shadcn colors
- Never use `Colors.blue`, `Colors.red`, etc. directly
- Never skip theme extensions when adding new semantic colors
- Never use Material Icons - use LucideIcons only
- Never import from other features (features cannot import features)

## Accessibility Requirements (2026 Standards)

All UI components must meet WCAG 2.1 AA compliance:

### Touch Targets
- Minimum touch target size: **48x48dp** (WCAG 2.5.5)
```dart
// Correct
ShadButton(
  style: ButtonStyle(
    minimumSize: WidgetStateProperty.all(const Size(48, 48)),
  ),
  onPressed: onPressed,
  child: Text('Action'),
)
```

### Semantic Roles
Use explicit semantic roles for screen readers (Flutter 3.16+):
```dart
Semantics(
  role: SemanticsRole.list,
  explicitChildNodes: true,
  child: ListView(...),
)
```

### Live Regions
Announce dynamic content changes:
```dart
Semantics(
  liveRegion: LiveRegion.polite,
  child: Text('Status updated'),
)
```

### Color Contrast
Ensure 4.5:1 contrast ratio for text (WCAG 1.4.3):
```dart
// Use ColorScheme.fromSeed with contrastLevel
ColorScheme.fromSeed(
  seedColor: brandColor,
  contrastLevel: 0.5, // Medium contrast
)
```

### Reduced Motion

Respect user motion preferences:

```dart
if (!MediaQuery.of(context).disableAnimations) {
  // Play animations
}
```

### High Contrast Mode (Flutter 3.38+)

Support system high contrast settings:

```dart
// Check for high contrast mode
final isHighContrast = MediaQuery.of(context).highContrast;

// Adjust UI elements
Container(
  color: isHighContrast ? Colors.yellow : context.shadColors.primary,
  child: Text(
    'High contrast text',
    style: TextStyle(
      fontWeight: isHighContrast ? FontWeight.bold : FontWeight.normal,
    ),
  ),
)
```

### Text Scaling Support (2026)

Respect user text scaling preferences:

```dart
// Get text scaler from MediaQuery
final textScaler = MediaQuery.of(context).textScaler;

// Apply to text
Text(
  'Scalable text',
  textScaler: textScaler,
)
```

### Semantic Headings (Flutter 3.16+)

Use semantic headings for screen reader navigation:

```dart
Semantics(
  header: true,  // Marks as heading for screen reader outline
  child: Text('Section Title', style: context.typo.h2),
)

// Screen reader live regions for dynamic content
Semantics(
  liveRegion: LiveRegion.polite,
  child: Text('Status updated'),
)
```

## References

- [shadcn/ui - The Foundation for Design Systems](https://ui.shadcn.com/)
- [shadcn_flutter Package](https://pub.dev/packages/shadcn_flutter)
- [Design Systems in Flutter - Medium](https://nimeshpiyumantha.medium.com/design-systems-in-flutter-bringing-modern-ui-principles-into-mobile-apps-inspired-by-shadcn-e5a19b086fc8)
- [Theming and Customization in Flutter - freeCodeCamp](https://www.freecodecamp.org/news/theming-and-customization-in-flutter-a-handbook-for-developers/)
