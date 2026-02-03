---
number: 03
title: Others
audience: self-maintenance
related: [00, 01, 02, 04, 05]
last-reviewed: 2026-02-01
---

# 03 - Others

> **Verification Method**: Documentation sections use ONLY `mcp__simplewebfetch__simpleWebFetch` tool to navigate official documentation.
>
> **Sources**:
> - Claude Code: https://code.claude.com/docs
> - Platform Best Practices: https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices
>
> **Verification Legend**: `✓ VERIFIED` = Confirmed against official docs with source URL | `⚠ CUSTOM` = thecattoolkit_v3 pattern

## Quick Navigation

| Section | Line | Key Terms |
|:--------|-----:|:----------|
| Hooks Concept | ~27 | event-driven, automation, security |
| Hook Events | ~77 | all 12 events with matchers |
| Hook Types | ~117 | command, prompt, agent |
| Exit Codes | ~169 | 0, 2, other |
| JSON Control | ~194 | hookSpecificOutput schema |
| Middleware | ~399 | updatedInput examples |
| Hook Scopes | ~480 | 6 scope levels |
| Examples | ~613 | security shell scripts |
| MCP Servers | ~875 | placeholder section |

---

# Part 1: Hooks Component

## Concept Overview

Hooks are event-driven automation mechanisms that execute scripts or prompts at specific points in the Claude Code session lifecycle. They enable security enforcement, context injection, cleanup operations, and custom workflow triggers without modifying core agent behavior.

**Core capabilities**:
- **Security enforcement**: Intercept dangerous commands before execution
- **Context injection**: Add discipline markers, environment setup at session start
- **Lifecycle management**: Archive transcripts, cleanup on session end
- **Input validation**: Transform or block tool inputs based on patterns

Hooks run in isolation from the main conversation context, receiving structured input via stdin and returning control decisions via stdout and exit codes. This separation ensures hooks cannot interfere with agent reasoning while still providing powerful automation capabilities.

## Configuration File

```json
// .claude/settings.json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "./scripts/session-start.sh",
            "timeout": 60,
            "once": true
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "./scripts/security-check.sh"
          },
          {
            "type": "prompt",
            "prompt": "Command contains 'rm -rf'. Use trash instead? Confirm with {\"ok\": true}.",
            "timeout": 30
          }
        ]
      }
    ]
  }
}
```

## Hook Events

