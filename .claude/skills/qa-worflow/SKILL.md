---
name: qa-workflow
description: Complete QA Validator workflow orchestration. References specialized skills for each validation step. Load at session startup for full protocol.
---

# QA Workflow

> "Orchestration layer for QA validation - delegate to specialized skills for each step."

## Core Responsibilities

- **Load the proper skills and tools** - Always ensure you have the right skills loaded for each task. Run tasks and subagents in parallel when possible to optimize time.
- **Full validation** - type-check, lint, test, build, automated testing
- **Write and Fix Tests** - You must write unit and e2e tests for every task
- **E2E regression** - Run `npm test:e2e` before MCP validation
- **Visual regression** - Screenshot comparison with Vision MCP
- **Code quality review** - Check for code quality smells, anti-patterns, wrong design patterns and implementation issues
- **Server-authoritative validation** - Verify client and server multiplayer architecture, in case game project
- **Bug reporting** - Structured bug reports with evidence
- **Specifications validation** - Check implementation vs design specifications

## Validation Workflow

**PRE-REQUISITE: You should already have loaded the `shared-worktree` skill and be in the correct worktree directory before starting this workflow!**

1. **UPDATE STATUS FILE** (MANDATORY - First step)

2. **RUN VALIDATION FEEDBACK LOOPS**
   - Follow the guidelines of `qa-validation-workflow` and proceed with steps

3. **TEST COVERAGE CHECK**
   - `Skill("qa-test-creation")` - Check if tests exist for modified files
   - If tests missing: MUST invoke `test-creator` sub-agent before proceeding
4. **IF BLOCKED**
   - Update state: `state.status = "awaiting_pm""`
   - Document blocker in task data at prd.json

5. **TEST PASS** - Commit everything and merge it to the `master` branch

6. **TEST DO NOT PASS** - Check your skills and decision tree

7. **COMMIT** - At the end of the task, commit all changes to the current branch

8. **SEND TO PM**

9. **EXIT**

**IF BLOCKED**
- Update state: `state.status = "awaiting_pm"`, `state.lastSeen = "{ISO_TIMESTAMP}"`
- Document blocker in task prd.json
- Send message to PM with details
- Send message to watchdog to update status
- Exit and wait

## Quick Decision Tree

```text

START VALIDATION
│
├─→ Tests missing? ──► Skill("qa-test-creation")
│
├─→ Run tests ─────────► Skill("qa-validation-workflow")
│ │
│ └─→ Tests fail? ──► Analyze (see Test Failure Decision Tree below)
│
├─→ Code quality check ──► Skill("qa-code-review")
│
├─→ Browser testing ────► Skill("qa-browser-testing")
│ └─► Choose sub-agent based on task type
│
└─→ Report result ─────► Skill("qa-reporting-bug-reporting")

```

---

## Test Failure Decision Tree

```text

                    TESTS FAIL
                        │
        ┌───────────────┴───────────────┐
        │                               │
    Test Code Issue?              Game Code Issue?
        │ YES                          │ YES
        ▼                               ▼

Fix and Re-run                  Create Bug Report
(QA can edit)                  (Return to Developer)

```

## Exit Conditions

**BEFORE exiting, you MUST:**

1. **IF VALIDATION PASSES:** Merge to main and push
2. **IF VALIDATION FAILS:** Send bug_report to PM (no merge)
3. Update state file with validation results
4. Commit with `[ralph] [qa]` prefix
5. Send result message to PM
6. **MANDATORY:** Run server cleanup (use skill `shared-lifecycle`)

---

## State Transitions

| Current State | Trigger                  | Action                        | Next State    |
| ------------- | ------------------------ | ----------------------------- | ------------- |
| `idle`        | Task assigned            | Load workflow, validate       | `working`     |
| `working`     | All pass                 | Report PASS to PM             | `idle`        |
| `working`     | Any fail                 | Report FAIL with bug report   | `idle`        |
| `working`     | Criteria unclear         | Ask Game Designer             | `awaiting_gd` |
| `working`     | Test approach unclear    | Ask PM                        | `awaiting_pm` |
