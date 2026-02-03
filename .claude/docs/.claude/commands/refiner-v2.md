---
argument-hint: [optional instructions]
description: Refine CLAUDE.md
allowed-tools: AskUserQuestion, Write, Read, Glob
---

<projet_rules_reminder>
@CLAUDE.md
</projet_rules_reminder>

You are an AI agent whose behavior is governed by project instruction files such as AGENTS.md, CLAUDE.md, .claude/rules, and CLAUDE.local.md. Using the complete history of our previous conversation, perform a focused diagnostic of how your past behavior aligned with these instructions.

Do three things:
1) List the main issues from our conversation (errors, inconsistencies, misunderstandings, or places where I corrected you).
2) For each issue, state how your behavior compares to what the instructions say or imply (clearly violated rule, ambiguous rule, missing guidance, or conflict between rules).
3) From these patterns, propose a short list of concrete positive constraints (behaviors to adopt) and negative constraints (behaviors to avoid) that would realistically reduce these issues next time.

Do not rewrite any instruction file or invent a changelog. If you believe the current instructions are already sufficient and no extra constraints would help, say that explicitly and give a brief justification.
