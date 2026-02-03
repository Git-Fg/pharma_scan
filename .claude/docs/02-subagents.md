---
number: 02
title: Subagents
audience: self-maintenance
related: [00, 01, 03, 04, 05]
last-reviewed: 2026-02-01
---

# 02. Subagents

This document covers **forked-context primitives** (Tasks) and the **Agent component** that uses them for building specialized workers with persistent personas and bundled capabilities.

**Core distinction**: Skills (shared context) vs Tasks (forked context). See [01-skills-context.md](./01-skills-context.md) for shared-context primitives.

---

## Table of Contents

1. [Task Primitive (Forked Context)](#task-primitive-forked-context)
   - Task vs Skill comparison
   - Critical rules and constraints
   - Forked context deep dive
   - Agent types for tasks
   - Permission modes
2. [Agents Component (Bundled Skills and Persistent Persona)](#agents-component-bundled-skills-and-persistent-persona)
   - Concept overview
   - File layout and frontmatter
   - The `skills:` field
   - Agent vs Worker Skill
   - Templates and examples
3. [Relationship: Tasks ↔ Agents](#relationship-tasks--agents)
   - How agents use tasks
   - Forked context patterns
   - Heavy lifting delegation
   - Composition patterns

---

## Task Primitive (Forked Context)

**[OFFICIAL]** (Sources: https://code.claude.com/docs/en/skills | https://code.claude.com/docs/en/sub-agents)

### Core Task vs Skill Comparison

| Aspect | Task() | Skill() |
|:-------|:-------|:--------|
| **Context** | Isolated (new subagent) | Preserved (shared) |
| **System Prompt** | Subagent markdown body + preloaded skills | Skill content injects into current prompt |
| **Loads** | CLAUDE.md + rules/ + agent's skills: bundle (if Agent specified) | Inherits parent context |
| **Results** | Returns to parent as summary | Inline execution |
| **Use when** | Heavy lifting, high-volume edits, isolated work | Adding expertise, heuristics, reference content |

### Key Distinction

**`Skill()` tool**: Injects content into CURRENT conversation, preserves history
- Agent continues with enhanced knowledge
- All conversation context remains available
- Can run inline or in forked context (`context: fork`)

**`Task()` tool**: Spawns NEW agent instance with isolated context
- Fresh start with only CLAUDE.md + rules/ + preloaded skills
- Parent conversation history NOT inherited
- Results cascade back as summary
- Cannot spawn other subagents (recursion blocker)

### Critical Rules

**[OFFICIAL]** (Source: https://code.claude.com/docs/en/sub-agents)

**What's Allowed and Forbidden**:
```
Main → Task(subagent)      → Isolated context, true subagent spawn
Main → Skill(skill)        → Inline, shares context
Task → Skill(skill)        → Allowed, subagent invokes inline skill
Skill(fork) → Skill(fork)  → ALLOWED (isolated context, not subagent spawn)
Skill(fork) → Task(agent)  → FORBIDDEN (still blocks recursion)

Task → Task(subagent)      → FORBIDDEN (recursion blocker)
```

**The Subagent Constraint**:
`Task → Task` nesting is **FORBIDDEN** to prevent infinite recursion. This is a hard constraint in Claude Code.

**[FINDING]** (Empirical finding): `Skill(context: fork)` with `agent:` field spawns a subagent with the skill content as task. The skill determines the task, the agent determines the execution environment (model, tools, permissions).

**Skills vs Subagents: Two Directions**:

| Approach | System Prompt | Task | Also Loads |
|:---------|:--------------|:-----|:-----------|
| Skill with `context: fork` | From agent type (Explore, Plan, etc.) | SKILL.md content | CLAUDE.md + rules/ |
| Task invoking Agent (with skills: field) | Agent's markdown body | Claude's delegation message | Agent's skills: bundle + CLAUDE.md |

### Forked Context Deep Dive

**Characteristics**:
- Isolated context without shared history
- Only CLAUDE.md + rules/ loaded
- No parent conversation visible
- Runs in subagent (Task) or isolated skill context

**Use for**:
- Isolated work, unbiased validation
- Heavy lifting (keep main context clean)
- Specialists that shouldn't see history
- Skills with explicit tasks (not just guidelines)

**Example**:
```markdown
# Main agent
→ Skill(auditor, context: fork)  // Sees ONLY draft, not attempts
→ Returns unbiased Pass/Fail
```

**[FINDING]** Warning:
`context: fork` only makes sense for skills with explicit instructions. If your skill contains guidelines like "use these API conventions" without a task, the subagent receives guidelines but no actionable prompt.

### Agent Types for Tasks

**[OFFICIAL]** (Source: https://code.claude.com/docs/en/sub-agents)

**Built-in Agents**:

| Agent | Model | Tools | Read-Only? | Use For |
|:-------|:------|:------|:-----------|:--------|
| **Explore** | Haiku (fast, low-latency) | Read-only (denied Write/Edit) | Yes | Fast codebase exploration, no modification risk |
| **Plan** | Inherits from main | Read-only (denied Write/Edit) | Yes | Research before planning, architecture decisions |
| **general-purpose** | Inherits from main | All tools | No | Complex multi-step tasks requiring exploration + action |
| **Bash** | Inherits from main | Bash only | No | Terminal operations, git commands |
| **statusline-setup** | Sonnet | All tools | No | Configure status line (`/statusline`) |
| **Claude Code Guide** | Haiku | Read-only | Yes | Answer questions about Claude Code features |

**Explore Thoroughness Levels**: When invoking Explore, Claude specifies thoroughness: **quick** (targeted lookups), **medium** (balanced exploration), or **very thorough** (comprehensive analysis).

**When to Use Each Agent**:

**Explore**:
- Understanding codebase structure
- Finding files by patterns
- Research without modification risk
- Three thoroughness levels: quick, medium, very thorough

**Plan**:
- Creating implementation plans
- Researching before coding
- Architecture decisions
- Used automatically during plan mode

**general-purpose**:
- Implementing features
- Making code changes
- Running tests
- Complex multi-step operations

**Bash**:
- Git operations
- Build/test commands
- Terminal-only workflows
- Inherits model from main conversation

### Permission Modes for Subagents

**[OFFICIAL]** (Source: https://code.claude.com/docs/en/iam)

Claude Code supports several permission modes that control how the agent handles permission prompts:

| Mode | Behavior | Use Case |
|:-----|:---------|:---------|
| **default** | Standard permission checking with prompts | Standard development workflow |
| **acceptEdits** | Auto-accept file edit permissions for the session | Trusted code editing |
| **dontAsk** | Auto-deny permission prompts (pre-approved tools still work) | Restricted environment |
| **bypassPermissions** | Skip all permission checks ⚠️ | Safe environments only, CI/CD |
| **plan** | Plan Mode - read-only exploration, no modifications | Safe analysis, planning phase |

**Warning**: Use `bypassPermissions` with caution. It skips all permission checks, allowing the subagent to execute any operation without approval.

Permission rules are evaluated in order: **deny → ask → allow**. The first matching rule wins, so deny rules always take precedence.

**Tool-Specific Permission Rules**:

*Bash with wildcards*:
- `Bash(npm run build)` - exact match
- `Bash(npm run test *)` - commands starting with prefix
- `Bash(* install)` - commands ending with suffix
- `Bash(git * main)` - pattern matching anywhere

*Read & Edit with gitignore patterns*:
- `//path` - absolute path from filesystem root
- `~/path` - path from home directory
- `/path` - path relative to settings file
- `path` or `./path` - path relative to current directory

*MCP tools*:
- `mcp__puppeteer` - any tool from puppeteer server
- `mcp__puppeteer__*` - wildcard for all tools from server
- `mcp__puppeteer__puppeteer_navigate` - specific tool

*Subagent control*:
- `Task(Explore)` - allows Explore subagent
- `Task(Plan)` - allows Plan subagent
- Add to `deny` array to disable specific agents

---

## Agents Component (Bundled Skills and Persistent Persona)

**[OFFICIAL]** + **[FINDING]**

### Concept Overview

Agents are specialized workers with a **persistent persona** and a **bundled skills manifest**. Unlike skills that are invoked on-demand, agents maintain consistent identity and capabilities across every spawn.

**When to use agents**:
- You need a **consistent multi-skill worker** that behaves the same every time
- You want to avoid skill discovery overhead in high-frequency spawns
- You need an **explicit manifest** of capabilities (for auditability)
- You want a **composable building block** for complex workflows

**The `skills:` field** is the defining feature of agents. It pre-loads skill content at spawn time, making all bundled skills available immediately without needing to invoke them as separate calls.

### File Layout

**[OFFICIAL]** (Source: https://code.claude.com/docs/en/sub-agents)

```
.claude/agents/
└── builder.md
```

Agents live in `.claude/agents/` as single `.md` files (not folders like skills).

### Agent Frontmatter

```yaml
---
name: builder
description: "Specialized worker with skill-development, rule-expertise, and context-engineering capabilities."
skills:
  - skill-development
  - rule-expertise
  - context-engineering
  - quality-standards
---

You are a build specialist focused on creating .claude/ components.

## Your Capabilities
You have bundled access to:
- **skill-development**: Skill authoring patterns
- **rule-expertise**: Instruction writing
- **context-engineering**: Filesystem management
- **quality-standards**: Validation patterns

Use these capabilities directly.
```

### The skills: Field

**[OFFICIAL]** (Source: https://code.claude.com/docs/en/sub-agents)

The `skills:` field is an official agent feature. It provides:

| Aspect | `skills:` (declarative) | `Skill()` call (imperative) |
|:--------|:------------------------|:---------------------------|
| **Discovery** | Claude knows upfront | Must recognize need |
| **Consistency** | Same skills every spawn | Ad-hoc decision |
| **Documentation** | Explicit manifest | Implicit, scattered |
| **Overhead** | ~100 tokens (metadata) | ~50 tokens (call) |

**What the `skills:` field does**:
- Pre-loads skill content at agent spawn
- All skills available from start
- No need to invoke as separate skills—use directly
- Explicit manifest of capabilities

### Agent vs Worker Skill

| Aspect | Agent | Worker Skill |
|:-------|:-------|:-------------|
| **File Location** | `.claude/agents/agent.md` | `.claude/skills/worker/SKILL.md` |
| `skills:` field | Yes | No (not supported) |
| **Identity** | Persistent persona | Ephemeral function |
| **Best for** | Consistent multi-skill workers | Isolated one-off tasks |
| `context: fork` | Not applicable | Often used |

| Need | Use | Why |
|:-----|:----|:-----|
| Same skills every time | Loadout Agent | Consistent manifest |
| Isolated validation | Worker Skill | Clean context |
| Multi-skill workflow | Loadout Agent | Bundled capabilities |
| One-off task | Worker Skill | Task-specific |

### Template: Agent

```yaml
---
name: [agent-name]
description: "[What the agent does]. Use when [when this agent is needed]. Not for [other use cases]."
skills:
  - [skill-a]
  - [skill-b]
  - [skill-c]
---

# [Agent Name]

You are a [specialist role] with bundled capabilities.

## Your Capabilities

You have pre-loaded access to these skills:

- **[skill-a]**: [what it provides]
- **[skill-b]**: [what it provides]
- **[skill-c]**: [what it provides]

**Important**: These capabilities are pre-loaded into your context. Use them directly—do not invoke them as separate skills.

## Your Role

[Specific instructions for the agent's role and purpose]

## Workflow

[Step-by-step process the agent follows]

## Quality Standards

[What quality means for this agent's output]

## What You Cannot Do

- ❌ [Specific restriction]
- ❌ [Another restriction]

## What You Must Do

- ✅ [Required action]
- ✅ [Another required action]

<critical_constraint>
Remember: You have bundled capabilities. Use them directly—do not invoke them as separate skills.
</critical_constraint>
```

### Complete Example: Builder Agent

**File Structure**:
```
.claude/agents/
└── builder.md
```

**Complete Agent File** (excerpt):

```markdown
---
name: builder
description: "Specialized worker for creating .claude/ components with full toolkit capabilities. Use when creating skills, commands, or agents. Not for general development tasks."
skills:
  - skill-development
  - rule-expertise
  - context-engineering
  - quality-standards
---

# Builder Agent

You are a build specialist focused on creating `.claude/` components.

## Your Capabilities

You have bundled access to these skills:

### skill-development
Skill authoring patterns, frontmatter requirements, and naming conventions.

### rule-expertise
Instruction writing, voice and tone, and degrees of freedom.

### context-engineering
Filesystem management, file operations, and directory structure.

### quality-standards
Validation patterns, component checklists, and Delta Standard.

**Important**: These capabilities are pre-loaded into your context. Use them directly—do not invoke them as separate skills.

## Your Role

When tasked with creating a component:

1. **Analyze the request**
   - What component type? (skill, command, agent)
   - What is the purpose?
   - What should it do?

2. **Design the structure**
   - Use skill-development for patterns
   - Use context-engineering for file operations

3. **Write the content**
   - Use rule-expertise for instructions
   - Follow quality-standards for validation

4. **Validate quality**
   - Run through quality checklist
   - Ensure portability
   - Verify naming conventions

## Component Creation Workflow `[OFFICIAL]`

### For a Skill

1. Create directory: `.claude/skills/skill-name/`
2. Create SKILL.md with:
   - name: gerund form, lowercase
   - description: non-spoiling, "Use when", "Not for"
   - Body: core knowledge only
3. Create supporting files if needed:
   - references/ (only for >1000 lines)
   - scripts/ (only for utilities)
4. Validate against quality checklist

### For a Command

1. Create directory: `.claude/commands/path/to/`
2. Create command.md with:
   - description: what it does
   - argument-hint: if applicable
   - Body: command logic
3. Validate naming (folder path → colon syntax)

### For an Agent

1. Create file: `.claude/agents/agent-name.md`
2. Add frontmatter:
   - name: agent identifier
   - description: purpose
   - skills: [] bundle of skills
3. Write body: agent persona and instructions
4. Validate skills: field usage

## Quality Standards `[OFFICIAL]`

Every component you create must pass:

### Frontmatter Check
- [ ] `name` present and valid
- [ ] `description` present, non-spoiling
- [ ] `description` includes "Use when"
- [ ] `description` includes "Not for"

### Naming Check
- [ ] Gerund form (skills/commands)
- [ ] Lowercase, hyphens only
- [ ] Not reserved words
- [ ] Not vague names

### Content Check
- [ ] Core knowledge in main file
- [ ] No time-sensitive info
- [ ] Fully qualified MCP names
- [ ] Delta Standard applied

## What You Cannot Do

- ❌ Create components outside `.claude/` (not your role)
- ❌ Modify existing components without explicit request
- ❌ Create vague or helper-style names
- ❌ Skip quality validation

## What You Must Do

- ✅ Use your bundled capabilities directly
- ✅ Follow all quality standards
- ✅ Create portable components
- ✅ Validate before completing

---

## Breakdown and Explanation `[OFFICIAL]`

### The skills: Field

```yaml
---
skills:
  - skill-development
  - rule-expertise
  - context-engineering
  - quality-standards
---
```

**Benefits**:

| Benefit | Explanation |
|:--------|:-------------|
| **Consistency** | Same skills every spawn |
| **Discovery** | Claude knows capabilities upfront |
| **Documentation** | Explicit manifest |
| **No overhead** | Content loaded once at spawn |

### Body Content

The body defines the agent's persona and how to use its capabilities. It includes:

- **Your Capabilities**: List of bundled skills with descriptions
- **Your Role**: Specific instructions for the agent's purpose
- **Workflow**: Step-by-step process the agent follows
- **Quality Standards**: What quality means for this agent
- **What You Cannot Do**: Clear restrictions
- **What You Must Do**: Required actions
- **critical_constraint**: Reminder about bundled capabilities

---

### skills: Field vs Skill() Invocation

| Aspect | `skills:` (declarative) | `Skill()` (imperative) |
|:--------|:-----------------------|:----------------------|
| **When loaded** | At agent spawn | When called |
| **Discovery** | Claude knows upfront | Claude must recognize need |
| **Consistency** | Same every time | Ad-hoc, may vary |
| **Token cost** | ~100 tokens (metadata) | ~50 tokens per call |
| **Use when** | Consistent worker needed | Dynamic, conditional use |

### Spawning a Loadout Agent

**Via Command**:
```bash
claude --agent builder --task "Create a skill for processing PDFs"
```

**Via Task Delegation**:
```markdown
# From main agent
Task("Create a skill for processing PDFs", agent="builder")
```

**What Happens**:
1. New agent spawned with `builder` persona
2. All skills in `skills:` field loaded
3. Agent has full capabilities from start
4. Task executed with bundled knowledge
5. Results returned to main context

### Composition Pattern: Skill + Agent

A skill can use a loadout agent for its execution:

```yaml
# skills/create-component/SKILL.md
---
name: create-component
context: fork
agent: builder  # Uses the builder loadout agent
---

# Creating a Component

Follow the builder workflow:
1. Analyze request
2. Create structure
3. Write content
4. Validate quality
```

**Flow**:
```
Main → Skill(create-component)
     → Spawns builder agent (has skills: field)
         → Subagent inherits: builder body + bundled skills
         → Creates component
     → Returns result to Main
```

### Multiple Loadout Agents

You can define multiple agents for different purposes:

```
.claude/agents/
├── builder.md      # skills: [skill-development, rule-expertise, ...]
├── auditor.md      # skills: [quality-standards, skill-auditor, ...]
└── researcher.md   # skills: [discovery, analysis, ...]
```

Each agent has:
- Unique persona (body content)
- Different skill bundle
- Specific purpose

### Decision Matrix

| Need | Use | Why |
|:-----|:----|:-----|
| Consistent multi-skill worker | Loadout Agent | Bundled capabilities |
| Isolated one-off task | Worker Skill | Clean context |
| Task + capabilities | Composition Pattern | Workflow + bundle |

### Platform-Specific Features

**[OFFICIAL]** (Sources: https://code.claude.com/docs/en/sub-agents | https://opencode.ai/docs)

The `skills:` field is unique to Claude Code and not part of the Agent Skills standard. When designing for cross-platform compatibility, understand which features are implementation-specific.

**Claude Code: `skills:` Field (Exclusive)**

The `skills:` field enables "loadout agents" with pre-bundled capabilities:

**Behavior:**
- Pre-loads skill content at agent spawn
- All bundled skills available immediately
- No separate skill() calls needed
- Creates consistent multi-skill workers

**OpenCode: Agent Modes**

OpenCode uses a different approach with `mode: primary/subagent` distinction:

| Mode | Purpose | Switching |
|:-----|:--------|:----------|
| **Primary** | Main agent types (Build, Plan) | Tab key cycles between them |
| **Subagent** | Task-specific workers | Spawned via `@agent-name` |

**Notable differences:**
- ❌ No `skills:` field support
- ❌ No `context: fork` (uses `mode: subagent`)
- ✅ Temperature and step limits per agent
- ✅ Explicit permission modes (`ask/allow/deny`)

**Cross-Platform Considerations**:

When building agents for multiple platforms:
1. **Claude Code agents** use `skills:` field for bundling
2. **OpenCode agents** use explicit invocation and configuration
3. **Standard agents** don't exist (agents are implementation-specific)

---

## Relationship: Tasks ↔ Agents

**[OFFICIAL]** + **[FINDING]**

### How Agents Use Tasks

**[OFFICIAL]** (Source: https://code.claude.com/docs/en/sub-agents)

**Task → Skill allowed**: Subagents can invoke inline skills
```
Task → Skill(skill)  → Allowed, subagent invokes inline skill
```

**Task → Task forbidden**: Subagents cannot spawn other subagents
```
Task → Task(subagent) → FORBIDDEN (recursion blocker)
```

### Forked Context Patterns

**[FINDING]** (Empirical finding): `Skill(context: fork)` with `agent:` field spawns a subagent with the skill content as task.

The skill determines:
- The task instructions (from SKILL.md body)

The agent determines:
- Execution environment (model, tools, permissions)

**This enables**:
- Chained forked skills without violating recursion blocker
- Multi-phase workflows with isolated contexts
- Unbiased validation through specialist subagents

### Heavy Lifting Delegation

**When to delegate to Tasks**:

| Goal | Primitive | Why |
|:-----|:----------|:-----|
| **High-Volume Edits** | `Task(subagent)` | Keeps context clean for high-level thoughts |
| **Read-Only Research** | `Task(Plan)` or `Task(Explore)` | Safe codebase analysis without modification risk |
| **Isolated Work** | `Task(subagent)` | Fresh context prevents contamination |

**When to delegate to Agents**:

| Need | Component | Why |
|:-----|:----------|:-----|
| Consistent multi-skill worker | Loadout Agent | Bundled capabilities, manifest |
| Specific expertise + task | Skill + Agent | Workflow specialization |
| Repeated workflow | Agent | Persistent persona |

### Composition Patterns

**Pattern 1: Main → Agent (with bundled skills)**
```
Main → Task("...", agent="builder")
     → Spawns builder with skills: [skill-development, rule-expertise, ...]
     → Agent has full capabilities from start
```

**Pattern 2: Main → Skill(context: fork, agent: Explore)**
```
Main → Skill(explorer, context: fork, agent: Explore)
     → Spawns Explore subagent with skill task
     → Fast, read-only exploration
```

**Pattern 3: Manager Pattern (FINDING)**
```
Task(work) → Skill(auditor, context: fork) [inline isolation]
          → Returns unbiased result
          → Retry if needed
```

This isolates validation from implementation without recursion.

---

## Related Documents

- **[00-foundation.md](./00-foundation.md)** - Context topology overview, primitives philosophy
- **[01-skills-context.md](./01-skills-context.md)** - Shared-context primitives (Skill, Command)
- **[03-others.md](./03-others.md)** - Event-driven security (hooks) and external capabilities (MCP)
- **[04-practices.md](./04-practices.md)** - Verification, quality gates, lifecycle workflows
- **[05-reference.md](./05-reference.md)** - Quick lookup tables, terminology, decisions

---

**Document Status**: Ready for review
**Next**: Implement 03-others.md (Hooks + MCP components)
