---
name: shared-cancel-ralph
description: Cancel active Ralph loop. Use when you need to stop the autonomous development session.
category: orchestration
tags: [cancel, stop, shutdown, session]
dependencies: [shared-ralph-core]
---

# Cancel Ralph

> "Cancel active Ralph loop – progress preserved in prd.json and progress.txt"

## When to Use This Skill

Use **when**:
- You need to stop the autonomous Ralph loop
- You want to pause development work
- You observe unwanted behavior

---

## Quick Start

<examples>
Example 1: Cancel with report
```
Ralph loop cancelled.

Session: feature-development
Iterations completed: 5/200
Tasks completed: 3/10

Progress preserved in:
- prd.json.items (completed tasks marked)
- prd.json.session (session state)
- progress.txt (session log)

To resume: /ralph
```

Example 2: Cancel after specific error
```
Ralph loop cancelled due to build failure.

Session: feature-development
Iterations completed: 12/200
Tasks completed: 5/10

Error: Build failed - missing dependency

Progress preserved. Fix issue and resume with /ralph
```
</examples>

---

## Action

1. Read `prd.json.session` if it exists
2. Update status to `"terminated"`
3. Report current progress

---

## Report Format

```
Ralph loop cancelled.

Session: {session name}
Iterations completed: {n}/{max}
Tasks completed: {n}/{total}

Progress preserved in:
- prd.json.items (completed tasks still marked)
- prd.json.session (session state)
- progress.txt (session log)

To resume: /ralph
```

---

## After Cancel

- All completed tasks remain marked in `prd.json`
- Session state preserved in `prd.json.session`
- Progress log preserved in `progress.txt`
- Resume with `/ralph` when ready

---

## Related Skills

| Skill | Purpose |
|-------|---------|
| `shared-ralph-core` | Session structure |
| `shared-ralph-hitl` | Single iteration mode |
