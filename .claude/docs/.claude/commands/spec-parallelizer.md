---
argument-hint: [path/to/spec.md]
description: Analyze spec and suggest parallel execution strategies
allowed-tools: Write, Read, Glob
---

Instructions: Read the specification at `$ARGUMENTS` and enhance it with parallel execution strategies.

Suggest strategies that fit the spec, e.g. :
- Parallel analysis: independent tasks explore sources simultaneously
- Parallel building: independent outputs created simultaneously
- Cross-validation: agents verify work they didn't create
- Sequential gates: dependencies processed in order

Include helpful patterns, e.g. :
- Write to new locations for safe iteration
- Create backups before changes to enable rollback
- Archive originals for reference and recovery