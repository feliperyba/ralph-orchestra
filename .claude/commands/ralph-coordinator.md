---
description: Start PM coordinator loop for multi-session Ralph
argument-hint: "[--max-iterations N] [--completion-promise TEXT]"
---

# /ralph-coordinator

Start the **PM coordinator** loop in Terminal 1. This is the orchestrator that assigns tasks to workers and tracks progress.

## CRITICAL: PM Coordinator MUST NOT CODE

**The PM Agent is NOT ALLOWED to:**
- Edit source code files (.ts, .tsx, .js, .jsx, .css, .html, etc.)
- Edit configuration files (tsconfig.json, vite.config.ts, package.json, etc.)
- Run build commands or test commands
- Fix bugs or implement features directly

**The PM Agent MAY:**
- Edit `.claude/session/*` state files only
- Edit `prd.json` ONLY for task status updates (passes, status, assignment metadata)
- Read source files for context
- Research online for specifications
- Coordinate between Developer and QA

## Usage

```bash
/ralph-coordinator --max-iterations 30
```

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `--max-iterations N` | 50 | Maximum loop iterations (safety limit) |
| `--completion-promise TEXT` | "RALPH_COMPLETE" | Phrase signaling completion |

## What It Does

1. **Initializes session**:
   - Creates `.claude/session/` directory
   - Creates `coordinator-state.json` with session info
   - Creates `handoff-log.json` for tracking
   - Creates `progress.txt` for human-readable log

2. **Reviews PRD** (`prd.json`):
   - Finds incomplete items (`passes: false`)
   - Checks task dependencies
   - Selects next task by priority

3. **Assigns tasks to workers**:
   - Creates `current-task.json` with task details
   - Updates `coordinator-state.json` with assignment
   - Logs handoff to `handoff-log.json`

4. **Monitors progress**:
   - Checks worker heartbeats
   - Waits for QA validation results
   - Tracks completion status

5. **Detects completion**:
   - When all PRD items have `passes: true`
   - Runs final validation
   - Outputs `<promise>RALPH_COMPLETE</promise>`

## Prerequisites

- **Terminal 1 only** - This is the coordinator terminal
- Workers should be started in separate terminals:
  - Terminal 2: `/ralph-worker --agent developer`
  - Terminal 3: `/ralph-worker --agent qa`

## Session Files

| File | Purpose |
|------|---------|
| `.claude/session/coordinator-state.json` | Main coordination state |
| `.claude/session/current-task.json` | Active task assignment |
| `.claude/session/handoff-log.json` | Agent handoff history |
| `.claude/session/progress.txt` | Human-readable log |

## Task Selection Priority

The coordinator selects tasks using this priority order:

1. **Architectural** - Affects entire codebase
2. **Integration** - Reveals incompatibilities early
3. **Spike/Unknown** - Exploratory work
4. **Functional** - Standard features
5. **Polish** - UI, optimization, docs

## Example Output

```
Initializing Ralph session...
Session ID: ralph-1737270400
Created .claude/session/coordinator-state.json
Created .claude/session/handoff-log.json
Created .claude/session/progress.txt

Waiting for workers to connect...

[00:10] Developer connected (lastSeen: 2026-01-19T12:00:10Z)
[00:15] QA connected (lastSeen: 2026-01-19T12:00:15Z)

[00:20] Selected feat-002: Camera Follow System
Priority: HIGH (architectural)
Dependencies: feat-001 (PASSED)
Assigned to developer

[00:45] Developer completed feat-002
[00:50] QA validating feat-002...
[01:05] feat-002 PASSED all checks
Updated prd.json: feat-002.passes = true

[01:10] Selected test-001: E2E Test Suite Setup
Priority: HIGH (integration)
Assigned to qa

...continues...

[30:00] All 9 tasks passed!
Running final validation...
✓ TypeScript: pass
✓ Build: pass

<promise>RALPH_COMPLETE</promise>

Session complete!
```

## Stopping the Coordinator

To stop an active coordinator loop, run in any terminal:
```bash
/cancel-ralph
```

The coordinator will:
- Set status to "terminated"
- Wait for current task to complete
- Exit gracefully
- Preserve all progress

## See Also

- [`/ralph-worker`](ralph-worker.md) - Worker command
- [`.claude/orchestration/multi-session-coordinator.md`](../orchestration/multi-session-coordinator.md) - Full protocol
- [`agents/pm/AGENT.md`](../../agents/pm/AGENT.md) - PM agent instructions
