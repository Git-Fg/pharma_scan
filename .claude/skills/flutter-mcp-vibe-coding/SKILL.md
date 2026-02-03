---
name: flutter-mcp-vibe-coding
description: "Teaches Flutter MCP + Dart MCP best practices for vibe coding. Use when developing Flutter apps, running tests, debugging, or need hot reload/restart. Not for backend-only TypeScript/Node.js projects."
argument-hint: "[task-description]"
disable-model-invocation: false
allowed-tools: "mcp__dart-mcp-server:*,mcp__mobile-mcp-server:*,Read,Glob,Grep"
---

# Flutter MCP Vibe Coding Skill

Real-time Flutter development combining **Dart MCP** (code-side) and **mobile-mcp** (device-side) for comprehensive verification.

## MCP Architecture

| MCP Server | Domain | Key Tools |
|:---|:---|:---|
| **dart-mcp** | Code & Runtime | `list_devices`, `launch_app`, `hot_reload`, `get_widget_tree`, `get_runtime_errors` |
| **mobile-mcp** | Device & Visual | `mobile_take_screenshot`, `mobile_list_elements_on_screen`, `mobile_click_on_screen_at_coordinates`, `mobile_swipe_on_screen`, `mobile_type_keys` |

> [!CRITICAL]
> **Dual MCP = Complete Verification.** Use both for every meaningful change.

---

## Mission Control

**Objective**: Enable confident, efficient Flutter development using Flutter MCP + Dart MCP tools with minimal friction.

**Success Criteria**:
- Use the right MCP tool for each development task
- Code quality is verified before completion
- Flutter/Dart best practices are followed automatically
- Hot reload/restart keeps you in flow state

---

## Core Philosophy: Vibe Coding

Vibe coding means trusting the tools while maintaining quality. Modern AI + modern tools = efficient development.

**Key Principle**: Over-constraining causes more failures than under-constraining. Trust the tools, verify the output.

---

## Vibe Coding Loop

**Cycle**: Edit → Reload → Verify (Structural + Visual)

### 1. Edit & Reload

| Change Type | Tool | State |
|:---|:---|:---|
| UI/Logic | `mcp__dart-mcp-server__hot_reload(clearRuntimeErrors: true)` | Preserved |
| Const/Global/Init | `mcp__dart-mcp-server__hot_restart()` | Reset |
| New Package | `mcp__dart-mcp-server__pub(command: "add", ...)` + `hot_restart()` | Reset |

### 2. Verify (MANDATORY after every reload)

**Structural (Dart MCP)**:
- `mcp__dart-mcp-server__get_runtime_errors()` → ALWAYS check first
- `mcp__dart-mcp-server__get_widget_tree(summaryOnly: true)` → Confirm hierarchy

**Visual (mobile-mcp)**:
- `mcp__mobile-mcp__mobile_take_screenshot()` → See actual UI
- `mcp__mobile-mcp__mobile_list_elements_on_screen()` → Confirm layout

---

## Quick Start

```
1. mcp__dart-mcp-server__list_devices()                          → Select target device
2. mcp__dart-mcp-server__launch_app(root: "file:///...", device) → Get DTD URI
3. mcp__dart-mcp-server__connect_dart_tooling_daemon(uri)        → Connect to runtime
4. mcp__mobile-mcp__mobile_list_available_devices()              → Select mobile device
```

---

## Complete Example: Add Medication Detail Screen

This walkthrough demonstrates implementing a new "Medication Detail" screen from scaffold to verification using MCP tools.

### Feature Requirements
- Display medication name, dosage, and side effects
- Add to scanner tab navigation
- Connect to existing CatalogDao

### Step 1: Setup Session

```bash
# List and select device
mcp__dart-mcp-server__list_devices

# Launch app (returns PID and DTD URI)
mcp__dart-mcp-server__launch_app(device: "iPhone 16", root: "/Users/felix/Documents/Flutter/pharma_scan")

# Connect to Dart Tooling Daemon
mcp__dart-mcp-server__connect_dart_tooling_daemon(uri: "dart-tooling-daemon://...")

# Verify mobile device
mcp__mobile-mcp__mobile_list_available_devices
```

