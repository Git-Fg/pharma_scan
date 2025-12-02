# Maintenance Documentation

**Version:** 1.0.0  
**Status:** Operator Manual  
**Context:** This document contains daily operations, testing, and release procedures.

For technical architecture, see `docs/ARCHITECTURE.md`. For domain-specific logic, see `docs/DOMAIN_LOGIC.md`.

---

## Setup & Run

### Prerequisites

- **Flutter SDK:** Latest stable version (check `pubspec.yaml` for minimum version)
- **Dart SDK:** Bundled with Flutter
- **Python:** For analysis tools (optional, uses `uv` for execution)
- **Build Tools:** `build_runner` for code generation

### Initial Setup

```bash
# Clone the repository
git clone <repository-url>
cd <project-directory>

# Install dependencies
flutter pub get

# Generate code (Riverpod, AutoRoute, Dart Mappable, Drift)
dart run build_runner build --delete-conflicting-outputs

# Run the app
bash tool/run_session.sh
```

### Running the Application

**CRITICAL:** `bash tool/run_session.sh` and `bash tool/run_session.sh stop` are the **ONLY** permitted ways to run the Flutter app for testing.

```bash
# Start the app
bash tool/run_session.sh

# Stop the app
bash tool/run_session.sh stop
```

**Note:** The `run_session.sh` script handles:

- Hot reload configuration
- Device selection
- Log management
- Process cleanup

---

## The Quality Gate

You are responsible for build health. Run this sequence **before committing** (stop immediately if any step fails):

```bash
# 1. Generate code
dart run build_runner build --delete-conflicting-outputs

# 2. Auto-fix linting issues (repeat up to 3 times)
dart fix --apply
dart fix --apply  # Some fixes expose new opportunities
dart fix --apply  # Third pass for completeness

# 3. Analyze code (strict mode)
dart analyze --fatal-infos --fatal-warnings

# 4. Run tests
flutter test
```

### Quality Gate Details

**Code Generation:**

- Generates Riverpod providers (`*.g.dart`)
- Generates AutoRoute routes (`*.gr.dart`)
- Generates Dart Mappable mappers (`*.mapper.dart`)
- Generates Drift database code (`*.drift.dart`)

**Auto-Fix Discipline:**

- `very_good_analysis` is significantly stricter than default
- Run `dart fix --apply` **aggressively** (up to 3 times)
- Some fixes expose new opportunities for other fixes
- Manual suppression comments are forbidden (unless false positive)

**Analysis:**

- `--fatal-infos` treats info-level issues as errors
- `--fatal-warnings` treats warnings as errors
- Generated files are excluded via `analysis_options.yaml`

**Testing:**

- Unit tests for logic in `lib/core/`
- Widget tests for UI components
- Integration tests for complete flows

**Reference:** `.cursor/rules/flutter-qa.mdc`

---

## Testing

### Running Tests

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/core/logic/sanitizer_test.dart

