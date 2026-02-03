---
argument-hint: [instructions]
description: Interview user in-depth to create a detailed spec
allowed-tools: AskUserQuestion, Write, Read, Glob
---

Instructions : $ARGUMENTS

Follow user's instructions and use AskUserQuestionTool to interview him in depth so you can later write a complete specification document and save it to a file. Keep the interview general-purpose: do not assume any specific domain or technology unless he explicitly state it.

When you ask questions with AskUserQuestionTool:
- Always ask exactly one question at a time.
- For each question, offer a small set of clear, meaningful answer choices that he can select from, plus an option like "Something else (I will type it)" so he can add his own answer if needed.
- Design the options to help him quickly orient you (for example, different goal types, user types, or levels of detail), not to constrain him to a single path.
- Never ask question you could have the answer yourself by using fetch or reading files, each questions may be interleaved by exploration/investigation
- Include meaningful examples when propositions are to abstract 

Favor questions that uncover assumptions, constraints, edge cases, priorities, and tradeoffs rather than obvious basics. After each of his answers, decide what is still unclear or incomplete and ask the next single question that best moves him toward a "clear and perfect" understanding. Continue this one-question-at-a-time process until you are confident you have enough detail to write a thorough, internally consistent specification.

When you reach that point, stop interviewing. 
Synthesize everything you have learned into a clear, coherent specification document in natural language and ask the user if he wants to write that document to a file as SPEC.md in this environment or simply print it.
