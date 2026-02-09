---
name: qa-validation-workflow
description: Full validation workflow for QA agent. Runs automated checks (type-check, lint, test, build) and browser testing with E2E tests. Use when validating implementation after code review.
category: validation
---

# Validation Workflow Skill

> "Trust but verify – automated tests catch regressions, browser tests catch reality."

## When to Use This Skill

Use when:

- `currentTask.status === "ready_for_qa"`
- Developer has committed changes
- Ready to validate implementation

---

## MANDATORY: Worktree Verification (CRITICAL - FIRST STEP)

**⚠️ CRITICAL: You MUST validate from the CORRECT worktree where the code was implemented!**

### Step 1: Determine Which Worktree to Validate

**Check the task's `agent` field to know which worktree contains the code:**

| Task Agent | Worktree Path            | Branch Name           | Command to Navigate         |
| ---------- | ------------------------ | --------------------- | --------------------------- |
| {agent}  | `../{agent}-worktree`  | `{agent}-worktree`  | `cd ../{agent}-worktree`  |

**⚠️ NEVER validate from main if the task was implemented in a worktree!**

### Step 2: If You Ran Tests in Wrong Worktree

**Stop immediately and report the error:**

1. The validation results are INVALID
2. Send message to PM: "ERROR: Validated wrong worktree. Re-running..."
3. Navigate to correct worktree
4. Re-run ALL validation steps

**Remember: QA validates the agent's worktree, NOT main (unless task.agent = "qa")**

---


## Validation Pipeline

```
      [GATE: E2E tests MUST exist - CREATE if missing]
                  │
                  ▼
┌─────────────┐    ┌──────────┐    ┌──────────────┐    ┌──────────┐
│ Type Check  │───▶│   Lint   │───▶│ TEST CHECK   │───▶│  Build   │
│    (tsc)    │    │ (eslint) │    │  (Coverage)  │    │  (vite)  │
└─────────────┘    └──────────┘    └──────────────┘    └──────────┘
       │                │                   │                  │
       ▼                ▼                   ▼                  ▼
   Pass/Fail       Pass/Fail          Tests Missing?      Pass/Fail
       │                │                   │                  │
       │                │            ┌──────┴──────┐          │
       │                │            │             │          │
       │                │         Create Tests   CANNOT PASS  │
       │                │            │          WITHOUT TEST  │
       │                │            │             │          │
       │                └────────────┴─────────────┘          │
       │                                                      │
       └──────────────────────────────────────────────────────┘
                                          │
                                          ▼
                              ┌─────────────────────┐
                              │  E2E TEST EXECUTION │ ◄── MANDATORY GATE
                              │  (npm run test:e2e)  │     NO EXCEPTIONS
                              └─────────────────────┘
                                          │
                              ┌──────────┴──────────┐
                              │                     │
                         PASS                   FAIL
                          │                        │
                          ▼                        ▼
                    Update PRD            Fix either the code or the test, following test plan.
```

**⚠️ MANDATORY RULE: If Unit/E2E tests don't exist, CREATE THEM before validation can pass.**

## **DO NOT mark validation as PASSED without Unit/ E2E tests covering the task acceptance criteria.**

## Progressive Guide

### Test Coverage Check (BEFORE Automated Checks)

1. **Load qa-test-creation skill**

   ```bash
   Skill("qa-test-creation")
   ```

2. **Identify modified source files**

   ```bash
   # Get files changed in this task
   git diff --name-only HEAD~5 | grep '^src/'
   # Or read from task context
   ```

3. **For EACH modified source file, check test coverage:**

   **Unit Test Check:**
   - Source: `src/components/game/player/index.ts`
   - Test must exist: `src/tests/components/game/player/index.test.ts`
   - If missing: **BLOCK** - invoke test-creator

   **E2E Test Check:**
   - Check if `tests/e2e/{feature}-suite.spec.ts` exists
   - Example: `tests/e2e/gameplay-suite.spec.ts`, `tests/e2e/ui-suite.spec.ts`
   - If missing: **BLOCK** - invoke test-creator

### Acceptance Criteria Verification

For each acceptance criterion in `current-task-qa.json` (acceptanceCriteria array):

```markdown
## Acceptance Criteria Verification

### Criterion 1: "Vehicle responds to WASD input"

- **Test**: Pressed W, A, S, D keys
- **Result**: ✅ PASS / ❌ FAIL
- **Notes**: Vehicle moves forward, left, backward, right correctly

### Criterion 2: "Physics simulation runs at 60Hz"

- **Test**: Checked physics debug panel
- **Result**: ✅ PASS / ❌ FAIL
- **Notes**: Physics running at target rate
```

## Anti-Patterns

❌ **DON'T:**

- Assume automated tests are sufficient
- Mark as passed without running E2E tests
- Ignore console warnings/errors

✅ **DO:**

- Always run E2E tests for validation
- Verify each acceptance criterion via test output
- Review test screenshots as evidence
- Document any concerns in bug notes
- Check console for errors in test output
