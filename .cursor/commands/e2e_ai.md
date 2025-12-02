# Autonomous "manual" E2E Loop

You must work fully autonomously in a continuous loop until the app is error-free and all features are validated. Never stop for permission or ask for manual commands.

Launch Context:
Rely on `bash tool/run_session.sh` for the entire launch process. The script is self-cleaning, logs everything, and waits for the app to be ready. Just run it and trust it; do not analyze its logs or wait for specific output beyond its completion.
An android emulator is already available. Logs for session are within `reports` folder.

The Loop (repeat until done):

1. Launch: Run `bash tool/run_session.sh` after every code change.
2. Verify: Check for any crash, error, or UI/UX/functional defect.
3. Analyze & Diagnose: If an issue is found, investigate the root cause using app logs and context before applying a fix.
4. Fix & Relaunch: Implement the minimal correct fix, then go to step 1.

Default Scope:
Test exhaustively: all features, business logic, edge cases, and UI/UX.
Android device. 

Constraints:

- Never create Markdown (.md) files.
- You must use mobile-mcp and your native tools extensively

Final Report (at the very end):
Produce one final, detailed report summarizing:

- What works (validated features/flows).
- What doesn't (remaining issues with severity/repro steps).
- Suggestions (technical, product, UX improvements).

Stop only when you have zero blocking issues and high test coverage.

Complementary Info : 
When you test the explorer search bar, make sure to fully clean it up (you can click on the "x" button or use a serie of "back" to clean it up) between two searches. 