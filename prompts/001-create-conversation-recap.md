<objective>
Create a comprehensive recap document of the previous conversation session. This recap will serve as a knowledge transfer document, allowing any future Claude context to quickly understand what work was performed, what issues were encountered, and what remains to be done.

The recap must be thorough enough that a fresh agent could continue the work without needing to re-read the entire conversation history.
</objective>

<context>
This prompt is typically invoked at the end of a work session or when context switching is needed. The conversation history will contain all the information about what was discussed, what actions were taken, what errors occurred, and what decisions were made.

The recap serves as:
1. A handoff document for future sessions
2. A reference for understanding project state changes
3. A record of problem-solving approaches
4. A todo list tracking remaining work

The output should be saved in `.recap/` folder (create if missing) using a descriptive filename with timestamp.
</context>

<requirements>
Thoroughly analyze the conversation history and extract:

1. **Session Metadata**
   - Date/time of session
   - Branch name (if applicable)
   - User's primary goals for the session

2. **Tasks Completed**
   - All tasks that were successfully finished
   - Files created, modified, or deleted
   - Code changes with brief explanations of WHY changes were made
   - Tests run and their results

3. **Issues Encountered**
   - Any errors, warnings, or failures that occurred
   - Root causes (if identified)
   - Solutions that were applied
   - Issues that remain unresolved

4. **Decisions Made**
   - Architectural decisions
   - Trade-offs considered
   - Rejections of alternatives (with reasoning)

5. **Remaining Tasks**
   - Explicit incomplete work
   - Follow-up items mentioned but not started
   - Technical debt identified but not addressed
   - Any "TODO" comments or similar markers in code

6. **Commands Run**
   - Key bash commands executed (git, build, test, etc.)
   - MCP tool invocations that were significant
   - Any custom scripts or tools used

Organize findings in a clear, hierarchical structure with markdown formatting.
</requirements>

<output_format>
Create a markdown file at:
`.recap/[YYYY-MM-DD]-[session-topic].md`

Use the following structure:

```markdown
# Session Recap: [Descriptive Title]

**Date:** [ISO 8601 date]
**Branch:** [git branch name]
**Session Focus:** [Brief 1-2 sentence summary]

---

## Executive Summary
[2-3 paragraphs summarizing the entire session - what was attempted, what was achieved, what remains]

---

## Tasks Completed

### [Category 1]
- **[Task Name]** - [Brief description of what was done]
  - Files: `path/to/file1.ext`, `path/to/file2.ext`
  - Impact: [What this accomplished]

### [Category 2]
[Continue as needed...]

---

## Changes Made

### Files Modified
| File | Change Summary | Reason |
|------|----------------|--------|
| `path/to/file.ext` | [Brief description] | [Why it was changed] |

### Files Created
- `path/to/new_file.ext` - [Purpose and content]

### Files Deleted
- `path/to/old_file.ext` - [Reason for deletion]

---

## Issues & Resolutions

### ✅ Resolved Issues
| Issue | Solution | Location |
|-------|----------|----------|
| [Description] | [How it was fixed] | [file:line or context] |

### ⚠️ Unresolved Issues
| Issue | Status | Next Steps |
|-------|--------|------------|
| [Description] | [Current state] | [What needs to happen] |

---

## Decisions Made

### [Decision Category]
**Decision:** [What was decided]
**Context:** [Why this decision was needed]
**Alternatives Considered:** [Other options and why they were rejected]
**Impact:** [How this affects the project]

---

## Remaining Tasks

### High Priority
- [ ] [Task description] - [Why it's important]

### Medium Priority
- [ ] [Task description]

### Low Priority / Nice to Have
- [ ] [Task description]

---

## Key Commands Used
```bash
# [Category]
command  # [What it did]
```

---

## Next Session Recommendations
1. [Suggested starting point]
2. [Areas that need attention]
3. [Potential blockers to watch for]

---

## Artifacts Generated
- [Any output files, reports, or documentation created]
```

</output_format>

<constraints>
- DO NOT include every single message exchange - focus on outcomes and key information
- DO NOT copy large code blocks - summarize what was changed and why
- DO be specific about file paths and line numbers where relevant
- DO NOT speculate - if something is unclear from context, note it as "Unknown"
- DO NOT include tool error output unless it was significant to problem-solving
- The recap should be comprehensive but concise - aim for readability over exhaustiveness
</constraints>

<verification>
Before completing, verify the recap:
- [ ] All completed tasks are listed
- [ ] All file changes are documented
- [ ] All issues (resolved and unresolved) are captured
- [ ] Remaining tasks are clearly identified
- [ ] The executive summary accurately reflects the session
- [ ] File paths are accurate and use relative paths from project root
- [ ] Markdown formatting is clean and readable
</verification>

<success_criteria>
A successful recap will:
1. Enable a fresh agent to understand the session within 2-3 minutes
2. Provide enough context to continue remaining work without re-reading conversation
3. Serve as a historical record of what was done and why
4. Be saved in the correct location with a descriptive filename
</success_criteria>
