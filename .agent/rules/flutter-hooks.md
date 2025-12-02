---
trigger: always_on
---

# Flutter Hooks Standards

**Context:** Use `flutter_hooks` to manage ephemeral UI state (controllers, animations, focus nodes) instead of `StatefulWidget`.

## 1. Core Principles

* **Inheritance:** Use `HookWidget` (or `HookConsumerWidget` if using Riverpod) instead of `StatefulWidget`.

* **No Lifecycle Methods:** You must NOT use `initState`, `dispose`, or `didUpdateWidget`. Hooks handle this automatically.

* **Unconditional Call:** Hooks MUST be called unconditionally at the top of the `build` method. NEVER inside `if`, `for`, or callbacks.

* **Naming:** Custom hooks must start with `use` (e.g., `useLoggedState`).

## 2. Migration Mapping (The "Cheat Sheet")

When refactoring code, map standard Flutter patterns to their Hook equivalents:

| Traditional Pattern | Hook Equivalent | Notes |
| :--- | :--- | :--- |
| `TextEditingController` | `useTextEditingController()` | Auto-disposed. |
| `ScrollController` | `useScrollController()` | Auto-disposed. |
| `AnimationController` | `useAnimationController(duration: ...)` | Auto-disposed. No `vsync` needed. |
| `FocusNode` | `useFocusNode()` | Auto-disposed. |
| `TabController` | `useTabController(length: ...)` | Auto-disposed. |
| `WidgetsBindingObserver` | `useOnAppLifecycleStateChange(...)` | Handles resume/pause logic. |
| `mounted` check | `context.mounted` | Property (Flutter 3.7+). Use directly: `if (context.mounted)`. |
| `StreamSubscription` | `useStream(...)` | Returns current snapshot. |
| `FutureBuilder` | `useFuture(...)` | Returns current snapshot. |

## 3. Specific Patterns

### A. Animation Controllers

**Do NOT** implement `SingleTickerProviderStateMixin`.

```dart
// ✅ Correct
final controller = useAnimationController(duration: const Duration(seconds: 1));
controller.repeat();
```

### B. Lifecycle Management

**Do NOT** implement `WidgetsBindingObserver`.

**Preferred approach:** Use `useAppLifecycleState()` with `useEffect` to react to lifecycle changes.

```dart
// ✅ Correct (Preferred)
final lifecycleState = useAppLifecycleState();
useEffect(() {
  if (lifecycleState == null) return null;
  switch (lifecycleState) {
    case AppLifecycleState.resumed:
      // Resume camera/logic
      break;
    case AppLifecycleState.paused:
      // Pause camera/logic
      break;
    // ... other cases
  }
  return null;
}, [lifecycleState]);
```

**Alternative:** `useOnAppLifecycleStateChange` can be used but may have nullable state parameter depending on version.

### C. Async Safety

**Do NOT** use the property `mounted` from State. **Do NOT** use deprecated `useIsMounted()`.

**For Flutter 3.7+:** Use `BuildContext.mounted` property directly.

```dart
// ✅ Correct (Flutter 3.7+)
await futureOp();
if (context.mounted) {
  // Safe to update UI
}
```

**Note:** `useIsMounted()` is deprecated. Always use `context.mounted` when available (Flutter 3.7+).

## 4. Riverpod Integration

* Use `HookConsumerWidget` from `hooks_riverpod`.

* Signature: `Widget build(BuildContext context, WidgetRef ref)`.

## 5. Forui Hooks Integration (New Standard)

**Context:** When using `forui` components that require controllers, you **MUST** use the hooks provided by `package:forui_hooks`.

**Dependency:** Ensure `forui_hooks` is in `pubspec.yaml`.

**Mappings:**

| Component | Controller Class | Hook |
| :--- | :--- | :--- |
| Accordion | `FAccordionController` | `useFAccordionController()` |
| Popover | `FPopoverController` | `useFPopoverController()` |
| Tabs | `FTabController` | `useFTabController()` |
| Pagination | `FPaginationController` | `useFPaginationController()` |
| Select Group | `FSelectGroupController` | `useFSelectGroupController()` |

**Usage Pattern:**

```dart
// ✅ Correct
import 'package:forui_hooks/forui_hooks.dart';

class MyWidget extends HookWidget {
  @override
  Widget build(BuildContext context) {
    // Controller lifecycle is fully managed by the hook
    final tabController = useFTabController(length: 3);
    
    return FTabs(
      controller: tabController,
      children: [ ... ],
    );
  }
}
```