# State Management Patterns

This document outlines the standardized state management patterns used in PharmaScan to ensure consistency, safety, and maintainability across the codebase.

## Core Principles

1. **Safety First**: All state modifications must check `ref.mounted` to prevent zombie state updates
2. **Error Handling**: All async operations must use `AsyncValue.guard` for consistent error handling
3. **Type Safety**: Leverage Riverpod Generator for compile-time type safety
4. **Separation of Concerns**: Side effects (toasts, haptics, navigation) should be handled separately from state logic

## Standard Patterns

### 1. Safe Write Operations

All write operations in notifiers must use the `AsyncValue.guard` pattern:

```dart
Future<void> someWriteOperation(SomeData data) async {
  final result = await safeExecute(
    () async {
      // Perform the operation
      await someService.updateData(data);
    },
    operationName: 'NotifierName.someWriteOperation',
  );

  if (!isMounted()) return;

  if (result.hasError) {
    logError(
      '[NotifierName] Failed to update data',
      result.error!,
      result.stackTrace ?? StackTrace.current,
    );
  }
}
```

### 2. ref.mounted Safety Checks

Before any state modification, always check if the ref is still mounted:

```dart
void updateState(SomeState newState) {
  if (!isMounted(context: 'updateState')) return;
  state = AsyncData(newState);
}
```

### 3. Using SafeAsyncNotifierMixin

All notifiers should mix in `SafeAsyncNotifierMixin` for standardized safety:

```dart
@riverpod
class MyNotifier extends _$MyNotifier with SafeAsyncNotifierMixin {
  @override
  MyState build() => const MyState();

  Future<void> performAction() async {
    // Safe execution with built-in error handling
    final result = await safeExecute(
      () => someAsyncOperation(),
      operationName: 'MyNotifier.performAction',
    );

    if (!isMounted()) return;
    // Handle result
  }
}
```

### 4. Side Effects Handling

Side effects (toasts, haptics, navigation) should be handled in dedicated hooks:

```dart
// In the widget
useMySideEffects(context: context, ref: ref);

// Hook implementation
void useMySideEffects({required BuildContext context, required WidgetRef ref}) {
  useEffect(() {
    final subscription = ref.watch(myProvider.notifier).sideEffects.listen((effect) {
      if (!context.mounted) return;

      switch (effect) {
        case MyToast(:final message):
          ShadToaster.of(context).show(ShadToast(title: Text(message)));
        case MyHaptic(:final type):
          // Handle haptic feedback
      }
    });

    return subscription.cancel;
  }, [context, ref]);
}
```

## Implementation Guidelines

### For New Notifiers

1. **Always use Riverpod Generator**: Use `@riverpod` annotations
2. **Mix in SafeAsyncNotifierMixin**: For standardized safety checks
3. **Use safeExecute()**: For all async operations
4. **Check isMounted()**: Before state modifications
5. **Use logError()**: For consistent error logging

### Error Handling Patterns

#### Success Case
```dart
if (result.hasData) {
  // Handle success
}
```

#### Error Case
```dart
if (result.hasError) {
  logError(
    '[Component] Operation failed',
    result.error!,
    result.stackTrace ?? StackTrace.current,
  );
  // Optionally show user-friendly error message
}
```

#### Cleanup
```dart
if (!isMounted()) return; // Early exit for safety
```

## Available Utilities

### AsyncNotifierHelper
- `safeExecute()`: Wraps operations in AsyncValue.guard with logging
- `isMounted()`: Checks ref.mounted with optional context logging

### SafeAsyncNotifierMixin
- `safeExecute()`: Delegates to AsyncNotifierHelper
- `isMounted()`: Delegates to AsyncNotifierHelper
- `logError()`: Conditionally logs errors if ref is mounted

### useAsyncFeedback Hook
- Handles loading states and error toasts for AsyncValue providers
- Provides haptic feedback for success states

## Migration Checklist

When refactoring existing code:

1. ✅ Add `SafeAsyncNotifierMixin` to notifier classes
2. ✅ Replace direct async calls with `safeExecute()`
3. ✅ Add `isMounted()` checks before state updates
4. ✅ Replace manual error handling with `logError()`
5. ✅ Extract complex side effects to dedicated hooks
6. ✅ Test error scenarios to ensure proper user feedback

## Examples

### Before (Unsafe)
```dart
Future<void> updateItem(Item item) async {
  await service.update(item);
  state = AsyncData(updatedState); // May throw if ref unmounted
}
```

### After (Safe)
```dart
Future<void> updateItem(Item item) async {
  final result = await safeExecute(
    () => service.update(item),
    operationName: 'MyNotifier.updateItem',
  );

  if (!isMounted()) return;

  if (result.hasError) {
    logError('[MyNotifier] Failed to update item', result.error!, result.stackTrace!);
    return;
  }

  // Success case handled automatically by stream/database updates
}
```

## Benefits

- **No Zombie State**: Eliminates state modifications on unmounted refs
- **Consistent Error Handling**: Standardized error logging and user feedback
- **Type Safety**: Compile-time guarantees through Riverpod Generator
- **Maintainability**: Clear patterns make code easier to understand and modify
- **Testability**: Separated concerns are easier to unit test
- **Developer Experience**: Predictable patterns reduce cognitive load