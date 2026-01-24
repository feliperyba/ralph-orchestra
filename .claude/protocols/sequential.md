# Sequential Handoff Protocol

Token-efficient single-agent orchestration where only one agent runs at a time. Agents communicate via handoff signals.

## Architecture Overview

```
┌─────────┐            ┌─────────┐            ┌─────────┐
│   PM    │ ─handoff─▶ │Developer│ ─handoff─▶ │   QA    │
│  Agent  │            │  Agent  │            │  Agent  │
└─────────┘            └─────────┘            └─────────┘
     ▲                                              │
     └──────────────────────────────────────────────┘
                    (one at a time)
```

**Key Principle**: Only ONE agent session is active. Handoffs occur via signal file.

## Handoff Signal Format

**File**: `.claude/session/handoff-signal.json`

```json
{
  "targetAgent": "qa",
  "context": "Validate feat-001 - Implementation complete",
  "timestamp": "2026-01-20T12:00:00Z"
}
```

**Terminal Output** (backup for watchdog):

```
HANDOFF:qa:Ready for validation
```

## Handoff Types

### 1. PM → Developer (Task Assignment)

**PM Action**: Update `prd.json` and write handoff signal

```json
{
  "targetAgent": "developer",
  "context": "Task feat-001 assigned - Implement vehicle physics",
  "timestamp": "2026-01-20T12:00:00Z"
}
```

**Developer Detects**: On session start, reads `handoff-signal.json`

1. Sees `targetAgent === "developer"`
2. Reads task details from `prd.json.items[{taskId}]`
3. Updates `prd.json.agents.developer.status = "working"`
4. Begins implementation

### 2. Developer → QA (Implementation Complete)

**Developer Action**: Commit work, update PRD, write handoff signal

```bash
# Commit work
git add .
git commit -m "[ralph] [developer] feat-001: Implement vehicle physics

- Added Rapier physics body
- Connected keyboard controls

PRD: feat-001 | Agent: developer | Iteration: 1"
```

```json
{
  "targetAgent": "qa",
  "context": "Validate feat-001 - Implementation complete. See prd.json.items[feat-001]",
  "timestamp": "2026-01-20T12:15:00Z"
}
```

### 3. QA → PM (Validation Passed)

**QA Action**: Run validation, commit results, write handoff signal

```bash
# All checks passed
npm run type-check && npm run lint && npm run test && npm run build

git commit --allow-empty -m "[ralph] [qa] feat-001: Validation PASSED

- TypeScript: pass
- Lint: pass
- Tests: pass
- Build: pass

PRD: feat-001 | Agent: qa | Iteration: 2"
```

```json
{
  "targetAgent": "pm",
  "context": "Task feat-001 passed validation. Ready for next task.",
  "timestamp": "2026-01-20T12:20:00Z"
}
```

### 4. QA → Developer (Validation Failed)

**QA Action**: Document bugs, write handoff signal

```json
{
  "targetAgent": "developer",
  "context": "Fix bugs in feat-001 - Vehicle falls through floor. See prd.json.items[feat-001].bugs",
  "timestamp": "2026-01-20T12:20:00Z"
}
```

### 5. Any Agent → PM (Question)

When clarification is needed:

```json
{
  "targetAgent": "pm",
  "context": "Need clarification on feat-001 - What physics material for wheels?",
  "timestamp": "2026-01-20T12:10:00Z"
}
```

## State Transition Diagram

```
        ┌─────────────┐
        │   pending   │
        └──────┬──────┘
               │ PM assigns
               ▼
        ┌─────────────┐
        │  assigned   │
        └──────┬──────┘
               │ Developer accepts
               ▼
        ┌─────────────┐
        │ in_progress │
        └──────┬──────┘
               │ Developer completes
               ▼
        ┌─────────────┐
        │ready_for_qa │
        └──────┬──────┘
               │
         ┌─────┴─────┐
         │           │
      QA PASS     QA FAIL
         │           │
         ▼           ▼
    ┌──────────┐ ┌──────────┐
    │  passed  │ │needs_fix │
    └────┬─────┘ └────┬─────┘
         │            │
         │            └─> Returns to in_progress
         │
         ▼
    ┌──────────┐
    │completed │
    └──────────┘
```

## Advantages vs Event-Driven

| Aspect          | Sequential                 | Event-Driven               |
|-----------------|----------------------------|---------------------------|
| Token Usage     | Low (one agent at a time)  | Higher (parallel agents)  |
| Speed           | Slower (serial execution)  | Faster (parallel work)    |
| Complexity      | Simple (file signals)      | Complex (message queues)  |
| Debugging       | Easy (linear flow)         | Harder (concurrent)       |
| Resource Usage  | Minimal                    | Higher                    |

## Best Practices

1. **Always write handoff-signal.json** - Primary communication method
2. **Also output HANDOFF:agent:context** - Backup for watchdog detection
3. **Update prd.json before handoff** - Ensure state is current
4. **Commit code changes** - Don't leave uncommitted work
5. **Check for pending handoff** on session start - Look for `handoff-signal.json`

## Handoff Log

All handoffs are logged to `.claude/session/handoff-log.json`:

```json
{
  "handoffs": [
    {
      "timestamp": "2026-01-20T12:00:00Z",
      "from": "pm",
      "to": "developer",
      "task": "feat-001",
      "reason": "task_assignment"
    },
    {
      "timestamp": "2026-01-20T12:15:00Z",
      "from": "developer",
      "to": "qa",
      "task": "feat-001",
      "reason": "implementation_complete",
      "commit": "a1b2c3d"
    }
  ]
}
```

## Session Complete Signal

When all tasks are done, PM outputs:

```
<promise>RALPH_COMPLETE</promise>
```

And updates `prd.json.session.status = "completed"`

All workers detect this and exit gracefully.
