---
number: 05
title: Reference
audience: self-maintenance
related: [00, 01, 02, 03, 04]
last-reviewed: 2026-02-01
---

# 05 - Reference

Quick lookup tables, key terms, architectural decisions, and research findings.

## Quick Navigation

| Section | Line | Key Terms |
|:--------|:-----|:----------|
| Quick Reference Tables | ~15 | frontmatter, agents, context, hooks |
| Frontmatter Syntax | ~20 | YAML, skills, commands, agents |
| Agent Capabilities | ~95 | Explore, Plan, general-purpose, tools |
| Context Modes | ~120 | shared, forked, injected |
| Hooks Reference | ~145 | events, types, exit codes |
| Portability Matrix | ~180 | cross-platform, skills, commands |
| Quality Checklist | ~215 | verification, naming, content |
| Key Terms | ~245 | primitives, patterns, features |
| Architectural Decisions | ~310 | ADRs, findings, status |
| Personal Findings | ~375 | TOC pattern, navigation |

---

## Quick Reference Tables

### Frontmatter Syntax Reference

**[OFFICIAL]** ✓ VERIFIED (Sources: https://code.claude.com/docs/en/skills | https://code.claude.com/docs/en/sub-agents)

```yaml
---
# Skill Frontmatter
name: skill-name              # Max 64 chars, lowercase, hyphens only
description: "Brief description. Use when {trigger conditions}. Not for {exclusions}."
license: MIT                  # Optional: for open-source skills
context: fork                 # Optional: for isolated workers
agent: general-purpose        # Required if context: fork
user-invocable: true          # Optional: visibility in / menu (default: true)
disable-model-invocation:     # Optional: require explicit user intent
argument-hint: "<value>"      # Optional: show expected arguments
model: sonnet                 # Optional: model override
---
```

**Agent Frontmatter**:
```yaml
---
name: agent-name
description: "Brief description."
skills:                       # Agents only: bundle skills
  - skill-a
  - skill-b
---
```

**Command Frontmatter**:
```yaml
---
description: "Brief description."
argument-hint: "[--option]"
---
```

**Folder Structure**:
```
skill-name/
├── SKILL.md              # Required - main skill file
├── scripts/              # Optional - executable code
├── references/           # Optional - documentation
└── assets/               # Optional - templates, fonts, icons
```

### Frontmatter Field Reference

**[OFFICIAL]** ✓ VERIFIED (Source: https://code.claude.com/docs/en/skills)

**Note**: Skills and Commands are unified (Claude Code 2.1+) - both use `Skill()` for invocation. These fields apply to both.

#### Skill/Command Frontmatter Fields

| Field | Type | Required | Purpose |
|:------|:-----|:---------|:--------|
| `name` | string | No (uses dir name) | Component identifier (max 64 chars) |
| `description` | string | Recommended | What it does, when to use |
| `license` | string | No | License for open-source (MIT, Apache-2.0) |
| `context` | "fork" | No | Run in isolated context |
| `agent` | string | No (if context: fork) | Which agent type (Explore/Plan/general-purpose) |
| `model` | string | No | Model to use (sonnet/opus/haiku/inherit) |
| `allowed-tools` | list | No | Restrict which tools |
| `user-invocable` | boolean | No (default: true) | Visibility in / menu |
| `disable-model-invocation` | boolean | No | Require explicit user intent |
| `argument-hint` | string | No | Hint for expected arguments during autocomplete |
| `hooks` | object | No | Event-driven automation |

#### Agent Frontmatter Fields

**⚠️ These fields are ONLY valid in `.claude/agents/*.md` files. They are NOT supported in Skill or Command files.**

| Field | Type | Required | Purpose |
|:------|:-----|:---------|:--------|
| `skills:` | list | Yes (for agents) | Bundle multiple skills into agent |

### Argument Access Reference

**[OFFICIAL]** ✓ VERIFIED (Source: https://code.claude.com/docs/en/skills)

| Syntax | Meaning |
|:-------|:---------|
| `$ARGUMENTS` | All arguments as single string |
| `$ARGUMENTS[0]` or `$0` | First argument |
| `$ARGUMENTS[N]` or `$N` | Nth argument (0-indexed) |

### Agent Capabilities Reference

**[OFFICIAL]** ✓ VERIFIED (Source: https://code.claude.com/docs/en/sub-agents)

**Built-in Agent Types**:

| Agent | Tools | Read-Only? | Use For |
|:-------|:------|:-----------|:--------|
| **Explore** | Glob, Grep, Read, LSP | Yes | Fast exploration, no risk |
| **Plan** | Glob, Grep, Read, LSP | Yes | Planning, architecture |
| **general-purpose** | All tools | No | Implementation, execution |
| **Bash** | Bash only | No | Terminal operations |

**Tool Access by Agent**:

| Tool | Explore | Plan | general-purpose | Bash |
|:-----|:--------|:-----|:----------------|:-----|
| Read | ✅ | ✅ | ✅ | ❌ |
| Write | ❌ | ❌ | ✅ | ❌ |
| Edit | ❌ | ❌ | ✅ | ❌ |
| Glob | ✅ | ✅ | ✅ | ❌ |
| Grep | ✅ | ✅ | ✅ | ❌ |
| Bash | ❌ | ❌ | ✅ | ✅ |
| LSP | ✅ | ✅ | ✅ | ❌ |

### Context Modes Reference

| Mode | Behavior | Inheritance | Use When |
|:-----|:----------|:-------------|:---------|
| **Shared** | Preserves history | Sees parent context | Adding expertise to current work |
| **Forked** | Copy, no shared history | CLAUDE.md + rules/ only | Isolated work, unbiased validation |
| **Injected** | @/! content at invocation | Deterministic state | Entry points, workflows |

### Command/Invocation Reference

**Task vs Skill**:
```
Task(agent-name)              # Spawn subagent
Skill(skill-name)              # Inject content
Skill(skill-name, context: fork)  # Isolated execution
```

**Context Injection**:
```
@path/to/file                 # Inject file content
!`command`                    # Inject bash output
```

**Special Frontmatter**:
```yaml
---
user-invocable: false         # Hidden from / menu
disable-model-invocation: true  # Explicit intent only
argument-hint: "<file>"       # Show expected args
once: true                    # Run hook once
matcher: "Bash"               # Filter events
---
```

### Hooks Quick Reference

**Events**:

| Event | When Fires | Use Case |
|:------|:-----------|:---------|
| `SessionStart` | Session init | Load discipline context |
| `PreToolUse` | Before tool | Security, validation |
| `PostToolUse` | After tool | Logging, cleanup |
| `Stop` | Session stop | Cleanup, archive |

**Hook Types**:

| Type | Purpose | Returns |
|:-----|:--------|:--------|
| `command` | Execute script | Exit code + JSON stdout |
| `prompt` | Ask user | User decision (JSON) |

**Exit Codes**:

| Code | Behavior | Use For |
|:-----|:---------|:--------|
| **0** | Success, parse JSON | Control decisions |
| **2** | Blocking error | Security violations |
| **Other** | Non-blocking | Warnings |

### Cross-Platform Portability Matrix

**[OFFICIAL]** ✓ VERIFIED (Sources: https://agentskills.io/specification | https://code.claude.com/docs/en/skills | https://opencode.ai/docs)

**Skill Feature Portability**:

| Feature | Standard | Claude Code | OpenCode | Portable? |
|:--------|:---------|:------------|:---------|:----------|
| `SKILL.md` + YAML | ✅ | ✅ | ✅ | ✅ **Yes** |
| `name` (64 chars) | ✅ | ✅ | ✅ | ✅ **Yes** |
| `description` (1024 chars) | ✅ | ✅ | ✅ | ✅ **Yes** |
| `license` | ✅ | ✅ | ✅ | ✅ **Yes** |
| `compatibility` | ✅ | ✅ | ✅ | ✅ **Yes** |
| `metadata` | ✅ | ✅ | ✅ | ✅ **Yes** |
| `scripts/` directory | ✅ | ✅ | ✅ | ✅ **Yes** |
| `references/` directory | ✅ | ✅ | ✅ | ✅ **Yes** |
| `context: fork` | ❌ | ✅ | ❌ | ❌ **No** |
| `agent: Explore/Plan` | ❌ | ✅ | ❌ | ❌ **No** |
| `skills:` field | ❌ | ✅ | ❌ | ❌ **No** |
| `user-invocable` | ❌ | ✅ | ❌ | ❌ **No** |
| `hooks` | ❌ | ✅ | ❌ | ❌ **No** |
| On-demand loading | Optional | Auto | `skill()` | ⚠️ **Varies** |

**Command Portability**:

| Feature | Claude Code | OpenCode | Portable? |
|:--------|:------------|:---------|:----------|
| Single `.md` file | ✅ | ✅ | ✅ **Yes** |
| Colon syntax naming | ✅ | ❌ | ❌ **No** |
| `subtask: true` | ❌ | ✅ | ❌ **No** |
| Unified with skills | ✅ | ❌ | ❌ **No** |

### Quality Checklist

**Before You Start**:
- [ ] Identified 2-3 concrete use cases
- [ ] Tools identified (built-in or MCP)
- [ ] Reviewed official documentation
- [ ] Planned folder structure

**During Development**:

| Check | Requirement |
|:------|:------------|
| Frontmatter | `name` + `description` (What-When-Not format) |
| File naming | Folder: kebab-case, File: exactly `SKILL.md` |
| YAML delimiters | Frontmatter wrapped in `---` |
| Description | Includes trigger phrases and exclusions |
| Content | Core knowledge in SKILL.md, not scattered |
| Examples | Concrete scenarios with expected behavior |

**Before Upload**:
- [ ] Tested triggering on obvious tasks
- [ ] Tested triggering on paraphrased requests
- [ ] Verified doesn't trigger on unrelated topics
- [ ] Functional tests pass
- [ ] Tool integration works (if applicable)
- [ ] Compressed as .zip file

**After Upload**:
- [ ] Test in real conversations
- [ ] Monitor for under/over-triggering
- [ ] Collect user feedback
- [ ] Iterate on description and instructions

**Reference**: See official guide Reference A (lines 1774-1840) for complete checklist.

---

## Key Terms

### Core Primitives

**Agent** [OFFICIAL] - Persistent persona with bundled capabilities, defined in `.claude/agents/agent.md`. Uses `skills:` field to pre-load multiple skills.

**Skill** [OFFICIAL] - Knowledge worker with folder structure (`.claude/skills/name/SKILL.md`). Can have supporting files (references/, scripts/) and progressive disclosure.

**Command** [OFFICIAL] - Single-file entry point in `.claude/commands/`. Merged into skills in Claude Code 2.1—both create `/name` commands.

**Task** [OFFICIAL] - Tool that spawns new agent with forked context. Used for delegating complex multi-step tasks. **Constraint**: `Task → Task` nesting is FORBIDDEN.

### Context Modes

**Context** [OFFICIAL] - The conversation history, file contents, and system prompt that an agent operates within.

**Forked Context** [OFFICIAL] - Copy of context that doesn't share history with parent. Used by `Task()` and `Skill(context: fork)`.

**Shared Context** [OFFICIAL] - Context that preserves conversation history. Default for `Skill()` tool.

**Injected Context** [OFFICIAL] - Content inserted via `@file` or `` !command `` patterns at skill invocation time.

### Key Patterns

**Delta Standard** [FINDING] - Principle that **Good Component = Expert Knowledge − What Claude Already Knows**. Keep best practices, domain expertise. Remove basics, standard docs, Claude-obvious operations.

**Manager Pattern** [FINDING] - Orchestration pattern with automatic retry: `Main → Skill(manager) → Task(create) → Skill(auditor, fork) → [retry if fail] → Main`.

**Chain of Experts** [FINDING] - Multi-phase workflow exploiting recursion loophole: `Skill(fork) → Skill(fork)` (allowed, unlike `Task → Task`).

**Recursion Loophole** [FINDING] - `Skill(context: fork)` runs inline with context isolation (not true subagent spawn), allowing chained forked skills unlike forbidden `Task → Task`.

**Loadout Agent** [FINDING] - Agent with bundled skills via `skills:` field. Creates consistent worker with same capabilities every spawn.

### Component Features

**Frontmatter** [OFFICIAL] - YAML metadata at top of skill/command/agent files. Defines component behavior (name, description, context, agent, etc.).

**Argument-Hint** [OFFICIAL] - Frontmatter field showing expected arguments during autocomplete.

**User-Invocable** [OFFICIAL] - Frontmatter field controlling visibility in `/` menu. Values: `true` (default), `false` (agent-only).

**Disable-Model-Invocation** [OFFICIAL] - Frontmatter field preventing auto-invocation. Skill only runs when explicitly invoked by user.

**Non-Spoiling Description** [FINDING] - Description saying what component does without revealing implementation details. Critical for avoiding token waste.

### Quality & Standards

**Progressive Disclosure** [FINDING] - Three-tier content loading: Metadata (~100 tokens, always), SKILL.md (<5k tokens, when triggered), references/ (as needed).

**Quality Gate** [FINDING] - Automated validation phase (BUILD, TYPE, LINT, TEST, SECURITY, DIFF).

**Gerund Form** [FINDING] - Naming convention for skills/commands: verb ending in "-ing" (e.g., `processing-pdfs`, `creating-skills`).

---

## Architectural Decisions

### Commands Merged into Skills

**Status**: [OFFICIAL] Accepted (Claude Code 2.1)
**Impact**: Simplified architecture

Treat commands as skills with single-file structure. Both create `/name` commands and work the same way internally. Skills recommended due to additional features (supporting files, progressive disclosure).

### Context Topology over Micromanagement

**Status**: [COMMUNITY] Accepted (Verified against platform best practices)
**Impact**: Better AI autonomy

Encode goals, constraints, success criteria, and examples rather than micromanaging step-by-step behavior. Modern agents perform better with autonomy than rigid scripts.

### Manager Pattern for Quality Validation

**Status**: [FINDING] Accepted
**Impact**: Unbiased quality gates

Use `Task(work)` + `Skill(auditor, context: fork)` with automatic retry on failure. Auditor sees only draft, not implementation attempts—enabling objective validation.

### Chain of Experts via Recursion Loophole

**Status**: [FINDING] Accepted
**Impact**: Multi-phase workflows possible

`Task → Task` nesting is forbidden. **[FINDING]**: `Skill(context: fork)` runs inline with context isolation (not true subagent), allowing `Skill(fork) → Skill(fork)` chaining.

### Progressive Disclosure

**Status**: [FINDING] Accepted
**Impact**: Efficient token usage

Three-tier loading: Metadata (always ~100 tokens), SKILL.md (when triggered <5k), references/ (as needed). Enables many skills without token bloat.

### Gerund Form Naming

**Status**: [FINDING] Accepted
**Impact**: Consistent discoverability

Use gerund form for all skill/command names: `processing-pdfs`, `analyzing-spreadsheets`. Action-oriented, consistent, discoverable.

### Non-Spoiling Descriptions

**Status**: [FINDING] Accepted
**Impact**: Better system prompts

Descriptions should say what component does, when to use it, and what it's NOT for—without revealing implementation details.

### Loadout Agents

**Status**: [FINDING] Accepted
**Impact**: Consistent multi-skill workers

Use `skills:` field in agents to bundle multiple capabilities. Creates consistent worker with explicit capability manifest.

---

## Personal Findings

### TOC Pattern for Large Files

**[FINDING]** - Optimization pattern for agent navigation

**The Problem**: Agents typically read files using `head -n 100` or similar truncation. If critical information is scattered throughout 500+ line files, agents miss it.

**The Solution**: Add grep-friendly Table of Contents in first 50 lines.

**When to Use TOC**:

| File Type | Use TOC? | Reason |
|:----------|:---------|:-------|
| `references/*.md` in skills | ✅ YES | Large, read on-demand |
| Documentation files (500+ lines) | ✅ YES | Agents need navigation |
| Knowledge bases | ✅ YES | Quick lookup needed |
| `SKILL.md` | ❌ NO | Should be <500 lines, fully loaded |
| `CLAUDE.md` | ❌ NO | Autoloaded, should be concise |
| `.claude/rules/*.md` | ❌ NO | Autoloaded, keep focused |
| Templates | ❌ NO | Short, copy-paste ready |
| Examples | ❌ NO | Short, self-contained |

**TOC Format**:

```markdown
## Quick Navigation

| Section | Line | Key Terms |
|:--------|:-----|:----------|
| Overview | ~15 | purpose, scope, usage |
| Configuration | ~45 | settings, options, config |
| API Reference | ~120 | methods, functions, endpoints |
| Examples | ~200 | code, usage, samples |
| Troubleshooting | ~280 | errors, issues, fixes |
```

**Key Terms Column**: Enables grep-based navigation. Best practices:
- Use 3-5 terms per section
- Use lowercase, hyphenated format
- Include synonyms users might search for
- Match actual content keywords

**Implementation Checklist**:
- [ ] TOC starts within first 30 lines
- [ ] Each major section has a row
- [ ] Line numbers are approximate (~N format)
- [ ] Key terms are grep-friendly
- [ ] TOC itself is under 25 lines
- [ ] First major section visible by line 50

**Example Impact**:

**Before** (agent reads first 100 lines, misses API section at line 400):
```markdown
# API Documentation

## Introduction
Long introduction text...
[100 lines of context]

## Getting Started
[150 lines of setup]

## API Reference    <- Agent never sees this
```

**After** (agent sees TOC, can navigate):
```markdown
# API Documentation

## Quick Navigation
| Section | Line | Key Terms |
|:--------|:-----|:----------|
| Introduction | ~10 | overview, purpose |
| Getting Started | ~110 | setup, install, config |
| API Reference | ~260 | endpoints, methods, auth |

## Introduction
...
```

---

## Content Badge Legend

- **[OFFICIAL]** - Ground truth from Claude Code official documentation
- **[COMMUNITY]** - Best practices from community/Platform docs
- **[FINDING]** - Personal research findings and empirical discoveries
