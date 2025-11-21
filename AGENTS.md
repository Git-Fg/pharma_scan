# PharmaScan - Development Manifest

Your primary mission is to contribute to the development of the **PharmaScan** application. This document is the single source of truth for all development principles, quality standards, and project architecture.

**Core Philosophy:** Prioritize **simplicity**, **robustness**, and **performance**. The application must be instantly responsive. The code is the ultimate authority; your contributions must be clear, self-documenting, and rigorously tested.

---

## 1. Core Protocols & Workflow

### **Workflow A: Code Development (Features & Fixes)**

1. **Analyze & Plan:**
    * Review `AGENTS.md` and active `.cursor/rules` (Architecture, MCP, Native Tools).
    * Check for existing functionality to avoid duplication.
2. **Implement:**
    * Write clean, performant code.
    * **Update Tests Concurrently:** If business logic changes, update unit/integration tests immediately.
3. **String Audit (CRITICAL):**
    * Before finalizing, scan all changed files for hardcoded string literals inside `Text()` widgets or string parameters.
    * Extract ALL user-facing strings to `lib/core/utils/strings.dart` and use `Strings.*` constants.
    * **Rationale:** Ensures i18n readiness, consistency, and easier string management. See `.cursor/rules/flutter-standards.mdc` section 12.
4. **Generate Code:**
    * If `@freezed` or `@DriftDatabase` models change, run the generator via **Dart MCP** tools (or shell if unavailable): `dart run build_runner build --delete-conflicting-outputs`.
5. **Auto-Fix & Verify (Quality Gate):**
    * **Immediate Fixes:** Whenever `dart analyze` reports auto-fixable warnings or errors, run `dart fix --apply` before proceeding.
    * **Static Analysis:** `dart analyze --fatal-infos --fatal-warnings` must pass cleanly after auto-fixes.
    * **Test Execution:** Run `dart test` (plus targeted suites) to confirm regressions are absent.
    * **Integration Checks:** Run relevant integration tests (e.g., `data_pipeline_test.dart` for DB changes).

---

## 2. Tooling Governance (Strict)

### **2.1. Native Tool Supremacy**

You possesses powerful native capabilities for reading, writing, and searching files.

* **CONSTRAINT:** You **MUST** use your internal native tools (`read_file`, `edit_file`, `grep`, `ls`) for all file system operations.
* **PROHIBITED:** Never use shell commands (e.g., `cat`, `sed`, `awk`, `find`, `grep` in CLI) to mimic native behaviors. Refer to `.cursor/rules/native-tools.mdc`.

### **2.1.1. Logging Discipline**

* **FORBIDDEN:** Never run `flutter logs`; it blocks the terminal and disrupts automation.
* **REQUIRED:** Use in-app logs provided by talker to debug any issue

### **2.1.2. Flutter Run Execution**

* **MANDATORY:** Always start `flutter run` as a background command so the shell remains available for additional automation steps.
* **RATIONALE:** Background execution keeps pipelines non-blocking and lets you immediately run analysis, tests, or auxiliary scripts without opening new shells.

### **2.2. Autonomous MCP Usage**

You are equipped with specialized Model Context Protocol (MCP) tools.

* **CONSTRAINT:** You **MUST** proactively and autonomously use these tools when relevant without asking for permission.
* **Docs (Context7):** Always resolve libraries and fetch docs for Riverpod, Freezed, Drift, Shadcn.
* **Mobile Control:** Use Mobile MCP for UI validation on emulators.
* **Dart/Flutter:** Use Dart MCP for analysis, testing, and pub management.
Refer to `.cursor/rules/mcp-autonomy.mdc` for specific tool triggers.

---

## 3. Technical Best Practices (The Immutable Rules)

### 3.1. Code Quality

* **Comments:** Explain the "Why" (`// WHY: ...`), not the "What".
* **Zero Artifacts:** No `print()`, `debugPrint()`, or commented-out code.
* **Scoped Modification:** Touch only files related to the task. No unsolicited refactoring.
* **Network Downloads:** Always rely on the shared `FileDownloadService` (Dio + Talker) for HTTP transfers so logging, caching, and cancellation stay centralized.
* **UI Kit First:** Before introducing any styled widget, check `lib/core/widgets/ui_kit/` (notably the `Pharma*` helpers such as `PharmaBackHeader`, `PharmaBadges`, `SectionHeader`) and reuse them instead of recreating the same patterns.

