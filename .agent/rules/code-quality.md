# Code Quality

## General Principles
* **Code structure:** Adhere to maintainable code structure and separation of concerns (e.g., UI logic separate from business logic).
* **Naming conventions:** Avoid abbreviations and use meaningful, consistent, descriptive names for variables, functions, and classes.
* **Conciseness:** Write code that is as short as it can be while remaining clear.
* **Simplicity:** Write straightforward code. Code that is clever or obscure is difficult to maintain.
* **Error Handling:** Anticipate and handle potential errors. Don't let your code fail silently.
* **Styling:**
    * Line length: Lines should be 80 characters or fewer.
    * Use `PascalCase` for classes, `camelCase` for members/variables/functions/enums, and `snake_case` for files.
* **Functions:**
    * Functions short and with a single purpose (strive for less than 20 lines).
* **Testing:** Write code with testing in mind. Use the `file`, `process`, and `platform` packages, if appropriate, so you can inject in-memory and fake versions of the objects.
* **Logging:** Use the `logging` package instead of `print`.

## Lint Rules

Include the package in the `analysis_options.yaml` file. Use the following analysis_options.yaml file as a starting point:

```yaml
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    # Add additional lint rules here:
    # avoid_print: false
    # prefer_single_quotes: true
```

## Logging

* **Structured Logging:** Use the `log` function from `dart:developer` for structured logging that integrates with Dart DevTools.

```dart
import 'dart:developer' as developer;

// For simple messages
developer.log('User logged in successfully.');

// For structured error logging
try {
  // ... code that might fail
} catch (e, s) {
  developer.log(
    'Failed to fetch data',
    name: 'myapp.network',
    level: 1000, // SEVERE
    error: e,
    stackTrace: s,
  );
}
```

## Testing

* **Running Tests:** To run tests, use the `run_tests` tool if it is available, otherwise use `flutter test`.
* **Unit Tests:** Use `package:test` for unit tests.
* **Widget Tests:** Use `package:flutter_test` for widget tests.
* **Integration Tests:** Use `package:integration_test` for integration tests.
* **Assertions:** Prefer using `package:checks` for more expressive and readable assertions over the default `matchers`.

### Testing Best practices
* **Convention:** Follow the Arrange-Act-Assert (or Given-When-Then) pattern.
* **Unit Tests:** Write unit tests for domain logic, data layer, and state management.
* **Widget Tests:** Write widget tests for UI components.
* **Integration Tests:** For broader application validation, use integration tests to verify end-to-end user flows.
* **integration_test package:** Use the `integration_test` package from the Flutter SDK for integration tests. Add it as a `dev_dependency` in `pubspec.yaml` by specifying `sdk: flutter`.
* **Mocks:** Prefer fakes or stubs over mocks. If mocks are absolutely necessary, use `mockito` or `mocktail` to create mocks for dependencies. While code generation is common for state management (e.g., with `freezed`), try to avoid it for mocks.
* **Coverage:** Aim for high test coverage.