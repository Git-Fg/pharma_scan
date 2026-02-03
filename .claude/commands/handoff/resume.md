---
description: "Resume work from a handoff document. Use at session start to restore context from previous session. Not for planning resume - use plan-specific mechanisms instead."
argument-hint: "[<handoff-type>]"
---

# Resume from Handoff

<mission_control>
<objective>Restore session context from a YAML handoff document and prepare to continue work</objective>
<success_criteria>Handoff context loaded, goal/now extracted, ready to proceed with next step</success_criteria>
</mission_control>

## Current handoff (if exists)

<injected_content>
@.claude/workspace/handoffs/handoff.yaml
</injected_content>

## Current diagnostic (if exists)

<injected_content>
@.claude/workspace/handoffs/diagnostic.yaml
</injected_content>

If neither file exists: No handoff to resume - ask user for context

## Workflow

### 1. Detect

Inject and parse handoff/diagnostic files:

**Current handoff (if exists)**

<injected_content>
@.claude/workspace/handoffs/handoff.yaml
</injected_content>

**Current diagnostic (if exists)**

<injected_content>
@.claude/workspace/handoffs/diagnostic.yaml
</injected_content>

If neither file exists: No handoff to resume - ask user for context

### 2. Execute

Parse the injected YAML and extract key fields:

- **goal**: What was accomplished
- **now**: Immediate next action
- **test**: Verification command
- **done_this_session**: Completed tasks
- **decisions**: Key decisions made
- **blockers**: Issues encountered
- **next**: Next steps

### 3. Verify

Run the verification command from handoff and present summary:

```
=== Handoff: {session-name} ===
Date: {date}
Status: {status} | Outcome: {outcome}

GOAL: {goal}

NOW: {now}

TEST: {test}

Completed:
  - {task 1}
  - {task 2}

Decisions:
  - {decision 1}
  - {decision 2}

Next Steps:
  1. {next 1}
  2. {next 2}
```

- If test passes → Proceed with "now" action
- If test fails → Report issue and await resolution

## Usage Patterns

**Resume from default handoff:**

```
/handoff:resume
```

**Resume from diagnostic:**

```
/handoff:resume diagnostic
```

**Resume from archived:**

```
/handoff:resume attic/handoff_20260129_143022.yaml
```

## Recognition Questions

| Question | Recognition |
| :------- | :---------- |
| Was handoff.yaml injected? | Parse and extract fields |
| Was diagnostic.yaml injected? | Use if no handoff.yaml |
| Was the goal accomplished? | Check `goal` field |
| What should happen now? | Extract `now` field |
| How do I verify? | Run `test` command |

---

## Validation Checklist

Before claiming resume complete:

- [ ] Handoff/diagnostic YAML injected and parsed
- [ ] Goal and now fields extracted
- [ ] Test command identified and run
- [ ] Clear summary presented before proceeding
- [ ] Context fully restored

---

<critical_constraint>
MANDATORY: Always extract goal/now/test fields for statusline
MANDATORY: Run verification test before proceeding
MANDATORY: Present clear summary before asking for action
No exceptions. Resume must restore complete context.
</critical_constraint>
