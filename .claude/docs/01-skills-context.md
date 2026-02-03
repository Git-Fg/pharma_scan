---
number: 01
title: Skills Context
audience: self-maintenance
related: [00, 02, 04, 05]
last-reviewed: 2026-02-01
---

# 01. Skills & Context

This document covers **context-based primitives** (Skills) and **components that use them** (Commands). These primitives operate with shared or injected context, making them ideal for expertise transfer and user-facing workflows.

For **forked-context primitives** (subagents, agents), see [02-subagents.md](02-subagents.md).

---

## Table of Contents

- [Skill Primitive](#skill-primitive)
  - [Concept Overview](#concept-overview)
  - [Context Modes](#context-modes-shared-vs-fork)
  - [Frontmatter Syntax](#frontmatter-syntax)
  - [Context Loading Behavior](#context-loading-behavior)
  - [Naming Conventions](#naming-conventions)
  - [Description Guidelines](#description-guidelines)
  - [Argument Access](#argument-access)
  - [Invocation Control](#invocation-control)
  - [Hooks in Skills](#hooks-in-skills)
  - [Skill Location](#skill-location)
- [Commands Component](#commands-component)
  - [Command Specification](#command-specification)
  - [ @/! Injection Syntax](#-injection-syntax)
  - [Templates](#templates)
  - [Best Practices](#best-practices)
- [Relationship: Skills ↔ Commands](#relationship-skills--commands)
  - [Unified Model](#unified-model)
  - [How Commands Use Skills](#how-commands-use-skills)
  - [Composition Patterns](#composition-patterns)
  - [When to Choose](#when-to-choose)

---

## Skill Primitive

### Concept Overview

**[OFFICIAL]** Skills are the primary knowledge injection mechanism in Claude Code. They provide persistent expertise that shapes how Claude thinks and works across sessions and conversations.

**Source**: skills.md lines 36-42

> **Custom slash commands have been merged into skills.** A file at `.claude/commands/review.md` and a skill at `.claude/skills/review/SKILL.md` both create `/review` and work the same way.

**[OFFICIAL]** When to Use Skills (Source: https://code.claude.com/docs/en/skills)

| Use Case | Skill Type |
|:---------|:-----------|
| Add domain expertise to current work | Default Skill (shared context) |
| Encapsulate a reusable workflow | Default Skill (shared context) |
| Create an isolated worker/auditor | Forked Skill (context: fork) |
| Run research in isolated context | Forked Skill with `agent: Explore` |
| Bundle multiple related skills | Agent with `skills:` field |

**Source**: skills.md lines 44-59

### Context Modes (Shared vs Fork)

**[OFFICIAL]** Context Modes Table

| Mode | Memory | Best For |
|:-----|:-------|:---------|
| **default** (shared) | Shared with main conversation | Heuristics, code standards, patterns, adding domain expertise |
| **fork** | Isolated subagent context | Specialists (Linter, Auditor, Validator), unbiased validation |

**Source**: skills.md lines 60-67

**[OFFICIAL]** Key insight: Default skills preserve conversation history, allowing Claude to build on previous context. Forked skills run in isolated context, enabling unbiased validation without implementation history.

**[FINDING]** Warning about context:fork

> `context: fork` only makes sense for skills with explicit instructions. If your skill contains guidelines like "use these API conventions" without a task, the subagent receives the guidelines but no actionable prompt.

**[FINDING]**

### Frontmatter Syntax

**[OFFICIAL]** Complete Frontmatter Example (Source: https://code.claude.com/docs/en/skills)

```yaml
---
name: skill-name              # Max 64 chars, lowercase, hyphens only
description: "Brief description. Use when {trigger conditions + keywords}. Not for {exclusions}."
context: fork                 # Optional: run in isolated subagent context
disable-model-invocation: true  # Optional: prevent Claude from auto-invoking
user-invocable: true          # Optional: visibility in / menu (default: true)
argument-hint: "<value>"      # Optional: show expected arguments
allowed-tools: Read, Grep, Glob  # Optional: tool whitelist
model: sonnet                 # Optional: model override
agent: general-purpose        # Required if context: fork
hooks:                        # Optional: event-driven automation
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./scripts/validate.sh"
---
```

**Source**: skills.md lines 261-286

**[OFFICIAL]** Frontmatter Field Reference

**Complete Reference**: See [05-reference.md](05-reference.md#frontmatter-field-reference) for canonical table with all fields including `license`.

| Field | Type | Required | Purpose |
|:------|:-----|:---------|:--------|
| `name` | string | No (uses dir name) | Skill identifier (max 64 chars) |
| `description` | string | Recommended | What it does, when to use |
| `context` | "fork" | No | Run in isolated context |
| `agent` | string | No (if `context: fork`) | Agent type (Explore/Plan/general-purpose) |
| `model` | string | No | Model override (sonnet/opus/haiku) |
| `user-invocable` | boolean | No (default: true) | Visibility in / menu |
| `disable-model-invocation` | boolean | No | Require explicit intent |
| `argument-hint` | string | No | Autocomplete hint |
| `hooks` | object | No | Event-driven automation |

### Context Loading Behavior

**[OFFICIAL]** Progressive Disclosure Levels (Source: https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)

| Level | Content | When Loaded | Token Cost |
|:-------|:--------|:------------|:-----------|
| **Metadata** | `name` and `description` from YAML | Always (startup) | ~100 tokens each |
| **Instructions** | SKILL.md body | When triggered | Under 5k tokens |
| **Resources** | Bundled files, scripts | As needed | Effectively free |

**Source**: skills.md lines 198-210

**[FINDING]** The Principle

SKILL.md serves as an overview that points Claude to detailed materials as needed—like a table of contents in an onboarding guide. Keep SKILL.md under 500 lines for optimal performance.

**[FINDING]** Reference File Structure

Keep references one level deep from SKILL.md:

```
# SKILL.md (one level)
## Basic usage
[instructions in SKILL.md]

**Advanced features**: See [advanced.md](advanced.md)
**API reference**: See [reference.md](reference.md)
**Examples**: See [examples.md](examples.md)

# advanced.md (referenced from SKILL only)
**More details**: See [deeper.md](deeper.md)  <- DON'T DO THIS
```

**Source**: skills.md lines 207-228

### Naming Conventions

**[FINDING]** Use gerund form: `processing-pdfs`, `analyzing-spreadsheets`, `creating-skills`

**Rules:**
- Lowercase letters, numbers, hyphens only
- Max 64 characters
- Avoid reserved words: `anthropic`, `claude`
- Avoid vague names: `helper`, `utils`, `worker`

**[OFFICIAL]**

### Description Guidelines

**[COMMUNITY]** Format: Third person, non-spoiling, includes "Use when" and "Not for"

```yaml
---
description: "Extracts text from PDF files. Use when working with PDF documents or need text extraction from PDFs. Not for image-based PDFs (use OCR tools) or other document formats."
---
```

**Components of a Good Description:**

| Element | Purpose | Example |
|:--------|:--------|:--------|
| **What it does** | Clear statement of function | "Extracts text from PDF files" |
| **Use when** | Trigger conditions + keywords | "Use when working with PDF documents or need text extraction" |
| **Not for** | Exclusions (what it's NOT for) | "Not for image-based PDFs (use OCR tools)" |

**[OFFICIAL]**

### Argument Access

**[OFFICIAL]** Access passed arguments and environment variables in skill content: (Source: https://code.claude.com/docs/en/skills)

| Variable | Description |
|:---------|:------------|
| `$ARGUMENTS` | All arguments passed when invoking the skill. |
| `$ARGUMENTS[N]` | Access a specific argument by 0-based index |
| `$N` | Shorthand for `$ARGUMENTS[N]` (e.g., `$0` for first) |
| `${CLAUDE_SESSION_ID}` | The current session ID. Useful for logging. |

**Source**: skills.md lines 438-474

**[OFFICIAL]** argument-hint Syntax

Shows expected arguments to users during autocomplete.

```yaml
---
name: my-skill
description: Description of what this skill does
argument-hint: [required-arg] [optional-arg]
---
```

**Syntax conventions:**

| Format | Meaning | Example |
|:--------|:---------|:--------|
| `[value]` | Argument placeholder | `[filename]` |
| `[--flag]` | Optional flag | `[--recursive]` |
| `|` | Alternatives | `[markdown|html|pdf]` |

**Source**: skills.md lines 409-435

### Invocation Control

**[OFFICIAL]** By default, both you and Claude can invoke any skill. Two frontmatter fields let you restrict this: (Source: https://code.claude.com/docs/en/skills)

| Field | Effect |
|:------|:-------|
| **`disable-model-invocation: true`** | Only you can invoke the skill. Use for workflows with side effects. |
| **`user-invocable: false`** | Only Claude can invoke the skill. Use for background knowledge. |

**Source**: skills.md lines 477-498

### Hooks in Skills

**[OFFICIAL]** Hooks can be defined directly in skill frontmatter. These hooks are scoped to the skill's lifecycle. (Source: https://code.claude.com/docs/en/hooks)

```yaml
---
name: secure-operations
description: Perform operations with security checks
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./scripts/security-check.sh"
---
```

**Source**: skills.md lines 502-526

### Skill Location

**[OFFICIAL]** Where you store a skill determines who can use it: (Source: https://code.claude.com/docs/en/skills)

| Location | Path | Applies to |
|:---------|:-----|:-----------|
| **Enterprise** | See managed settings | All users in your organization |
| **Personal** | `~/.claude/skills/<skill-name>/SKILL.md` | All your projects |
| **Project** | `.claude/skills/<skill-name>/SKILL.md` | This project only |
| **Plugin** | `<plugin>/skills/<skill-name>/SKILL.md` | Where plugin is enabled |

**Source**: skills.md lines 155-173

---

## Commands Component

### Command Specification

**[OFFICIAL]** Commands are single-file markdown components that provide entry points for user interaction and agent workflows. They live in the `commands/` directory and are invoked using colon syntax (e.g., `/path:to:command`).

**Source**: commands.md lines 23-25

**[OFFICIAL]** Single-File Layout (Source: https://code.claude.com/docs/en/skills)

```
commands/
└── path/
    └── to/
        └── command.md   # Maps to /path:to:command
```

**Naming**: Folder path maps to colon syntax (`commands/meta/refine/commands.md` → `/meta:refine:commands`)

**Source**: commands.md lines 41-52

### @/! Injection Syntax

**[OFFICIAL]** @/! Injection in Skills (Source: https://code.claude.com/docs/en/skills)

Both commands and skills support runtime content injection.

| Pattern | Purpose | Example |
|:--------|:--------|:--------|
| `@path/to/file` | Inject file content | `@docs/architecture.md` |
| `!command` | Execute bash, inline output | `!git rev-parse --abbrev-ref HEAD` |

**Source**: skills.md lines 356-366

**[OFFICIAL]** How it works

- **User invocation** (`/skill-name`): Content injected before execution
- **Agent invocation** (`Skill(skill-name)`): Same behavior - content injected at call time

**[FINDING]** Inject Dynamic Context with !command

The `!command` syntax runs shell commands before the skill content is sent to Claude. The command output replaces the placeholder, so Claude receives actual data, not the command itself.

Example:

```yaml
---
name: pr-summary
description: Summarize changes in a pull request
context: fork
agent: Explore
---

## Pull request context
- PR diff: !`gh pr diff`
- PR comments: !`gh pr view --comments`
- Changed files: !`gh pr diff --name-only`

## Your task
Summarize this pull request...
```

When this skill runs:
1. Each `!command` executes immediately (before Claude sees anything)
2. The output replaces the placeholder in the skill content
3. Claude receives the fully-rendered prompt with actual PR data

This is preprocessing, not something Claude executes. Claude only sees the final result.

**Source**: skills.md lines 372-405

### Templates

**[OFFICIAL]** Template: Command

```yaml
---
description: "[What it does]. Use when [trigger conditions]. Not for [exclusions]."
argument-hint: "[arg1] [arg2]"
---

# Command Name

[Brief description of what this command does]

## Usage

[How to use this command]

## Examples

[Concrete examples]

## Notes

[Any additional notes]
```

**Source**: commands.md lines 216-239

### Best Practices

**[FINDING]** The Power of Text-Only Commands

A command doesn't need branching logic or complex structures to be effective. Natural language instructions adapt to whatever the user reveals.

**Why Simple Wins:**
- **Adaptability:** Natural language pivots based on user revelations
- **Maintenance:** 10 lines vs. 50 lines = easier updates
- **Effectiveness:** AskUserQuestion provides better interaction than hardcoded branches
- **Focus:** Guides goal and approach, not rigid process

**[FINDING]** Built-in Tools as Structure

The structure comes from **tools**, not command logic:

| Your Command Says | Tool Handles |
|:------------------|:-------------|
| "Ask one question at a time" | AskUserQuestion enforces single-question flow |
| "Offer meaningful choices" | AskUserQuestion presents options |
| "Read files if needed" | Read/Glob provides file access |
| "Write the result" | Write tool saves output |

**Source**: commands.md lines 70-187

**[FINDING]** When to Keep Commands Simple

**Use Simple Text Commands When:**
- Goal is user discovery or clarification
- Workflow adapts based on input
- Interaction pattern matters more than rigid steps
- Quick entry point needed

**Add Command Structure When:**
- Arguments require parsing (--flags, options)
- Multiple distinct sub-workflows exist
- Must integrate with external tools/systems
- User needs explicit guidance on invocation

**Source**: commands.md lines 160-173

---

## Relationship: Skills ↔ Commands

### Unified Model

**[OFFICIAL]** Commands Merged into Skills (Source: https://code.claude.com/docs/en/skills - "Custom slash commands have been merged into skills.")

In Claude Code 2.1, commands and skills were unified to use the same underlying `Skill` tool. Previously, they were separate concepts with different invocation mechanisms.

**[OFFICIAL]** Decision: Treat commands as skills with single-file structure. Both create `/name` commands and work the same way internally. Skills are the recommended approach since they support additional features.

**[FINDING]**

**[OFFICIAL]** Command vs Skill Comparison

| Aspect | Command | Skill |
|:-------|:--------|:------|
| **File Structure** | Single `.md` file | Folder with `SKILL.md` |
| **Naming** | Folder path → colon syntax | Explicit `name:` field |
| **Supporting Files** | No | Yes (`references/`, `scripts/`) |
| **Progressive Disclosure** | No | Yes (reference files, bundled content) |
| **Hooks** | Yes | Yes |
| **Precedence** | Lower | Higher (if same name, skill wins) |
| **@/! Injection** | Yes | Yes |

**Key Point**: Commands and skills use the same underlying `Skill` tool. Skills are recommended for new components due to additional features.

**Source**: commands.md lines 54-66

### How Commands Use Skills

**[FINDING]** Commands can invoke skills using the `Skill()` tool:

```markdown
# In a command
Invoke skill: Skill(skill-name)
```

**Source**: Implicit from skills.md commands.md relationship

### Composition Patterns

**[FINDING]** Decision: Multi-Phase Delegation

`Task → Task` nesting is forbidden by recursion blocker. Multi-phase workflows need clean separation of concerns.

Use single Task with inline skills for multi-phase workflows. **CUSTOM** (Empirical finding: `Skill(context: fork)` runs inline with context isolation—does not spawn true subagents, allowing chained forked skills).

**[FINDING]**

**[FINDING]** Manager Pattern for Skill Creation

Use Manager Pattern: `Task(work)` + `Skill(auditor, context: fork)` with automatic retry on failure.

**Rationale:**
- **Unbiased quality gates**: Auditor sees only the draft, not implementation attempts
- **Separation of concerns**: Implementation and validation are isolated
- **Automatic retry**: Manager handles retry logic without user intervention
- **Clear error reporting**: Auditor returns structured Pass/Fail + issues

**[FINDING]**

### When to Choose

**[FINDING]** Decision Matrix

| If the goal is... | Use this Primitive | Why? |
|:------------------|:-------------------|:-----|
| **Exploration** | `Skill(context: fork)` w/ `agent: Explore` | Fastest, cheapest, cannot accidentally break code |
| **High-Volume Edits** | `Task(subagent)` | Keeps context clean for high-level thoughts |
| **Strict Compliance** | `Skill(context: fork)` | No "Context Contamination" from previous shortcuts |
| **User Shortcuts** | `Skill` with `@`/`!` injection | Deterministic context injection at invocation time |
| **Adding Expertise** | `Skill()` (default) | Content injects, preserves history |
| **Read-Only Research** | `Task(Plan)` or `Task(Explore)` | Safe codebase analysis without modification risk |
| **Manual-Only Workflows** | `Skill` with `disable-model-invocation: true` | Prevents automatic invocation for sensitive ops |

**[FINDING]**

**[FINDING]** Simple vs. Complex Skills Decision Matrix

| Aspect | Simple Skill | Complex Skill |
|:-------|:-------------|:--------------|
| **Length** | 20-50 lines | 100+ lines |
| **Structure** | Natural language guidelines | Step-by-step enforcement |
| **Best For** | Discovery, exploration, heuristics | Validation, strict workflows |
| **Tools Used** | AskUserQuestion for interaction | Task delegation for isolation |
| **Maintenance** | Low - easy to update | Higher - strict process changes |

**Guideline:** Start simple. Add structure only when:
- The process must be followed exactly
- Output format must be strictly consistent
- Multiple validation phases are required
- Safety depends on explicit checks

**Source**: skills.md lines 137-152
