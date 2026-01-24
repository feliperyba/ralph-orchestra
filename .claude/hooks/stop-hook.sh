#!/bin/bash
# Ralph Wiggum Stop Hook
# Blocks normal exit, creates self-referential loop by feeding same prompt back
#
# This hook is called when Claude attempts to exit. It checks the Ralph session
# state and either allows exit or signals to continue the loop.
#
# Environment Variables:
#   RALPH_COMPLETION_PROMISE - Phrase that signals completion (default: RALPH_COMPLETE)
#   RALPH_MAX_ITERATIONS - Maximum iterations before forced exit (default: 50)
#
# Session State:
#   prd.json.session - Main session state (SINGLE SOURCE OF TRUTH)
#   .claude/session/last-output.txt - Last Claude output for completion detection
#   .claude/session/context-reset-count.txt - Track number of context resets

set -e

# Configuration
SESSION_DIR=".claude/session"
PRD_JSON="prd.json"
LAST_OUTPUT="$SESSION_DIR/last-output.txt"
RESET_COUNT_FILE="$SESSION_DIR/context-reset-count.txt"
COMPLETION_PROMISE=${RALPH_COMPLETION_PROMISE:-"RALPH_COMPLETE"}
CONTEXT_RESET_PROMISE="CONTEXT_RESET"
MAX_ITERATIONS=${RALPH_MAX_ITERATIONS:-50}

# Initialize reset counter
if [ ! -f "$RESET_COUNT_FILE" ]; then
    echo "0" > "$RESET_COUNT_FILE"
fi

# Ensure session directory exists
mkdir -p "$SESSION_DIR"

# Initialize prd.json.session if doesn't exist
if [ -f "$PRD_JSON" ]; then
    # Check if session section exists
    if ! jq -e '.session' "$PRD_JSON" &> /dev/null; then
        # Add session section to existing prd.json
        jq --arg max "$MAX_ITERATIONS" --arg promise "$COMPLETION_PROMISE" \
            '.session = {
                sessionId: "ralph-'"$(date +%Y%m%d-%H%M%S)"'",
                startedAt: "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
                maxIterations: ($max | tonumber),
                iteration: 1,
                completionPromise: $promise,
                status: "running",
                currentTask: null,
                stats: {totalTasks: 0, completed: 0, failed: 0, commits: 0}
            }' "$PRD_JSON" > "$PRD_JSON.tmp" && mv "$PRD_JSON.tmp" "$PRD_JSON"
    fi
else
    # Create new prd.json with session section
    cat > "$PRD_JSON" << EOF
{
  "project": "",
  "version": "1.0.0",
  "session": {
    "sessionId": "ralph-$(date +%Y%m%d-%H%M%S)",
    "startedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "maxIterations": $MAX_ITERATIONS,
    "iteration": 1,
    "completionPromise": "$COMPLETION_PROMISE",
    "status": "running",
    "currentTask": null,
    "stats": {
      "totalTasks": 0,
      "completed": 0,
      "failed": 0,
      "commits": 0
    }
  },
  "agents": {
    "pm": {"status": "idle", "lastSeen": null, "currentTaskId": null, "pid": 0},
    "developer": {"status": "idle", "lastSeen": null, "currentTaskId": null, "pid": 0},
    "techartist": {"status": "idle", "lastSeen": null, "currentTaskId": null, "pid": 0},
    "qa": {"status": "idle", "lastSeen": null, "currentTaskId": null, "pid": 0},
    "gamedesigner": {"status": "idle", "lastSeen": null, "currentTaskId": null, "pid": 0}
  },
  "items": []
}
EOF
fi

# Read current state (using jq if available, otherwise basic parsing)
if command -v jq &> /dev/null; then
    STATUS=$(jq -r '.session.status // "running"' "$PRD_JSON" 2>/dev/null || echo "running")
    ITERATION=$(jq -r '.session.iteration // 1' "$PRD_JSON" 2>/dev/null || echo "1")
    MAX=$(jq -r '.session.maxIterations // '"$MAX_ITERATIONS" "$PRD_JSON" 2>/dev/null || echo "$MAX_ITERATIONS")
else
    # Fallback without jq - simple grep (looks for session.status)
    STATUS=$(grep -o '"status":[[:space:]]*"[^"]*"' "$PRD_JSON" 2>/dev/null | head -1 | cut -d'"' -f4 || echo "running")
    ITERATION=$(grep -o '"iteration":[[:space:]]*[0-9]*' "$PRD_JSON" 2>/dev/null | head -1 | grep -o '[0-9]*$' || echo "1")
    MAX=$(grep -o '"maxIterations":[[:space:]]*[0-9]*' "$PRD_JSON" 2>/dev/null | head -1 | grep -o '[0-9]*$' || echo "$MAX_ITERATIONS")
fi

# ============================================================================
# FORCED RESTART GUARDRAIL
# ============================================================================
# This hook ALWAYS signals restart (exit 42) after each response.
# Only max iterations allows actual exit - the external loop script
# (agent-loop.ps1) becomes the primary authority on when to stop.
# ============================================================================

# Check max iterations FIRST - this is the ONLY exit condition
if [ "$ITERATION" -gt "$MAX" ]; then
    echo "=== Max iterations reached ($ITERATION/$MAX) ==="
    echo "Ralph loop stopping..."
    # Update status in prd.json.session
    if command -v jq &> /dev/null; then
        jq '.session.status = "max_iterations_reached"' "$PRD_JSON" > "$PRD_JSON.tmp" && mv "$PRD_JSON.tmp" "$PRD_JSON"
    fi
    exit 0
fi

# Check for terminated status (manual cancellation via /cancel-ralph)
if [ "$STATUS" = "terminated" ] || [ "$STATUS" = "terminating" ]; then
    echo "=== Ralph loop terminated (status: $STATUS) ==="
    exit 0
fi

# Check for context reset promise - track it but still continue
if [ -f "$LAST_OUTPUT" ]; then
    if grep -q "<promise>$CONTEXT_RESET_PROMISE</promise>" "$LAST_OUTPUT" 2>/dev/null; then
        # Increment reset counter
        RESET_COUNT=$(cat "$RESET_COUNT_FILE" 2>/dev/null || echo "0")
        RESET_COUNT=$((RESET_COUNT + 1))
        echo "$RESET_COUNT" > "$RESET_COUNT_FILE"
        echo "--- Context reset detected (reset #$RESET_COUNT) ---"
        # Clear the promise from last-output to prevent re-triggering
        > "$LAST_OUTPUT"
    fi
fi

# Check for completion promise - update status but still continue
# The external loop script will detect completion and stop
if [ -f "$LAST_OUTPUT" ]; then
    if grep -q "<promise>$COMPLETION_PROMISE</promise>" "$LAST_OUTPUT" 2>/dev/null; then
        echo "--- Completion promise detected, updating status ---"
        if command -v jq &> /dev/null; then
            jq '.session.status = "completed"' "$PRD_JSON" > "$PRD_JSON.tmp" && mv "$PRD_JSON.tmp" "$PRD_JSON"
        fi
        # Note: We still continue - external loop will detect "completed" status
    fi
fi

# Increment iteration counter in prd.json.session
if command -v jq &> /dev/null; then
    jq '.session.iteration += 1' "$PRD_JSON" > "$PRD_JSON.tmp" && mv "$PRD_JSON.tmp" "$PRD_JSON"
fi

# ALWAYS signal restart - exit code 42 means "run again with same prompt"
echo "=== Ralph iteration $ITERATION/$MAX - forcing restart ==="
exit 42
