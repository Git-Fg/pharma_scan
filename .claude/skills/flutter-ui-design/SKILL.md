---
description: Create distinctive, production-grade Flutter interfaces using shadcn_ui_flutter. Guides UI decisions from design thinking through implementation with semantic tokens, component selection, and Flutter-specific patterns.
---

This skill guides creation of distinctive, production-grade Flutter interfaces using shadcn_ui_flutter. It covers design thinking, component selection, and implementation patterns for building memorable, cohesive UIs.

## Design Thinking

Before coding, understand the context and commit to a BOLD aesthetic direction:
- **Purpose**: What problem does this interface solve? Who uses it?
- **Tone**: Pick an extreme: brutally minimal, maximalist chaos, retro-futuristic, organic/natural, luxury/refined, playful/toy-like, editorial/magazine, brutalist/raw, art deco/geometric, soft/pastel, industrial/utilitarian, etc.
- **Constraints**: Technical requirements (Flutter, performance, accessibility).
- **Differentiation**: What makes this UNFORGETTABLE? What's the one thing someone will remember?

**CRITICAL**: Choose a clear conceptual direction and execute it with precision. Bold maximalism and refined minimalism both work - the key is intentionality, not intensity.

Then implement working Flutter code using shadcn_ui that is:
- Production-grade and functional
- Visually striking and memorable
- Cohesive with a clear aesthetic point-of-view
- Meticulously refined in every detail

---

## Flutter Design Tokens

Use semantic design tokens from the shadcn_ui theme extension:

| Token | Access | Example |
|:---|:---|:---|
| **Typography** | `context.typo.h1-h5`, `.large`, `.medium`, `.small` | `context.typo.h3` |
| **Colors** | `context.shadColors.primary`, `.muted`, `.accent` | `context.shadColors.primary` |
| **Spacing** | `context.spacing.xs` through `xxl` | `context.spacing.md` |
| **Radius** | `context.radiusSmall`, `.medium`, `.large` | `context.radiusMedium` |
| **Semantic** | `context.surfacePositive`, `.textWarning` | `context.surfacePositive` |

**Always use tokens** - never hardcode colors or dimensions.

---

## Shadcn UI Component Library

### Form Components

| Component | When to Use |
|:---|:---|
| `ShadButton` | Primary, secondary, outline, ghost, destructive variants |
| `ShadIconButton` | Icon-only actions (close, menu, navigation) |
| `ShadInput` | Single-line text input |
| `ShadInputFormField` | Text input with validation support |
| `ShadTextarea` | Multi-line text input |
| `ShadSelect<T>` | Dropdown selection (generic type-safe) |
| `ShadSelectFormField<T>` | Select with form integration |
| `ShadCombobox<T>` | Dropdown with search functionality |
| `ShadCheckbox` | Boolean/ternary checkbox selection |
| `ShadRadioGroup<T>` | Single choice from options |
| `ShadRadio<T>` | Individual radio option |
| `ShadSwitch` | Toggle switch (on/off) |
| `ShadSwitchFormField` | Switch with form integration |
| `ShadSlider` | Range/value selection slider |
| `ShadInputOTP` | OTP/captcha character input |

### Date/Time Components

| Component | When to Use |
|:---|:---|
| `ShadCalendar` | Calendar view for date selection |
| `ShadDatePicker` | Date picker dialog |
| `ShadTimePicker` | Time picker dialog |

### Display Components

| Component | When to Use |
|:---|:---|
| `ShadCard` | Container with optional title/description/footer |
| `ShadBadge` | Status indicators, counts, labels |
| `ShadAlert` | Warning/info/error banners with icons |
| `ShadAvatar` | User/profile images with fallback |
| `ShadProgress` | Progress indicator (determinate/indeterminate) |
| `ShadSeparator` | Visual divider between content |
| `ShadTable` | Tabular data display |

### Navigation Components

| Component | When to Use |
|:---|:---|
| `ShadTabs` | Tab navigation (horizontal/vertical) |
| `ShadBreadcrumb` | Navigation breadcrumbs |
| `ShadMenubar` | Menu bar with dropdown items |
| `ShadPopover` | Popover menu (anchored positioning) |
| `ShadTooltip` | Hover tooltip (with delay) |
| `ShadContextMenu` | Right-click context menu |

### Layout Components

| Component | When to Use |
|:---|:---|
| `ShadDialog` | Modal dialog (use `showShadDialog`) |
| `ShadSheet` | Bottom sheet drawer (use `showShadSheet`) |
| `ShadResizable` | Resizable panel layout |

### Feedback Components

| Component | When to Use |
|:---|:---|
| `ShadToast` | Toast notifications (use `showShadToast`) |
| `ShadSonner` | Modern notification (v0.24.0+) |

### Data Components

