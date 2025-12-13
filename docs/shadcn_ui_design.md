# Shadcn UI Guide (PharmaScan 2025)

**Version:** 2.0.0
**Context:** Definitive guide for UI development, theming, and component usage.
**Status:** Enforced Standard.

---

## 1. Core Philosophy: The "No-Boilerplate" Mandate

We leverage the native capabilities of `shadcn_ui` to minimize code and maximize consistency.

### The 5 Golden Rules

1. **Theme is the Single Source of Truth:**
    * **✅ DO:** Use `context.shadTheme`, `context.shadTextTheme`, `context.shadColors`.
    * **❌ DON'T:** Re-declare colors, border radii, or breakpoints in constants files (e.g., `AppDimens` styling constants are deprecated).

2. **Radius Policy:**
    * **✅ DO:** Use `context.shadTheme.radius` for all borders.
    * **❌ DON'T:** Hardcode `BorderRadius.circular(8)`.

3. **Responsive Policy:**
    * **✅ DO:** Use `ShadResponsiveBuilder` or `context.breakpoints` to switch layouts.
    * **❌ DON'T:** Use `MediaQuery.of(context).size.width` manually.

4. **No "Dumb Wrappers":**
    * **✅ DO:** Use `ShadCard`, `ShadButton` directly in your widget tree.
    * **❌ DON'T:** Create `MyCustomButton` that just wraps `ShadButton` to add padding. Padding belongs in the layout, not the component definition.

5. **Semantic Colors:**
    * **✅ DO:** Use `context.shadColors.destructive`, `context.shadColors.primary`.
    * **❌ DON'T:** Use `Colors.red`, `Color(0xFF...)`.

---

## 2. Setup & Configuration

### Root Configuration (`main.dart`)

We configure the theme **once** at the root. We do not manually construct color palettes; we use the semantic factory constructors.

```dart
ShadApp.custom(
  themeMode: themeMode,
  // ☀️ LIGHT: Teal 700 (Medical Deep Green)
  theme: ShadThemeData(
    brightness: Brightness.light,
    colorScheme: const ShadGreenColorScheme.light(
      primary: Color(0xFF0F766E), // The ONLY hardcoded color allowed
    ),
  ),
  // 🌙 DARK: Teal 500 (Accessible Emerald)
  darkTheme: ShadThemeData(
    brightness: Brightness.dark,
    colorScheme: const ShadGreenColorScheme.dark(
      primary: Color(0xFF14B8A6),
    ),
  ),
  appBuilder: (context) => MaterialApp.router(/*...*/),
);
````

### Theme Access Patterns

We use the `ShadThemeContext` extension in `lib/core/theme/theme_extensions.dart` for consistent theme access:

```dart
// ✅ Preferred patterns
context.shadTheme.colorScheme.primary
context.shadColors.primary
context.shadTextTheme.h3
context.shadTheme.radius