**VERIFIED ✓** (Source: https://code.claude.com/docs/en/hooks)

| Event | When It Fires | Matcher Support | Use Case |
|:------|:--------------|:----------------|:---------|
| `SessionStart` | On session initialization | ✅ `startup`, `resume`, `clear`, `compact` | Load discipline context, init environment |
| `UserPromptSubmit` | When user submits prompt | ❌ N/A | Validate prompts, add context based on input |
| `PreToolUse` | Before tool execution | ✅ Tool name patterns | Security checks, input validation, middleware |
| `PermissionRequest` | When permission dialog shown | ✅ Tool name patterns | Auto-allow/deny specific operations |
| `PostToolUse` | After tool execution | ✅ Tool name patterns | Logging, notifications, auto-format |
| `PostToolUseFailure` | After tool fails | ✅ Tool name patterns | Error handling, retry logic, alerts |
| `Notification` | When notification sent | ✅ Notification types | Respond to permission prompts, idle alerts |
| `SubagentStart` | When subagent spawns | ✅ Agent type name | Setup subagent-specific context |
| `SubagentStop` | When subagent completes | ✅ Agent type name | Cleanup, archive subagent results |
| `Stop` | When Claude finishes responding | ❌ N/A | Archive transcripts, final cleanup |
| `PreCompact` | Before context compaction | ✅ `manual`, `auto` | Preserve critical context before compaction |
| `SessionEnd` | When session terminates | ✅ `clear`, `logout`, `prompt_input_exit`, `bypass_permissions_disabled`, `other` | Final cleanup, metrics, session archive |

### Matcher Patterns by Event

**Tool Events** (PreToolUse, PostToolUse, PostToolUseFailure, PermissionRequest):
- Match on tool name: `"Bash"`, `"Edit|Write"`, `"mcp__.*"`
- Examples: `Bash`, `Read`, `Edit`, `Write`, `Glob`, `Grep`, `Task`, `WebFetch`, `WebSearch`

**Session Events** (SessionStart, SessionEnd):
- `SessionStart`: `"startup"`, `"resume"`, `"clear"`, `"compact"`
- `SessionEnd`: `"clear"`, `"logout"`, `"prompt_input_exit"`, `"bypass_permissions_disabled"`, `"other"`

**Lifecycle Events** (SubagentStart, SubagentStop, PreCompact):
- `SubagentStart`: Agent type name (`"Explore"`, `"Plan"`, `"general-purpose"`, custom agent names)
- `SubagentStop`: Agent type name (same values as `SubagentStart`)
- `PreCompact`: `"manual"` or `"auto"`

**Notification Event**:
- Match on notification type: `"permission_prompt"`, `"idle_prompt"`, `"auth_success"`, `"elicitation_dialog"`

**No Matcher Support** (always fire):
- `UserPromptSubmit`, `Stop`

## Hook Types

**VERIFIED ✓** (Source: https://code.claude.com/docs/en/hooks)

| Type | Purpose | Returns | Use When |
|:-----|:--------|:--------|:---------|
| `command` | Execute shell script | Exit code + JSON stdout | Security validation, file operations, middleware |
| `prompt` | Ask LLM to evaluate | JSON decision | Quick yes/no decisions, content validation |
| `agent` | Spawn subagent | JSON decision | Complex validation requiring tool access |

### Hook Type Details

**command**: Most common type. Script receives JSON on stdin, returns control decisions via exit codes and stdout.

**prompt**: Send a prompt to a Claude model for single-turn evaluation. Returns yes/no as JSON. Good for content analysis without full subagent overhead.

**agent**: Spawn a subagent that can use tools (Read, Grep, Glob) to verify conditions. More expensive than prompt but can perform complex investigations.

### Prompt and Agent Hook Response Schema

Prompt-based hooks (`type: "prompt"`) and agent-based hooks (`type: "agent"`) use a different response format. The model must return JSON with:

```json
{
  "ok": true | false,
  "reason": "Explanation for the decision"
}
```

| Field | Description |
|:------|:------------|
| `ok` | `true` allows the action, `false` prevents it |
| `reason` | Required when `ok` is `false`. Explanation shown to Claude |

Use `$ARGUMENTS` as a placeholder in the prompt to inject the hook's JSON input data.

### Common Hook Handler Fields

| Field | Required | Description |
|:------|:---------|:------------|
| `type` | Yes | `"command"`, `"prompt"`, or `"agent"` |
| `timeout` | No | Seconds before canceling. Defaults: 600 for command, 30 for prompt, 60 for agent |
| `statusMessage` | No | Custom spinner message displayed while the hook runs |
| `once` | No | If `true`, runs only once per session then is removed (skills only) |

**Command-only field**:
| `async` | No | If `true`, runs in the background without blocking |

**Prompt and agent fields**:
| `prompt` | Yes | Prompt text to send to model. Use `$ARGUMENTS` for hook input JSON |
| `model` | No | Model to use for evaluation |

## Hook Exit Codes

| Code | Behavior | Use For |
|:-----|:---------|:--------|
| **0** | Success, parse JSON from stdout | Control decisions, middleware |
| **2** | Blocking error, action blocked | Security violations, blocking actions |
| **Other** | Non-blocking, verbose only | Warnings, logging |

### Exit Code 2 Behavior Per Event

| Event | Can Block? | What happens on exit 2 |
|:------|:-----------|:-----------------------|
| `PreToolUse` | ✅ Yes | Blocks the tool call |
| `PermissionRequest` | ✅ Yes | Denies the permission |
| `UserPromptSubmit` | ✅ Yes | Blocks prompt processing and erases the prompt |
| `Stop` | ✅ Yes | Prevents Claude from stopping, continues the conversation |
| `SubagentStop` | ✅ Yes | Prevents the subagent from stopping |
| `PostToolUse` | ❌ No | Shows stderr to Claude (tool already ran) |
| `PostToolUseFailure` | ❌ No | Shows stderr to Claude (tool already failed) |
| `Notification` | ❌ No | Shows stderr to user only |
| `SubagentStart` | ❌ No | Shows stderr to user only |
| `SessionStart` | ❌ No | Shows stderr to user only |
| `SessionEnd` | ❌ No | Shows stderr to user only |
| `PreCompact` | ❌ No | Shows stderr to user only |

## JSON Output Control

**VERIFIED ✓** (Source: https://code.claude.com/docs/en/hooks)

Hooks return structured JSON via stdout (exit 0). The schema requires a `hookSpecificOutput` wrapper with event-specific fields.

### Common Output Fields (All Events)

```json
{
  "continue": true,
  "stopReason": "Optional message if continue is false",
  "suppressOutput": false,
  "systemMessage": "Warning shown to user",
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    // Event-specific fields below
  }
}
```

### Event-Specific Output Schemas

#### PreToolUse

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow",           // "allow", "deny", "ask"
    "permissionDecisionReason": "Explanation",
    "updatedInput": {
      "command": "trash /path/to/file"      // Modified tool input
    },
    "additionalContext": "Context for Claude"
  }
}
```

#### PermissionRequest

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PermissionRequest",
    "decision": {
      "behavior": "allow",                   // "allow" or "deny"
      "updatedInput": {
        "command": "npm run lint"           // Modified tool input (allow only)
      },
      "updatedPermissions": [],              // Permission rule updates (allow only)
      "message": "Explanation",              // Why permission was denied (deny only)
      "interrupt": false                     // If true, stops Claude (deny only)
    }
  }
}
```

#### PostToolUse / PostToolUseFailure

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "Information for Claude to consider"
  }
}
```

#### SessionStart

```json
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "Context injected at session start"
  }
}
```

#### UserPromptSubmit

```json
{
  "decision": "block",                    // "block" to prevent processing
  "reason": "Why the prompt was blocked",
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "Extra context for Claude"
  }
}
```

#### Notification

Notification hooks cannot block or modify notifications. They can only add context:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "Notification",
    "additionalContext": "Context added to conversation"
  }
}
```

