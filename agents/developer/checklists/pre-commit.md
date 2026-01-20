---
name: pre-commit
description: Checklist before committing code changes
category: validation
---

# Pre-Commit Checklist

## Mandatory Checks

Run ALL before committing:

```bash
npm run type-check && npm run lint && npm run test && npm run build
```

- [ ] **Type Check** — `npm run type-check` passes with 0 errors
- [ ] **Lint** — `npm run lint` passes with 0 warnings
- [ ] **Test** — `npm run test` all tests pass
- [ ] **Build** — `npm run build` succeeds

## Code Quality

- [ ] No `@ts-ignore` or `@ts-expect-error` without justification
- [ ] No `any` types without comment explaining why
- [ ] No `eslint-disable` without explanation
- [ ] No console.log (use proper logging if needed)
- [ ] No hardcoded values (use constants or config)
- [ ] No commented-out code

## React/R3F Specific

- [ ] useEffect dependencies are correct
- [ ] useMemo/useCallback used for expensive computations
- [ ] Refs used for animated values (not useState)
- [ ] Components handle null/undefined gracefully
- [ ] No memory leaks (cleanup in useEffect)

## Physics Specific (if applicable)

- [ ] Collision groups configured
- [ ] RigidBody types appropriate
- [ ] Forces scaled by deltaTime
- [ ] Debug view tested

## Commit Message Format

```
[ralph] [developer] {{PRD_ID}}: Brief description

- Change 1
- Change 2
- Change 3

PRD: {{PRD_ID}} | Agent: developer | Iteration: {{N}}
```

**Example:**

```
[ralph] [developer] feat-001: Implement vehicle physics

- Added Rapier physics body to Vehicle component
- Connected keyboard input to vehicle controls
- Configured physics materials for floor interaction

PRD: feat-001 | Agent: developer | Iteration: 3
```

## After Commit

Update task status:

```json
// current-task.json
{
  "status": "ready_for_qa",
  "implementedAt": "{{ISO_TIMESTAMP}}",
  "commit": "{{COMMIT_HASH}}"
}
```

Update heartbeat:

```json
// coordinator-state.json
{
  "agents": {
    "developer": {
      "status": "idle",
      "lastSeen": "{{ISO_TIMESTAMP}}"
    }
  }
}
```