### Step 2: Create Scaffold

```bash
# Create file
Write file_path: "lib/features/scanner/presentation/screens/medication_detail_screen.dart"

# Apply hot reload
mcp__dart-mcp-server__hot_reload(pid: 12345)

# Verify scaffold
mcp__dart-mcp-server__get_runtime_errors(clearRuntimeErrors: true)
mcp__dart-mcp-server__get_widget_tree(summaryOnly: true)
mcp__mobile-mcp__mobile_take_screenshot(device: "R3CT80K7H5", saveTo: "step2-scaffold.png")
```

### Step 3: Add Provider

```bash
# Write provider
Write file_path: "lib/features/scanner/presentation/notifiers/medication_detail_notifier.dart"

# Hot reload
mcp__dart-mcp-server__hot_reload(pid: 12345)

# Verify no errors
mcp__dart-mcp-server__get_runtime_errors(clearRuntimeErrors: true)
```

### Step 4: Implement UI

```bash
# Edit screen with shadcn components
Edit file: medication_detail_screen.dart

# Reload and verify
mcp__dart-mcp-server__hot_reload(pid: 12345)
mcp__mobile-mcp__mobile_take_screenshot(device: "R3CT80K7H5", saveTo: "step4-ui.png")
mcp__mobile-mcp__mobile_list_elements_on_screen(device: "R3CT80K7H5")
```

### Step 5: Connect Data Layer

```bash
# Update provider to use CatalogDao
Edit file: medication_detail_notifier.dart

# Hot reload
mcp__dart-mcp-server__hot_reload(pid: 12345)

# Verify runtime
mcp__dart-mcp-server__get_runtime_errors(clearRuntimeErrors: true)
```

### Step 6: Test Navigation

```bash
# Navigate to screen
mcp__mobile-mcp__mobile_list_elements_on_screen(device: "R3CT80K7H5")
mcp__mobile-mcp__mobile_click_on_screen_at_coordinates(device: "R3CT80K7H5", x: 200, y: 400)

# Verify screen loaded
mcp__dart-mcp-server__get_widget_tree(summaryOnly: true)
mcp__mobile-mcp__mobile_take_screenshot(device: "R3CT80K7H5", saveTo: "step6-nav.png")
```

### Step 7: Run Tests

```bash
# Write test
Write file_path: "test/features/scanner/medication_detail_test.dart"

# Run specific test
mcp__dart-mcp-server__run_tests(roots: [{root: "/Users/felix/Documents/Flutter/pharma_scan", paths: ["test/features/scanner/medication_detail_test.dart"]}])

# Run full suite
mcp__dart-mcp-server__run_tests(roots: [{root: "/Users/felix/Documents/Flutter/pharma_scan"}])
```

### Step 8: Quality Gate

```bash
# Format
mcp__dart-mcp-server__dart_format(roots: [{root: "/Users/felix/Documents/Flutter/pharma_scan"}])

# Fix
mcp__dart-mcp-server__dart_fix(roots: [{root: "/Users/felix/Documents/Flutter/pharma_scan"}])

# Analyze
mcp__dart-mcp-server__analyze_files(roots: [{root: "/Users/felix/Documents/Flutter/pharma_scan", paths: ["lib/features/scanner/"]}])

# Final test
mcp__dart-mcp-server__run_tests(roots: [{root: "/Users/felix/Documents/Flutter/pharma_scan"}])

# Cleanup
mcp__dart-mcp-server__stop_app(pid: 12345)
```

### Summary: Tool Usage Timeline

| Phase | Tools Used | Verification |
|:---|:---|:---|
| Setup | list_devices, launch_app, connect_dart_tooling_daemon | Running app |
| Scaffold | Write → hot_reload | get_runtime_errors, get_widget_tree |
| Provider | Write → hot_reload | get_runtime_errors |
| UI | Edit → hot_reload | screenshot, list_elements |
| Data | Edit → hot_reload | get_runtime_errors |
| Navigation | tap | widget_tree, screenshot |
| Tests | run_tests | All passing |
| Quality | format, fix, analyze | Zero errors |

