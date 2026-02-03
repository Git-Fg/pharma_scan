---
description: "Capture project discoveries (patterns, gotchas, decisions, context) to project rules (CLAUDE.md, CLAUDE.local.md, .claude/rules/) when users say 'remember this', 'that worked', or architectural decisions are made. Keywords: capture, archive, pattern, gotcha, context, decision, remember. Not for temporary notes, migration notes, or edit logs."
argument-hint: "[<target>]"
allowed-tools: Read, Edit, Write, Grep, AskUserQuestion
---

<mission_control>
<objective>Capture project discoveries to project rules as permanent project memory; refine and evolve existing rules when patterns emerge</objective>
<success_criteria>Insights archived with context, "why", "when"; rules evolved with preserved history; zero meta-notes or migration markers</success_criteria>
</mission_control>

# Project Discovery Archive

Build lasting project memory by capturing permanent insights, architectural decisions, working commands, patterns, and gotchas as they emerge during development.

## Context

<injected_content>
Current Rules: @CLAUDE.md
.claude/rules/principles.md
.claude/rules/architecture.md
.claude/rules/quality.md
</injected_content>

## Injection Phase

**FIRST**, review the injected context before performing any archival:

1. **Identify existing sections** - Architecture, patterns, gotchas, discoveries
2. **Identify rules** - Principles, architecture, quality that may need evolution
3. **Scan conversation** - Extract potential learnings from context
4. **Detect existing patterns** - Avoid redundancy with documented knowledge
5. **Align with conventions** - Ensure proposed content matches project style

## Detection Modes

### Implicit Mode (Default - No Arguments)

When invoked without explicit content, **infer from conversation**:

| Signal Type      | Detection Pattern                                  | Capture Target      |
| ---------------- | -------------------------------------------------- | ------------------- |
| Success marker   | `"that worked"`, `"finally"`, `"got it"`           | Command + context   |
| Explicit request | `"remember this"`, `"note this"`, `"archive this"` | Stated insight      |
| Decision made    | Planning outcome, architecture choice              | ADR                 |
| Gotcha found     | Issue description + solution                       | Gotcha record       |
| Pattern found    | Reusable approach identified                       | Pattern capture     |
| Context needed   | Important information to preserve                  | Context snippet     |
| Rule evolution   | Existing guidance updated                          | Rule refinement     |

**Inference Process:**

1. Scan last 20 messages for discovery indicators
2. Identify unique insights not already in CLAUDE.md
3. Extract commands/patterns/gotchas with success context
4. Detect architectural decisions from execution flow
5. Propose specific additions with diffs

### Explicit Mode (Argument Provided)

When `$ARGUMENTS` specifies target:
- **pattern**: Capture reusable pattern from conversation
- **gotcha**: Capture lesson learned or pitfall
- **decision**: Capture architectural decision as ADR
- **context**: Save context snippet for reference
- **all**: Run all capture types and aggregate

## Capture Templates

### Pattern Template

```markdown
## Pattern: [Name]

### When to Use
[Conditions that trigger this pattern]

### Why
[Benefits and rationale]

### How
[Implementation guidance]

### Example
```[language]
[Code example]
```

### Related
[Related patterns or skills]
```

### Gotcha Template

```markdown
## Gotcha: [Title]

### What Happened
[Description of the issue]

### Why It Happened
[Root cause analysis]

### How to Detect
[Signs that indicate this issue]

### How to Prevent
[Prevention strategies]

### Related
[Related issues or skills]
```

### Context Template

```markdown
## Context: [Title]

### What
[Description of the context]

### Why Important
[Rationale for preserving this]

### Duration
[How long this remains relevant]

### Tags
[Keywords for retrieval]
```

### ADR Template

```markdown
## ADR: [Number] - [Title]

**Date:** YYYY-MM-DD
**Status:** [Proposed|Accepted|Deprecated]
**Type:** [Architectural|Technical|Process]

### Context
[What triggered this decision]

### Decision
[What was decided]

### Alternatives
[What else was considered]

### Consequences
Positive:
- [List]

Negative:
- [List]

### Related
[References to other decisions or documents]
```

## Core Workflow

**Execute this pattern during active work:**

1. **Detect capture triggers** - Listen for key phrases and events
2. **Extract insight** - Identify the permanent knowledge
3. **Align with conventions** - Check CLAUDE.md and rules
4. **Locate section** - Find appropriate CLAUDE.md section
5. **Append with context** - Add insight with "why" and "when"
6. **Report result** - Output action, discovery, location

## Alignment Check

Before proposing any addition, verify alignment:

| Check             | Question                              | Action if Fail                      |
| ----------------- | ------------------------------------- | ----------------------------------- |
| Delta check       | Would Claude know this from training? | Don't archive                       |
| Convention check  | Does this match project style?        | Format to match                     |
| Redundancy check  | Is this already documented?           | Reference existing, don't duplicate |
| Specificity check | Is this project-specific?             | Remove generic advice               |
| Permanence check  | Will this be relevant in 6 months?    | Archive if yes                      |

## What to Archive

**Capture:**
- Permanent project knowledge (commands, patterns, gotchas, decisions)
- Rule evolution with rationale
- Architectural decisions with context
- Reusable approaches with when/how guidance

**NEVER Archive:**
- Migration notes ("migrated from X to Y")
- Edit logs ("updated file", "modified section")
- Meta-notes ("this was a refactoring")
- Date-stamped entries
- Version tracking

## Output Format

**Binary test:** "Does this capture a knowledge principle, not a changelog entry?"

After inference or explicit content, present discoveries with `AskUserQuestion`:

```
## Discoveries Found

[X] **[Type]** - [The discovery]
   - Signal: [Detection trigger]
   - Why: [Rationale for future sessions]
   - When: [Trigger condition for application]
   - Where: [Proposed location]
```

**AskUserQuestion:**

```
Found X discoveries. What would you like to do?

Options:
- Archive all as project knowledge
- Archive specific ones (tell me which)
- Modify content before archiving
- Skip (nothing worth archiving)
```

### After Approval

Apply the change and confirm:

```
Action: Archived [type]
Location: [Section/file updated]
Content: [The captured knowledge]
Why: [Rationale captured]
When: [Trigger condition]
```

<critical_constraint>
MANDATORY: Only capture permanent knowledge - never temporary notes
MANDATORY: Never archive migration notes, edit logs, or meta-commentary
MANDATORY: Target both CLAUDE.md and .claude/rules/ for refinement
MANDATORY: Include context (why and when), not just what
MANDATORY: Never create date-stamped sections or update logs
MANDATORY: Validate CLAUDE.md structure before appending
MANDATORY: Propose before applying - no silent changes
MANDATORY: Check for redundancy before proposing additions
MANDATORY: Align with project conventions (CLAUDE.md style)
MANDATORY: Trust conversational memory, only read session files if context unclear
No exceptions. Archive creates lasting project memory, not transient notes.
</critical_constraint>
