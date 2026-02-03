# CLAUDE.md

> **Verification Method**: Documentation sections use ONLY `mcp__simplewebfetch__simpleWebFetch` tool to navigate official documentation.
>
> **Sources**:
> - Claude Code: https://code.claude.com/docs
> - Platform Best Practices: https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices
>
> **Verification Legend**: `✓ VERIFIED` = Confirmed against official docs with source URL

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## The SAV Directory

**SAV = Self-Contained Archive and Verification**

This directory is the **knowledge preservation system** for the thecattoolkit_v3 project. It contains a complete, self-contained documentation system that can recreate the entire toolkit from scratch.

### Purpose

- Complete knowledge base for AI agent instruction projects
- Self-contained (no external dependencies except official Claude Code docs)
- Pattern library with proven implementations
- Can be copied to any new project and work standalone

### Key Documents

| File | Purpose |
|------|---------|
| `00-foundation.md` | Philosophy, patterns, ecosystem, primitives overview - start here for first principles |
| `01-skills-context.md` | Skill primitive + Commands component (context-based: shared memory, @/! injection) |
| `02-subagents.md` | Task primitive + Agents component (forked-context: subagents, heavy lifting) |
| `03-others.md` | Hooks + MCP components (event-driven security, external capabilities) |
| `04-practices.md` | Workflows, quality gates, writing guidelines, anti-patterns (how-to across lifecycle) |
| `05-reference.md` | Quick lookup tables, key terms, decisions, findings (reference material) |
| `REORG_SPEC.md` | Migration specification and execution plan for this reorganization |

### Core Philosophy: Autonomy-First (2026)

**Paradigm shift from 2024 → 2026:**

| Old Way (2024) | New Way (2026) |
|----------------|----------------|
| Carefully constrain agents | Trust agents by default |
| List forbidden actions | State objectives and alternatives |
| Rigid step-by-step scripts | Autonomous decision-making |
| Magic syntax/formatting | Natural language |
| Micromanage operations | Reactive constraints only |

**Key insight:** Over-constraining agents causes more failures than under-constraining. Modern models follow instructions precisely without micromanagement.

### Quick Reference Patterns

**Context Topology Primitives:**

| Primitive | Memory Mode | Best For |
|-----------|-------------|----------|
| Skill (Default) | Shared | Heuristics, code standards |
| Skill (frontmatter with context: fork) | Isolated | Specialists (Linter, Auditor) |
| Task (Subagent) | Forked | Heavy lifting (refactoring, tests) |
| Command | Injected | Entry points, workflows |

**Multi-Phase Delegation:** (⚠ CUSTOM pattern, uses official features)
- Subagent constraint: `Task → Task` forbidden (true subagent nesting)
- **⚠ CUSTOM** (Empirical finding): `Skill(context: fork)` runs inline with context isolation—does not spawn subagents, allowing chained forked skills
- Use single Task with inline skills OR chained forked skills for multi-phase workflows
- Enables unbiased validation through isolated contexts

**Delta Standard:**
```
Good Component = Expert Knowledge - What Claude Already Knows
```

Keep: best practices, modern conventions, project-specific decisions, domain expertise
Remove: basic concepts, standard library docs, generic tutorials, Claude-obvious operations

The `sav/` directory is the core intellectual property - the accumulated knowledge from 33+ production skills and 2026 research findings.

---

## Reading Flow

**New to the project? Start here:**

```
START HERE
    ↓
00-foundation.md (first principles, what exists, how to think, why)
    ↓
    ├─→ 01-skills-context.md (if building context-based components)
    ├─→ 02-subagents.md (if building forked-context components)
    └─→ 03-others.md (if using hooks or MCP)
    ↓
04-practices.md (how to design, create, verify, maintain)
    ↓
05-reference.md (lookup when needed)
```

**Need something specific? Jump directly:**
- Understanding context modes → 00-foundation.md → Primitives Overview
- Building a Skill → 01-skills-context.md → Skill Primitive
- Creating a Command → 01-skills-context.md → Commands Component
- Using subagents → 02-subagents.md → Task Primitive
- Quality verification → 04-practices.md → Verify Phase

---

## Content Attribution

Documentation uses inline badges to indicate source:
- `[OFFICIAL]` - Ground truth from Claude Code official documentation
- `[COMMUNITY]` - Best practices from community/Platform docs
- `[FINDING]` - Personal research findings and empirical discoveries

---

## Migration Status

**Completed**: Migration from 17-file structure to 6-file consolidated structure (2026-02-01).

Old files archived in `archive/old-structure/`. See `REORG_SPEC.md` for migration specification.
