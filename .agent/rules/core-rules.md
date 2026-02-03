# Core Rules for Flutter & PharmaScan

You are an expert in Flutter and Dart development. Your goal is to build beautiful, performant, and maintainable applications following modern best practices.

---

## PharmaScan Domain Philosophy

**CRITICAL**: Before working on explorer, scanner, or backend pipeline, read the core philosophy documentation:

- [`docs/DOMAIN_MODEL.md`](../../docs/DOMAIN_MODEL.md) - Data model, CIP/CIS hierarchy, form prioritization
- [`docs/EXPLORER_CORE_GOAL.md`](../../docs/EXPLORER_CORE_GOAL.md) - CIP naming goal, rangement philosophy
- [`docs/REGEX_BRITTLENESS.md`](../../docs/REGEX_BRITTLENESS.md) - Why regex is brittle, composition-based solution

### The Core Goal

**For each CIP in the system, we need:**

1. **Clean Brand Name** - For alphabetical sorting ("rangement") and scanner display
2. **Clean Generic Name** - For therapeutic equivalence display and cluster grouping

### Pharmacy Drawers Focus

The system prioritizes **pharmacy drawer forms** (tiroirs) over rare/hospital forms:

**Primary Focus (Must Work)**:
- Oral solids: comprimé, gélule, lyophilisat
- Oral liquids: sirop, suspension, solution buvable
- Ophthalmic: collyre, pommade oculaire
- ORL: spray nasal, gouttes auriculaires
- Gynécologique: ovule, crème vaginale
- Dermatologique: crème, pommade, gel
- Inhalation: inhalateur, spray

**Secondary Focus (Nice-to-have)**:
- Pastilles, suppositoires

**Lower Priority (Acceptable to Fail)**:
- Injectables, perfusions, hospital-only forms

### Rangement Philosophy

- Clusters sort by **princeps brand name** (not generic name)
- "Amoxicilline (Réf: Clamoxyl)" appears under **C**, not **A**
- Generics should sort under their princeps brand, not by their own name

### Regex Brittleness

**Current Issue**: Pipeline uses regex for salt stripping, LCS naming, and pharmacological masking. This is brittle and lacks semantic understanding.

**Solution**: Use composition-based lookup from BDPM data (`CIS_COMPO_bdpm.txt`) instead of regex pattern matching.

**Priority**: Fix regex issues for common drawer forms (gélule, comprimé, sirop, collyre, crème) first. These represent 80%+ of daily scans.

---

## Flutter Development Guidelines

### Interaction Guidelines
* **User Persona:** Assume the user is familiar with programming concepts but may be new to Dart.
* **Explanations:** When generating code, provide explanations for Dart-specific features like null safety, futures, and streams.
* **Clarification:** If a request is ambiguous, ask for clarification on the intended functionality and the target platform.
* **Dependencies:** When suggesting new dependencies from `pub.dev`, explain their benefits.
* **Formatting:** Use `dart format` to ensure consistent code formatting.
* **Fixes:** Use `dart fix --apply` to automatically fix common errors.
* **Linting:** Use `dart analyze` to catch common issues.

### Project Structure
* **Standard Structure**: Flutter project structure with `lib/main.dart` as entry point
* **Layer Organization**:
  * `lib/core/` - Shared infra (cannot import features)
  * `lib/features/` - Business domains (scanner, explorer, restock, home, settings)
  * `lib/app/` - Entry, router, theme
* **Rule**: `core` cannot import `features`
* **Rule**: `features` cannot import other `features`

### Flutter Style Guide
* **SOLID Principles**: Apply throughout the codebase
* **Composition over Inheritance**: Favor composition for complex widgets and logic
* **Immutability**: Prefer immutable data structures. Widgets should be immutable
* **State Management**: Separate ephemeral state and app state using Riverpod
* **Widgets are for UI**: Compose complex UIs from smaller, reusable widgets
* **Navigation**: Use `auto_route` for type-safe routing

### Code Standards
* Null safety required, avoid `!` unless guaranteed non-null
* Exhaustive switch statements
* Const constructors everywhere
* 80 char line limit, 20 line function target
* Use `developer.log()` not `print()`
* Type-safe identifiers: Use extension types (`Cip13`, `CisCode`) over raw primitives

### Testing
* Unit tests for business logic
* Widget tests for UI components
* Integration tests for critical user flows
* Use `flutter test` to run tests
* Aim for high test coverage on core domain logic
