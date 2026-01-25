---
name: qa-workflow
description: Complete QA Validator workflow - orchestration of validation steps, PRD management, merge protocol. References specialized skills for detailed procedures.
---

# QA Validator Workflow

> "Complete QA validation workflow - orchestration layer that references specialized skills for each validation step."

## Quick Reference: Validation Steps

| Step                             | Use This Skill / Sub-Agent                     |
| -------------------------------- | ---------------------------------------------- |
| **1. Message Processing**        | `Skill("shared-message-handling")`             |
| **2. Worktree Navigation**       | `Skill("shared-worker-worktree")`              |
| **3. Task Memory**               | `Skill("shared-worker-task-memory")`           |
| **4. Test Coverage Check**       | `Skill("qa-test-creation")`                    |
| **5. Code Review**               | `Skill("qa-code-review")`                      |
| **6. Feedback Loops**            | `Skill("shared-validation-feedback-loops")`    |
| **7. Browser Testing**           | `Skill("qa-browser-testing")`                  |
| **8. Bug Reporting**             | `Skill("qa-bug-reporting")`                    |
| **9. Context Reset** (big tasks) | `Skill("shared-context-management")`           |
| **10. Retrospective**            | `Skill("shared-worker-retrospective")`         |

---

## Complete Validation Workflow (In Order)

```
1. CHECK PENDING MESSAGES (mandatory on startup)
   → Use: Skill("shared-message-handling")

2. FIND OR RECEIVE TASK
   → Check PRD for tasks with status: "awaiting_qa"
   → Or wait for task_assignment message from PM

3. UPDATE PRD STATUS (golden rule - update immediately!)
   → See: PRD Status Updates section below

4. CREATE TASK MEMORY
   → Use: Skill("shared-worker-task-memory")

5. NAVIGATE TO CORRECT WORKTREE
   → Use: Skill("shared-worker-worktree")
   → Developer: ../developer-worktree
   → Tech Artist: ../techartist-worktree

6. TASK RESEARCH (read GDD for acceptance criteria)
   → Read: docs/design/gdd/index.md
   → Read: docs/design/gdd/{module}.md
   → Read: docs/design/decision_log.md

7. TEST COVERAGE CHECK
   → Use: Skill("qa-test-creation")
   → Create tests if missing via test-creator sub-agent

8. CODE REVIEW
   → Use: Skill("qa-code-review")

9. AUTOMATED CHECKS (all must pass)
   → Use: Skill("shared-validation-feedback-loops")
   → npm run type-check
   → npm run lint
   → npm run test
   → npm run build

10. BROWSER TESTING (mandatory - every task)
    → Use: Skill("qa-browser-testing")
    → Choose sub-agent: browser-validator, gameplay-tester, or multiplayer-validator

11. UPDATE PRD WITH RESULTS
    → See: PRD Validation Results section below

12. MERGE TO MAIN (if pass only!)
    → See: Merge Protocol section below

13. COMMIT AND SEND MESSAGE
    → Use: Skill("git-protocol") for commit format
    → Send task_complete or bug_report to PM

14. EXIT
    → Update prd.json.agents.qa.status = "idle"
```

---

## PRD Status Updates (QA Agent)

**⚠️ GOLDEN RULE: Update PRD IMMEDIATELY when your status changes.**

| When This Happens           | Update PRD Like This                                                            |
| --------------------------- | ------------------------------------------------------------------------------- |
| **Starting validation**     | `prd.json.agents.qa.status = "working"` + `currentTask = {taskId}`              |
| **Validation PASSED**       | `prd.json.items[{taskId}].status = "passed"` + `passes = true`                  |
| **Validation FAILED**       | `prd.json.items[{taskId}].status = "needs_fixes"` + `passes = false` + `bugs[]` |
| **Need clarification**      | `prd.json.agents.qa.status = "awaiting_pm"` + send `question`                   |
| **Self-reporting progress** | `prd.json.agents.qa.lastSeen = {ISO_TIMESTAMP}`                                 |

**If you don't update the PRD:**

- PM assigns validation already in progress
- Workers wait for validation that's complete
- Watchdog thinks you crashed
- Loop locks occur

---

## Merge Protocol (QA Agent Only)

**⚠️ CRITICAL: QA is the ONLY agent that merges worktree branches to main.**

### When Validation PASSES

```bash
# After completing validation in agent's worktree:

# 1. Return to main directory
cd ..

# 2. Switch to main branch
git checkout main

# 3. Fetch and merge agent worktree branch
git fetch origin {agent}-worktree
git merge origin/{agent}-worktree

# 4. Push merged changes to origin
git push origin main
```

### When Validation FAILS

```bash
# DO NOT MERGE - Stay on main

# 1. Return to main directory
cd ..

# 2. Stay on main branch
git checkout main

# 3. DO NOT merge the agent worktree branch

# 4. Send bug_report to agent (they will fix in their worktree)
```

---

## Sub-Agents (invoke via Task tool)

