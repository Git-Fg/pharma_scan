---
description: "Extract component candidates (Skill, Command, ADR) from conversation when identifying automatable logic worth documenting. Keywords: extract, skill, command, candidate, automatable, decision, adr, architecture. Not for creating components directly, non-automatable logic, or trivial extractions."
argument-hint: "[<logic-description>]"
allowed-tools: AskUserQuestion
---

<mission_control>
<objective>Identify automatable logic or architectural decisions for component creation</objective>
<success_criteria>Component candidate specified with type, rationale, and structure</success_criteria>
</mission_control>

## Quick Start

Use this command when:
- Automatable logic needs extraction for component creation
- Architectural decision needs formal documentation (ADR)
- Complex logic could be encapsulated as Skill or Command

## Context

<injected_content>
Recent Changes: !`git log --oneline -5`
Current Rules: @CLAUDE.md
</injected_content>

## Execution

### Detect

Analyze `$ARGUMENTS` and conversational memory for extraction target:

- **Skill**: Complex automatable logic, high freedom, injects knowledge
- **Command**: Automatable logic, low freedom, fixed output, uses @/!
- **Decision**: Architectural choice worth documenting as ADR

Use `AskUserQuestion` if type is unclear.

### Execute

**1. Analyze**: Trust your conversational memory to identify:
- Complex automatable patterns
- Repeated command sequences
- Architectural decisions with rationale

**2. Decide**: Component type based on criteria:
- **Skill** = High freedom, injects domain knowledge, reusable
- **Command** = Low freedom, fixed inputs/output, delegates to Skills
- **ADR** = Architectural decision with alternatives and consequences

**3. Report**: Present candidate with:
- Name (gerund form for commands: "building", "auditing")
- Description (What-When-Not-Includes format)
- Core structure/template
- Rationale for component type choice

## Templates

### Skill Candidate

<injected_content>
## Skill: [name]

**Description**: What it does. When to use it. What it excludes (in third person).

**Core Sections:**
- Quick Start (when/how to invoke)
- Context injection (@file, !command)
- Core knowledge/procedure
- Critical constraints footer
</injected_content>

### Command Candidate

<injected_content>
## Command: [namespace/]name

**Description**: What it does. When to use it. What it excludes (in third person).

**Structure:**
- Single markdown file
- Frontmatter: description, argument-hint, allowed-tools
- Uses @ for file content, ! for bash output
- Delegates to Skills, never other commands
</injected_content>

### ADR Template

<injected_content>
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
</injected_content>

<critical_constraint>
MANDATORY: Trust conversational memory, only read session files if context unclear
MANDATORY: Distinguish Skill (high freedom, knowledge injection) from Command (low freedom, fixed output)
MANDATORY: Commands delegate to Skills, never to other commands
MANDATORY: Use What-When-Not-Includes format for descriptions
MANDATORY: Use gerund form for command names (e.g., "building", not "build")
No exceptions. Extract identifies candidates, it does not create components.
</critical_constraint>
