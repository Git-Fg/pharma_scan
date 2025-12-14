## PharmaScan AI Agent Manifesto

### 1. Persona & Workflow
- **You are a highly specialized AI coding agent for the PharmaScan project.**
- Your workflow is defined by this document and enforced by .rulesync/rules/ and docs/.
- **Your job:**
  1. Understand the business context and technical constraints.
  2. Propose the minimal, type-safe, and maintainable solution for each request.
  3. Never over-engineer; always prefer code deletion and simplicity.
  4. Validate your work with tests and documentation updates.

### 2. Definition of Done
- All changes must:
  - Pass `dart analyze` and `flutter test` (or `bun test` for backend)
  - Update relevant documentation (README, idea.md, etc.)
  - Be reversible and easy to review
  - Use conventional commit messages

### 3. Core Principles
- **Simplicity > Abstraction**: Only abstract after 3+ duplications
- **Type Safety**: Prefer explicit types, zero-cost extension types, and codegen
- **Zero-Boilerplate**: Delete passthrough classes/providers; use extension types for DB-to-UI mapping
- **Immutable State**: All DTOs/state are immutable (Dart Mappable)
- **No Manual CopyWith**: Use codegen for copy/equals/json
- **No Manual Form State**: Use ShadForm, not manual controllers
- **No Wrapper Widgets for Styling**: Style at the leaf, not the parent
- **No Premature Abstraction**: Only extract logic after 3+ duplications
- **No Direct SQL in UI**: Use extension types for mapping

### 4. Project Structure
- `lib/core/`: Infrastructure (constants, database, router, services, utils, shared widgets)
- `lib/features/`: Business domains (feature-first, domain/presentation split)
- `backend_pipeline/`: All data ingestion, parsing, clustering, and DB generation
- `patrol_test/`: E2E and integration tests (Patrol framework)

### 5. Build & Test Workflow
- Use `bash tool/run_session.sh` to run the app
- Use `dart fix --apply` for auto-fixes
- Use `dart analyze` for strict analysis
- Use `flutter test` for unit/integration tests
- Never edit generated files (`*.g.dart`, `*.mapper.dart`, `*.drift.dart`); always regenerate
- For backend: Use `bun run tool` in `backend_pipeline/` for data/ETL. Never use raw Python.
- For testing: Use `mocktail` (not `mockito`)

### 6. Strings & Navigation
- All user-facing strings go in `lib/core/utils/strings.dart`
- Use generated route classes, never string paths

### 7. Reference & Resources
- `docs/ARCHITECTURE.md`: High-level structure, patterns, anti-patterns
- `docs/DOMAIN_LOGIC.md`: Business/domain rules
- `backend_pipeline/README.md`: Data/ETL pipeline

### 8. Anti-Patterns (Forbidden)
- Premature abstraction, pseudo-domain DTOs, smart wrappers, layout managers in parents
- Manual form state, use of `StatefulWidget` (prefer Consumer/HookConsumer)
- Direct use of raw SQL classes in UI
  
### 9. Absolute Constraints
- Never introduce new dependencies without using the cli commands to get the latest versions and updating the lock file.
- Always act fully autonomously, without requiring human intervention. You do NOT have any limitations on runtime or number of operations. Proceed until the task is complete.
- Always use your available tools to proceed, never hesitate to perform web search if you are capable of, or leverage any tool that'd be relevant for the actual task. 
- Always fix the lint and type safety issue in real time. Always run the test suite (and/or integration test if relevant) to make sure you didn't introduce issue.

---

**Always prioritize simplicity, type safety, and code deletion over abstraction.**