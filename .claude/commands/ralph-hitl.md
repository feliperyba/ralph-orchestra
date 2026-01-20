---
description: Start single Ralph iteration (HITL mode) for learning and prompt refinement
---

# /ralph-hitl

Run **ONE iteration** of Ralph for human-in-the-loop development.

## Purpose

HITL (Human-in-the-Loop) mode is designed for:
- Learning Ralph behavior before going AFK
- Prompt refinement and debugging
- High-risk architectural decisions
- Understanding multi-agent coordination

## How It Differs From /ralph

| Feature | /ralph | /ralph-hitl |
|---------|--------|-------------|
| Auto-loop | Yes | No |
| Max iterations needed | Yes | No |
| Visibility | Minimal | Full |
| Waits for approval | No | Yes |
| Best for | AFK work | Learning |

## What Happens

1. **Review State**: Show current PRD status and progress.txt
2. **Select Task**: Explain which task was selected and why
3. **Explore**: Show which files will be examined
4. **Implement**: Build the feature with full visibility
5. **Validate**: Run feedback loops and show results
6. **Propose Commit**: Show the commit that would be made
7. **Wait**: Pause for your approval before proceeding

## Usage

```bash
/ralph-hitl
```

You can specify which agent to simulate:

```bash
/ralph-hitl --agent developer
/ralph-hitl --agent qa
/ralph-hitl --agent pm
```

## Example Output

```
=== RALPH HITL MODE ===

Session: threejs-sprint-1
Iteration: 3/30

[PM] Reviewing PRD...
Found 8 incomplete items
Selected: feat-001 (Vehicle Physics) - HIGH PRIORITY

[DEVELOPER] Exploring codebase...
Found: src/components/game/player/
Pattern: Use @react-three/rapier like in Floor.tsx

[DEVELOPER] Implementing...
Creating: Vehicle.tsx
Modifying: gameStore.ts

[DEVELOPER] Running feedback loops...
✓ TypeScript: No errors
✓ Lint: No warnings

[DEVELOPER] Proposed commit:
[ralph] [developer] feat-001: Implement vehicle physics

- Added Rapier physics body to Vehicle component
- Connected keyboard input to vehicle controls
- Configured physics materials for floor interaction

PRD: feat-001 | Agent: developer | Iteration: 3

Awaiting your approval... (or provide feedback)
```

## Best Practices

1. **Start with HITL** - Use HITL mode first to validate your prompt
2. **Review carefully** - Check each step before approving
3. **Refine prompt** - Adjust based on what you see
4. **Then go AFK** - Once comfortable, switch to `/ralph` for autonomous runs

## Transition to AFK Mode

Once satisfied with HITL behavior:

```bash
# Start the full autonomous loop
/ralph --role coordinator --max-iterations 30
```

See Also

- `/ralph` - Full autonomous multi-session mode
- `.claude/orchestration/multi-session-coordinator.md` - Coordination protocol
