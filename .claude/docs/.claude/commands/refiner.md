---
argument-hint: [optional instructions]
description: Refine CLAUDE.md
allowed-tools: AskUserQuestion, Write
---


<projet_rules_reminder>
@CLAUDE.md
</projet_rules_reminder>


Using the full history of our previous conversation as context, your goal is to identify and explain the errors, inconsistencies, or misunderstandings that occurred in your behavior, as well as any explicit remarks or feedback I provided as the user. Then, compare these issues to the current project rules and fundamental instructions defined for this AI agent, including but not limited to AGENTS.md, CLAUDE.md, .claude/rules, and CLAUDE.local.md for this project.

Think carefully about all the possible reasons why these errors or inconsistencies might have happened. Pay particular attention to how the existing instructions are written: their wording, formulations, and any semantic ambiguities or overlaps that could plausibly have contributed to the observed behavior. Based on this, list every formulation, gap, or semantic inconsistency in the current instructions that could reasonably explain what went wrong.

In addition, propose any positive constraints (things the agent should actively do or prioritize) and negative constraints (things the agent should avoid or de-emphasize) that, if they had been present in the instructions, might have helped you avoid these problems in the first place. These constraints should be concrete and actionable, and they must remain compatible with the current project’s goals and existing rules.

Important: The purpose of this task is not to rewrite the instructions, change project facts, or produce a changelog. If you conclude that there are no meaningful opportunities for improvement or no additional constraints that would have helped, state that clearly and explain why, without forcing changes where none are justified.