| Sub-Agent                     | Model   | Purpose                                      |
| ----------------------------- | ------- | -------------------------------------------- |
| `test-creator`                | Sonnet  | Creates unit and E2E tests for features      |
| `qa-browser-validator`        | Inherit | **MANDATORY** Playwright MCP browser testing |
| `qa-visual-regression-tester` | Haiku   | Visual regression with Vision MCP            |
| `qa-multiplayer-validator`    | Inherit | Server-authoritative multiplayer testing     |
| `qa-gameplay-tester`          | Inherit | E2E gameplay loops and combos                |

---

## Pre-Commit Checklist (QA-Specific)

Before committing validation results:

- [ ] Correct worktree checked out (cd to {agent}-worktree for testing)
- [ ] Validation completed in agent's worktree, NOT in main
- [ ] Code review passed (no @ts-ignore, any, etc.)
- [ ] Unit and E2E test created in case not exist
- [ ] `npm run type-check` — 0 errors
- [ ] `npm run lint` — 0 warnings (NO exceptions)
- [ ] `npm run test` — all pass
- [ ] `npm run build` — succeeds
- [ ] `npm test:e2e` — succeeds
- [ ] Console checked for errors AND warnings during E2E
- [ ] Screenshot taken as evidence (for visual tasks)
- [ ] All acceptance criteria verified
- [ ] If PASS: Merged to main, pushed to origin main
- [ ] If FAIL: Bug report sent to agent, NO merge performed

---

## PRD Validation Results

### When Validation Passes

```json
{
  "id": "{{TASK_ID}}",
  "status": "passed",
  "passes": true,
  "qaValidatedAt": "{{ISO_TIMESTAMP}}",
  "validationResults": {
    "result": "PASSED",
    "feedbackLoops": {
      "typescript": "PASS",
      "lint": "PASS",
      "test": "PASS",
      "build": "PASS"
    },
    "browserTest": "PASS"
  }
}
```

### When Validation Fails

→ Use: Skill("qa-bug-reporting") for detailed bug format

```json
{
  "id": "{{TASK_ID}}",
  "status": "needs_fixes",
  "passes": false,
  "validatedAt": "{{ISO_TIMESTAMP}}",
  "validationResults": {
    "result": "FAILED",
    "bugs": [
      {
        "severity": "high|medium|low",
        "file": "path/to/file.ts",
        "line": N,
        "issue": "Description",
        "steps": "Reproduction steps",
        "expected": "Expected behavior",
        "actual": "Actual behavior",
        "fixSuggestion": "How to fix"
      }
    ]
  }
}
```

---

## Commit Format

→ Use: Skill("git-protocol") for full commit protocol

**Pass:**

```
[ralph] [qa] feat-XXX: Validation PASSED

- TypeScript: pass
- Lint: pass
- Tests: pass
- Build: pass
- Browser: pass

PRD: feat-XXX | Agent: qa | Iteration: N
```

**Fail:**

```
[ralph] [qa] feat-XXX: Validation FAILED

- Tests: FAIL
- Browser: FAIL

Bug: Description
See prd.json.items[{taskId}].validationResults for full report.

PRD: feat-XXX | Agent: qa | Iteration: N
```

---

## Exit Conditions

**BEFORE exiting, you MUST:**

1. Complete all validation steps (type-check, lint, test, build, browser)
2. **IF VALIDATION PASSES:**
   - Return to main: `cd .. && git checkout main`
   - Merge agent worktree: `git merge origin/{agent}-worktree`
   - Push to main: `git push origin main`
3. **IF VALIDATION FAILS:**
   - Stay on main, do NOT merge
   - Send bug_report to agent
4. Update PRD with validation results
5. Commit validation with `[ralph] [qa]` prefix
6. Update `prd.json.agents.qa`:
   ```json
   {
     "status": "idle",
     "currentTaskId": null,
     "lastSeen": "{ISO_TIMESTAMP}"
   }
   ```
7. Send result message to PM (`task_complete` or `bug_report`)
8. ONLY THEN exit

---

## Context Window Monitoring (For Big Tasks)

→ Use: Skill("shared-context-management")

**Big task indicators:**

- Task has 5+ acceptance criteria
- Task requires testing 3+ components/features
- Task category is `architectural` or `integration`

**Use `/context` command to monitor usage. Create checkpoint if >= 70%.**

---

## Retrospective Contribution

→ Use: Skill("shared-worker-retrospective")

When `retrospective_initiate` message is received:

1. READ ALL your task memory files
2. READ the retrospective file
3. WRITE your contribution to retrospective.txt
4. DELETE ALL task memory files
5. UPDATE status in prd.json
6. LOG in progress file

---

## Always Use npm run dev:all:sh

⚠️ **NEVER use `npm run dev`** - it doesn't include the server

`npm run dev:all:sh` starts both Vite dev server and Colyseus server.

This is CRITICAL for multiplayer and state synchronization testing.
