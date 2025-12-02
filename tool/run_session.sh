#!/bin/bash
#
# run_session.sh (v1.0 - Unified):
# - Manages a single Flutter run session for autonomous validation.
# - Self-cleaning: If a PID file exists from a previous run, it terminates
#   that process before starting a new one.
# - Starts a new Flutter app instance in the background.
# - Logs all output to a unique, session-specific file.
# - Stores the new process PID.
# - Outputs the SESSION_ID for use by the calling script.
#
# Usage:
#   bash tool/run_session.sh        # Start a new session (from project root)
#   bash tool/run_session.sh stop   # Stop the current session only
#

set -e

# Get the project root directory (one level up from tool/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PID_FILE="$PROJECT_ROOT/reports/flutter.pid"
DEVICE_ID="emulator-5554"

# --- Stop Mode Handling ---
if [ "$1" = "stop" ]; then
    if [ -f "$PID_FILE" ]; then
        OLD_PID=$(cat "$PID_FILE")
        echo "Terminating Flutter session (PID: $OLD_PID)..." >&2
        kill "$OLD_PID" > /dev/null 2>&1 || true
        rm "$PID_FILE"
        echo "Session terminated successfully." >&2
        exit 0
    else
        echo "No active session found." >&2
        exit 0
    fi
fi

# --- Self-Cleaning Logic ---
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    echo "Found stale PID file for process $OLD_PID. Terminating previous session..." >&2
    # Kill the process; hide errors if it's already gone.
    kill "$OLD_PID" > /dev/null 2>&1 || true
    rm "$PID_FILE"
    echo "Previous session terminated." >&2
    # If this script was only called for cleanup, exit now.
    # The presence of a running process implies we are starting a new one.
fi

# --- Session Initialization ---
SESSION_ID=$(date +%Y-%m-%d_%H-%M-%S)
LOG_FILE="$PROJECT_ROOT/reports/run_${SESSION_ID}.log"

echo "Starting new session: $SESSION_ID" >&2
echo "Log file: $LOG_FILE" >&2

# Output SESSION_ID to stdout for the calling agent
echo "$SESSION_ID"

# --- Log File Cleanup ---
# Clean up old log files, keeping only the 2 newest (so we'll have 3 total after creating the new one)
mkdir -p "$PROJECT_ROOT/reports"
if ls "$PROJECT_ROOT/reports/run_*.log" 1> /dev/null 2>&1; then
    ls -t "$PROJECT_ROOT/reports/run_*.log" 2>/dev/null | tail -n +3 | xargs rm -f 2>/dev/null || true
fi

# --- Background Process Execution ---
(
    echo "--- Autonomous Validation Session ID: $SESSION_ID ---" > "$LOG_FILE"
    echo "--- Started at: $(date -u +%Y-%m-%dT%H:%M:%SZ) ---" >> "$LOG_FILE"

    echo "[SETUP] Launching Flutter App on device '$DEVICE_ID'..." >> "$LOG_FILE" 2>&1
    # Run flutter from project root and redirect all output (stdout and stderr) to the log file
    cd "$PROJECT_ROOT"
    flutter run -d "$DEVICE_ID" >> "$LOG_FILE" 2>&1

) & # Run the entire sub-shell in the background

# --- PID Management ---
FLUTTER_PID=$!
echo "$FLUTTER_PID" > "$PID_FILE"
echo "Flutter app launched in background with PID: $FLUTTER_PID" >&2

# Wait for the app to signal readiness to prevent race conditions
echo "Waiting for app to become ready..." >&2
timeout 60s bash -c "until [ -f \"$LOG_FILE\" ] && [ -s \"$LOG_FILE\" ]; do sleep 0.5; done; tail -f \"$LOG_FILE\" | grep -m 1 \"A Dart VM Service\""

echo "App is ready. Script finished." >&2
exit 0

