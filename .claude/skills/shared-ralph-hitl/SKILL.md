---
name: shared-ralph-hitl
description: Single Ralph iteration with full visibility for learning. Use proactively to learn Ralph's behavior before autonomous mode.
category: orchestration
tags: [hitl, learning, single-iteration, visibility]
dependencies: [shared-ralph-core, shared-validation-feedback-loops]
---

# Ralph HITL (Human-In-The-Loop) Mode

> "Learn Ralph's behavior with full visibility before trusting autonomous mode."

## When to Use This Skill

Use **when**:
- Learning Ralph's behavior for the first time
- Refining your prompt based on observations
- Building confidence in the system
- Catching issues before AFK mode

---

## Quick Start

<examples>
Example 1: Start HITL session
```
Read progress.txt → Read prd.json
Select task → Explain priority choice
Explore files → Show patterns
Implement → Show changes
Validate → Run feedback loops
Propose commit → Wait for approval
Update state → STOP (single iteration)
```

Example 2: Ask for approval
```
I propose the following commit:

[ralph] feat-001: Add user authentication

- Implemented JWT token validation
- Added login form component

Files changed:
- src/auth/login.tsx (new)
- src/auth/jwt.ts (new)

Do you approve this commit?
```

Example 3: Priority reasoning
```
I selected feat-003 (Database setup) over feat-001 (UI components)
because:
1. Architectural task takes priority
2. Other tasks depend on database layer
3. Blocks multiple downstream tasks

Do you agree with this choice?
```
</examples>

---

## HITL vs AFK

| Aspect | HITL (This Mode) | AFK (Autonomous) |
|--------|------------------|------------------|
| Visibility | Full, show everything | Minimal, logs only |
| Approval | Wait for commit approval | Auto-commit |
| Iterations | Single (STOP after) | Continuous (max-iter) |
| Purpose | Learning, refinement | Production work |
| Command | `/ralph-hitl` | `/ralph` |

---

## Your Process (Single Iteration)

### Step 1: Review Progress & PRD (Show Me)

1. **Read `progress.txt`** - Understand what's already done
2. **Read `prd.json`** - See available tasks
3. **Select task** - Explain priority reasoning
4. **Show acceptance criteria** - Verify understanding
5. **Ask for agreement** - "Do you agree with this choice?"

**Priority Order**: architectural > integration > spike > functional > polish

### Step 2: Explore (Show Me)

- Tell which files you'll read
- Show patterns from existing code
- Ask if anything else should be considered

### Step 3: Implement (Show Me)

- Make **small, focused changes**
- Explain decisions as you go
- Show exactly what's changing

### Step 4: Validate - ALL Feedback Loops

Run ALL before committing:
- `npm run type-check` - 0 errors
- `npm run lint` - 0 warnings
- `npm run test` - All pass
- `npm run build` - Success

**DO NOT commit if any fail.** Show errors and ask how to proceed.

### Step 5: Propose Commit (Wait for Approval)

- Show exact commit message
- Show files changed (git diff)
- **WAIT for approval**

**Commit format:**
```
[ralph] feat-XXX: Brief description

- Change 1
- Change 2

PRD: feat-XXX | Iteration: N
```

### Step 6: Update State & STOP

- Update `prd.json` → `passes: true`
- Append to `progress.txt`
- **STOP here** - Single iteration only

---

## Important Rules

- **Do NOT loop** - ONE iteration only
- **Show everything** - Full visibility
- **Wait for approval** - Don't auto-commit
- **Answer questions** - Explain reasoning
- **Quality over speed** - Small steps compound

---

## What to Watch For

While observing Ralph:
- Does it pick the right task priority?
- Are commits focused or too large?
- Do feedback loops catch issues?
- Is code quality what you expect?

Use observations to refine your prompt for AFK mode.

---

## Transitioning to AFK

Once comfortable:
1. Refine prompt based on HITL observations
2. Set modest max iterations (10-20) for first AFK run
3. Review commits when you return
4. Iterate on prompt

---

## Related Skills

| Skill | Purpose |
|-------|---------|
| `shared-ralph-core` | Session structure |
| `shared-validation-feedback-loops` | Quality gates |
| `shared-cancel-ralph` | Cancel active loop |
