# Agentic Standards & Documentation Architecture

**Version:** 2025.1

**Scope:** Meta-rules for AI Agents (Cursor, Windsurf, etc.)

## 1. The Prime Directive: Minimalism

- **Zero Noise:** Do not include "introductory fluff" or "conversational filler" in rules.
- **Direct Access:** You already know standard Flutter/Riverpod patterns. Do not re-explain them. Only document **deviations** or **project-specific** choices.
- **Context Hygiene:** Never cross-reference rule files by name (e.g., "See `ui-policy.mdc`"). If a rule relies on another, it implies a failure of modularity.

## 2. Documentation Layering

This project uses a strict 3-layer architecture for context. You must respect these boundaries:

### Layer A: The Persona (`AGENTS.md`)

- **Role:** Your "System Prompt". Defines **WHO** you are and **HOW** you think.
- **Content:** Workflow loops, error handling philosophy, and definition of done.
- **Constraint:** Must be radically self-sufficient. It never references specific `.mdc` files. It assumes the environment (Cursor) automatically provides the necessary technical rules via `globs`.

### Layer B: The Technical Guardrails (`.cursor/rules/*.mdc`)

- **Role:** The "Linter". Defines **HARD CONSTRAINTS** for the stack.
- **Content:** "Use `ShadButton`, not `ElevatedButton`". "Use `AsyncValue.guard`".
- **Constraint:** Generalist. These rules could apply to *any* PharmaScan-like app. They must not contain specific business logic.
- **Automation:** These are auto-loaded by the IDE based on file modification (`globs`). Do not manually request them.

### Layer C: The Domain Brain (`docs/*.md`)

- **Role:** The "Knowledge Base". Defines **WHAT** we are building.
- **Content:** BDPM parsing logic, French pharmaceutical laws, grouping algorithms.
- **Constraint:** Project-specific. This is the only place for "Business Logic".

## 3. Interaction Protocol

- **Implicit Context:** Assume strictly typed context is available.
- **No Meta-Commentary:** Do not output "According to rule `flutter-data.mdc`...". Just write the code that complies with it.
- **Correction Loop:** If you encounter a conflict between layers, prioritize:
    1. `docs/` (Domain Truth)
    2. `.cursor/rules/` (Technical Constraints)
    3. `AGENTS.md` (Behavioral Patterns)
