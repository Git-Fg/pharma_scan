---
targets:
  - '*'
root: false
description: 'AutoRoute navigation patterns, router injection, and route configuration'
globs: []
cursor:
  alwaysApply: false
  description: 'AutoRoute navigation patterns, router injection, and route configuration'
---
# Navigation (AutoRoute 11.0.0)

## Navigation Triggering

1. **Inside UI (Widgets):**
   - ✅ Use `context.router.push(...)` / `context.router.replace(...)` directly.
   - ❌ Do not inject the router via `ref.read(appRouterProvider)` inside `build()` or callbacks.
   - Rationale: `BuildContext` already exposes the typed AutoRoute extensions; keeps UI simple and avoids passing `ref` only for navigation.

2. **Inside Logic (Notifiers/Services):**
   - ✅ Use `ref.read(appRouterProvider)` when no `BuildContext` is available.
   - Rationale: Logic layers cannot access `context`, so router provider remains the correct injection point.

## Router Provider Pattern

```dart
@Riverpod(keepAlive: true)
AppRouter appRouter(Ref ref) => AppRouter();
```

## Notifier Injection Example

```dart
@riverpod
class MyNotifier extends _$MyNotifier {
  void performAction() {
    final router = ref.read(appRouterProvider);
    router.push(const DetailRoute());
  }
}
```

## Widget Navigation Example

```dart
ShadButton(
  onPressed: () => context.router.push(const DetailRoute()),
  child: Text(Strings.navigate),
);
```

## Reference Implementation

- Router: `lib/core/router/app_router.dart`
- Provider: `lib/core/router/router_provider.dart`
- Tab Navigation: See main screen implementation
- Path Parameters: See detail screen implementations