// ❌ Deprecated - Do not use
context.colors.primary
context.typo.h3
context.primary
```

---

## 3\. Typography System

All typography must use `context.shadTextTheme.*`. Do not manually create `TextStyle` objects unless absolutely necessary for specific one-off formatting.

### Headers

| Style | Usage | Code |
| :--- | :--- | :--- |
| **H1 Large** | Page Titles (Hero) | `style: context.shadTextTheme.h1Large` |
| **H1** | Page Titles (Standard) | `style: context.shadTextTheme.h1` |
| **H2** | Section Headers | `style: context.shadTextTheme.h2` |
| **H3** | Card Titles | `style: context.shadTextTheme.h3` |
| **H4** | Sub-section / Dialog Titles | `style: context.shadTextTheme.h4` |

### Body & Content

| Style | Usage | Code |
| :--- | :--- | :--- |
| **P** | Standard Body Text | `style: context.shadTextTheme.p` |
| **Lead** | Subtitles / Intros | `style: context.shadTextTheme.lead` |
| **Large** | Emphasized Body | `style: context.shadTextTheme.large` |
| **Small** | Captions / Metadata | `style: context.shadTextTheme.small` |
| **Muted** | Secondary Info / Hints | `style: context.shadTextTheme.muted` |

### Special

| Style | Usage | Code |
| :--- | :--- | :--- |
| **Blockquote** | Quotes / callouts | `style: context.shadTextTheme.blockquote` |
| **Table** | Data grids | `style: context.shadTextTheme.table` |
| **List** | List items | `style: context.shadTextTheme.list` |

---

## 4\. Responsive Design (Native)

We adhere to the standard `shadcn_ui` breakpoints.

### Breakpoint Values

* `tn` (Tiny): 0
* `sm` (Small): 640
* `md` (Medium): 768
* `lg` (Large): 1024
* `xl` (Extra Large): 1280
* `xxl` (Extra Extra Large): 1536

### Usage Pattern

Use `ShadResponsiveBuilder` to return different widgets based on screen size.

```dart
ShadResponsiveBuilder(
  builder: (context, breakpoint) {
    return switch (breakpoint) {
      ShadBreakpointTN() => const MobileLayout(),
      ShadBreakpointSM() => const MobileLayout(),
      ShadBreakpointMD() => const TabletLayout(),
      ShadBreakpointLG() => const DesktopLayout(),
      ShadBreakpointXL() => const DesktopLayout(),
      ShadBreakpointXXL() => const DesktopLayout(),
    };
  },
);
```

For simple conditional logic (e.g., hiding a sidebar):

```dart
if (context.breakpoints.lg <= context.breakpoint) {
  return SideBar(); // Show only on Large+
}
```

---

## 5\. Components & Examples

### Buttons

```dart
// Primary (Solid)
ShadButton(
  onPressed: () {},
  child: const Text('Save Changes'),
)

// Secondary (Muted background)
ShadButton.secondary(
  onPressed: () {},
  child: const Text('Cancel'),
)

// Destructive (Red)
ShadButton.destructive(
  onPressed: () {},
  child: const Text('Delete Account'),
)

// Outline (Border only)
ShadButton.outline(
  onPressed: () {},
  child: const Text('View Details'),
)

// Ghost (No background until hover)
ShadButton.ghost(
  onPressed: () {},
  child: const Text('Settings'),
)
```

### Cards

Always use `ShadCard` for content grouping. Use the `footer` slot for actions.

```dart
ShadCard(
  title: Text('Notification Settings', style: context.shadTextTheme.h4),
  description: const Text('Manage your push notifications.'),
  footer: Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      ShadButton(child: const Text('Save'), onPressed: () {}),
    ],
  ),
  child: Column(
    children: [
      // Content here
    ],
  ),
)
```

### Forms (Hook Pattern)

We use `flutter_hooks` + `ShadForm`. **Do not** use `StatefulWidget` for simple forms.

```dart
class LoginForm extends HookConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Memoize the GlobalKey
    final formKey = useMemoized(() => GlobalKey<ShadFormState>());

    return ShadForm(
      key: formKey,
      child: Column(
        children: [
          ShadInputFormField(
            id: 'email',
            label: const Text('Email'),
            validator: (v) => v.isEmpty ? 'Required' : null,
          ),
          ShadButton(
            onPressed: () {
              if (formKey.currentState!.saveAndValidate()) {
                final data = formKey.currentState!.value;
                print(data['email']); 
              }
            },
            child: const Text('Login'),
          )
        ],
      ),
    );
  }
}
```

### Sheets & Dialogs

* **Mobile:** Prefer `ShadSheet` (Side: Bottom).
* **Desktop:** Prefer `ShadDialog` or `ShadSheet` (Side: Right).

<!-- end list -->

```dart
// Sheet (Preferred for Mobile)
showShadSheet(
  context: context,
  side: ShadSheetSide.bottom,
  builder: (context) => const MedicationDetailSheet(),
);

// Alert Dialog
showShadDialog(
  context: context,
  builder: (context) => ShadDialog.alert(
    title: const Text('Are you sure?'),
    description: const Text('This action cannot be undone.'),
    actions: [
      ShadButton.outline(child: const Text('Cancel'), onPressed: () => Navigator.pop(context)),
      ShadButton.destructive(child: const Text('Delete'), onPressed: () {}),
    ],
  ),
);
```
