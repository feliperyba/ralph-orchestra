---
description: Cancel active Ralph loop and preserve progress
---

# /cancel-ralph

Stops the active Ralph Wiggum loop across all sessions.

## Usage

```bash
/cancel-ralph
```

## What Happens

1. **Sets termination flag** in `.claude/session/coordinator-state.json`
2. **Current iteration completes** its current task
3. **All sessions exit** gracefully after committing
4. **Progress is preserved** in `progress.txt` and `prd.json`

## Session State

The termination state is stored in:

```json
{
  "status": "terminating",
  "terminatedAt": "2026-01-19T12:30:00Z",
  "reason": "user_requested"
}
```

## Resume After Cancellation

To resume a cancelled session:

```bash
# Restart coordinator with same session ID
/ralph --role coordinator --session previous-session-id

# Workers will automatically reconnect
```

## Emergency Stop

If Ralph is not responding to normal cancellation:

```bash
# Set termination flag manually
echo '{"status":"terminated","reason":"emergency"}' > .claude/session/coordinator-state.json
```

## Progress Preservation

All work completed before cancellation is preserved:
- Commits remain in git history
- `prd.json` retains `passes: true` for completed items
- `progress.txt` logs all completed work

## Example

```bash
$ /cancel-ralph

Cancelling Ralph loop...
Session: threejs-sprint-1
Current iteration: 7/30

Waiting for current task to complete...
✓ Developer completed feat-002
✓ QA validated feat-002

Loop cancelled.
Progress preserved in progress.txt
7 tasks completed, 3 remaining

To resume: /ralph --role coordinator --session threejs-sprint-1
```

See Also

- `/ralph` - Start autonomous loop
- `.claude/session/coordinator-state.json` - Session state file
