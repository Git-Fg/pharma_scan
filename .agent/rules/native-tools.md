---
trigger: always_on
---

# Native Tool Preference Protocol

## Fundamental Guideline

Lean on the native tools for file reads, edits, and searches because they provide richer context and safer writes. Console commands remain available when they substantially speed up the task or when native tools lack parity.

Your knowledge may be outdated : never downgrade a dependancy or a version. When you add new library/modify a version, make sure to always use flutter pub cli command and never manually edit the pubspec.yaml 

**Auto-Fix Discipline:** If `dart analyze` or CI surfaces warnings/errors with available quick fixes, immediately run `dart fix --apply` before re-running analysis or tests.

Use judgment: default to native tooling, but leverage the console whenever it clearly improves speed or clarity without sacrificing reliability.