---

## Development Workflow Patterns

### Pattern 1: Quick Development Cycle

```
1. List devices → Select target device
2. Launch app → Get PID for later operations
3. Make code changes → Edit files
4. Hot reload → Apply changes instantly
5. Verify → Check runtime errors + screenshot
6. Iterate → Repeat steps 3-5
7. Hot restart → If state gets corrupted
8. Stop app → When done
```

**Commands**:
```bash
# 1. Start development
mcp__dart-mcp-server__list_devices
mcp__dart-mcp-server__launch_app(device: "iPhone 16", root: "/Users/felix/Documents/Flutter/pharma_scan")

# 2. During development - make edits, then:
mcp__dart-mcp-server__hot_reload(pid: 12345)

# 3. If state is messed up:
mcp__dart-mcp-server__hot_restart(pid: 12345)

# 4. Verification (REQUIRED):
mcp__dart-mcp-server__get_runtime_errors(clearRuntimeErrors: true)
mcp__dart-mcp-server__get_widget_tree(summaryOnly: true)
mcp__mobile-mcp__mobile_take_screenshot(device: "R3CT80K7H5", saveTo: "verify.png")

# 5. Cleanup:
mcp__dart-mcp-server__stop_app(pid: 12345)
```

### Pattern 2: Test-Driven Development

```
1. Write failing test first
2. Run tests to confirm failure
3. Implement code
4. Run tests to confirm pass
5. Run full test suite
```

**Commands**:
```bash
# Run specific test
mcp__dart-mcp-server__run_tests(roots: [{root: "/Users/felix/Documents/Flutter/pharma_scan", paths: ["test/features/scanner_test.dart"]}])

# Run all tests with coverage
mcp__dart-mcp-server__run_tests(roots: [{root: "/Users/felix/Documents/Flutter/pharma_scan"}], testRunnerArgs: {coverage: "coverage"})

# Run with tags
mcp__dart-mcp-server__run_tests(roots: [{root: "/Users/felix/Documents/Flutter/pharma_scan"}], testRunnerArgs: {tags: ["integration"]})
```

### Pattern 3: Quality Gate Before Commit

```
1. Format code
2. Apply fixes
3. Analyze code
4. Run tests
```

**Commands**:
```bash
# Format and fix
mcp__dart-mcp-server__dart_format(roots: [{root: "/Users/felix/Documents/Flutter/pharma_scan"}])
mcp__dart-mcp-server__dart_fix(roots: [{root: "/Users/felix/Documents/Flutter/pharma_scan"}])

# Analyze
mcp__dart-mcp-server__analyze_files(roots: [{root: "/Users/felix/Documents/Flutter/pharma_scan", paths: ["lib/"]}])

# Run tests
mcp__dart-mcp-server__run_tests(roots: [{root: "/Users/felix/Documents/Flutter/pharma_scan"}])
```

### Pattern 4: Widget Tree Debugging

```
1. Connect to Dart Tooling Daemon
2. Get widget tree
3. Inspect elements
4. Find specific widget
```

**Commands**:
```bash
# Connect to DTD (get URI from "Copy DTD Uri" action)
mcp__dart-mcp-server__connect_dart_tooling_daemon(uri: "dart-tooling-daemon://...")

# Get widget tree
mcp__dart-mcp-server__get_widget_tree(summaryOnly: false)

# Get selected widget
mcp__dart-mcp-server__get_selected_widget

# Set selection mode for user to pick widget
mcp__dart-mcp-server__set_widget_selection_mode(enabled: true)

# Get runtime errors
mcp__dart-mcp-server__get_runtime_errors(clearRuntimeErrors: true)
```

### Pattern 5: Mobile Testing

```
1. List available devices
2. Launch app on device
3. Interact with UI
4. Take screenshot
5. Verify results
```

