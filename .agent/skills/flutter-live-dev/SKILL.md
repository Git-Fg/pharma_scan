---
description: "Enables real-time Flutter development with hot reload, widget inspection, and manual E2E testing via Dart MCP + mobile-mcp. Use when iterating on UI, debugging runtime errors, verifying widget trees, or manually testing flows on real devices. Not for initial project setup or CI/CD."
---

# Flutter Live Development

Real-time Flutter development ("vibe coding") combining **Dart MCP** (code-side) and **mobile-mcp** (device-side) for comprehensive verification and manual testing.

## MCP Architecture

| MCP Server | Domain | Key Tools |
|:---|:---|:---|
| **dart-mcp** | Code & Runtime | `hot_reload`, `get_widget_tree`, `get_runtime_errors`, `flutter_driver` |
| **mobile-mcp** | Device & Visual | `take_screenshot`, `list_elements_on_screen`, `click`, `swipe`, `type_keys` |

> [!CRITICAL]
> **Dual MCP = Complete Verification.** You MUST use both for every meaningful change.

---

## Quick Start

```
1. list_devices()                          → Select target device
2. launch_app(root: "file:///...", device) → Get DTD URI
3. connect_dart_tooling_daemon(uri)        → Connect to runtime
4. mobile_list_available_devices()         → Select mobile device
```

---

## Vibe Coding Loop

**Cycle**: Edit → Reload → Verify (Structural + Visual)

### 1. Edit & Reload

| Change Type | Tool | Action |
|:---|:---|:---|
| **UI/Logic** | `hot_reload(clearRuntimeErrors: true)` | Preserves State |
| **Provider/Schema** | `hot_restart()` | Resets State (Crucial for Riverpod/Generated code) |
| **Const/Global** | `hot_restart()` | Resets State |
| **New Package** | `pub(...)` → `hot_restart()` | Resets State |

### 2. Verify (MANDATORY after every reload)

**Structural (Dart MCP)**:
- `get_runtime_errors()` → ALWAYS check first
- `get_widget_tree(summaryOnly: true)` → Confirm hierarchy