### 3.2. Design System (Shadcn UI)

* **Library:** `websites/flutter-shadcn-ui_mariuti` (Context7 ID).
* **Rules:**
  * Use `ShadTheme.of(context)`.
  * **NO** hardcoded `Colors.xxx` or `TextStyle`.
  * **NO** `BoxDecoration`.
  * **Toasts:** Use `ShadSonner` (Stackable), never `ShadToaster`.
  * **Typography:** Use `theme.textTheme.h4`, `muted`, `p`. No `copyWith` overrides.
  * **Tables:** Use `ShadTable.list` for aligned data.
  * **Forms:** Use `ShadSelect` and `ShadRadioGroup` inside `ShadPopover`.

### 3.3. Architecture & Layout

* **Layering:** Strict separation between **UI** (Widgets) and **Services** (Business Logic).
* **Spacing:** Use the `gap` package for all linear spacing. Do NOT use `SizedBox` for margins between widgets.
* **Accessibility:** Bottom-anchored control panels MUST live in scrollable, SafeArea-aware containers (e.g., `AdaptiveBottomPanel`) so 200% text scaling or small screens never overflow.
* **State & Dependency Injection:**
  * Local UI state -> `StatefulWidget`.
  * Global/Shared state -> Riverpod (`@riverpod` generated Notifiers).
  * **Dependency Injection:** Services MUST be provided via Riverpod providers (`ref.watch`/`ref.read`). **GetIt**/`sl<T>()` and other service locators are forbidden.
  * **Settings Persistence:** `AppSettings` table in Drift is the single source of truth for configuration (theme, sync cadence, metadata). Do **not** use `shared_preferences`, Hive, or any client-side key-value stores for app state.

### 3.4. Data Model (Deterministic)

* **Parsing:** "Knowledge-Injected" strategy. Inject Official Form/Lab -> Subtract from Raw String -> Parse Remainder.
* **Source of Truth:** `medicament_summary` table (Pre-aggregated). All read paths must query this table.
* **Validation:** Use `data_validator.py` to audit BDPM data integrity.
* **Drift Best Practices:** See `.cursor/rules/architecture-data.mdc` for detailed Drift rules, including `.isIn()` usage with large sets (no manual chunking required since Drift 2.24.0+).

---

## 4. Development Toolkit

* **Code Gen:** `dart run build_runner build --delete-conflicting-outputs`
* **Auto-Fix:** Run `dart fix --apply` immediately when analyzer warnings/errors are fixable.
* **Quality Gate:** `dart run build_runner build --delete-conflicting-outputs && dart fix --apply && dart analyze --fatal-infos --fatal-warnings && dart test`
* **Data Refresh:** `uv run python data_validation/generate_smart_test_data.py`
* **BDPM Downloads:** TXT endpoints ignore `ETag`/`Last-Modified`; always re-download files instead of relying on HTTP cache metadata.

---

## 5. Documentation Maintenance Protocol

Whenever a new best practice, deprecation, or tooling upgrade is discovered:

1. **Locate Impacted Docs:** Identify every occurrence in `AGENTS.md`, `.cursor/rules/`, and project scripts that references outdated Flutter-only tooling (e.g., the previous build_runner invocation).
2. **Update Commands:** Replace obsolete tooling instructions with the current Dart equivalents (`dart run ...`, `dart analyze`, `dart test`, `dart fix --apply`) while keeping `flutter run` solely for launching the UI on devices.
3. **Enforce Auto-Fixes:** Explicitly document the requirement to run `dart fix --apply` whenever analyzer warnings/errors can be auto-corrected before re-running analysis/tests.
4. **Propagate Changes:** Re-run quality gates and update changelogs/readmes so the new rules remain the single source of truth.

## 6. Resource Context

Quick references for difficult layouts and common pitfalls:

* **Flutter Constraints Rule:** "Constraints go down. Sizes go up. Parent sets position."
* **Shadcn Layout:** Prefer flexible rows/columns inside Cards over fixed tables.
* **Navigation:** GoRouter StatefulShellRoute for persistent bottom tabs.

---

**Example of Context7 Libraries id:**

* Freezed: `rrousselgit/freezed`
* Riverpod: `websites/pub_dev-riverpod`
* ShadcnUI: `websites/flutter-shadcn-ui_mariuti`
* Drift: `websites/pub_dev_drift`