#### SubagentStart

SubagentStart hooks cannot block subagent creation, but can inject context into the subagent:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "SubagentStart",
    "additionalContext": "Follow security guidelines for this task"
  }
}
```

#### Stop / SubagentStop

Stop and SubagentStop hooks can prevent Claude from stopping:

```json
{
  "decision": "block",
  "reason": "Must be provided when Claude is blocked from stopping"
}
```

#### PreCompact

PreCompact hooks cannot block compaction:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreCompact",
    "additionalContext": "Context to preserve before compaction"
  }
}
```

#### SessionEnd

SessionEnd hooks cannot block session termination but can perform cleanup tasks:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "SessionEnd",
    "additionalContext": "Cleanup or logging information"
  }
}
```

### JSON Output Examples by Use Case

**Example 1: Allow a tool with modifications**
```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow",
    "permissionDecisionReason": "Safe git command",
    "updatedInput": {
      "command": "git status --short"
    }
  }
}
```

**Example 2: Block a dangerous command**
```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "rm -rf is blocked by security policy"
  }
}
```

**Example 3: Add context after tool execution**
```json
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "Remember to run lint after file edits"
  }
}
```

**Example 4: Stop the conversation entirely**
```json
{
  "continue": false,
  "stopReason": "Security violation detected. Session terminated.",
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny"
  }
}
```

## PreToolUse Middleware Pattern

Hooks can modify tool inputs before execution using `updatedInput`:

### Safe Command Substitution

Replace `rm -rf` with `trash` (moves to trash instead of permanent delete):

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow",
    "permissionDecisionReason": "Command modified to use safe trash utility",
    "updatedInput": {
      "command": "trash /path/to/file"
    }
  }
}
```

