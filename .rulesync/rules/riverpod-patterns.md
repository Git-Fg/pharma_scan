---
targets:
  - '*'
root: false
description: Riverpod state management patterns and provider architecture
globs: []
cursor:
  alwaysApply: false
  description: Riverpod state management patterns and provider architecture
---
# Riverpod Patterns (2025 Standard)

## Core Mandates

1. **Generation:** Use `@riverpod` annotations exclusively. Manual `Provider` definitions are **BANNED**.
2. **Lifecycle:** Use `autoDispose` by default. Use `keepAlive: true` only for global singletons (Auth, Database).

## The "Mounted Guard" Protocol

**Critical:** To prevent "Zombie State" exceptions (setting state after widget disposal), you MUST check `ref.mounted` after every `await` in a Notifier.

```dart
@riverpod
class AuthController extends _$AuthController {
  @override
  FutureOr<void> build() {}
  Future<void> login() async {
    state = const AsyncLoading();
    final result = await _repo.login();
    
    // 🛑 SAFETY CHECK
    if (!ref.mounted) return;
    
    state = AsyncData(null);
  }
}
```

## Performance: The `.select()` Rule

**Rule:** Never watch a full object if you only need a specific field.

**Why:** Prevents unnecessary widget rebuilds when unrelated fields change.

```dart
// ❌ BAD: Rebuilds on ANY user change
final user = ref.watch(userProvider);
// ✅ GOOD: Rebuilds ONLY when name changes
final name = ref.watch(userProvider.select((u) => u.valueOrNull?.name));
```

## Architecture Layers

1. **Data Layer:** Functional Providers (`@riverpod`) returning Repositories.
2. **App Layer:** Notifiers (`class ... extends _$Notifier`) managing state.
3. **UI Layer:** `ConsumerWidget` consuming state via `ref.watch`.

## AsyncValue Pattern

- **Read:** Return `Future<T>` or `Stream<T>` from providers. Let `AsyncValue` handle loading/error states in UI.
- **Write:** Use `AsyncValue.guard` in Notifiers to capture errors automatically.

```dart
Future<void> update() async {
  state = const AsyncLoading();
  state = await AsyncValue.guard(() => _repo.update());
}
```

## Anti-Patterns

- ❌ `StateNotifier` / `ChangeNotifier` (Legacy).
- ❌ Passing `Ref` to UI widgets or Repositories.
- ❌ Side effects in `build()` (Use `ref.listen` in the Widget).
