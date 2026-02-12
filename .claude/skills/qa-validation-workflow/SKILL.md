---
name: qa-validation-workflow
description: Full validation workflow for QA agent. Runs automated checks (type-check, lint, test, build) and code quality review with enforced checkpoints. Use when validating implementation after code review.
category: validation
---

# Validation Workflow Skill

> "Trust but verify – automated tests catch regressions, code review catches quality issues."

### Validation State Tracking

**CRITICAL:** This workflow uses a checkpoint system to ensure ALL validation steps are completed before proceeding.

**State File:** `.claude/session/validation-state.json`

```json
{
  "taskId": "feat-XXX",
  "startedAt": "ISO-8601-timestamp",
  "checkpoints": {
    "codeReview": null,
    "typeCheck": null,
    "lint": null,
    "test": null,
    "build": null,
    "codeRefactor": false
  }
}
```

**Checkpoint Values:**
- `null` - Not yet started
- `"PASS"` - Check completed successfully
- `"FAIL"` - Check failed, validation aborted
- `false` / `true` - Boolean for code-refactor gate

### Acceptance Criteria Verification

For each acceptance criterion in `prd.json` for the target task (acceptanceCriteria array):
- Read GDD specifications for the feature
- Verify code logic implements the criteria
- Cross-reference implementation against design docs

### Validation Flow with Enforced Checkpoints

**PREREQUISITE:** Initialize validation-state.json before starting.

```
STEP 0: INITIALIZE STATE
  → Create .claude/session/validation-state.json
  → Set taskId, startedAt, initialize all checkpoints

STEP 1: CODE QUALITY PRE-CHECK (MANDATORY)
  → Load skill: qa-code-review
  → Run quality checks on changed files
  → Update checkpoint: checkpoints.codeReview = "PASS"/"FAIL"
  → IF FAIL: STOP validation, report bug

STEP 2: TYPE CHECK
  → Run: npm run type-check
  → Checkpoint: checkpoints.typeCheck = "PASS"/"FAIL"
  → IF FAIL: STOP validation, report bug

STEP 3: LINT
  → Run: npm run lint
  → Checkpoint: checkpoints.lint = "PASS"/"FAIL"
  → IF FAIL: STOP validation, report bug

STEP 4: TEST
  → Run: npm run test
  → Checkpoint: checkpoints.test = "PASS"/"FAIL"
  → IF FAIL: STOP validation, report bug

STEP 5: BUILD
  → Run: npm run build
  → Checkpoint: checkpoints.build = "PASS"/"FAIL"
  → IF FAIL: STOP validation, report bug

STEP 6: CODE REFACTOR GATE (MANDATORY - Enforced)
  → VERIFY: checkpoints.codeRefactor == true
  → IF false: EXECUTE code-refactor subagent
    - Task: "Review files using codebase-cleanup-refactor-clean skill"
    - Files: Read from validation_request.payload.files
    - Context: QA validation for task {taskId}
  → WAIT for code-refactor completion
  → IF changes were made: RE-EXECUTE steps 2-5 (re-validation loop)
  → Update checkpoint: checkpoints.codeRefactor = true
  → IF re-validation FAILS: Report bug, DO NOT proceed

STEP 7: SPECIFICATION VALIDATION
  → Read prd.json acceptanceCriteria for taskId
  → Read relevant GDD documents
  → Verify each criterion met in implementation
  → Document results: passed criteria, any gaps found

STEP 8: FINAL DECISION
  → READ all checkpoints from validation-state.json
  → IF any checkpoint = "FAIL": status = "FAILED", create bug_report
  → IF all checkpoints = "PASS": status = "PASSED", proceed
  → NEVER proceed without completing steps 0-7
```

### Re-Validation Loop After Refactor

**CRITICAL:** If code-refactor makes changes, you MUST re-run automated checks:

1. **Reset relevant checkpoints:** typeCheck, lint, test, build → `null`
2. **Re-run steps 2-5** in sequence
3. **If any fail:** Report bug to PM, DO NOT merge
4. **If all pass:** Continue to step 7 (spec validation)

### Code Refactor Subagent Invocation

**MANDATORY GATE:** Before spec validation (step 7), you MUST run code-refactor.

**When to invoke:**
- After all automated checks pass (steps 1-5)
- Before specification validation (step 7)
- Verify checkpoint: `checkpoints.codeRefactor == false`

**Invocation pattern:**
```xml
<task>
Use the Task tool with:
- subagent_type: "code-refactor"
- model: "sonnet" (for capable refactoring work)
- prompt: "Review and refactor these files using the codebase-cleanup-refactor-clean skill:
  Files: ${validation_request.payload.files.create + validation_request.payload.files.modify}
  Context: QA validation for task ${taskId}

  Focus on: code quality, clean code principles, SOLID patterns, maintainability"
</task>
```

**After code-refactor completes:**
1. Read the subagent's output/recommendations
2. Update `checkpoints.codeRefactor = true`
3. **If changes were made:** Re-run automated checks (steps 2-5)
4. Only proceed to spec validation after re-validation passes

### Fail-Stop Protocol

**If any step fails:**

1. **Update checkpoint** with `"FAIL"`
2. **STOP validation immediately** - do not proceed to next step
3. **Investigate the failure** - capture error output
4. **Create bug report** using qa-reporting-bug-reporting skill
5. **Send bug_report to PM** with status `"FAILED"`
6. **DO NOT merge** to main

### Automated Check Commands

| Check | Command | Expected Output |
|--------|----------|----------------|
| Type Check | `npm run type-check` | No TypeScript errors |
| Lint | `npm run lint` | No lint warnings or errors |
| Test | `npm run test` | All tests pass |
| Build | `npm run build` | Build succeeds |

### Validation State File Format

**File:** `.claude/session/validation-state.json`

```json
{
  "taskId": "feat-028",
  "startedAt": "2026-02-12T10:30:00Z",
  "completedAt": null,
  "checkpoints": {
    "codeReview": "PASS",
    "typeCheck": "PASS",
    "lint": "PASS",
    "test": "PASS",
    "build": "PASS",
    "codeRefactor": true
  },
  "finalStatus": null
}
```

### Exit Conditions

**Before completing validation, you MUST:**

1. **Verify all checkpoints completed:**
   - codeReview: "PASS"
   - typeCheck: "PASS"
   - lint: "PASS"
   - test: "PASS"
   - build: "PASS"
   - codeRefactor: true

2. **If ANY checkpoint is "FAIL":**
   - Create bug_report with details
   - Send to PM with status "FAILED"
   - DO NOT merge to main

3. **If ALL checkpoints are "PASS" or true:**
   - Complete specification validation
   - Send to PM with status "PASSED"
   - Update validation-state.json finalStatus

### Important

- **NEVER skip the code-refactor gate** - checkpoint must be true before spec validation
- **ALWAYS re-validate after refactor changes** - steps 2-5 must pass again
- **UPDATE checkpoints after each step** - validation-state.json is source of truth
- **STOP immediately on FAIL** - do not continue validation if any check fails

### See Also

- [qa-workflow](../qa-workflow/SKILL.md) — Main orchestration
- [qa-code-review](../qa-code-review/SKILL.md) — Code quality pre-check
- [qa-reporting-bug-reporting](../qa-reporting-bug-reporting/SKILL.md) — Bug report format
