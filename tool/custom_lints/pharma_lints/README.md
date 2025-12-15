# PharmaScan Custom Lints

This package contains the custom linting rules for the PharmaScan codebase. It leverages `custom_lint` to strictly enforce architectural boundaries, design system usage, and data patterns.

## 🛡️ Active Rules

### 1. `enforce_architecture_layering`
**Category**: Architecture  
**Goal**: Enforce strict module boundaries to prevent "Spaghetti Code" and help AI agents reason locally.

- **Rule**: `Core` cannot import `Features`.
- **Rule**: `Feature A` cannot import `Feature B` (unless explicitly exempted).
- **Exceptions**: `AppRouter`, `ScaffoldShell`, and DI containers are allowed to see everything.

**❌ Bad:**
```dart
// In lib/features/scanner/
import 'package:pharma_scan/features/home/home_provider.dart'; // Violation
```

**✅ Good:**
```dart
// In lib/features/scanner/
import 'package:pharma_scan/core/utils/date_utils.dart'; // OK
```

### 2. `avoid_direct_colors`
**Category**: Design System  
**Goal**: Ensure the app looks premium and consistent by preventing raw hex/material colors.

- **Rule**: Ban `Color(0xFF...)` and `Colors.red` etc.
- **Fix**: Provides a Quick Fix to add `// ignore: avoid_direct_colors` (pragmatic) or you should manually use `context.shadColors`.

**❌ Bad:**
```dart
Container(color: Colors.red) // Violation
```

**✅ Good:**
```dart
Container(color: context.shadColors.destructive) // OK
```

### 3. `enforce_dto_conversion`
**Category**: Data Integrity  
**Goal**: Standardize how data leaves the "Model" layer.

- **Rule**: Any class ending in `Model` must implement `toEntity()`.

---

## 🏗️ Developer Guide: Creating Rules (2025 Best Practices)

We follow modern 2025 standards for high-performance and "Agent-Friendly" linting.

### 1. Performance First ("The Fast Linter")
The analyzer is busy. Your rule must be optimized.
*   **Target Specific Nodes**: Never use `visitNode()`. Override specific visitors like `visitInstanceCreationExpression`.
*   **Syntax First, Semantics Later**: Type resolution (checking `staticType`) is expensive. Check the string name first.
    ```dart
    // ❌ Slow: Checks type metadata immediately
    if (node.staticType?.isDartUIColors ?? false) ...
    
    // ✅ Fast: Checks string token, only resolves type if name matches
    if (node.constructorName.name.name == 'Color') { ... }
    ```
*   **Shared Context**: Use `CustomLintContext` to share expensive computations if needed.

### 2. Designing for AI Agents
Linting is the **Language of Constraints** for AI.
*   **Grep-ability**: Enforce patterns that can be searched by text (e.g., specific naming conventions).
*   **Locality**: An agent reading `feature_a.dart` should not need to read `feature_b.dart` to understand it. `enforce_architecture_layering` makes this possible by banning invisible dependencies.
*   **Determinism**: If there are two ways to do something, ban one. Agents work best with "One Way".

### 3. Adding a New Rule
1.  Create a file in `lib/src/rules/<category>/`.
2.  Extend `DartLintRule`.
3.  Implement `run()` using `LintUtils` for fast checks.
4.  **Crucial**: Implement `getFixes()` where possible. An AI Agent can apply a Fix; it cannot easily read a massive error log.
5.  Export it in `lib/pharma_lints.dart`.
6.  Add a test case in `test/src/lint_validation.dart`.

### 4. Running Verification
```bash
# In this directory
dart test

# In the main project
dart run custom_lint
```