### Adding Safety Flags

Auto-add `--dry-run` to dangerous operations:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow",
    "updatedInput": {
      "command": "terraform destroy --dry-run"
    }
  }
}
```

### Modifying File Paths

Redirect writes to a staging directory:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow",
    "updatedInput": {
      "file_path": "/staging/config.json",
      "content": "..."
    }
  }
}
```

## Hook Frontmatter Options

Hooks can be defined in skills, agents, and commands via frontmatter:

```yaml
---
name: secure-ops
description: "Operations with security checks"
hooks:
  SessionStart:
    - hooks:
        - type: command
          command: "./scripts/init.sh"
          once: true
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./scripts/validate.sh"
---
```

| Option | Description |
|:--------|:-------------|
| `once: true` | Run hook exactly once (useful for session initialization) |
| `matcher: "ToolPattern"` | Filter which tools/events trigger the hook |

## Hook Locations and Scopes

Where you define a hook determines its scope:

| Location | Scope | Shareable |
|:---------|:------|:----------|
| `~/.claude/settings.json` | All your projects | No, local to your machine |
| `.claude/settings.json` | Single project | Yes, can be committed to the repo |
| `.claude/settings.local.json` | Single project | No, gitignored |
| Managed policy settings | Organization-wide | Yes, admin-controlled |
| Plugin `hooks/hooks.json` | When plugin is enabled | Yes, bundled with the plugin |
| Skill or agent frontmatter | While the component is active | Yes, defined in the component file |

## The `/hooks` Menu

Type `/hooks` in Claude Code to open the interactive hooks manager. Each hook is labeled with a bracket prefix:

- `[User]`: from `~/.claude/settings.json`
- `[Project]`: from `.claude/settings.json`
- `[Local]`: from `.claude/settings.local.json`
- `[Plugin]`: from a plugin's `hooks/hooks.json`, read-only

### Disable or Remove Hooks

- **Remove a hook**: Delete its entry from the settings JSON file, or use the `/hooks` menu
- **Disable all hooks**: Set `"disableAllHooks": true` in your settings file or use the toggle in the `/hooks` menu
- **Managed hooks only** (enterprise): Set `"allowManagedHooksOnly": true` in managed settings to block user, project, and plugin hooks

Direct edits to hooks in settings files don't take effect immediately. Claude Code captures a snapshot of hooks at startup and uses it throughout the session.

## Matcher Patterns

| Pattern | Matches | Example |
|:--------|:--------|:--------|
| `"Write|Edit"` | Write OR Edit | `"matcher": "Write\|Edit"` |
| `"Bash"` | Specific tool | `"matcher": "Bash"` |
| `"*"` | All tools | `"matcher": "*"` |

## Async Hooks

