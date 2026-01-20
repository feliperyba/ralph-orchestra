---
description: Start autonomous Ralph loop with multi-agent orchestration
argument-hint: "[--max-iterations N] [--completion-promise TEXT] [--role coordinator|worker] [--agent pm|developer|qa]"
---

# /ralph

Start autonomous development loop using Ralph Wiggum technique with multi-agent coordination.

## Multi-Session Setup

The Ralph Wiggum system uses **three separate terminal sessions** for autonomous development:

```bash
# Terminal 1: PM Agent (Coordinator)
/ralph --role coordinator --max-iterations 30

# Terminal 2: Developer Agent (Worker)
/ralph --role worker --agent developer

# Terminal 3: QA Agent (Worker)
/ralph --role worker --agent qa
```

## Options

| Option | Description | Default |
|--------|-------------|---------|
| `--role` | `coordinator` or `worker` | Required |
| `--agent` | For workers: `pm`, `developer`, or `qa` | Required for workers |
| `--max-iterations` | Maximum loop iterations | `50` |
| `--completion-promise` | Phrase signaling completion | `RALPH_COMPLETE` |
| `--session` | Session identifier | Auto-generated |

## How Multi-Session Ralph Works

### Coordinator (PM Agent)
1. Reviews `prd.json` for incomplete items
2. Selects next highest-priority task
3. Assigns task to Developer via `.claude/session/coordinator-state.json`
4. Monitors for QA validation results
5. When QA passes, marks PRD item `passes: true`
6. When all items pass, outputs `<promise>RALPH_COMPLETE</promise>`

### Worker Agents (Developer, QA)
1. Poll `.claude/session/coordinator-state.json` for assignments
2. Perform assigned work
3. Update state file with progress
4. Commit work with standard format
5. Return to waiting state

## Session Files

| File | Purpose |
|------|---------|
| `prd.json` | Project requirements with `passes` field |
| `progress.txt` | Session progress log |
| `.claude/session/coordinator-state.json` | Shared coordination state |
| `.claude/session/current-task.json` | Active task details |
| `.claude/session/handoff-log.json` | Handoff history |

## Completion Conditions

Loop outputs `<promise>RALPH_COMPLETE</promise>` when:
- All PRD items have `passes: true`
- All tests pass (`npm run test`)
- No linting errors (`npm run lint`)
- Build succeeds (`npm run build`)
- TypeScript compilation passes (`npm run type-check`)

## Safety

- `--max-iterations` prevents infinite loops
- Each agent commits work before handoff
- Failed validation returns task to Developer
- Session state preserved if interrupted

## Example Session Startup

```bash
# Step 1: Start the PM coordinator first
/ralph --role coordinator --max-iterations 30

# Step 2: In a new terminal, start the Developer worker
/ralph --role worker --agent developer

# Step 3: In a third terminal, start the QA worker
/ralph --role worker --agent qa
```

The coordinator will begin assigning tasks immediately. Workers will poll for assignments and work autonomously.

## See Also

- `/ralph-hitl` - Single iteration mode for learning
- `/cancel-ralph` - Cancel active loop
- `.claude/orchestration/multi-session-coordinator.md` - Detailed coordination protocol
- `agents/*/AGENT.md` - Agent-specific Ralph instructions
