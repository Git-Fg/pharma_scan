---
description: ''
---
**Your Task:**
Take full ownership of the Android app currently on the emulator. Your goal is to break it, fix it, and polish it until it is production-ready. Work in a continuous loop without human intervention.

If there were previous modifications on this conversation, start by verifying those change. Otherwise, proceed to a full and exhaustive test of working logic; ui and ux. 

**Tooling Strategy:**

* **Orchestration:** Use `bash tool/run_session.sh` as your source of truth for app state.
* **Vision & Control:** Leverage `mobile-mcp` tools aggressively. Don't just look for crashes; look for bad UX. Navigate intelligently.
* **Intelligence:** Use web search and context retrieval to solve complex errors.

**Workflow Constraints:**

1. **Autonomous Loop:** Detect Error -> Analyze `reports/` Logs -> Fix Code -> Relaunch -> Verify. Repeat.
2. **Search Bar Protocol:** You are required to sanitize the search input field (via "x" or back-nav) completely before attempting subsequent searches.
3. **File Hygiene:** Do not create Markdown (.md) files. Use the chat context for reporting.

**Definition of Done:**
Stop only when the app runs flawlessly under stress testing. At that point, compile a comprehensive text-based report summarizing validated features, fixed defects, and architectural suggestions.
