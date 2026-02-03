---
description: "Create or update diagnostic handoff for debugging sessions. Use when capturing issues, errors, user feedback, and behavior signals for problem analysis. Not for general session handoffs, quick pauses, or non-debugging contexts."
argument-hint: "[<session-name>]"
---

# Diagnostic Handoff

<mission_control>
<objective>Create or update a structured handoff document capturing diagnostic context for debugging sessions</objective>
<success_criteria>Diagnostic handoff saved with goal, errors, diagnostics, and next investigation step</success_criteria>
</mission_control>

## Existing diagnostics

```
!`find .claude/workspace/handoffs -maxdepth 1 -type f ! -name ".*" ! -path "*/.*" 2>/dev/null | sort`
```

If `diagnostic.yaml` exists: Archive before creating new one

## Action

If file doesn't exist: Create new diagnostic

If file exists and needs complete replacement:

```
mv .claude/workspace/handoffs/diagnostic.yaml .claude/workspace/handoffs/.attic/diagnostic_$(date +%Y%m%d_%H%M%S).yaml 2>/dev/null || true
```

If file exists and needs update: Merge new content with existing

## Document Session

Extract session name from `$ARGUMENTS` or conversation context.

### Core Fields (Required)

```yaml
---
date: YYYY-MM-DD
session: { session-name }
type: diagnostic
status: { in_progress|complete|blocked }
severity: { low|medium|high|critical }
---
goal: { What this diagnostic session was investigating }
now: { What the next session should do first }
test: { Command to verify fix or continue investigation }
```

### Diagnostic Context (Required)

```yaml
user_feedback:
  - "{Feedback quote or summary}"

behavior_signals:
  - "{Observed behavioral drift or issue}"

errors:
  - message: "{Exact error message}"
    file: "{file:line}"
    stack: "{Stack trace if available}"

diagnostics:
  - {Root cause analysis or hypothesis}

investigations:
  - {Test performed}
    result: "{What was found}"
    files: [{files examined}]
```

### Resolution (Optional)

```yaml
resolutions:
  - { What was fixed or determined }

workarounds:
  - { Temporary solution applied }

still_unresolved:
  - { Issues still open }
```

## Save

```
Write: .claude/workspace/handoffs/diagnostic.yaml
```

---

<critical_constraint>
MANDATORY: Capture exact error messages with file:line references
MANDATORY: Document behavior signals observed during session
MANDATORY: Include root cause analysis or hypotheses
MANDATORY: Provide clear next investigation step
MANDATORY: Archive via mv before write if complete replacement
No exceptions. Diagnostic handoffs must enable continuous investigation.
</critical_constraint>