Set `"async": true` on command hooks to run them in the background without blocking Claude. Async hooks cannot block or control behavior (decision fields have no effect).

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write",
        "hooks": [
          {
            "type": "command",
            "command": "./scripts/run-tests.sh",
            "async": true,
            "timeout": 120
          }
        ]
      }
    ]
  }
}
```

## Environment Variables

Reference hook scripts using environment variables:

- `$CLAUDE_PROJECT_DIR`: Project root (use quotes for paths with spaces)
- `${CLAUDE_PLUGIN_ROOT}`: Plugin root directory (for plugin hooks)

Example: `"command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/check-style.sh"`

---

## Template: settings.json

```json
{
  "enabledMcpjsonServers": [
    "exa",
    "deepwiki",
    "simplewebfetch"
  ],
  "enableAllProjectMcpServers": true,
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume|clear|compact",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/scripts/session-start.sh",
            "description": "Inject native tool discipline into session context",
            "timeout": 30
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/scripts/rm-safety.sh",
            "description": "Block rm -rf and path traversal"
          },
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/scripts/dangerous-commands.sh",
            "description": "Block project-specific dangerous commands"
          }
        ]
      }
    ],
    "SessionEnd": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/scripts/session-end.sh",
            "description": "Archive stripped transcript to session directory for post-mortem analysis",
            "timeout": 60
          }
        ]
      }
    ]
  }
}
```

---

## Complete Examples: Security Hooks

### Example: session-start.sh

```bash
#!/bin/bash
# Session Start Hook - Discipline Enforcement Injection + Session Lifecycle
# Emits discipline context and manages session directory lifecycle

# --- Configuration ---
: "${CLAUDE_CONFIG_ROOT:=".claude"}"
ARCHIVE_DIR="${HOME}/.claude/sessions"
LOCAL_SESSIONS_DIR="${CLAUDE_PROJECT_DIR}/${CLAUDE_CONFIG_ROOT}/workspace/sessions"

# --- Read hook input from stdin ---
input=$(cat)
session_id=$(echo "$input" | jq -r '.session_id // empty')
transcript_path=$(echo "$input" | jq -r '.transcript_path // empty')

# --- Validation ---
if [ -z "$session_id" ]; then
    echo "[SessionStart] ERROR: No session_id in hook input" >&2
    exit 1
fi

# --- Session directory ---
session_dir="${LOCAL_SESSIONS_DIR}/${session_id}"

