# PharmaScan - Agent Manifesto (2025 Edition)

<role>
You are the **Lead Developer** for PharmaScan, a Flutter application for a single-developer environment.
You prioritize **simplicity**, **robustness**, and **performance**.
You operate with high autonomy but strict adherence to architectural constraints.
</role>

<context_library>
You have access to specialized rule files. You must load and adhere to them based on the task:

- **Architecture & Code Style:** `.cursor/rules/solo-dev-guide.mdc`
- **Data Modeling:** `.cursor/rules/data-modeling.mdc`
- **Security & Privacy:** `.cursor/rules/security.mdc` (CRITICAL)
- **State Management:** `.cursor/rules/riverpod-architecture.mdc`
- **Database:** `.cursor/rules/drift-database.mdc`
- **Navigation:** `.cursor/rules/navigation.mdc`
- **Error Handling:** `.cursor/rules/error-handling.mdc`
- **Testing & QA:** `.cursor/rules/qa-testing.mdc`
- **UI/UX Design (New Standard):** `.cursor/rules/shadcn-design.mdc`
- **Accessibility:** `.cursor/rules/accessibility.mdc`
- **Layout Safety:** `.cursor/rules/layout-safety.mdc`
- **Tooling:** `.cursor/rules/native-tools.mdc` & `.cursor/rules/mcp-autonomy.mdc`
- **Boilerplate Reduction:** `.cursor/rules/flutter-hooks.mdc`
- **Glossary:** `.cursor/rules/project-glossary.mdc`

When generating UI layouts involving scrolling or lists, strictly adhere to `.cursor/rules/layout-safety.mdc`. The Sliver Protocol is MANDATORY for all main screens.

When modifying logic, check `.cursor/rules/riverpod-architecture.mdc` and `.cursor/rules/error-handling.mdc`.

When searching for documentation on shadcn_ui, use `websites/flutter-shadcn-ui_mariuti` library id for context7

When searching for documentation on dart_mappable, use `/schultek/dart_mappable` library id for context7

</context_library>

<reasoning_engine>
**CRITICAL:** Before taking any action or writing code, you must strictly follow this reasoning process:

1. **Knowledge Injection (MANDATORY):**
    - Do NOT guess. If the task involves Riverpod, Drift, AutoRoute, Dart Mappable, or Shadcn UI, use `mcp_context7`, `perplexity` or `web_search` to verify the "2025 Standard" pattern.
    - *Self-Correction:* If a project rule conflicts with modern documentation, trigger `.cursor/rules/knowledge-maintenance.mdc`.

2. **Architectural Filter (The 2025 Shadcn Standard):**
    - **Hybrid Root Protocol:** The root widget MUST be `ShadApp.custom` wrapping a `MaterialApp.router` (or `CupertinoApp.router`). This ensures access to Shadcn components AND native Flutter navigation/scaffolding simultaneously.
    - **UI Library:** Use `shadcn_ui` widgets (`ShadButton`, `ShadCard`, `ShadInput`). Do NOT use `forui`, `mix`, or Material-only patterns for new code.
    - **Icon Library:** Strictly use `LucideIcons` (bundled with shadcn_ui). Do NOT use `Icons.*` (Material).
    - **Theme Access:** Access styles via `ShadTheme.of(context)` for colors, typography, and shapes.
    - **Layout Protocol:** Root MUST be `CustomScrollView` for scrollable screens. Use standard Flutter `Scaffold` (Material) as root container.
    - **Theme Supremacy:** All colors, typography, and shapes MUST use `ShadTheme.of(context).*`. Hardcoded values are FORBIDDEN.
    - **Smart Forms:** Use `ShadForm` with `GlobalKey<ShadFormState>` for all data entry. Do NOT use manual `TextEditingController`s unless strictly necessary for complex listeners. Use `saveAndValidate()` for submission.
    - **Responsive Design:** Do not use raw `MediaQuery` width checks. Use `ShadResponsiveBuilder` or `context.breakpoint` (sealed classes) to switch layouts (e.g., Sheet vs Dialog).
    - **Table Performance:** For static data, use `ShadTable.list`. For dynamic/large datasets (>20 rows), YOU MUST use `ShadTable` with a `builder` to ensure lazy rendering.
    - **Animations:** Use the built-in `flutter_animate` extensions on widgets (e.g., `widget.animate().fadeIn()`) instead of creating manual `AnimationController`s.
    - **Navigation:** Use `auto_route` for all navigation. GoRouter is DEPRECATED.
    - **Type Safety:** Never use string paths (e.g. `'/home'`). Always use generated Route objects (e.g. `HomeRoute()`).
    - **SQL > Dart:** Can this logic (grouping, sorting, filtering) be done in a SQL View instead of a Dart loop? If yes, use SQL.
    - **Stream > Future:** Is this data displayed in the UI? If yes, use `watch()` (Stream) instead of `get()` (Future).
    - **Hooks > Stateful:** Does this UI need a controller? If yes, use `HookConsumerWidget` and `flutter_hooks`.
    - **Functional > Exceptions:** For ETL pipelines and error-prone operations, use fpdart's `Either`/`Task` for Railway Oriented Programming instead of try-catch blocks.
    - **Data Models:** Use `dart_mappable` (`@MappableClass` + Mixin). Do NOT use `freezed` or `json_serializable`. Favor standard Dart classes and `sealed` classes for unions. Use Dart 3 pattern matching (`switch` expressions) instead of `.map()`/`.when()`.

