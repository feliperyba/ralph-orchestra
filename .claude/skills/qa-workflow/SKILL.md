---
name: qa-workflow
description: Complete QA Validator workflow - orchestration of validation steps, PRD management, merge protocol with Agile phase integration.
---

# QA Validator Workflow

> "Complete QA validation workflow - orchestration layer that references specialized skills for each validation step."

## Quick Reference

| Step                       | Skill / Sub-Agent                           |
| -------------------------- | ------------------------------------------- |
| **1. Message Processing**  | `Skill("shared-message-handling")`          |
| **2. Worktree Navigation** | `Skill("shared-worker-worktree")`           |
| **3. Task Memory**         | `Skill("shared-worker-task-memory")`        |
| **4. Test Coverage Check** | `Skill("qa-test-creation")`                 |
| **5. Code Review**         | `Skill("qa-code-review")`                   |
| **6. Feedback Loops**      | `Skill("shared-validation-feedback-loops")` |
| **7. Browser Testing**     | `Skill("qa-browser-testing")`               |
| **8. Bug Reporting**       | `Skill("qa-reporting-bug-reporting")`       |
| **9. Context Reset**       | `Skill("shared-context-management")`        |

---

## Agile Phase Integration

| Agile Phase            | QA Workflow Step  | Action                                         |
| ---------------------- | ----------------- | ---------------------------------------------- |
| **Sprint Planning**    | Task Research     | Read GDD, check acceptance criteria            |
| **Daily Standup**      | PRD Status Update | Update `prd.json.agents.qa.status` immediately |
| **Sprint Review**      | Validation        | Code review → Feedback loops → Browser testing |
| **Retrospective**      | Bug Reporting     | Document findings with evidence                |
| **Definition of Done** | Exit              | Merge (PASS) or ProblemReport (FAIL)           |

---

<validation-pipeline>

## Complete Validation Workflow (In Order)

```
1. CHECK PENDING MESSAGES → Skill("shared-message-handling")
2. FIND OR RECEIVE TASK → Check PRD for status: "awaiting_qa"
3. UPDATE PRD STATUS → See PRD Updates section below
4. CREATE TASK MEMORY → Skill("shared-worker-task-memory")
5. NAVIGATE TO WORKTREE → Skill("shared-worker-worktree")
6. TASK RESEARCH → Read docs/design/gdd/
7. TEST COVERAGE CHECK → Skill("qa-test-creation")
8. CODE REVIEW → Skill("qa-code-review")
9. AUTOMATED CHECKS → Skill("shared-validation-feedback-loops")
10. BROWSER TESTING → Skill("qa-browser-testing") + sub-agent
11. UPDATE PRD RESULTS → See Validation Results section
12. MERGE TO MAIN → Only if PASS (see Merge Protocol)
13. COMMIT AND MESSAGE → [ralph] [qa] prefix + send to PM
14. EXIT → Update prd.json.agents.qa.status = "idle"
```

</validation-pipeline>

---

## PRD Status Updates (Daily Standup Protocol)

**⚠️ GOLDEN RULE: Update PRD IMMEDIATELY when your status changes.**

<examples>
<example>
<input>Starting validation on task feat-123</input>
<action>Update PRD</action>
<expected>
```json
{
  "prd.json.agents.qa": {
    "status": "working",
    "currentTask": "feat-123",
    "lastSeen": "2025-01-26T10:30:00Z"
  }
}
```
</expected>
</example>

<example>
<input>Validation passed - all criteria met</input>
<action>Update PRD</action>
<expected>
```json
{
  "prd.json.items['feat-123']": {
    "status": "passed",
    "passes": true,
    "qaValidatedAt": "2025-01-26T11:45:00Z"
  }
}
```
</expected>
</example>

<example>
<input>Validation failed - console errors found</input>
<action>Update PRD</action>
<expected>
```json
{
  "prd.json.items['feat-123']": {
    "status": "needs_fixes",
    "passes": false,
    "validatedAt": "2025-01-26T11:30:00Z",
    "validationResults": {
      "result": "FAILED",
      "bugs": [...]
    }
  }
}
```
</expected>
</example>