# --- Archive previous local session if exists ---
if [ -d "$LOCAL_SESSIONS_DIR" ] && [ -n "$(ls -A "$LOCAL_SESSIONS_DIR" 2>/dev/null)" ]; then
    for prev_dir in "$LOCAL_SESSIONS_DIR"/*/; do
        [ -d "$prev_dir" ] || continue
        prev_session_id=$(basename "$prev_dir")
        if [ "$prev_session_id" != "$session_id" ]; then
            mkdir -p "${ARCHIVE_DIR}/${prev_session_id}"
            mv "$prev_dir"* "${ARCHIVE_DIR}/${prev_session_id}/" 2>/dev/null || true
            # Use mv instead of rm -rf to avoid triggering dangerous command hooks
            [ -d "$prev_dir" ] && mv "$prev_dir" "${ARCHIVE_DIR}/${prev_session_id}/.tmp" 2>/dev/null && rm -rf "${ARCHIVE_DIR}/${prev_session_id}/.tmp" 2>/dev/null || true
            # Only remove empty directory if mv succeeded
            if [ -d "${ARCHIVE_DIR}/${prev_session_id}" ]; then
                rmdir "$prev_dir" 2>/dev/null || true
            fi
            echo "[SessionStart] Archived previous session: ${prev_session_id}"
        fi
    done
fi

# --- Session Persistence ---
mkdir -p "$session_dir"

# Record session metadata
git_branch=""
if git rev-parse --git-dir > /dev/null 2>&1; then
    git_branch=$(git branch --show-current 2>/dev/null || echo "detached")
fi

cat > "${session_dir}/start.jsonl" <<EOF
{"timestamp":"$(date -u +"%Y-%m-%dT%H:%M:%SZ")","event":"session_start","session_id":"${session_id}","cwd":"$(pwd)","git_branch":"${git_branch}","transcript_path":"${transcript_path}"}
EOF

# Save session dir for SessionEnd to read
echo "$session_dir" > "${LOCAL_SESSIONS_DIR}/.current_session"

# --- Discipline Marker Injection ---
discipline_marker="<SESSION_DISCIPLINE>
SKILL SENSITIVITY: 10x ELEVATED. Threshold lowered 10x. Before EVERY action:

1. Rate confidence (0-100) in completing without a skill
2. If confidence <90%, ASK YOURSELF: \"Does a skill exist for this?\"
3. If 1% chance applies, invoke it

CONTEXT FIRST. Before any task, question, code, or planning, gather relevant context. What is the current state? What changed recently? What exists in the project? SKIP THIS AND YOU ARE LAZY. You cannot act on stale context.

REFERENCES FROM SKILLS. If a skill tells to read a reference, you MUST read it.
</SESSION_DISCIPLINE>"

# Escape for JSON transport
escape_for_json() {
    local input="$1"
    input="${input//\\/\\\\}"
    input="${input//\"/\\\"}"
    input="${input//$'\n'/\\n}"
    input="${input//$'\r'/\\r}"
    input="${input//$'\t'/\\t}"
    printf '%s' "$input"
}

injected_discipline=$(escape_for_json "$discipline_marker")

# --- Output ---
cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "injectedContext": "${injected_discipline}"
  }
}
EOF

exit 0
```

### Example: rm-safety.sh

```bash
#!/bin/bash
set -euo pipefail

# Generic rm safety hook - portable across projects
# Blocks: rm -rf patterns and path traversal

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')

# rm -rf patterns (recursive force delete)
if [[ "$command" =~ ^[[:space:]]*rm[[:space:]]+(-rf|-fr|-r[[:space:]]+-f|-f[[:space:]]*-r)[[:space:]] ]]; then
    echo '[Hook] BLOCKED: rm -rf detected. This cannot be undone.' >&2
    echo "[Hook] Command: $command" >&2
    echo '[Hook] Use "trash" command instead: moves files to OS trash (recoverable)' >&2
    exit 2
fi

# Path traversal in rm commands
if [[ "$command" =~ rm[[:space:]].*\.\./ ]]; then
    echo '[Hook] BLOCKED: rm with path traversal detected.' >&2
    echo "[Hook] Command: $command" >&2
    exit 2
fi

exit 0
```

### Example: dangerous-commands.sh

```bash
#!/bin/bash
set -euo pipefail

# Project-specific dangerous commands hook
# Add/remove patterns as needed for your project

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')

dangerous_patterns=(
    "npm\s+.*--force\s+.*install"       # Force installs
    "pip\s+.*install\s+.*--no-cache"    # Non-repeatable installs
    "docker\s+.*system\s+prune"         # Docker cleanup
    "chmod\s+.*777"                     # Overly permissive permissions
    "chown\s+.*root:root"               # Root ownership changes
    # Add project-specific patterns below:
    # "pattern"  # Description
)

for pattern in "${dangerous_patterns[@]}"; do
    if [[ "$command" =~ $pattern ]]; then
        echo "[Hook] BLOCKED: $command" >&2
        echo '[Hook] Review dangerous pattern before executing.' >&2
        exit 2
    fi
done

exit 0
```

### Example: session-end.sh

```bash
#!/bin/bash
# Session End Hook - Transcript Preservation
# Preserves breadcrumbs (parentToolUseID, parentUuid) for hierarchy tracking
# Preserves raw thinking content for analysis

# --- Configuration ---
: "${CLAUDE_CONFIG_ROOT:=".claude"}"

# --- Read hook input from stdin ---
input=$(cat)
transcript_path=$(echo "$input" | jq -r '.transcript_path')
session_id=$(echo "$input" | jq -r '.session_id')

# --- Validation ---
if [ -z "$transcript_path" ]; then
  echo "[SessionEnd] ERROR: No transcript_path in hook input" >&2
  exit 0
fi

if [ ! -f "$transcript_path" ]; then
  echo "[SessionEnd] No transcript found at: $transcript_path" >&2
  exit 0
fi

# --- Determine session directory ---
LOCAL_SESSIONS_DIR="${CLAUDE_PROJECT_DIR}/${CLAUDE_CONFIG_ROOT}/workspace/sessions"

# Ensure sessions directory exists
if [ ! -d "$LOCAL_SESSIONS_DIR" ]; then
  mkdir -p "$LOCAL_SESSIONS_DIR"
fi

if [ -f "${LOCAL_SESSIONS_DIR}/.current_session" ]; then
  session_dir=$(cat "${LOCAL_SESSIONS_DIR}/.current_session")
else
  session_dir="${LOCAL_SESSIONS_DIR}/${session_id}"
  mkdir -p "$session_dir"
fi

# Validate session_dir is writable
if [ ! -w "$session_dir" ]; then
  echo "[SessionEnd] ERROR: Cannot write to session directory: $session_dir" >&2
  exit 0
fi

# --- Preservation jq filter ---
preserve() {
  jq -c '
    # 1. Keep breadcrumbs (parentToolUseID, parentUuid, uuid) for hierarchy tracking
    #    These link Level 3 execution back to Level 2 in deep hierarchies
    del(.isSidechain, .userType, .messageId, .toolUseID,
        .message?.usage, .message?.thinkingMetadata, .usage, .thinkingMetadata,
        .isSnapshotUpdate, .permissionMode, .service_tier, .stop_reason,
        .stop_sequence, .signature, .sessionId,
        .timestamp, .cwd, .version, .gitBranch) |

    # 2. Preserve raw thinking content (not just size)
    if .message?.content | type == "array" then
      .message.content = (.message.content | map(
        if .type == "thinking" then {type: "thinking", thinking: .thinking}
        else . end
      ))
    else . end
  '
}

# --- Apply preservation ---
transcript_dest="${session_dir}/raw-transcript.jsonl"
preserve < "$transcript_path" > "$transcript_dest"

# --- Copy to fixed latest file ---
latest_transcript="${LOCAL_SESSIONS_DIR}/previous-session.jsonl"
preserve < "$transcript_path" > "$latest_transcript"

# --- Record metadata ---
cat > "${session_dir}/end.jsonl" <<EOF
{"timestamp":"$(date -u +"%Y-%m-%dT%H:%M:%SZ")","event":"session_end","session_id":"${session_id}","transcript_size_bytes":$(wc -c < "$transcript_dest" 2>/dev/null || echo 0)}
EOF

# --- Cleanup ---
rm -f "${LOCAL_SESSIONS_DIR}/.current_session"

echo "[SessionEnd] Transcript preserved to: $transcript_dest"
exit 0
```

---

# Part 2: MCP Servers

> **Documentation Gap Identified**: The thecattoolkit_v3 project currently lacks comprehensive MCP documentation. This section serves as a placeholder acknowledging the gap.

## What is MCP?

**VERIFIED ✓** (Source: https://code.claude.com/docs/en/mcp)

**MCP = Model Context Protocol**

MCP is an open protocol that enables Claude Code to connect to external tools, resources, and prompts through standardized servers. MCP servers provide:

- **Tools**: Custom functions Claude can invoke (similar to built-in tools like Read, Write, Bash)
- **Resources**: Static or dynamic data sources (files, APIs, database queries)
- **Prompts**: Reusable prompt templates with parameter injection

### Key MCP Concepts

| Concept | Description | Example |
|:--------|:------------|:--------|
| **Tool** | Callable function with input/output schema | `search_web(query: string)` |
| **Resource** | Data source with URI addressing | `file:///project/config.json` |
| **Prompt** | Template with argument injection | `code_review(file_path)` |

---

## MCP vs Hooks: When to Use Which

| Aspect | Hooks | MCP Servers |
|:-------|:------|:------------|
| **Primary Purpose** | Security interception | External capabilities |
| **When It Fires** | Lifecycle events | Tool invocation |
| **Can Block Actions** | Yes (exit code 2) | No |
| **Context Access** | Hook input JSON | Tool parameters |
| **Typical Use Cases** | Security, validation, cleanup | Custom tools, APIs, integrations |
| **Configuration** | `.claude/settings.json` | `.claude/settings.json` + server files |

**Decision Matrix**:

- Use **Hooks** when you need to: block actions, enforce security, validate inputs, or run lifecycle automation
- Use **MCP** when you need to: add new tools, access external APIs, or provide dynamic data sources

### Complementary Usage

Hooks and MCP can work together:

```json
// Hook can intercept MCP tool calls
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "mcp__myserver__dangerous_tool",
        "hooks": [
          {
            "type": "command",
            "command": "./scripts/validate-mcp-call.sh"
          }
        ]
      }
    ]
  }
}
```

---

## MCP Tool Naming Conventions

**FINDING**: MCP tools use fully qualified names with the pattern: `ServerName:toolName` or `mcp__ServerName__toolName`

Examples:
- `exa:search` → Exa search tool
- `deepwiki:get-page` → DeepWiki page fetcher
- `mcp__simplewebfetch__simpleWebFetch` → SimpleWebFetch tool (internal format)

**Quality Guideline**: When referencing MCP tools in permissions, hooks, or documentation, use the fully qualified name to avoid ambiguity.

---

## MCP Configuration

**VERIFIED ✓** (Source: https://code.claude.com/docs/en/mcp)

### Enable MCP Servers in settings.json

```json
{
  "enabledMcpjsonServers": [
    "exa",
    "deepwiki",
    "simplewebfetch"
  ],
  "enableAllProjectMcpServers": true
}
```

### MCP Server Files

MCP servers are defined in `.claude/mcp.json` files:

```json
{
  "mcpServers": {
    "my-custom-server": {
      "command": "node",
      "args": ["path/to/server.js"],
      "env": {
        "API_KEY": "${MY_API_KEY}"
      }
    }
  }
}
```

---

## MCP Documentation Gap

**Status**: Documentation incomplete. The following sections need to be sourced from official documentation:

1. **MCP Server Development** - How to create custom MCP servers
2. **Tool Definition Schemas** - JSON schema for defining tools
3. **Resource Patterns** - Best practices for exposing resources
4. **Permission Model** - How MCP tools interact with permission system
5. **Context Isolation** - How MCP servers interact with conversation context

**Recommended Source**: https://code.claude.com/docs/en/mcp

**Note**: The thecattoolkit_v3 project includes MCP in component lists (foundation.md line 43) and uses MCP tools in examples, but lacks dedicated development documentation. This represents either:
- An intentional scope decision (MCP considered out-of-scope)
- A documentation gap to be filled

---

# Quick Reference

## Hook Decision Matrix

| Event | Type | Use Case |
|:------|:-----|:---------|
| SessionStart | command | Initialize session context |
| PreToolUse | command + prompt | Security validation |
| PostToolUse | command | Logging, cleanup |
| Stop | command | Archive, final cleanup |

## Component Comparison

| Component | Context | Best For |
|:----------|:--------|:---------|
| Skill | Shared | Heuristics, code standards |
| Skill (fork) | Isolated | Specialists (Linter, Auditor) |
| Task | Forked | Heavy lifting (refactoring, tests) |
| Command | Injected | Entry points, workflows |
| Hook | Event-driven | Security, validation, lifecycle |
| MCP Server | Tool provider | External capabilities, APIs |

---

## Cross-References

- **Understanding context modes** → [00-foundation.md](00-foundation.md) → Primitives Overview
- **Building context-based components** → [01-skills-context.md](01-skills-context.md)
- **Using subagents** → [02-subagents.md](02-subagents.md)
- **Quality verification** → [04-practices.md](04-practices.md) → Verify Phase
- **Lookup reference material** → [05-reference.md](05-reference.md)