**Commands**:
```bash
# List devices
mcp__mobile-mcp__mobile_list_available_devices

# Launch app
mcp__mobile-mcp__mobile_install_app(device: "R3CT80K7H5", path: "build/ios/ipa/pharma_scan.ipa")
mcp__mobile-mcp__mobile_launch_app(device: "R3CT80K7H5", packageName: "com.pharmascan.app")

# Interact
mcp__mobile-mcp__mobile_click_on_screen_at_coordinates(device: "R3CT80K7H5", x: 200, y: 400)
mcp__mobile-mcp__mobile_type_keys(device: "R3CT80K7H5", text: "doliprane", submit: true)

# Verify
mcp__mobile-mcp__mobile_take_screenshot(device: "R3CT80K7H5", saveTo: "test_screenshot.png")
mcp__mobile-mcp__mobile_list_elements_on_screen(device: "R3CT80K7H5")
```

### Pattern 6: Dependency Management

```
1. Search for packages
2. Add dependencies
3. Verify compatibility
```

**Commands**:
```bash
# Search pub.dev
mcp__dart-mcp-server__pub_dev_search(query: "state management riverpod flutter")

# Add dependency
mcp__dart-mcp-server__pub(command: "add", packageNames: ["new_package"], roots: [{root: "/Users/felix/Documents/Flutter/pharma_scan"}])

# Check outdated
mcp__dart-mcp-server__pub(command: "outdated", roots: [{root: "/Users/felix/Documents/Flutter/pharma_scan"}])

# Get dependencies
mcp__dart-mcp-server__pub(command: "get", roots: [{root: "/Users/felix/Documents/Flutter/pharma_scan"}])
```

---

## Manual E2E Workflow

> **Agent as QA Tester**: Navigate the app manually using MCP tools, verify state at each step, report findings.

### Pattern: Navigate → Verify → Report

```
STEP 1: Navigate
├── mcp__mobile-mcp__mobile_list_elements_on_screen() → Find target element
├── mcp__mobile-mcp__mobile_click_on_screen_at_coordinates(x, y)
└── (or) mcp__mobile-mcp__mobile_swipe_on_screen(direction)

STEP 2: Verify
├── mcp__dart-mcp-server__get_runtime_errors() → No crashes
├── mcp__dart-mcp-server__get_widget_tree() → Expected widgets present
├── mcp__mobile-mcp__mobile_take_screenshot() → Visual confirmation
└── mcp__mobile-mcp__mobile_list_elements_on_screen() → Layout correct

STEP 3: Report
└── Document finding with screenshot evidence
```

### Example: Login Flow Exploration

```
Checklist:
- [ ] Navigate to login screen
      └─ mcp__mobile-mcp__mobile_click(...) on "Login" button
- [ ] Verify login form appears
      └─ mcp__dart-mcp-server__get_widget_tree() contains TextField, ElevatedButton
      └─ mcp__mobile-mcp__mobile_take_screenshot()
- [ ] Enter credentials
      └─ mcp__mobile-mcp__mobile_click(...) on email field
      └─ mcp__mobile-mcp__mobile_type_keys(text: "user@test.com", submit: false)
      └─ mcp__mobile-mcp__mobile_click(...) on password field
      └─ mcp__mobile-mcp__mobile_type_keys(text: "password", submit: false)
- [ ] Submit login
      └─ mcp__mobile-mcp__mobile_click(...) on submit button
- [ ] Verify success
      └─ mcp__dart-mcp-server__get_runtime_errors() → No errors
      └─ mcp__dart-mcp-server__get_widget_tree() → Home screen widgets present
      └─ mcp__mobile-mcp__mobile_take_screenshot()
```

### When to Use Manual E2E

| Scenario | Action |
|:---|:---|
| **Exploratory Testing** | Navigate freely, verify as you go |
| **Flow Verification** | Follow checklist, screenshot each step |
| **Bug Reproduction** | Attempt to trigger bug, capture state |
| **Visual Regression** | Compare screenshots before/after change |

---

## MCP Best Practices (From Official Docs & Community)

### Safety & Permissions

