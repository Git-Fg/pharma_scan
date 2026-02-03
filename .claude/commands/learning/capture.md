---
description: "Scan recent activity (session or git history) to identify automation gaps. Autonomously proposes new Skills, Agents, or Commands to streamline workflows. Use when you feel a process was tedious or repetitive. Keywords: automation, gap, repetitive, workflow, component. Not for archiving discoveries, extracting existing logic, or non-automation tasks."
argument-hint: ""
allowed-tools: AskUserQuestion, Bash
---

<mission_control>
<objective>Analyze recent manual labor or recurring patterns to architect a Toolkit Component that automates them</objective>
<success_criteria>Component proposal presented with clear scope, type, and rationale</success_criteria>
</mission_control>

# Automation Gap Capture

Identify automation opportunities from recent activity by detecting repetitive sequences, manual lookups, or complex cognitive loads that could be streamlined.

## Context

<injected_content>
Recent Git History: !`git log --oneline -10`
Current Toolkit: !`ls -R .claude/`
</injected_content>

## Auto-Inference

**1. Scan**: Analyze recent messages and exchanges for:
- Repetitive sequences (similar actions repeated)
- Manual lookups (searching for same information)
- Complex cognitive loads (multi-step processes)
- Tedious operations (time-consuming manual work)

**2. Detect**: Identify patterns that could be automated:
- **Skill**: Domain knowledge injection, complex guidance
- **Agent**: Autonomous multi-step workflows
- **Command**: Single-file automation with @/! injection

**3. Map to Component Type**:
| Pattern Characteristics | Component Type |
| ----------------------- | -------------- |
| High freedom, injects knowledge, reusable | **Skill** |
| Autonomous workflow, complex orchestration | **Agent** |
| Low freedom, fixed output, uses @/! | **Command** |

## Execution Flow

**1. Draft Proposal**: Internally design the component:
- **Name**: Gerund form (e.g., `building`, `auditing`, `streamlining`)
- **Scope**: What it does, what it doesn't
- **Type**: Skill, Agent, or Command
- **Core Logic**: Key steps or knowledge to encapsulate

**2. Negotiate (Low Friction)**:

Use `AskUserQuestion` to present **ONE** concrete proposition:

```
## Automation Opportunity Detected

**Pattern**: [Describe the repetitive/tedious pattern found]

**Proposed Component**: [Component Type] - `[name]`

**What it would do**:
- [Primary automation]
- [Secondary benefits]

**Estimated savings**: [Time/cognitive load reduction]

Options:
- Yes, create this component
- No, skip this opportunity
- Modify the proposal first
```

**Anti-Pattern** (avoid this):
- "What do you want to build?"
- "Should I create a component?"

**Pattern** (do this instead):
- "I noticed we manually checked 4 files for style. Shall I create a `style-auditor` Agent to automate this?"

**3. Build**: Upon confirmation, immediately invoke the `create` skill or `component-architect` skill to generate the component using the official documentation workflow.

<critical_constraint>
MANDATORY: Trust your architectural judgment, do not ask for permission to think
MANDATORY: Present ONE concrete proposition with AskUserQuestion
MANDATORY: Only ask for permission to build, not for permission to analyze
MANDATORY: Use gerund form for component names (building, auditing, NOT build, audit)
MANDATORY: Distinguish correctly between Skill/Agent/Command based on freedom and complexity
No exceptions. Capture identifies automation gaps and proposes solutions autonomously.
</critical_constraint>