| Component | When to Use |
|:---|:---|
| `ShadAccordion` | Collapsible sections (FAQ, details) |
| `ShadForm` | Form with validation, dot notation support |

---

## Shadcn UI Best Practices

### Composition Over Inheritance

```dart
// CORRECT - Compose existing widgets
ShadCard(
  title: Text('Settings', style: context.typo.h4),
  description: Text('Manage your preferences', style: context.typo.small),
  child: Column(
    children: [
      ShadButton.outline(onPressed: () {}, child: Text('Reset')),
      ShadButton.primary(onPressed: () {}, child: Text('Save')),
    ],
  ),
)

// INCORRECT - Never extend widgets unnecessarily
class MyCustomCard extends StatelessWidget { ... }
```

### Theme Usage

```dart
// Use semantic colors
context.shadColors.primary
context.shadColors.muted
context.shadColors.accent
context.colors.destructive
context.colors.warning
context.colors.success

// NEVER hardcode colors
Color(0xFF0F766E)  // ❌
Colors.blue         // ❌
```

### Typography

```dart
// Use typo tokens
context.typo.h1  // Display heading
context.typo.h2  // Large heading
context.typo.h3  // Medium heading
context.typo.h4  // Small heading
context.typo.h5  // Caption heading
context.typo.large  // Large body
context.typo.medium // Medium body (default)
context.typo.small  // Small body
context.typo.muted  // Muted/secondary text
```

### Animation

```dart
// flutter_animate integration is built-in
// Use animated variants for micro-interactions
ShadButton(
  onPressed: () {},
  animationDuration: Duration(milliseconds: 200),
  child: Text('Submit'),
)
```

---

## Flutter Motion Patterns

### Implicit Animations

| Widget | Use For |
|:---|:---|
| `AnimatedContainer` | Animate any container property |
| `AnimatedOpacity` | Fade in/out transitions |
| `AnimatedCrossFade` | Crossfade between two widgets |
| `AnimatedDefaultTextStyle` | Text style transitions |
| `TweenAnimationBuilder` | Custom tween animations |

### Explicit Animations

| Widget | Use For |
|:---|:---|
| `AnimationController` | Manual animation control |
| `Hero` | Shared element transitions between routes |
| `CustomTween` | Specialized transition logic |

### High-Impact Moments

- **Page load**: Staggered reveals using `animationDelay` in flutter_animate
- **Scroll**: Triggered animations via `NotificationListener`
- **Navigation**: Hero transitions for continuity between screens

---

## Spatial Composition

| Pattern | Widget | Use When |
|:---|:---|:---|
| **Linear** | `Row`, `Column` | Aligned, stacked content |
| **Overlap** | `Stack` | Layered elements, overlays |
| **Responsive** | `LayoutBuilder` | Adaptive to parent constraints |
| **Constrained** | `ConstrainedBox`, `SizedBox` | Fixed dimensions, limits |
| **Flexible** | `Flexible`, `Expanded` | Flex distribution, responsive sizing |
| **Aspect** | `AspectRatio`, `FittedBox` | Aspect ratio preservation |

---

## Visual Details

| Effect | Implementation |
|:---|:---|
| **Gradients** | `ShaderMask` with `LinearGradient` or `RadialGradient` |
| **Noise/Texture** | `CustomPaint` with noise image |
| **Shadows** | `BoxShadow` in `BoxDecoration` |
| **Blur** | `BackdropFilter` with `ImageFilter.blur` |
| **Clip shapes** | `ClipRRect`, `ClipPath`, `CustomClipper<Shape>` |

---

## Performance-Sensitive Design

| Pattern | Why |
|:---|:---|
| `const` constructors | Reduce rebuild overhead, improve performance |
| `Key` in lists | Proper element tracking, animation stability |
| `RepaintBoundary` | Isolate animated regions, reduce repaints |
| `AutomaticKeepAlive` | Preserve scroll position in nested lists |
| `LazyLoading` | Defer loading of images/network assets |

---

## Anti-Patterns to Avoid

| ❌ Don't | ✅ Instead |
|:---|:---|
| Hardcoded colors | `context.shadColors.*` |
| Material colors directly | Semantic extensions from theme |
| Extend StatelessWidget | Compose existing shadcn widgets |
| `print()` debugging | `LoggerService` |
| Cross-feature imports | Keep features isolated |
| Skip `const` | Use const where possible |

---

## Integration Points

- **flutter-mcp-vibe-coding**: For testing UIs with MCP tools
- **flutter-ui.md**: Project-specific UI rules
- **api-design.md**: Consistent naming conventions

---

## References

- shadcn_ui pub.dev: https://pub.dev/packages/shadcn_ui
- shadcn_ui docs: https://flutter-shadcn-ui.mariuti.com/