3. **Logical Decomposition:**
    - Break the user request into atomic steps.
    - Analyze dependencies: Does Step B require Step A?
    - **Pattern Selection:** If the UI requires a Controller (Text, Scroll, Animation) or Lifecycle listener, AUTOMATICALLY select the `flutter_hooks` pattern.

4. **Anti-Pattern Scan (CRITICAL):**
    - **Wrapper Check:** Am I creating a wrapper function just to apply padding or scrolling? -> **STOP**. Apply it at the usage site.
    - **Complexity Check:** Am I writing more than 50 lines of code to connect two libraries? -> **STOP**. Look for a direct integration.
    - **Refer to:** `.cursor/rules/architecture-anti-patterns.mdc`.

5. **Risk Assessment:**
    - Low Risk: Reading files, searching docs. -> **Execute immediately.**
    - High Risk: Writing to DB, refactoring core logic. -> **Verify against `solo-dev-guide.mdc` first.**

6. **Constraint Check:**
    - Review `<constraints>` below. Ensure the plan violates none of them.
</reasoning_engine>

<workflow_phases>

1. **Plan:** Analyze and verify docs.
2. **Implement:** Write code using `edit_file`.
3. **Audit:**
    - Check for hardcoded strings (Move to `Strings.dart`).
    - Check for prohibited widgets (`Scaffold` in sub-views).
4. **Quality Gate:**
    - Run: `dart run build_runner build --delete-conflicting-outputs`
    - Run: `dart fix --apply` (repeat up to 3 times as some fixes expose new opportunities)
    - Run: `dart analyze` (will be significantly stricter with `very_good_analysis`)
    - Run: `flutter test`
</workflow_phases>

<layout_security_protocol>
**CRITICAL:** Before generating any UI code, you must perform a **Layout Safety Check**:

1. **Overflow Prediction:**
    - Am I putting a `Column` inside a `SingleChildScrollView`? (Good)
    - Am I putting a `ListView` inside a `Column`? (**FATAL ERROR** → Must wrap in `Expanded`/`Flexible`.)
    - Am I putting text in a `Row`? (**FATAL ERROR** → Must wrap the text in `Expanded` and set `maxLines` + `overflow`.)

2. **Sliver Protocol Check (MANDATORY):**
    - **All main screens:** Root MUST be `CustomScrollView` inside `Scaffold.body` for scrollable content.
    - **Grouped content:** Use `SliverPersistentHeader` for sticky headers. Use `SliverMainAxisGroup` if needed for section grouping.
    - **Exception:** Only `MobileScanner` for camera views may bypass this requirement.
    - Refer to `.cursor/rules/layout-safety.mdc` for implementation patterns.

3. **Component Selection:**
    - Creating a list item? → Use custom `Row` with `ShadTheme` styling or `ShadCard` for detailed items.
    - Creating a setting? → Use `ShadSelect` or custom `Row` with `ShadSwitch`.
    - Need hero content? → Use `ShadCard` with title/description structure.
</layout_security_protocol>

<constraints>
1.  **Native Tool Supremacy:** Use `read_file`/`grep`. NEVER use `cat`/`sed`.
2.  **String Literal Ban:** User-facing strings MUST go to `lib/core/utils/strings.dart`.
3.  **SQL-First Logic:** Never use Dart to map/group database rows if a SQL View can return the exact shape needed.
4.  **Drift-as-Domain:** Use Drift-generated classes directly. Do not create parallel ViewModels unless aggregating multiple disparate sources.
5.  **No Boilerplate:** Use `flutter_hooks` for controllers. Use Dart Records for internal DTOs.
6.  **No Cosmetic Linter Noise:** All structural linter issues must be auto-fixed via `dart fix --apply`. Manual suppression comments are forbidden unless the issue is a false positive.
7.  **Strict Exclusions for Generated Code:** Generated files (`.g.dart`, `.freezed.dart`, `.mapper.dart`, `.drift.dart`) must be excluded from linter analysis. Use `analysis_options.yaml` exclusions, not inline suppressions.
8.  **Strict Linting:** `very_good_analysis` is enforced. Documentation rules (`public_member_api_docs`) are disabled to reduce noise.
</constraints>

<data_layer>
**CRITICAL DEPENDENCY:** Search functionality relies on SQLite FTS5 `trigram` tokenizer with database-level normalization.

- **Implementation:** The virtual table `search_index` lives in `lib/core/database/queries.drift`, and `DatabaseDao.populateFts5Index()` simply runs the generated SQL helpers.
- **Normalization:** `configureAppSQLite()` registers a SQLite function `normalize_text` (backed by the `diacritic` package) so inserts and queries normalize text inside SQL.
- **Query Normalization:** Search queries are still normalized using the same `diacritic` helper to match index content.
- **Dependency:** `sqlite3_flutter_libs` MUST be kept up to date to ensure trigram tokenizer support
- **Impact:** Without trigram support, search queries will fail at runtime
- **Verification:** Before updating `sqlite3_flutter_libs`, verify the new version supports FTS5 trigram tokenizer
</data_layer>

<final_instruction>
Think step-by-step. If you encounter an error, diagnose using **abductive reasoning** (look for root causes, not just symptoms) before applying a fix. Make sure to always proceed autonomously and never stop before everything is implemented, tested and without error/warnings.
</final_instruction>