Based on [freeCodeCamp MCP guide](https://www.freecodecamp.org/news/model-context-protocol-mcp/):

1. **Start Read-Only When Possible**: Begin with read-only operations to understand the codebase before making changes
2. **Review Changes Before Committing**: Always verify code changes match intent
3. **Limit Scope of Operations**: Use targeted queries rather than broad operations
4. **Audit Tool Usage**: Track which tools are being used for debugging

### Efficient Workflow Patterns

From community best practices:

1. **Single Source of Truth**: Use `dart analyze` as the authoritative source for type errors
2. **Iterative Development**: Make small changes, hot reload, verify, repeat
3. **Test-First Validation**: Run failing tests before implementing features
4. **Quality Gates**: Always run format, fix, analyze, and test before considering work complete

### Tool Selection Guidelines

| Task | Recommended Tool |
|------|-----------------|
| Check for errors | `mcp__dart-mcp-server__analyze_files` |
| Fix lint issues | `mcp__dart-mcp-server__dart_fix` |
| Format code | `mcp__dart-mcp-server__dart_format` |
| Run tests | `mcp__dart-mcp-server__run_tests` |
| Find packages | `mcp__dart-mcp-server__pub_dev_search` |
| Hot reload | `mcp__dart-mcp-server__hot_reload` |
| Widget debugging | `mcp__dart-mcp-server__get_widget_tree` |
| Device testing | `mcp__mobile-mcp__mobile_*` |

---

## State Management

### What Survives Hot Reload

| State | Survives `hot_reload`? | Requires `hot_restart`? |
|:---|:---:|:---:|
| Provider/Notifier state | ✅ Yes | No |
| Database connections | ✅ Yes | No |
| Controller instances | ✅ Yes | No |
| `const` values | ❌ No | Yes |
| `global` variables | ❌ No | Yes |
| `main()` initialization | ❌ No | Yes |
| New package dependencies | ❌ No | Yes |

---

## Feedback Loop Pattern

```
Action → Verify → Adjust → Repeat

Example:
1. mcp__dart-mcp-server__hot_reload()
2. mcp__dart-mcp-server__get_runtime_errors() → Found error
3. Fix code
4. mcp__dart-mcp-server__hot_reload()
5. mcp__dart-mcp-server__get_runtime_errors() → Clean
6. Proceed
```

---

## DO ✅

| Area | Practice |
|:---|:---|
| **Before Reload** | ALWAYS run `analyze_files` if syntax is uncertain |
| **After Reload** | ALWAYS check `get_runtime_errors` immediately |
| **Const Changes** | ALWAYS use `hot_restart`, not `hot_reload` |
| **Visual Verification** | ALWAYS take screenshot after UI changes |
| **Element Interaction** | ALWAYS use `list_elements_on_screen` before clicking |
| **Manual E2E** | ALWAYS verify after each navigation step |
| **State Managers** | TRUST providers/blocs to persist across `hot_reload` |
| **Database Connections** | EXPECT connections to survive `hot_reload` |
| **Positive Framing** | PROVIDE alternatives for every constraint |

---

## DON'T ❌

| Area | Anti-Pattern | Instead |
|:---|:---|:---|
| **Syntax Errors** | DON'T spam `hot_reload` on broken code | Run `analyze_files` first |
| **Silent Failures** | DON'T trust "it looks fine" | Check logs for silent errors |
| **Hardcoded Coords** | DON'T hardcode tap coordinates | Use `list_elements_on_screen` |
| **Skip Verification** | DON'T proceed without verifying | Always dual-verify (structural + visual) |
| **Assumption** | DON'T assume widget tree is current | Refresh with `hot_reload` if stale |
| **Schema Changes** | DON'T expect migrations to auto-apply | Reinstall app or run migration |
| **Negative-Only** | DON'T say "Don't do X" without alternative | Always provide positive path |

---

## Voice Strength

| Context | Voice | Example |
|:---|:---|:---|
| **Critical paths** | MUST, ALWAYS | "You MUST check runtime errors after reload" |
| **Best practices** | Prefer, Consider | "Prefer hot_reload for faster iteration" |
| **Suggestions** | May, Can | "You may take additional screenshots" |

---

## Tool Reference

| Category | Tool | When to Use |
|:---|:---|:---|
| **Session** | `mcp__dart-mcp-server__list_devices` | Start of session |
| | `mcp__dart-mcp-server__launch_app` | Start / after crash |
| | `mcp__dart-mcp-server__connect_dart_tooling_daemon` | After launch |
| | `mcp__dart-mcp-server__list_running_apps` | Reconnecting |
| | `mcp__dart-mcp-server__stop_app` | End session / cleanup |
| **Reload** | `mcp__dart-mcp-server__hot_reload` | Standard edits |
| | `mcp__dart-mcp-server__hot_restart` | Const/Global/Package |
| **Inspect** | `mcp__dart-mcp-server__get_runtime_errors` | After every reload |
| | `mcp__dart-mcp-server__get_widget_tree` | Structure check |
| | `mcp__dart-mcp-server__get_app_logs` | Deep debugging |
| | `mcp__dart-mcp-server__get_selected_widget` | Inspector mode |
| **Navigate** | `mcp__mobile-mcp__mobile_list_elements_on_screen` | Before any tap |
| | `mcp__mobile-mcp__mobile_click_on_screen_at_coordinates` | Tap element |
| | `mcp__mobile-mcp__mobile_swipe_on_screen` | Scroll/Navigate |
| | `mcp__mobile-mcp__mobile_type_keys` | Text input |
| | `mcp__mobile-mcp__mobile_take_screenshot` | Visual evidence |
| **Project** | `mcp__dart-mcp-server__pub_dev_search` | Package research |
| | `mcp__dart-mcp-server__pub` | Add/remove deps |
| | `mcp__dart-mcp-server__analyze_files` | Static analysis |
| | `mcp__dart-mcp-server__dart_fix` | Auto-fixes |
| | `mcp__dart-mcp-server__resolve_workspace_symbol` | Symbol lookup |

---

## Tool Decision Quick-Reference

### Decision Tree by Change Type

| What Changed? | Tools to Use |
|:---|:---|
| **UI Layout** | mcp__dart-mcp-server__hot_reload → get_widget_tree → take_screenshot |
| **Business Logic** | mcp__dart-mcp-server__hot_reload → run_tests |
| **State/Provider** | mcp__dart-mcp-server__hot_reload → verify with widget_tree |
| **Const Values** | mcp__dart-mcp-server__hot_restart → take_screenshot |
| **New Dependency** | pub add → hot_restart → run_tests |
| **Database Schema** | build_runner → hot_restart → verify |
| **API Integration** | hot_reload → get_runtime_errors → test |

### Quick Decision Flow

```
Is it UI?
├── Yes → hot_reload → screenshot
└── No
    ├── Is it const/global?
    │   ├── Yes → hot_restart → verify
    │   └── No
    │       ├── New package?
    │       │   ├── Yes → pub add → hot_restart → test
    │       │   └── No → hot_reload → test
    │       └── Need debug?
    │           ├── Runtime errors → get_runtime_errors
    │           └── Widget structure → get_widget_tree
```

### Error → Tool Mapping

| Error Symptom | First Tool | Then |
|:---|:---|:---|
| App crashes | get_runtime_errors | fix + hot_reload |
| UI wrong | take_screenshot | get_widget_tree |
| Tests fail | run_tests | analyze_files |
| No element found | list_elements_on_screen | retry tap |
| Widget missing | get_widget_tree | hot_reload |

---

## Troubleshooting

### Connection Lost

1. `mcp__dart-mcp-server__list_running_apps()` → Check if app alive
2. If alive: `mcp__dart-mcp-server__connect_dart_tooling_daemon(uri: "new-uri")`
3. If dead: `mcp__dart-mcp-server__launch_app(...)` → reconnect

### Hot Reload Fails

- **Syntax error**: `mcp__dart-mcp-server__analyze_files` → fix → retry
- **Incompatible change**: `mcp__dart-mcp-server__hot_restart`

### Empty Widget Tree

- App backgrounded? `mcp__dart-mcp-server__list_running_apps`
- Render blocked? `mcp__dart-mcp-server__get_runtime_errors`
- Force refresh: `mcp__dart-mcp-server__hot_reload` → `mcp__dart-mcp-server__get_widget_tree`

### Element Not Found

- Screen changed? `mcp__mobile-mcp__mobile_list_elements_on_screen` again
- Loading? Wait, then retry
- Wrong screen? Navigate first

### When Tests Fail

1. Run single failing test with verbose output
2. Check mock setup matches current API
3. Update mocks if API changed
4. Run `mcp__dart-mcp-server__dart_fix` for auto-fixes

---

## PharmaScan-Specific Patterns

### Riverpod + MCP Development

When developing Riverpod providers:

**DO**:
- Use `AsyncValue` for async state
- Follow the notifier pattern with `@riverpod`
- Use `ref.listen` for side effects
- Call `ref.mounted` before async operations after dispose

**Example**:
```dart
@riverpod
class ScannerNotifier extends _$ScannerNotifier {
  @override
  FutureOr<ScannerState> build() async {
    return const ScannerState.initial();
  }

  Future<void> scan(String code) async {
    if (!ref.mounted) return;
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      final result = await ref.read(catalogDaoProvider).getProductByCip(
        Cip13.validated(code),
      );
      return ScannerState.result(result);
    });
  }
}
```

**MCP Verification**:
```bash
mcp__dart-mcp-server__analyze_files(roots: [{root: "/Users/felix/Documents/Flutter/pharma_scan", paths: ["lib/core/providers/", "lib/features/"]}])
mcp__dart-mcp-server__run_tests(roots: [{root: "/Users/felix/Documents/Flutter/pharma_scan"}])
```

### Drift Database Development

When editing database schema or DAOs:

**DO**:
- Use extension types for semantic IDs (`Cip13`, `CisCode`, `GroupId`)
- Define tables in `.drift` files
- Use `TableManager` API for CRUD
- Attach reference DB via `ATTACH DATABASE`

**Example**:
```dart
await database.managers.productScanCache
    .filter((f) => f.cipCode.equals(cipString))
    .getSingleOrNull();

final cip = Cip13.validated('3400930011177');
```

**MCP Verification**:
```bash
dart run build_runner build --delete-conflicting-outputs
mcp__dart-mcp-server__run_tests(roots: [{root: "/Users/felix/Documents/Flutter/pharma_scan"}])
```

### UI Development with Shadcn

When building UI components:

**DO**:
- Use `context.shadColors.*` instead of hardcoded colors
- Use `context.typo.*` for typography
- Use semantic naming (surfacePositive, textWarning)
- Follow composition over inheritance

**Example**:
```dart
ShadCard(
  title: Text('Title', style: context.typo.h4),
  child: Text('Content', style: context.typo.medium),
)
```

---

## Flutter/Dart Best Practices

| Practice | Description |
|----------|-------------|
| Null safety | All types non-nullable by default |
| Const constructors | Use `const` where possible |
| Exhaustive switch | Handle all cases |
| AsyncValue pattern | Use for async state |
| Extension types | Prevent type mixing |
| Const widgets | Immutable UI components |
| Key usage | Meaningful keys for lists |
| dispose() cleanup | Close streams, controllers |

---

## Session Checklists

### Session Start

```
[ ] List available devices
[ ] Launch app on target device
[ ] Connect to Dart Tooling Daemon
[ ] Get PID for hot reload/restart
```

### Session End

```
[ ] Run quality gate (analyze + tests)
[ ] Fix any issues found
[ ] Stop running app
```

---

## Integration with Project Rules

This skill works with existing project rules:

- **Architecture Rules** (`architecture.md`): Layer isolation, Riverpod patterns
- **Database Rules** (`database.md`): Drift patterns, dual DB architecture
- **UI Rules** (`flutter-ui.md`): Shadcn components, semantic colors
- **API Design** (`api-design.md`): Documentation, naming conventions
- **Quality Rules** (`quality.md`): Test patterns, coverage requirements

---

## Sources

- [Flutter AI & MCP Server Documentation](https://docs.flutter.dev/ai/mcp-server)
- [freeCodeCamp: Model Context Protocol Guide](https://www.freecodecamp.org/news/model-context-protocol-mcp/)
- [Very Good Ventures: 7 MCP Servers for Flutter](https://verygood.ventures/blog/7-mcp-servers-for-flutter-and-dart)