<example>
<input>Need clarification on acceptance criteria</input>
<action>Update PRD + send Query</action>
<expected>
```json
{
  "prd.json.agents.qa": {
    "status": "awaiting_pm"
  }
}
```
Send `Query` message to PM with specific question.
</expected>
</example>
</examples>

**If you don't update the PRD:**

- PM assigns validation already in progress
- Workers wait for validation that's complete
- Watchdog thinks you crashed
- Loop locks occur

---

## Merge Protocol (Definition of Done)

**⚠️ CRITICAL: QA is the ONLY agent that merges worktree branches to main.**

### When Validation PASSES

```bash
# After completing validation in agent's worktree:
cd ..
git checkout main
git fetch origin {agent}-worktree
git merge origin/{agent}-worktree
git push origin main
```

### When Validation FAILS

```bash
# DO NOT MERGE - Stay on main
cd ..
git checkout main
# DO NOT merge - send ProblemReport to agent instead
```

---

<details>
<summary>Sub-Agents Reference</summary>

| Sub-Agent                     | Model   | Purpose                                      |
| ----------------------------- | ------- | -------------------------------------------- |
| `test-creator`                | Sonnet  | Creates unit and E2E tests for features      |
| `qa-browser-validator`        | Inherit | **MANDATORY** Playwright MCP browser testing |
| `qa-visual-regression-tester` | Haiku   | Visual regression with Vision MCP            |
| `qa-multiplayer-validator`    | Inherit | Server-authoritative multiplayer testing     |
| `qa-gameplay-tester`          | Inherit | E2E gameplay loops and combos                |

</details>

---

## Pre-Commit Checklist (Definition of Done)

- [ ] Correct worktree checked out
- [ ] Validation completed in agent's worktree, NOT in main
- [ ] Code review passed (no @ts-ignore, any, etc.)
- [ ] Tests exist for feature (created if missing)
- [ ] `npm run type-check` — 0 errors
- [ ] `npm run lint` — 0 warnings (NO exceptions)
- [ ] `npm run test` — all pass
- [ ] `npm run build` — succeeds
- [ ] Console checked for errors AND warnings during browser testing
- [ ] All acceptance criteria verified
- [ ] If PASS: Merged to main, pushed to origin main
- [ ] If FAIL: Bug report sent, NO merge performed

---

## PRD Validation Results (Sprint Review Output)

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

→ Use: `Skill("qa-reporting-bug-reporting")` for detailed bug format

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

<details>
<summary>Commit Format Details</summary>

Use: `Skill("shared-atomic-updates")` for commit protocol

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

- {Failed check}: FAIL
- Bug: {Description}

See prd.json.items[{taskId}].validationResults for full report.
PRD: feat-XXX | Agent: qa | Iteration: N
```

</details>

---

## Exit Conditions (V2)

**BEFORE exiting, you MUST:**

1. Complete all validation steps
2. **IF PASS:** Merge to main, push to origin main
3. **IF FAIL:** Stay on main, send `ProblemReport` to agent
4. Update PRD with validation results
5. Commit with `[ralph] [qa]` prefix
6. Update `prd.json.agents.qa` to idle with currentTaskId: null
7. Send result message to PM
8. ONLY THEN exit

---

<details>
<summary>Context & Retrospective Details</summary>

### Context Window Monitoring

→ Use: `Skill("shared-context-management")`

**Big task indicators:**

- 5+ acceptance criteria
- 3+ components/features to test
- Category is `architectural` or `integration`

Use `/context` command to monitor. Create checkpoint if >= 70%.

### Retrospective Contribution

→ Use: `Skill("shared-worker-retrospective")`

When `Retrospective` message received:

1. Read all task memory files
2. Read the retrospective file
3. Write contribution to retrospective.txt
4. Delete task memory files
5. Update status in prd.json
6. Send `Retrospective` back to PM

</details>

---

## References

| Resource | Purpose |
|----------|---------|
| `shared-ralph-core` | Session structure, status values |
| `shared-ralph-event-protocol` | V2 event-driven messaging |
| `docs/powershell/v2-architecture.md` | 🆕 V2 infrastructure: Event Sourcing, Actor Model, CQRS |
| `.claude/protocols/event-driven.md` | 🆕 V2 event-driven protocol details |
| `qa-router` | Complete QA skill catalog |

---
