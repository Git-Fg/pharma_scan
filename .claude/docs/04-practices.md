---
number: 04
title: Practices
audience: self-maintenance
related: [00, 01, 02, 03, 05]
last-reviewed: 2026-02-01
---

# 04 - Practices

**Table of Contents**
- [Design Phase](#design-phase)
  - [Requirements Gathering](#requirements-gathering)
  - [Implementation Planning](#implementation-planning)
- [Create Phase](#create-phase)
  - [Creation Workflows](#creation-workflows)
  - [Writing Guidelines](#writing-guidelines)
  - [Component Quality](#component-quality)
  - [Delta Standard](#delta-standard)
- [Verify Phase](#verify-phase)
  - [Six-Phase Quality Gates](#six-phase-quality-gates)
  - [Verification Workflow](#verification-workflow)
  - [Review Framework](#review-framework)
  - [Common Mistakes](#common-mistakes)
- [Maintain Phase](#maintain-phase)
  - [Session Handoff](#session-handoff)
  - [Evolution Practices](#evolution-practices)
  - [Autonomous Correction](#autonomous-correction)

---

## Design Phase

### Requirements Gathering

**[FINDING] Discovery Workflow**

Gather requirements and clarify vague ideas through structured interviews.

**Purpose**: Transform vague ideas into detailed specifications through systematic exploration.

**Workflow**:
```
1. User invokes /discovery
2. Discovery skill conducts structured interview
3. Explores: scope, requirements, constraints, success criteria, stakeholders
4. Creates detailed specification
5. Saves to project docs
```

**Discovery Interview Topics**:

| Topic | Questions |
|:------|:----------|
| **Scope** | What are we building? What's out of scope? |
| **Requirements** | What must it do? What should it do? |
| **Constraints** | Technical constraints? Time constraints? |
| **Success Criteria** | How do we know it's done? |
| **Stakeholders** | Who will use this? Who reviews it? |

**Implementation**:
- **Entrypoint**: `/discovery`
- **Output**: Detailed specification document
- **Key**: Structured interview → specification → ready for planning

---

### Implementation Planning

**[FINDING] Planning Workflow**

Create structured implementation plans with dependency graphs.

**Purpose**: Break down complex work into phases with clear dependencies.

**Workflow**:
```
1. User invokes /strategy:architect
2. Architect researches codebase
3. Creates STRATEGY.md with phases and dependency graph
4. User invokes /strategy:execute
5. Execute runs phases with parallel Task() batching
6. TodoWrite tracks phase-level progress
```

**Strategy Document Structure**:
```markdown
# STRATEGY.md: [Feature Name]

## Phases

### Phase 1: Foundation
**Depends on**: None
**Parallelizable**: No
- Create base structure
- Set up configuration

### Phase 2: Implementation
**Depends on**: Phase 1
**Parallelizable**: Yes
- Component A (can run in parallel)
- Component B (can run in parallel)
```

**Implementation**:
- **Create strategy**: `/strategy:architect`
- **Execute strategy**: `/strategy:execute`
- **Verify phase**: `/qa:verify-phase` (Gatekeeper between phases)

**Key**: Dependency graphs enable parallel execution while maintaining correct ordering.

---

## Create Phase

### Creation Workflows

**[FINDING] Component Creation Workflow**

Create new skills, commands, or agents with automatic quality validation.

**Purpose**: Generate components with built-in quality gates through Manager Pattern.

**Workflow**:
```
1. User invokes /factory or Skill(skill-manager)
2. Manager analyzes request (component type, name, purpose)
3. Manager spawns Task to create component
4. Forked auditor (quality-standards, context: fork) validates
5. If fails: Manager retries creation with fixes
6. If passes: Component returned to user
```

**Implementation**:
```yaml
Entrypoint: /factory <component-type> <name>

Behind the scenes:
Main → Skill(skill-manager)
       → Task(create-component)
       → Skill(quality-standards, context: fork)
         → Returns: Pass/Fail + issues
       → If Fail: Retry Task(create-component)
       → If Pass: Return to Main
```

**What Gets Created**:

**For a skill**:
```
.claude/skills/processing-pdfs/
├── SKILL.md              # With proper frontmatter and template
└── scripts/              # Empty directory
```

**For a command**:
```
.claude/commands/meta/refine/
└── documentation.md      # With description frontmatter
```

**For an agent**:
```
.claude/agents/
└── builder.md            # With skills: field
```

**Key**: Manager Pattern ensures quality validation before delivery.

---

**[FINDING] Liaison Pattern (Human-Negotiator Commands)**

Commands that clarify ambiguous user intent before routing to appropriate handler.

**Purpose**: Commands that need to clarify before delegating cannot auto-invoke skills.

**Implementation**:
```markdown
---
description: "Clarify intent and delegate to appropriate engine. Use when user intent is ambiguous. Not for clear intents."
disable-model-invocation: true
---

<mission_control>
<objective>Clarify ambiguous intent and route to appropriate handler</objective>
<success_criteria>User intent clarified and routed to correct engine</success_criteria>
</mission_control>

## Clarification
[AskUserQuestion to determine user intent]

## Execution
[Based on answer, invoke appropriate Skill]
```

**When to Use**:

| Pattern | Command Behavior |
|:--------|:-----------------|
| **Liaison Work** | Use AskUserQuestion to clarify ambiguous intent |
| **Delegation** | Once clarified, invoke the appropriate Skill |

**Key**: `disable-model-invocation: true` forces clarification before delegation.

---

### Writing Guidelines

**[COMMUNITY] Natural Language Over Syntax**

**Principle**: Talk to Claude like a senior engineer, not a tool.

Clear, direct, natural language beats magic syntax and rigid formatting.

**Examples**:

| ❌ Bad | ✅ Good |
|:-------|:-------|
| "Execute the following procedure with precision:" | "Create a new skill for processing PDFs" |
| "Commence initialization sequence:" | "Set up the project structure" |
| "Utilize the aforementioned mechanism:" | "Use this pattern when..." |

**Why Natural Language Works**:

Modern language models (Claude 4+) are trained on natural language. They understand:
- Conversational patterns
- Context and nuance
- Professional communication

Magic syntax and rigid formatting add unnecessary complexity.

**Key**: Natural language reduces cognitive friction and enables contextual adaptation.

---

**[FINDING] The Power of Simplicity**

Sometimes the most effective instructions are the simplest ones. Natural language commands often outperform complex structured templates for discovery and exploratory tasks.

**Why Simple Works**:

**Dynamic Adaptation Over Static Templates**

Rigid commands with branching logic force predetermined paths. Simple natural language adapts organically:

```
Complex Approach (200 lines):
- IF user mentions web THEN ask about framework
- IF user mentions database THEN ask about schema
- ELSE ask general questions
- Branch based on each answer...

Simple Approach (22 lines):
"Interview the user about their project. Use AskUserQuestion to ask one question at a time, adapting based on their answers. Focus on uncovering constraints and requirements."
```

**Example: Interview Command (reviewer-v2)**

A real example demonstrates the power of simplicity in just 22 lines:

```yaml
---
argument-hint: [instructions]
description: Interview user in-depth to create a detailed spec. Use when requirements are unclear. Not for tasks with rigid output formats.
allowed-tools: AskUserQuestion, Write, Read, Glob
---

Instructions: $ARGUMENTS

Follow user's instructions and use AskUserQuestionTool to interview him in depth so you can later write a complete specification document and save it to a file.

When you ask questions with AskUserQuestionTool:
- Always ask exactly one question at a time
- Offer clear, meaningful answer choices plus "Something else" option
- Design options to help orient the user, not constrain them
- Never ask questions you could answer yourself by using fetch or reading files
- Include meaningful examples when propositions are too abstract

Continue this one-question-at-a-time process until you have enough detail to write a thorough specification.
```

**Why this works**:
- No predetermined question sequences - adapts organically
- Built-in AskUserQuestion tool handles interaction complexity
- 22 lines accomplish what 200-line scripted commands attempt

**Key**: Tool-provided structure eliminates need for complex conditional logic.

---

**[COMMUNITY] Positive Constraints**

**Principle**: "Do this" not "Don't do that."

For every constraint, provide the alternative approach. Negative-only instructions leave agents stuck without knowing what to do instead.

**Examples**:

| ❌ Bad (Negative Only) | ✅ Good (Positive Alternative) |
|:-----------------------|:-------------------------------|
| "Don't use vague names" | "Use gerund form: `processing-pdfs`, `analyzing-data`" |
| "Don't micromanage" | "Give objectives and success criteria" |
| "Don't hide info in references/" | "Put everything helpful in SKILL.md" |
| "Don't spoil descriptions" | "Descriptions should state what/when/not, not how" |

**Why This Works**:

**The Psychology of Positive Framing**

1. **Activation vs. Suppression**: The brain processes "do this" (activation) more efficiently than "don't do that" (suppression)
2. **Decision Paralysis**: Negative-only constraints leave agents without a path forward
3. **Cognitive Load**: Positive alternatives reduce cognitive load by providing a ready-made solution

**When Negative Constraints Are Okay**:

| Situation | Why It Works | Always Provide Alternative |
|:----------|:-------------|:---------------------------|
| **Safety-critical** | Irreversible actions need clear prohibition | "Use 'trash' instead of rm -rf" |
| **Legal/compliance** | Non-negotiable restrictions | Reference the compliant alternative |
| **Hard boundaries** | Fundamental limits | Explain why and what to do instead |

**Pattern**:
```markdown
❌ Bad:
## Constraints
- Don't use X
- Avoid Y
- Never Z

✅ Good:
## Guidelines
- Use A instead of X
- Prefer B for Y
- Use C when Z would be problematic
```

**Key**: Always provide positive alternatives for every negative constraint.

---

**[COMMUNITY] Scope Boundaries (What-When-Not)**

Every description should clearly define:
1. **What** it does
2. **When** to use it (trigger conditions)
3. **Not** what it's for (exclusions)

**Description Template**:
```yaml
---
description: "[What it does]. Use when [trigger conditions + keywords]. Not for [exclusions]."
---
```

**Examples**:

| Poor Description | Good Description |
|:-----------------|:----------------|
| "This skill helps you with skills" | "Creates portable skills with quality validation. Use when creating skills or validating components. Not for code linting or type checking." |
| "A tool for processing files" | "Extracts text from PDF files. Use when working with PDF documents or need text extraction. Not for image-based PDFs (use OCR tools)." |

**Why This Works**:

| Element | Purpose |
|:--------|:---------|
| **What** | Clear statement of function |
| **When** | Trigger conditions + keywords for auto-invocation |
| **Not** | Exclusions prevent misuse |

**Key**: What-When-Not pattern prevents over-eager skill invocation and enables precise matching.

---

**[COMMUNITY] Degrees of Freedom**

Match the level of specificity to the task's fragility and variability.

**The Principle**: Think of Claude as a robot exploring a path:
- **Narrow bridge with cliffs**: Only one safe way → Specific guardrails (low freedom)
- **Open field with no hazards**: Many paths to success → General direction (high freedom)

**Freedom Levels**:

**High Freedom** (text-based instructions):
Use when multiple approaches are valid, decisions depend on context.

```
## Code review process
1. Analyze the code structure and organization
2. Check for potential bugs or edge cases
3. Suggest improvements for readability and maintainability
4. Verify adherence to project conventions
```

**Medium Freedom** (pseudocode or scripts with parameters):
Use when a preferred pattern exists but some variation is acceptable.

```
## Generate report
Use this template and customize as needed:
def generate_report(data, format="markdown", include_charts=True):
    # Process data
    # Generate output in specified format
```

**Low Freedom** (specific scripts, few/no parameters):
Use when operations are fragile, consistency is critical.

```
## Database migration
Run exactly this script:
python scripts/migrate.py --verify --backup
Do not modify the command or add additional flags.
```

**When to Use Each**:

| Level | Use When | Examples |
|:------|:---------|:---------|
| **High** | Creative tasks, context-dependent | Code review, analysis, writing |
| **Medium** | Pattern with variations | Report generation, data processing |
| **Low** | Fragile/dangerous operations | Database migrations, deployment |

**Key**: Match freedom to task fragility—prevent dangerous mistakes and unnecessary constraints.

---

**[FINDING] Mission Control Structure**

**Pattern**:
```markdown
<mission_control>
<objective>[What to achieve]</objective>
<success_criteria>[How to know it's done]</success_criteria>
</mission_control>
```

**Examples**:

**Simple Mission**:
```markdown
<mission_control>
<objective>Create a portable skill for processing PDFs</objective>
<success_criteria>Skill extracts text from PDFs and saves to output file</success_criteria>
</mission_control>
```

**Complex Mission**:
```markdown
<mission_control>
<objective>Implement Chain of Experts pattern for multi-phase workflow</objective>
<success_criteria>
- Entry point orchestrates phases
- Each phase runs in isolated context
- Results cascade correctly
- Quality gates pass
</success_criteria>
</mission_control>
```

**Alternative Approaches**:

**a) XML Structure** (Best for complex tasks):
```markdown
<mission_control>
<objective>Implement Chain of Experts pattern</objective>
<success_criteria>
- Entry point orchestrates phases
- Each phase runs in isolated context
</success_criteria>
</mission_control>
```

**b) Natural Language Headings** (Best for readability):
```markdown
## Objective
Implement Chain of Experts pattern for multi-phase workflow.

## Success Criteria
- Entry point orchestrates phases
- Each phase runs in isolated context
```

**c) Bullet Point Format** (Best for quick tasks):
```markdown
**Goal**: Implement Chain of Experts pattern

**Done when**:
- Entry point orchestrates phases
- Each phase runs in isolated context
```

**Why This Matters**:

1. **Prevents Scope Creep**: Clear criteria define when to stop
2. **Enables Self-Verification**: Agents can check work against explicit criteria
3. **Improves Task Decomposition**: Breaking down objectives forces clarity

**Key**: Objective + success criteria = clear completion detection.

---

**[OFFICIAL] Verification Strategies**

**✓ VERIFIED** (Source: https://code.claude.com/docs/en/best-practices) - "Give Claude a way to verify its work" is the #1 official best practice.

**Build In Self-Checks**:

Every workflow should include verification steps:

```markdown
## Before Completing

- [ ] Read modified files
- [ ] Run diagnostics
- [ ] Test if applicable
- [ ] Review git diff
```

**Example: Quality Gate Workflow**:
```markdown
## Verification Checklist

### Frontmatter
- [ ] `name` present and valid
- [ ] `description` present, non-spoiling
- [ ] `description` includes "Use when"
- [ ] `description` includes "Not for"

### Content
- [ ] Core knowledge in SKILL.md
- [ ] No time-sensitive info
- [ ] Examples work
- [ ] No AI slop
```

**Why This Matters**:

1. **Prevents Silent Failures**: Without verification, agents may assume success when something failed
2. **Builds Confidence**: When agents verify work, they can report completion with certainty
3. **Catches Edge Cases**: Verification steps force consideration of "what could go wrong?"

**Key**: Verification is the #1 best practice—always build in self-checks.

---

**[FINDING] Voice and Tone**

**Imperative Form**:
```
✅ "Create the skill directory."
✅ "Validate inputs before processing."
✅ "Use the Manager Pattern for quality gates."

❌ "You should create the skill directory."
❌ "Let's create the skill directory."
❌ "I would recommend creating..."
```

**Voice Strength**:

| Strength | When to Use | Markers | Model Compatibility |
|:----------|:-----------|:--------|:-------------------|
| **Gentle** | Best practices | Consider, prefer, may | Claude 4.5 only |
| **Standard** | Default patterns | Create, use, follow | Claude 4.5 + strong models |
| **Strong** | Quality gates | Always, never, must | **All models (recommended)** |
| **Critical** | Security, safety | **MUST, ALWAYS, NEVER** | **Required for GLM-4.7/minimax** |

**Why Strong Voice is Necessary**:

While we trust AI intelligence for problem-solving, strong and critical voice compensates for specific behavioral patterns:

| Failure Mode | Without Strong Voice | With "you MUST" / "CRITICAL" |
|:-------------|:---------------------|:------------------------------|
| **Missing Skill Invocation** | Agent misses skill that would help | "Use Skill(processing-pdfs) when working with PDFs" |
| **Ignoring Reference Files** | Agent skips references/, missing context | "you MUST read references/ for complete API docs" |
| **Constraint Drift** | Agent ignores constraints over long sessions | "MANDATORY: Run security scan before deployment" |

**When to Escalate Voice Strength**:

1. **Skill Triggers**: Use strong voice for trigger conditions
2. **Reference Navigation**: Use imperative for when to read supporting files
3. **Quality Gates**: Use critical for standards that must be met
4. **Safety Boundaries**: Use critical for anything that could cause harm

**Key**: Strong imperative language enables autonomy—it doesn't restrict it.

---

**[FINDING] Complete Example: Low Freedom Task**

**Pattern**: Absolute requirements with positive practices + negative boundaries

Inspired by Claude's official xlsx skill—demonstrates proper strong language usage.

```markdown
## Requirements for Outputs

### Zero Formula Errors
- Every Excel model MUST be delivered with ZERO formula errors (#REF!, #DIV/0!, #VALUE!, #N/A, #NAME?)

### Preserve Existing Templates (when updating templates)
- Study and EXACTLY match existing format, style, and conventions when modifying files
- Never impose standardized formatting on files with established patterns
- Existing template conventions ALWAYS override these guidelines

## CRITICAL: Use Formulas, Not Hardcoded Values

**Always use Excel formulas instead of calculating values in Python and hardcoding them.**

### ❌ WRONG - Hardcoding Calculated Values
```python
# Bad: Calculating in Python and hardcoding result
total = df['Sales'].sum()
sheet['B10'] = total  # Hardcodes 5000
```

### ✅ CORRECT - Using Excel Formulas
```python
# Good: Let Excel calculate the sum
sheet['B10'] = '=SUM(B2:B9)'
```

This applies to ALL calculations—totals, percentages, ratios, differences.

### Number Formatting Standards
- **Currency**: Use $#,##0 format; ALWAYS specify units in headers ("Revenue ($mm)")
- **Zeros**: Use number formatting to make all zeros "-"
- **Percentages**: Default to 0.0% format (one decimal)
```

**Key Techniques**:
1. **Absolute Requirements**: Use MUST, ALWAYS, NEVER for non-negotiable constraints
2. **Positive Best Practices**: Lead with what TO do
3. **Negative Boundaries**: Include hard limits with context
4. **❌/✅ Examples**: Show concrete wrong vs right implementations

---

**[FINDING] High Freedom Task Example**

**Pattern**: High-level objectives with absolute imperative constraints

Even creative, high-freedom tasks need strong imperative language for critical requirements.

```markdown
# Agent SDK Application Setup

## Overview
You are tasked with helping the user create a new Claude Agent SDK application. This is a creative task—design the architecture, choose patterns, implement features—but you MUST follow critical requirements for safety and quality.

## Critical Requirements (Non-Negotiable)

### Always Use Latest Versions
**CRITICAL**: Before installing ANY packages, you MUST:
1. Use WebSearch or WebFetch to verify the latest stable version
2. Check official package repositories (npm/PyPI)
3. Inform the user which version you're installing
4. NEVER install outdated versions without explicit user consent

### Code Verification Before Completion
**MANDATORY**: You MUST verify the code works before finishing:
- Run `npx tsc --noEmit` to check for type errors
- Fix ALL type errors until types pass completely
- **DO NOT consider the setup complete until type checking passes**

### Ask Questions One at a Time
**IMPORTANT**: When gathering requirements, you MUST:
- Ask questions ONE AT A TIME
- Wait for the user's response before asking the next question

## Implementation Guidelines (Creative Freedom)

You have creative freedom to:
- Design the project structure
- Choose architectural patterns
- Implement features based on user needs

**BUT you MUST follow the Critical Requirements above.**
```

**Key Techniques**:
1. **Separate Critical from Creative**: Critical Requirements (MUST) vs Implementation (freedom)
2. **Explain Why**: Every MUST has a "Why this matters" explanation
3. **Creative Sections Use Suggestive Language**: "You have creative freedom to..."
4. **Strong Boundaries Enable Boldness**: Clear constraints enable confident creativity

---

**[COMMUNITY] DO/DON'T Pattern**

For technical reference skills, use explicit DO/DON'T lists:

```markdown
## Security Best Practices

**DO:**
- ✅ Use prompt-based hooks for complex logic
- ✅ Use ${CLAUDE_PLUGIN_ROOT} for portability
- ✅ Validate all inputs in command hooks
- ✅ Quote all bash variables
- ✅ Set appropriate timeouts

**DON'T:**
- ❌ Use hardcoded paths
- ❌ Trust user input without validation
- ❌ Create long-running hooks
- ❌ Log sensitive information
```

**Key Characteristics**:
1. **DO Section**: Lead with ✅, start with action verbs, be specific but not prescriptive
2. **DON'T Section**: Lead with ❌, state absolute prohibitions, pair with DO alternative
3. **Both Sections High-Level**: Not micromanaging, strong imperative language, freedom to implement within boundaries

---

### Component Quality

**[COMMUNITY] Component Quality Checklist**

**✓ VERIFIED** (Source: https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)

**Before Considering a Component Complete**:

#### Frontmatter
- [ ] **`name` present**: Max 64 chars, lowercase, hyphens only
- [ ] **`description` present**: Non-spoiling, includes "Use when"
- [ ] **`description` has "Not for" clause**: Exclusions specified

#### Naming
- [ ] **Gerund form**: `processing-pdfs`, not `pdf-processor`
- [ ] **Lowercase only**: No capital letters
- [ ] **Hyphens as separators**: No underscores
- [ ] **Not reserved words**: Avoid `anthropic`, `claude`
- [ ] **Not vague**: Avoid `helper`, `utils`, `worker`

#### Description Quality
- [ ] **Third person**: "Processes files" not "I will process"
- [ ] **Non-spoiling**: Doesn't reveal body content
- [ ] **Trigger conditions**: "Use when..." included
- [ ] **Keywords included**: Terms users might say
- [ ] **Exclusions clear**: "Not for..." clause present

#### Progressive Disclosure
- [ ] **Core in SKILL.md**: Main patterns and instructions
- [ ] **references/ used sparingly**: Only for >1000 lines or domain-specific
- [ ] **No nested references**: Max one level deep
- [ ] **scripts/ for execution**: Scripts run, not loaded as text

#### Content Quality
- [ ] **No time-sensitive info**: Use "Old patterns" section for deprecated
- [ ] **Fully qualified MCP names**: `ServerName:toolName` format
- [ ] **No forward slashes in Windows paths**: Use backslashes consistently
- [ ] **No AI slop**: Professional, concise, no unnecessary comments

#### Testing
- [ ] **Examples work**: All code examples are functional
- [ ] **Edge cases covered**: Common edge cases addressed
- [ ] **Error handling**: Appropriate error handling described

---

### Delta Standard

**[COMMUNITY] Delta Standard**

**✓ VERIFIED** (Source: https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)

**Definition**: **Good Component = Expert Knowledge − What Claude Already Knows**

**What to Keep (Positive Delta)**:

| Category | Examples |
|:---------|:---------|
| **Best practices** | "Use `context: fork` for auditors" |
| **Modern conventions** | "Use gerund form for skill names" |
| **Project decisions** | "We use Manager Pattern for skill creation" |
| **Domain expertise** | "TypeScript 5.3+ supports `satisfies` operator" |
| **Anti-patterns** | "Don't use inline auditors, they're biased" |

**What to Remove (Zero/Negative Delta)**:

| Category | Examples |
|:---------|:---------|
| **Basic programming** | How to write a for loop |
| **Standard library docs** | What `Array.map()` does |
| **Generic tutorials** | "What is a hook?" |
| **Claude-obvious** | "Use Read tool to read files" |

**Applying the Delta Standard**:

When creating content, ask yourself:
1. **Is this expert knowledge?** Would a senior developer already know this?
2. **Is this project-specific?** Would someone outside this project benefit from this?
3. **Is this non-obvious?** Would Claude already know this from its training?

**Guideline**: If yes to all three → Include. If no to any → Consider excluding.

**Why This Matters**:

Applying the Delta Standard helps you create components that are:
- **Focused** — Only the essential knowledge, nothing extraneous
- **Maintainable** — Less content means less to update when things change
- **Effective** — Claude can quickly find the information it needs
- **Professional** — Shows respect for the reader's time and intelligence

---

## Verify Phase

### Example: Six-Phase Quality Gates

**[FINDING] Quality Gate Workflow**

Run comprehensive validation on codebase changes.

**⚠ CUSTOM** — The `/quality:run-gates` command is a thecattoolkit_v3 implementation that automates this workflow.

**A Common Sequence** (for compiled languages with type systems and test suites):

```
BUILD → TYPE → LINT → TEST → SECURITY → DIFF
```

**Note**: Adapt this sequence based on your project type. For example:
- Dynamic languages: Skip TYPE
- Simple scripts: Skip BUILD
- Projects without tests: Focus on other verification
- Documentation: Manual review may be more appropriate

| Phase | Purpose | What It Helps Verify |
|:------|:--------|:---------------------|
| **BUILD** | Compile/transpile | Code compiles without errors |
| **TYPE** | Type checking | Type safety, no type errors |
| **LINT** | Linting and style | Code style, best practices |
| **TEST** | Test suite | All tests pass, coverage adequate |
| **SECURITY** | Security scanning | No vulnerabilities, sensitive data exposure |
| **DIFF** | Change review | What changed, unintended modifications |

**Phase Details**:

#### 1. BUILD

**Purpose**: Verify code compiles/transpiles successfully.

**Commands by Language**:
```bash
# TypeScript/JavaScript
npm run build
tsc

# Python
python -m compileall .

# Rust
cargo build

# Go
go build ./...
```

**What We Look For**:
- Code compiles without errors
- Build artifacts are created
- No missing dependencies

#### 2. TYPE

**Purpose**: Verify type safety through static analysis.

**Commands by Language**:
```bash
# TypeScript
tsc --noEmit

# Python (mypy)
mypy src/

# Go
go vet ./...
```

**What We Look For**:
- Zero type errors
- Proper type annotations throughout
- Avoiding `any` types (TypeScript) without good reason

#### 3. LINT

**Purpose**: Maintain consistent code style and catch potential issues.

**Commands by Language**:
```bash
# TypeScript/JavaScript
eslint . --max-warnings 0
prettier --check .

# Python
ruff check .
black --check .

# Rust
cargo clippy
```

**What We Look For**:
- No linting errors
- Consistent formatting across the codebase
- Adherence to best practices

#### 4. TEST

**Purpose**: Verify functionality and prevent regressions.

**Commands**:
```bash
# TypeScript/JavaScript
npm test

# Python
pytest

# Rust
cargo test

# Go
go test ./...
```

**What We Look For**:
- All tests pass
- Adequate coverage for critical paths
- No tests skipped without explanation

#### 5. SECURITY

**Purpose**: Identify potential security vulnerabilities.

**Commands**:
```bash
# npm
npm audit

# Python
pip-audit
safety check

# Rust
cargo audit

# General
# Scan for secrets, API keys, passwords
git log --all --full-history --source -- "**/SECRET*"
```

**What We Look For**:
- No high/critical vulnerabilities in dependencies
- No secrets or credentials committed
- No obviously insecure code patterns

#### 6. DIFF

**Purpose**: Review exactly what changed before finalizing.

**Commands**:
```bash
# Show what will be committed
git diff --cached

# Show all changes
git diff

# Show file-by-file summary
git diff --stat
```

**What We Look For**:
- Only intended files were modified
- No accidental changes or side effects
- Changes align with the original task

**Implementation**:

**Entrypoint**: `/quality:run-gates`
**Quick version**: `/quality:quick` (Skips SECURITY phase)
**Returns**: Structured summary with Pass/Fail per phase

**Output Format**:
```
Phase           Status   Details
─────────────────────────────────────────────
BUILD           ✅ PASS  Compiled in 2.3s
TYPE            ✅ PASS  No type errors
LINT            ❌ FAIL  3 files need formatting
TEST            ✅ PASS  All 42 tests passed
SECURITY        ⏭️  SKIP  Skipped in quick mode
DIFF            ✅ PASS  5 files changed
```

**Key**: Each phase serves a specific purpose in the development lifecycle.

---

### Verification Workflow

**[OFFICIAL] Verification Before Completion**

**✓ OFFICIAL** (Source: https://code.claude.com/docs/en/best-practices) - "Give Claude a way to verify its work" is the #1 official best practice.

**The Recommended Verification Loop**:
```
1. Read modified files
2. Run diagnostics
3. Test if applicable
4. Review git diff
5. If issues found → Fix → Repeat from 1
6. If clean → Mark complete
```

**Step 1: Read Modified Files**

**Purpose**: Confirm edits applied correctly.

```markdown
# After editing, verify:
- Changes are in correct locations
- No unintended modifications
- Formatting is preserved
```

**Why This Matters**: Reading back your changes catches misplaced edits, accidental deletions, and formatting issues.

**Step 2: Run Diagnostics**

**Purpose**: Check for type/lint errors.

**For TypeScript projects**:
```
Run: mcp__vscode-mcp-server__get_diagnostics_code

Check for:
- Type errors (severity 0)
- Warnings (severity 1)
- Fix issues as appropriate for your project
```

**Why This Matters**: Diagnostics catch issues that are easy to miss but can cause problems later.

**Step 3: Test If Applicable**

**Purpose**: Ensure functionality works.

```bash
# Run tests
npm test
pytest
cargo test

# Run specific test if working on a feature
npm test -- --testNamePattern="specific test"
```

**Why This Matters**: Tests verify that your changes work as expected and haven't broken existing functionality.

**Step 4: Review Git Diff**

**Purpose**: Confirm only intended changes.

```bash
# Review staged changes
git diff --cached

# Review unstaged changes
git diff

# Check file-by-file summary
git diff --stat
```

**What to look for**:
- Only intended files modified
- No whitespace-only changes
- No debug code left in
- Changes align with task

**Why This Matters**: The diff review is your final sanity check. It catches accidental edits and helps you understand the full scope of changes.

**Key**: Verification loop ensures quality before completion.

---

### Review Framework

**[COMMUNITY] Review Perspectives**

This optional framework helps you think about your work from multiple angles.

**Three Perspectives to Consider**:

| Perspective | Question to Ask |
|:------------|:----------------|
| **Request** | What did the user explicitly ask for? |
| **Delivery** | What was actually implemented? |
| **Standards** | What do our quality guidelines recommend? |

**Why This Matters**:

Taking a moment to review your work from these three perspectives helps catch:
- Misunderstandings about requirements
- Scope creep or missed requirements
- Gaps between what was requested and what was delivered
- Opportunities to improve quality before finalizing

**Issue Severity Guidelines**:

| Severity | Examples | Suggested Approach |
|:---------|:---------|:-------------------|
| **Critical** | Build fails, security vulnerability, data loss | Fix immediately before proceeding |
| **High** | Type errors, test failures, missing critical functionality | Strongly recommended to address |
| **Medium** | Style issues, documentation gaps | Consider fixing if time permits |
| **Low** | Cosmetic issues, suggestions, nice-to-haves | Optional improvements |

**Example Gap Analysis**:
```
Request: "Add user authentication"
Delivery: Implemented OAuth2 login with JWT tokens
Standards: Follows our quality workflow guidelines

Gap Analysis:
- [Critical] SECURITY: No OAuth2 token rotation implemented
- [High] TEST: Missing integration tests for auth flow
- [Medium] LINT: Inconsistent variable naming in auth module
- [Low] DOCS: Auth module lacks inline comments

Decision: Fix Critical and High issues before completing
```

---

**[COMMUNITY] Feedback Loops**

**✓ VERIFIED** (Source: https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)

**The Pattern: Validator → Fix → Repeat**

Incorporate feedback loops into your workflow to catch issues early and ensure quality.

**Why This Matters**:

Feedback loops:
- **Catch mistakes early** — Before they become bigger problems
- **Build confidence** — You know your work is solid before finishing
- **Create learning opportunities** — Understanding why something fails helps you improve
- **Save time** — Fixing issues immediately is faster than debugging later

**Example: Style Guide Compliance (Skills without code)**:
```
## Content review process
1. Draft your content following the guidelines
2. Review against the checklist:
   - Check terminology consistency
   - Verify examples follow the standard format
   - Confirm all required sections are present
3. If issues found:
   - Note each issue with specific section reference
   - Revise the content
   - Review the checklist again
4. Consider proceeding when requirements are met
5. Finalize and save the document
```

**Example: Document Editing Process (Skills with code)**:
```
## Document editing process
1. Make your edits to `word/document.xml`
2. **Validate**: `python ooxml/scripts/validate.py unpacked_dir/`
3. If validation finds issues:
   - Review the error message carefully
   - Fix the issues in the XML
   - Run validation again
4. **Proceed when satisfied with quality**
5. Rebuild: `python ooxml/scripts/pack.py unpacked_dir/ output.docx`
6. Test the output document
```

**Checklist Pattern**:

For complex workflows, provide a checklist that can be copied and checked off:
```
## PDF form filling workflow
Copy this checklist and check off items as you complete them:

Task Progress:
- [ ] Step 1: Analyze the form (run analyze_form.py)
- [ ] Step 2: Create field mapping (edit fields.json)
- [ ] Step 3: Validate mapping (run validate_fields.py)
- [ ] Step 4: Fill the form (run fill_form.py)
- [ ] Step 5: Verify output (run verify_output.py)
```

---

**[COMMUNITY] Evaluation-Driven Development**

**✓ VERIFIED** (Source: https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)

**The Principle**:

Create evaluations **before** writing extensive documentation. This approach helps ensure your Skills solve real problems rather than documenting imagined ones.

**Why This Matters**:

Evaluation-driven development helps you:
- **Understand real needs** — By testing without a Skill first, you see what actually causes problems
- **Focus your efforts** — You write only what's needed to solve demonstrated issues
- **Measure improvement** — You have concrete evidence that your Skill helps
- **Avoid over-engineering** — You don't add complexity for hypothetical scenarios

**Evaluation-Driven Development Process**:

1. **Identify gaps**: Run Claude on representative tasks without a Skill. Document specific failures
2. **Create evaluations**: Build scenarios that test these gaps
3. **Establish baseline**: Measure Claude's performance without the Skill
4. **Write minimal instructions**: Create just enough content to address the gaps
5. **Iterate**: Execute evaluations, compare against baseline, and refine

**Developing Skills Iteratively**:

1. **Complete a task without a Skill**: Work through a problem using normal prompting. Notice what context, preferences, and procedural knowledge you repeatedly provide
2. **Identify the reusable pattern**: After completing the task, identify what you provided that would be useful for similar future tasks
3. **Create a Skill capturing the pattern**: Include the specific knowledge that proved helpful
4. **Review for conciseness**: Remove unnecessary explanations—focus on what Claude actually needed
5. **Test on similar tasks**: Use the Skill with fresh instances on related use cases
6. **Iterate based on observations**: If Claude struggles or misses something, refine with specific improvements

---

**[FINDING] Portability Verification**

A portable component works across different AI coding tools: Claude Code, Cursor, Zed, GitHub Copilot.

**Why This Matters**:

Portable components maximize your investment:
- **Future-proof**: Your work isn't locked to a single tool
- **Shareable**: Others can use your components regardless of their setup
- **Consistent**: Same quality experience across different platforms

**Portability Guidelines**:

- [ ] **Follows agentskills.io standard**: Component structure matches the standard
- [ ] **No platform-specific dependencies**: Works across different platforms
- [ ] **No Claude-specific features**: Uses standard primitives only
- [ ] **Universal frontmatter**: Standard fields only
- [ ] **Cross-platform paths**: No hard-coded Windows paths

**agentskills.io Compliance**:

**Standard structure**:
```yaml
---
name: component-name
description: "What it does. Use when..."
---
```

**Optional but widely supported**:
```yaml
context: fork
agent: general-purpose
```

**Non-standard (limits portability)**:
- Custom frontmatter fields
- Platform-specific scripts
- Claude-only features

---

**[FINDING] Quality Metrics (Reference Guidelines)**

These metrics are provided as reference points to help you assess component quality.

**Component Quality Indicators**:

| Aspect | Suggested Weight | What We Look For |
|:-------|:-----------------|:-----------------|
| **Frontmatter** | 20% | Complete, proper naming |
| **Description** | 25% | Non-spoiling, includes Use when/Not for |
| **Content** | 30% | Centralized, no time-sensitive info |
| **Portability** | 15% | Cross-platform compatible |
| **Examples** | 10% | Working, relevant |

**Quick Assessment Guidelines**:

| Indicator | Healthy Range | Consider Reviewing |
|:----------|:--------------|:-------------------|
| **SKILL.md length** | 500-2000 lines | <100 (might be too thin) or >5000 (might be too long) |
| **references/ count** | 0-2 files | >5 files (might be scattered) |
| **scripts/ count** | 0-3 scripts | >10 scripts (might be over-engineering) |
| **Description length** | 50-200 chars | <20 (might be too vague) or >500 (might be spoiling) |

---

### Common Mistakes

**[COMMUNITY] Mistake 1: Micromanagement**

**✓ VERIFIED** (Source: https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)

**Symptom**: Agent seems paralyzed, can't make decisions, or waits for explicit instructions on every minor detail.

**Cause**: Over-constraining with rigid step-by-step instructions.

**The Problem**:

❌ **Bad Example**:
```markdown
## Steps (Follow Exactly)

1. Create a folder named exactly "my-skill"
2. Create a file named exactly "SKILL.md" in that folder
3. Add exactly these fields to the frontmatter
4. Write exactly 3 sections in the body
```

**The Fix**: Give objectives and success criteria, not procedures.

✅ **Good Example**:
```markdown
<mission_control>
<objective>Create a skill for processing PDFs</objective>
<success_criteria>Skill extracts text from PDFs and handles errors gracefully</success_criteria>
</mission_control>

# Approach
1. Create the skill directory structure
2. Write SKILL.md with proper frontmatter
3. Add processing logic and error handling
4. Test with sample PDFs

Adapt these steps as needed for your use case.
```

**Key Principle**: > **2026 Research**: Over-constraining agents causes more failures than under-constraining.

**When Strong Language is NOT Micromanagement**:

There is a crucial distinction between **micromanagement** (dictating every step) and **compensation** (setting absolute boundaries for low-freedom tasks).

**Low Freedom Tasks Require Absolute Imperative Language**:

Some tasks have **zero degrees of freedom**—the output must meet exact specifications. For these tasks, strong imperative language (MUST, ALWAYS, NEVER) is not micromanagement; it's **essential compensation**.

| Micromanagement (Bad) | Compensation (Good) |
|:----------------------|:--------------------|
| Dictates every micro-step | Sets absolute boundaries only |
| "Do this, then this, then this" | "MUST meet these absolute constraints" |
| Prevents adaptation to edge cases | Allows any path within hard limits |

**When This Pattern Actually Works**: Micromanagement is appropriate for **safety-critical systems** where deviation is dangerous.

---

**[COMMUNITY] Mistake 2: Negative-Only Constraints**

**✓ VERIFIED** (Source: https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)

**Symptom**: Agent doesn't know what to do after being told what NOT to do. Seems stuck or confused.

**Cause**: "Don't" without "Do instead."

**The Problem**:

❌ **Bad Examples**:
```markdown
## Constraints
- Don't use vague names
- Avoid micromanagement
- Never hide information in references/
- Don't spoil descriptions
```

**The Fix**: Always provide positive alternatives.

✅ **Good Examples**:
```markdown
## Guidelines
- Use gerund form: `processing-pdfs`, `analyzing-data`
- Give objectives and success criteria
- Put everything helpful in SKILL.md
- Descriptions should state what/when/not, not how
```

**Pattern**:

| ❌ Don't | ✅ Do Instead |
|:----------|:-------------|
| Don't use vague names | Use gerund form with specific purpose |
| Avoid micromanagement | Provide objectives, not procedures |
| Never hide info | Centralize core knowledge in SKILL.md |
| Don't spoil descriptions | Use what/when/not pattern |

---

**[FINDING] Mistake 3: Context Pollution**

**Symptom**: Context is always full, compaction happening frequently, agent losing early instructions.

**Cause**: Bloated instructions, redundant content, not leveraging CLAUDE.md for persistent rules.

**The Problem**:

❌ **Bad Example**:
```markdown
# Every skill repeats these rules

## Naming Convention
- Use gerund form
- Lowercase only
- Hyphens for separators

## Quality Standards
- Frontmatter complete
- Description non-spoiling
- Examples work

## Error Handling
- Always validate inputs
- Provide clear error messages
```

**The Fix**: Put persistent rules in `CLAUDE.md` or `.claude/rules/`.

✅ **Good Example**:

**CLAUDE.md** (persistent, always loaded):
```markdown
# Project Rules

## Naming Convention
All components use gerund form, lowercase, hyphens only.

## Quality Standards
- Frontmatter complete
- Description non-spoiling
- Examples work
```

**SKILL.md** (specific to this skill):
```markdown
# PDF Processor

Extracts text from PDF files.

## Usage
Provide a PDF file path to extract text.

## Error Handling
Follow project standards for validation and error messages.
```

**Key Insight**: > **Context Compaction**: When context reaches ~78%, it compacts automatically. Put persistent rules in CLAUDE.md to survive compaction.

---

**[FINDING] Mistake 4: Scattered Knowledge**

**Symptom**: Can't find information, agent doesn't use it, or information is buried in nested references.

**Cause**: Hiding core knowledge in `references/` folder when it should be in SKILL.md.

**The Problem**:

❌ **Bad Structure**:
```
skills/my-skill/
├── SKILL.md              # "See references/patterns.md"
├── references/
│   ├── patterns.md       # "See references/advanced-patterns.md"
│   ├── advanced-patterns.md
│   └── exceptions.md
```

**The Fix**: **Put everything helpful in SKILL.md.**

✅ **Good Structure**:
```
skills/my-skill/
├── SKILL.md              # All core patterns, examples, guardrails
├── REFERENCE.md          # ONLY if >1000 lines of domain-specific data
```

**The Rule**: > **AI Agents Are Smart and Lazy**: They read SKILL.md but won't hunt for scattered references.

---

**[FINDING] Mistake 5: Spoiling Descriptions**

**Symptom**: Descriptions are verbose, wasting tokens, duplicating system prompt.

**Cause**: Description reveals body content instead of stating what/when/not.

**The Problem**:

❌ **Bad Descriptions**:
```yaml
---
description: "This skill reads the SKILL.md file and checks for frontmatter fields like name, description, and then verifies that the naming follows the gerund form convention..."
---
```

**The Fix**: Non-spoiling descriptions: **What - When - Not**

✅ **Good Descriptions**:
```yaml
---
description: "Validates skills against quality standards. Use when reviewing skill quality, checking frontmatter completeness, or verifying naming conventions. Not for code linting or type checking."
---
```

**The Pattern**:
```yaml
---
description: "[What it does]. Use when [trigger conditions + keywords]. Not for [exclusions]."
---
```

---

**[FINDING] Mistake 6: Magic Syntax**

**Symptom**: Instructions use special formatting, rigid structure, or "magical" commands.

**Cause**: Belief that AI needs special syntax to understand instructions.

**The Problem**:

❌ **Bad Example**:
```markdown
## === INITIALIZATION SEQUENCE ===

### [STEP 1]: Directory Creation
$ mkdir -p .claude/skills/[SKILL_NAME]

### [STEP 2]: File Creation
$ touch .claude/skills/[SKILL_NAME]/SKILL.md
```

**The Fix**: Use natural language and clear explanations.

✅ **Good Example**:
```markdown
# Creating a Skill

## Step 1: Create Directory Structure

```bash
mkdir -p .claude/skills/my-skill
```

## Step 2: Create SKILL.md

Add frontmatter with name and description:

```yaml
---
name: my-skill
description: "What it does. Use when..."
---
```
```

**Key Insight**: > **Natural Language > Magic Syntax**

Modern language models are trained on conversational text. Professional, clear language works better than rigid formatting.

---

**[COMMUNITY] Mistake 7: Over-Generalization**

**Symptom**: Instructions are too abstract, lacking concrete examples or specific guidance.

**Cause**: Fear of being too prescriptive, swinging too far toward "high freedom."

**The Problem**:

❌ **Bad Example**:
```markdown
# Create a skill

You should create a skill. Consider using appropriate patterns and following best practices. The skill should be effective and well-structured.
```

**The Fix**: Balance objectives with concrete guidance.

✅ **Good Example**:
```markdown
# Creating a Skill

<mission_control>
<objective>Create a skill for processing PDFs</objective>
<success_criteria>Skill extracts text and handles errors</success_criteria>
</mission_control>

## Structure
1. Create directory: `.claude/skills/processing-pdfs/`
2. Add SKILL.md with frontmatter
3. Include error handling
4. Test with sample files

## Frontmatter Template
```yaml
---
name: processing-pdfs
description: "Extracts text from PDF files. Use when working with PDF documents."
---
```

Adapt the structure to your needs, but ensure all components are present.
```

**Key**: Over-generalization leads to misapplication because agents lack concrete anchors for their reasoning.

---

**[FINDING] Mistake 8: Time-Sensitive Content**

**Symptom**: Instructions become outdated, refer to "current" or "latest" versions, or lack timestamps.

**Cause**: Writing content that assumes a specific point in time without dating it.

**The Problem**:

❌ **Bad Example**:
```markdown
## Current Best Practices

As of 2025, the recommended approach is...

## Latest Pattern
The newest pattern for skills is...
```

**The Fix**: Use "Old Patterns" sections for deprecated content, date everything.

✅ **Good Example**:
```markdown
## Recommended Approach (2025+)

Use `context: fork` for isolated workers...

## Old Patterns (Pre-2025)

These patterns were used in earlier versions:
- **Inline auditors**: Now use `context: fork` for unbiased validation
- **Single CLAUDE.md**: Now split into modular .claude/rules/*.md
```

**Key Insight**: Time-sensitive content causes **staleness decay** that silently degrades agent performance. Temporal labeling creates explicit version awareness.

---

## Maintain Phase

### Session Handoff

**[FINDING] Session Handoff Workflow**

Capture current session state for continuation in a new session.

**Purpose**: Preserve context across sessions for long-running work.

**Workflow**:
```
1. User invokes /handoff
2. Handoff skill captures:
   - Current task context
   - Recent file changes
   - Pending work
   - Conversation summary
3. Creates structured handoff document
4. Saves to .claude/workspace/handoffs/
5. User starts new session
6. User invokes /handoff:resume <handoff-id>
7. Context restored from handoff document
```

**Handoff Document Structure**:
```markdown
# Handoff: [Session ID]

**Created**: 2026-01-31 10:30:00
**Status**: In Progress

## Context
- Working on: Feature X implementation
- Files modified: 3
- Pending tasks: 2

## Recent Changes
- src/component.ts: Added new method
- tests/component.test.ts: Added tests
- README.md: Updated documentation

## Pending Work
- [ ] Implement edge case handling
- [ ] Add integration tests

## Conversation Summary
[Summary of key decisions and context]
```

**Implementation**:
- **Create handoff**: `/handoff [--full]`
- **Resume handoff**: `/handoff:resume <handoff-id>`
- **Diagnostic handoff**: `/handoff:diagnostic` (Captures issues/errors for debugging)

**Key**: Handoff documents enable seamless context preservation across sessions.

---

### Evolution Practices

**[FINDING] Refinement Workflow**

Update and improve project components (rules, skills, commands, documentation).

**Purpose**: Keep project knowledge current and aligned with actual usage.

**Workflow**:
```
1. User invokes /meta:reflect:session
2. Reflection skill analyzes:
   - Patterns in recent work
   - Recurring issues
   - New knowledge discovered
3. User invokes refinement commands
4. Components updated based on reflection
5. Quality gates verify changes
```

**Available Refinement Commands**:

| Command | Purpose |
|:--------|:---------|
| `/meta:refine:rules` | Update CLAUDE.md and .claude/rules/*.md |
| `/meta:refine:skills` | Update skill content based on patterns |
| `/meta:refine:commands` | Update command content |
| `/meta:refine:documentation` | Update project documentation |
| `/meta:reflect:session` | Analyze session for patterns |
| `/meta:reflect:drift` | Detect scattered knowledge |
| `/meta:reflect:patterns` | Identify recurring patterns |

**Example Usage**:
```bash
# First, reflect on the session
/meta:reflect:session

# Then refine based on findings
/meta:refine:rules
/meta:refine:skills
/meta:refine:documentation

# Check for knowledge drift
/meta:reflect:drift
```

---

**[FINDING] Capture Workflow**

Capture knowledge, decisions, patterns, and context during development.

**Purpose**: Preserve important insights for future reference.

**Available Capture Commands**:

| Command | Purpose |
|:--------|:---------|
| `/meta:capture:context` | Capture context snippet for reference |
| `/meta:capture:decision` | Record architectural decision (ADR) |
| `/meta:capture:pattern` | Document reusable pattern |
| `/meta:capture:gotcha` | Record lesson learned or pitfall |

**Storage Location**:
```
.claude/workspace/captures/
├── context/
├── decisions/
├── patterns/
└── gotchas/
```

**Example Usage**:
```bash
# Capture important context
/meta:capture:context

# Record architectural decision
/meta:capture:decision
# Records: Context, Decision, Rationale, Consequences

# Document a pattern
/meta:capture:pattern
# Records: Pattern name, when to use, implementation, examples
```

---

**[FINDING] Audit Workflow**

Comprehensive review of project health and components.

**Purpose**: Regular health checks for the project ecosystem.

**Available Audit Commands**:

| Command | Purpose |
|:--------|:---------|
| `/internal:review` | Review project health and component integrity |

**Implementation**: Uses `internal/review.md` command which routes to appropriate audit methodology.

**Supported audits**:
- Skills
- Commands
- Agents
- Hooks
- MCP servers

**Example Usage**:
```bash
# Run project review
/internal:review
```

---

**[FINDING] Learning Workflow**

Analyze and improve project rules and documentation.

**Purpose**: Systematic improvement of project guidance.

**Available Learning Commands**:

| Command | Purpose |
|:--------|:---------|
| `/learning:refine-rules` | Analyze CLAUDE.md for quality, consistency, best practices |
| `/learning:capture` | Archive discoveries when "that worked well" is said |
| `/learning:extract` | Extract component candidates from conversation |

**Example Usage**:
```bash
# Analyze and improve rules
/learning:refine-rules

# Archive discoveries after saying "that worked well"
/learning:archive
```

---

### Autonomous Correction

**[FINDING] Feedback Loop (Autonomous Rule Correction)**

The `system-refiner` skill implements autonomous rule correction when users say "no", "wrong", "wait", or similar negative feedback.

**Purpose**: Autonomously correct project rules when negative feedback occurs.

**The Detect → Trace → Gap → Patch Workflow**:
```
1. DETECT    → User correction ("No," "Wait," "Wrong," "Not what I meant")
2. TRACE     → Ask "Which instruction allowed this mistake?"
3. IDENTIFY  → Why did the instruction fail? (missing, vague, contradictory)
4. PATCH     → Apply targeted edit to the relevant file
5. REPORT    → "I've updated [file] to ensure I [new behavior]"
```

**Root Cause Mapping**:

| If the mistake reveals... | Target... |
|:--------------------------|:----------|
| Missing or wrong project rule | Documentation, CLAUDE.md, .claude/rules/ |
| Wrong procedural pattern | Relevant skill in .claude/skills/ |
| Command logic issue | Command file in .claude/commands/ |
| Agent behavior problem | Agent config in .claude/agents/ |
| Hook or tool mismatch | Hook definition or tool schema |

**Patching Principles**:
- **Be specific**: Patch the exact instruction that failed
- **Generalize**: Extract principle from the specific mistake
- **Respect structure**: Follow each file's existing conventions
- **Place strategically**: Put new constraints where they'll be noticed

**Critical Constraints**:
- NEVER create new files for corrections; ALWAYS edit existing rules/skills/commands/agents
- Use the Delta Standard: Only add rules for things you actually got wrong
- Keep patches atomic. Change the logic, not the formatting
- If unsure where the rule belongs, trace from effect to cause before editing

**Key**: Autonomous rule correction enables the system to learn from mistakes and improve over time.

---

**[FINDING] Testing Workflow**

Execute and validate project tests.

**Purpose**: Ensure functionality works as expected and prevent regressions.

**Available Test Commands**:

| Command | Purpose |
|:--------|:---------|
| `/run-tests` | Execute all tests in workspace |
| `/debug-tests` | Debug failing tests with isolation |
| `/qa:verify-phase` | Gatekeeper for strategy execution phases |

**Example Usage**:
```bash
# Run all tests
/run-tests

# Run specific test files
/run-tests src/**/*.test.ts

# Debug failing tests
/debug-tests tests/auth.test.ts
```

**Key**: Test validation ensures code quality and prevents regressions.

---

### Distribution & Sharing

**[OFFICIAL]** Share skills and components with others.

**Distribution Methods**:

| Method | Use For | Steps |
|:-------|:--------|-------|
| **GitHub Repo** | Open-source skills | 1. Create repo, 2. Add README, 3. Upload skill folder |
| **Claude Code Settings** | Personal/team use | Settings > Capabilities > Upload skill |
| **MCP Server Bundling** | MCP-enhanced skills | Include skill folder in MCP package |

**Best Practices**:
- Host on GitHub with clear README for human users
- Include installation instructions and examples
- Link from MCP documentation if bundled with server
- Use semantic versioning in metadata

**Reference**: See official guide Chapter 4 (lines 981-1175) for complete distribution details.

---

### Troubleshooting Guide

**[OFFICIAL]** Common issues and solutions.

#### Skill Won't Upload

| Error | Cause | Solution |
|:------|:------|:---------|
| "Could not find SKILL.md" | File not named exactly | Rename to `SKILL.md` (case-sensitive) |
| "Invalid frontmatter" | YAML formatting issue | Verify `---` delimiters, no unclosed quotes |
| "Invalid skill name" | Spaces or capitals | Use kebab-case: `my-skill`, not `My Skill` |

#### Skill Doesn't Trigger

| Symptom | Cause | Solution |
|:--------|:------|:---------|
| Never loads automatically | Vague description | Include specific trigger phrases users would say |
| Triggers too often | Overly broad scope | Add "Not for" exclusions to description |

**Debug Approach**: Ask Claude "When would you use this skill?" and adjust based on missing triggers.

#### MCP Connection Issues

| Symptom | Check |
|:--------|:------|
| MCP calls fail | Verify MCP server is connected in Settings > Extensions |
| Authentication errors | Check API keys, permissions, OAuth tokens |
| Tool not found | Verify skill references correct MCP tool names |

**Reference**: See official guide Chapter 5 (lines 1472-1691) for complete troubleshooting.

---

## Quick Reference: Workflow Selection

| Goal | Use | Workflow |
|:-----|:-----|:---------|
| Create component | `/factory` | Component Creation |
| Validate changes | `/quality:run-gates` | Quality Gate |
| Pause and resume later | `/handoff` | Session Handoff |
| Improve components | `/meta:refine:*` | Refinement |
| Autonomous rule correction | Auto-invoke on "no" | Feedback Loop |
| Clarify before acting | `/factory` (liaison mode) | Liaison Pattern |
| Gather requirements | `/discovery` | Discovery |
| Plan implementation | `/strategy:architect` | Planning |
| Save knowledge | `/meta:capture:*` | Capture |
| Review project | `/meta:audit:*` | Audit |
| Improve rules | `/learning:refine-rules` | Learning |
| Run tests | `/run-tests` | Testing |
| Fix errors | `/refine:component` | Component Repair |
| Review project | `/internal:review` | Audit |