**Visual (mobile-mcp)**:
- `mobile_take_screenshot()` → See actual UI (Don't guess!)
- `mobile_list_elements_on_screen()` → Confirm layout

---

## Stability Principles (The "Key" to Success)

Adhere to these principles to avoid common pitfalls like state loss or "ghost" bugs.

### 1. Stable Identifiers
**DO** use business IDs or indices for persistent state.
**DON'T** use internal framework keys (e.g., `RouteData.key`, `Element.key`) as they change on rebuilds.

> *Example: When managing tab state, use the `tabIndex` (0, 1, 2) as the registry key, NOT the route's randomized string key.*

### 2. Visual Diagnostics
**DO** inject state into the UI during debugging.
**DON'T** rely solely on logs (`print`).

> *Example: If a title isn't updating, temporarily change the fallback title to `Title ($debugState)` to see exactly what the app thinks is happening.*

### 3. Atomic Rewrites
**DO** use `write_to_file` for complex refactors (modifying >20% of a file or changing structure).
**DON'T** use `replace_file_content` multiple times on a shifting file; it leads to "target not found" errors.

---

## Dependency Best Practices

General rules for working with common Flutter libraries in a live-dev environment.

### Riverpod: Asynchronous State
**Pattern**: Notifier + AsyncValue + explicit `ref.mounted` checks.
```dart
@riverpod
class MyNotifier extends _$MyNotifier {
  @override
  FutureOr<MyState> build() async => const MyState.initial();

  Future<void> action() async {
    state = const AsyncValue.loading();
    // ... async work ...
    if (!ref.mounted) return; // CRITICAL: Check mount before state update
    state = const AsyncValue.data(newState);
  }
}
```
**Reload Rule**: Always `hot_restart` after changing the shape of a provider or its state class.

### Database (Drift/Sqlite)
**Pattern**: Strong Typing + Extension Types.
Avoid raw strings or loose IDs. Use `TableManager` or typed interfaces.
```dart
// DO: Use strongly typed IDs
final userId = UserId.validated('user_123');
await database.managers.users.filter((f) => f.id.equals(userId.value)).get();

// DON'T: Use raw strings for lookups
await database.customSelect('SELECT * FROM users WHERE id = ?', variables: [rawString]).get();
```
**Reload Rule**: Database connections persist through `hot_reload`, but schema changes require `builder_runner` + `hot_restart`.

### UI Systems (Shadcn/Material)
**Pattern**: Semantic Tokens over Hardcoded Values.
Always access theme properties via context extensions or semantic getters.
```dart
// DO: Use semantic tokens
Text('Error', style: context.typo.small, color: context.colors.destructive);

// DON'T: Hardcode values
Text('Error', style: TextStyle(fontSize: 12, color: Colors.red));
```
**Reload Rule**: UI changes are safe to `hot_reload` as long as theme dependencies are stable.

---

## Tool Decision Tree

Quick lookup for which tools to use when.

### Decision Flow
```
Is it UI?
├── Yes → hot_reload → screenshot → element_list
└── No
    ├── Is it const/global/schema/provider?
    │   ├── Yes → hot_restart → verify
    │   └── No (Logic only)
    │       ├── New package?
    │       │   ├── Yes → pub add → hot_restart → test
    │       │   └── No → hot_reload → test
    │       └── Need debug?
    │           ├── Runtime errors → get_runtime_errors
    │           └── Widget structure → get_widget_tree
```

### Problem → First Response
| Symptom | First Tool | Then |
|:---|:---|:---|
| **App Crash** | `get_runtime_errors` | Fix → `hot_reload` |
| **Logic Bug** | `run_tests(fail_fast: true)` | Fix → `run_tests` |
| **UI Glitch** | `mobile_take_screenshot` | `get_widget_tree` |
| **Missing Element** | `mobile_list_elements_on_screen` | Check layout code |

---

## Manual E2E Workflow

> **Agent as QA Tester**: Navigate the app manually using MCP tools, verify state at each step, report findings.

### Pattern: Navigate → Verify → Report

```
STEP 1: Navigate
├── mobile_list_elements_on_screen() → Find target element
├── mobile_click_on_screen_at_coordinates(x, y)
└── (or) mobile_swipe_on_screen(direction)

STEP 2: Verify
├── get_runtime_errors() → No crashes
├── get_widget_tree() → Expected widgets present
├── mobile_take_screenshot() → Visual confirmation
└── mobile_list_elements_on_screen() → Layout correct

STEP 3: Report
└── Document finding with screenshot evidence
```

---

## Best Practices

### Mission Control (Objective + Success Criteria)

Before any complex task, define:

```
<mission_control>
<objective>Verify login flow works correctly</objective>
<success_criteria>
- User can input credentials
- Submit triggers navigation to Home
- No runtime errors during flow
</success_criteria>
</mission_control>
```

### Verification is NOT Optional

Every workflow MUST include verification. Never assume success.

```
Verification Loop:
1. Take action
2. Check get_runtime_errors()
3. Check get_widget_tree()
4. Take screenshot
5. If issues → Fix → Repeat from 1
6. If clean → Proceed
```

## DO ✅

| Area | Practice |
|:---|:---|
| **Refactoring** | **ALWAYS** use `write_to_file` for deep changes/rewrites to avoid patch errors |
| **State Changes** | **ALWAYS** `hot_restart` after changing Provider shapes or generated files |
| **Diagnostics** | **ALWAYS** make invisible state visible (e.g., print IDs to UI text) |
| **Before Reload** | **ALWAYS** run `analyze_files` if syntax is uncertain |
| **After Reload** | **ALWAYS** check `get_runtime_errors` immediately |
| **Visual Verification** | **ALWAYS** take screenshot after UI changes |
| **Element Interaction** | **ALWAYS** use `list_elements_on_screen` before clicking |
| **Manual E2E** | **ALWAYS** verify after each navigation step |

## DON'T ❌

| Area | Anti-Pattern | Instead |
|:---|:---|:---|
| **Unstable Keys** | **DON'T** use `RouteData.key` or random IDs for registries | Use stable Business IDs or Indices |
| **Blind Coding** | **DON'T** trust logs alone | Use `mobile_take_screenshot` to see truth |
| **Syntax Errors** | **DON'T** spam `hot_reload` on broken code | Run `analyze_files` first |
| **Silent Failures** | **DON'T** trust "it looks fine" | Check logs for silent errors |
| **Hardcoded Coords** | **DON'T** hardcode tap coordinates | Use `list_elements_on_screen` |
| **Skip Verification** | **DON'T** proceed without verifying | Always dual-verify (structural + visual) |
| **Assumption** | **DON'T** assume widget tree is current | Refresh with `hot_reload` if stale |

---

## Tool Reference

| Category | Tool | When to Use |
|:---|:---|:---|
| **Session** | `list_devices` | Start of session |
| | `launch_app` | Start / after crash |
| | `connect_dart_tooling_daemon` | After launch |
| | `list_running_apps` | Reconnecting |
| | `stop_app` | End session / cleanup |
| **Reload** | `hot_reload` | Standard edits |
| | `hot_restart` | Provider/Generator/Const/Global |
| **Inspect** | `get_runtime_errors` | After every reload |
| | `get_widget_tree` | Structure check |
| | `get_app_logs` | Deep debugging |
| | `get_selected_widget` | Inspector mode |
| **Navigate** | `mobile_list_elements_on_screen` | Before any tap |
| | `mobile_click_on_screen_at_coordinates` | Tap element |
| | `mobile_swipe_on_screen` | Scroll/Navigate |
| | `mobile_type_keys` | Text input |
| | `mobile_take_screenshot` | Visual evidence |
| **Project** | `pub_dev_search` | Package research |
| | `pub` | Add/remove deps |
| | `analyze_files` | Static analysis |
| | `dart_fix` | Auto-fixes |
| | `resolve_workspace_symbol` | Symbol lookup |