# Run integration tests (requires emulator/device)
flutter test integration_test/pharmacist_flow_test.dart
```

### Test Structure

- **Unit Tests:** `test/core/` - Business logic, parsers, utilities
- **Widget Tests:** `test/features/` - UI components with mocked providers
- **Integration Tests:** `integration_test/` - Complete user flows

### Test Patterns

**Robot Pattern (Optional/Recommended):**

- Use for complex, multi-step flows reused across tests
- Store in `test/robots/`
- Direct finders are fine for simple tests

**AsyncValue Coverage:**

- MUST test Loading, Data, and Error states
- Use Riverpod overrides in `ProviderScope`

**String Literals Ban:**

- NEVER use hardcoded strings in tests
- Use `Strings.dart` constants
- Create helper methods for dynamic text (e.g., `Strings.itemCount(3)`)

**Reference:** `.cursor/rules/flutter-qa.mdc`

---

## Database Operations

### Modifying the Drift Schema

1. **Edit Schema Files:**
   - Tables: `lib/core/database/tables.drift`
   - Views: `lib/core/database/views.drift`
   - Queries: `lib/core/database/queries.drift`

2. **Generate Code:**

   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

3. **Migration (Production):**
   - Drift generates migration code automatically
   - Review migration files in `lib/core/database/migrations/`
   - Test migrations on development database

4. **Development (Dev Mode):**
   - In dev mode, uninstall the app to clean up the database
   - Use mobile-mcp tools to uninstall: `mcp_mobile_uninstall_app`

**Note:** The app is still in development. Never include migration logic or complex migration strategies in dev mode. Simply uninstall and reinstall to reset the database.

### FTS5 Search Index

**Populating the Index:**

- The search index is populated via `DatabaseDao.populateFts5Index()`
- This method calls SQL helpers defined in `queries.drift`
- Index uses trigram tokenizer for fuzzy matching

**Verification:**

- Before updating `sqlite3_flutter_libs`, verify FTS5 trigram tokenizer support
- Without trigram support, search queries will fail at runtime

**Reference:** `.cursor/rules/flutter-data.mdc` (FTS5 section)

### Database Analysis

**Python Scripts:**

- Use `uv run tool/analyze_data.py` for data analysis
- Create temporary scripts in `tool/` for hypothesis testing
- Faster to write Python than debug Dart parsing logic

**Reference:** `AGENTS.md` (Analysis Tools section)

---

## Golden Tests

### Generating Golden Files

**For Data Parsing:**

- Use your test data generator script (e.g., `uv run tool/parser_lab.py`)
- Generate JSON golden files for complex parsing logic
- Store in `tool/data/` (ignored by Git)

**For UI:**

- Use Flutter's golden test framework
- Store snapshots in `test/snapshots/`

### Updating Golden Tests

**Rule:** Any modification to parsing grammar (Python or Dart) must be accompanied by:

1. Regeneration of JSON golden files via your parser script
2. Passing the corresponding Dart golden tests

**Workflow:**

```bash
# 1. Regenerate golden files
uv run tool/your_parser.py

# 2. Run golden tests
flutter test test/core/parsing/golden_test.dart

# 3. Update snapshots if needed
flutter test --update-goldens
```

**Reference:** `.cursor/rules/flutter-qa.mdc` (Golden Tests section)

---

## Release Process

### Building Android APK

```bash
# Build debug APK
flutter build apk --debug

# Build release APK
flutter build apk --release

# Build App Bundle (for Play Store)
flutter build appbundle --release
```

### Building iOS (if applicable)

```bash
# Build iOS app
flutter build ios --release
```

### Versioning Strategy

- **Version Format:** `major.minor.patch` (e.g., `1.2.3`)
- **Update in:** `pubspec.yaml` and platform-specific files
- **Changelog:** Document breaking changes and new features

### Pre-Release Checklist

- [ ] Run quality gate (build, fix, analyze, test)
- [ ] Update version numbers
- [ ] Update changelog
- [ ] Test on physical devices (Android/iOS)
- [ ] Verify database migrations (if applicable)
- [ ] Check for hardcoded strings (move to `Strings.dart`)
- [ ] Verify no prohibited widgets (`Scaffold` in sub-views)

---

## Troubleshooting

### Build Issues

**Code Generation Fails:**

```bash
# Clean and regenerate
flutter clean
dart run build_runner clean
dart run build_runner build --delete-conflicting-outputs
```

**Analysis Errors:**

```bash
# Auto-fix issues
dart fix --apply  # Repeat up to 3 times

# Check analysis options
cat analysis_options.yaml
```

### Database Issues

**Search Not Working:**

- Verify `sqlite3_flutter_libs` supports FTS5 trigram tokenizer
- Check that `populateFts5Index()` was called
- Verify `normalize_text` SQL function is registered

**Migration Issues:**

- In dev mode, uninstall app to reset database
- Review migration files in `lib/core/database/migrations/`
- Test migrations on development database first

### Test Failures

**Widget Tests:**

- Ensure `ShadApp.custom` is used in test helpers
- Mock providers correctly in `ProviderScope`
- Test all `AsyncValue` states

**Integration Tests:**

- Ensure emulator/device is available
- Check that test data is properly set up
- Verify Robot classes are used for complex flows

---

## Additional Resources

- **Architecture:** `docs/ARCHITECTURE.md` - Technical architecture
- **Domain Logic:** `docs/DOMAIN_LOGIC.md` - Business logic and domain knowledge
- **Agent Manifesto:** `AGENTS.md` - Complete agent persona and workflow
- **Rule Files:** `.cursor/rules/*.mdc` - Detailed technical standards
