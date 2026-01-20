---
description: Start worker loop for multi-session Ralph
argument-hint: "--agent developer|qa"
---

# /ralph-worker

Start a **worker** loop (Developer or QA) in Terminal 2 or 3. Workers poll for task assignments from the coordinator and execute them.

## Usage

```bash
# Terminal 2: Developer Worker
/ralph-worker --agent developer

# Terminal 3: QA Worker
/ralph-worker --agent qa
```

## Required Options

| Option | Description |
|--------|-------------|
| `--agent developer` | Implement features and run feedback loops |
| `--agent qa` | Validate implementations with tests |

## What It Does

### Developer Worker

1. **Waits for coordinator** to create session files
2. **Registers presence** with heartbeat
3. **Polls for tasks** assigned to "developer"
4. **Implements feature**:
   - Reads task specs from `current-task.json`
   - Explores codebase
   - Writes code following project patterns
5. **Runs feedback loops**:
   - `npm run type-check`
   - `npm run lint`
6. **Commits work** with Ralph format
7. **Updates task** to "ready_for_qa"

### QA Worker

1. **Waits for coordinator** to create session files
2. **Registers presence** with heartbeat
3. **Polls for tasks** with status "ready_for_qa"
4. **Runs validation**:
   - `npm run type-check`
   - `npm run lint`
   - `npm run test`
   - `npm run build`
   - Browser testing (if Playwright available)
5. **Updates PRD**:
   - If pass: `passes: true`, status to "passed"
   - If fail: Add bugs, status to "needs_fixes"
6. **Commits validation results**

## Coordination Flow

```
PM Coordinator                   Developer Worker                    QA Worker
     │                                   │                                   │
     ├─ Assigns feat-002 ────────────>│                                   │
     │                                   ├─ Implement feature               │
     │                                   ├─ Run type-check, lint             │
     │                                   ├─ Commit work                      │
     │                                   ├─ Set status: ready_for_qa ────────>│
     │                                   │                                   ├─ Run validation
     │                                   │                                   ├─ Update PRD
     │<──────────────────────────────────┼────────── passes:true ───────────┤
     │                                   │                                   │
     ├─ Mark feat-002 complete          │                                   │
     ├─ Select next task ───────────────>│                                   │
```

## Session Files (Read Only)

Workers read these files to get work:

| File | Purpose |
|------|---------|
| `.claude/session/coordinator-state.json` | Main state (tasks, agents) |
| `.claude/session/current-task.json` | Active task details |

Workers update these files:

| File | Purpose |
|------|---------|
| `prd.json` | Mark `passes: true` when validated |
| `.claude/session/coordinator-state.json` | Update heartbeat, status |

## Polling Intervals

- **Workers**: Poll every 5 seconds
- **Heartbeat timeout**: 60 seconds (coordinator will warn if worker dies)

## Example Session

### Developer Worker

```bash
$ /ralph-worker --agent developer

Waiting for coordinator...
[15s] Coordinator connected.
Registered as developer.

[30s] Received task: feat-002 (Camera Follow System)
Reading current-task.json...
Specifications: Implement smooth camera that follows player vehicle

Exploring codebase...
Found: src/components/game/camera/ directory
Found: gameStore.ts has playerPosition state

Implementing PlayerCamera.tsx...
- Added useFrame hook for smooth follow
- Configured offset and damping

Running type-check... ✓ PASS
Running lint... ✓ PASS

Committing: [ralph] [developer] feat-002: Implement camera follow system

Updated task status to ready_for_qa

Waiting for next task...
```

### QA Worker

```bash
$ /ralph-worker --agent qa

Waiting for coordinator...
[15s] Coordinator connected.
Registered as qa.

[70s] Found task: feat-002 (status: ready_for_qa)
Reading current-task.json...
Acceptance criteria:
✓ Camera follows vehicle position
✓ Smooth damping on movement
✓ Camera maintains playable angle

Running type-check... ✓ PASS
Running lint... ✓ PASS
Running test... ✓ PASS
Running build... ✓ PASS
Browser testing...
- Navigated to http://localhost:3000
- No console errors
- Camera follows vehicle smoothly ✓

All checks passed!

Updating prd.json: feat-002.passes = true
Committing: [ralph] [qa] feat-002: Validation PASSED

Waiting for next task...
```

## Commit Formats

### Developer Commits

```
[ralph] [developer] feat-002: Implement camera follow system

- Added PlayerCamera.tsx with smooth damping
- Connected to player position from gameStore
- Configured offset (0, 5, 10) and follow speed (0.1)

PRD: feat-002 | Agent: developer | Iteration: 3
```

### QA Commits (Pass)

```
[ralph] [qa] feat-002: Validation PASSED

- TypeScript: pass
- Lint: pass
- Tests: pass
- Build: pass
- Manual: pass

PRD: feat-002 | Agent: qa | Iteration: 4
```

### QA Commits (Fail)

```
[ralph] [qa] feat-002: Validation FAILED

Bugs found:
- [CRITICAL] TypeScript: Property 'position' undefined on line 15
  Steps: Run npm run type-check
  Expected: pass
  Actual: "Cannot read property 'position' of undefined"

- [MEDIUM] Test: Camera jitter when vehicle stops
  Steps: Accelerate then release W
  Expected: Smooth stop
  Actual: Camera bounces

PRD: feat-002 | Agent: qa | Retry: 1 | Iteration: 4
```

## Handling Bugs

When you receive a task with `status == "needs_fixes"`:

1. Read bugs from `current-task.json`
2. Fix each bug in priority order
3. Re-run feedback loops
4. Commit with `[ralph] [developer] feat-XXX: Bug fixes`
5. Set status back to "ready_for_qa"

## Stopping the Worker

Workers will exit when:
- Coordinator status becomes "completed"
- Coordinator status becomes "terminated"
- Coordinator status becomes "max_iterations_reached"

To stop all sessions:
```bash
/cancel-ralph
```

## See Also

- [`/ralph-coordinator`](ralph-coordinator.md) - Coordinator command
- [`.claude/orchestration/agent-handoff.md`](../orchestration/agent-handoff.md) - Handoff protocol
- [`agents/developer/AGENT.md`](../../agents/developer/AGENT.md) - Developer instructions
- [`agents/qa/AGENT.md`](../../agents/qa/AGENT.md) - QA instructions
