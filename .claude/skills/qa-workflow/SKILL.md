---
name: qa-workflow
description: Complete QA Validator workflow orchestration. References specialized skills for each validation step. Load at session startup for full protocol.
---

# QA Workflow

> "Orchestration layer for QA validation - delegate to specialized skills for each step."

## Core Responsibilities

- **Load proper skills and tools** - Always ensure you have the right skills loaded for each task. Run tasks and subagents in parallel when possible to optimize time.
- **Full validation** - code quality review, type-check, lint, test, build, specifications validation
- **Code quality enforcement** - Check for code quality smells, anti-patterns, wrong design patterns and implementation issues
- **Checkpoint tracking** - Use validation-state.json to verify all steps complete before proceeding
- **Bug reporting** - Structured bug reports with evidence
- **Specifications validation** - Check implementation vs design specifications

## Standard Message Pipeline

- Read message input in this order: CLI message argument → `pending-messages-qa.json` → inbox diagnostics
- Never delete queue files (`messages/*`) or pending transaction files (`pending-messages-*.json`)
- Watchdog owns delivery and cleanup lifecycle
- Signal lifecycle using `status_update`:
   - `working` when validation starts
   - `awaiting_pm` / `awaiting_gd` when blocked
   - `ready` / `waiting` / `idle` when available for next delivery

## Agent Startup Protocol

**PRE-REQUISITE: You should already have loaded the `shared-worktree` skill and be in the correct worktree directory before starting this workflow!**

On each QA agent spawn, follow these steps EXACTLY in order:

### STEP 0: INITIALIZE VALIDATION STATE (MANDATORY - First action)

Before any validation work begins:

1. **Create** `.claude/session/validation-state.json` if it doesn't exist
2. **Initialize** with task information:
   ```json
   {
     "taskId": "{taskId from validation_request}",
     "startedAt": "{ISO-8601 timestamp}",
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
3. **PROCEED** to Step 1

### STEP 1: SEND STATUS UPDATE (MANDATORY)

Send `status_update` to watchdog with `status: "working"` and current task details.

### STEP 2: CODE QUALITY PRE-CHECK (MANDATORY - Unskippable)

**BEFORE** running any automated checks:

1. **Load** `qa-code-review` skill
2. **Identify** changed files from the validation request
3. **Run** quality checks using the qa-code-review skill's grep patterns
4. **Update checkpoint:** `validation-state.json` → `checkpoints.codeReview = "PASS"` or `"FAIL"`
5. **IF "FAIL":** Create bug report, STOP validation, report to PM
6. **IF "PASS":** Proceed to Step 3

### STEP 3: AUTOMATED CHECKS (MANDATORY)

Follow the `qa-validation-workflow` skill guidelines:

1. **Load** `qa-validation-workflow` skill
2. **Execute** in sequence:
   - Type Check → Update checkpoint
   - Lint → Update checkpoint
   - Test → Update checkpoint
   - Build → Update checkpoint
3. **Each step MUST update** its checkpoint in `validation-state.json` before proceeding
4. **IF any check FAILS:** STOP validation, create bug report, report to PM

### STEP 4: CODE REFACTOR GATE (MANDATORY - Enforced Checkpoint)

**BEFORE** proceeding to specification validation:

1. **READ** `validation-state.json`
2. **VERIFY** `checkpoints.codeRefactor == true`
3. **IF false:**
   - **READ** `validation_request.payload.files` for list of created/modified files
   - **INVOKE** code-refactor subagent using Task tool:
   ```
   Task tool → subagent_type: "code-refactor", model: "sonnet"
   Prompt: "Review and refactor these files using codebase-cleanup-refactor-clean skill:
   Files to review: {files.create} + {files.modify}
   Context: QA validation for task {taskId}
   Focus on: code quality, clean code principles, SOLID patterns, anti-patterns, maintainability"
   ``` WAIT for code-refactor subagent completion
   - **READ** code-refactor output to verify completion
   - **UPDATE** checkpoint: `checkpoints.codeRefactor = true`
   - **IF changes were made:** Re-execute Step 3 (re-validation loop)
   - **IF re-validation FAILS:** Report bug, DO NOT proceed
   - **ONLY** proceed to Step 5 after code-refactor checkpoint is true
   ```
   - **WAIT** for code-refactor subagent completion
   - **READ** code-refactor output to verify completion
   - **UPDATE** checkpoint: `checkpoints.codeRefactor = true`
   - **IF changes were made:** Re-execute Step 3 (re-validation loop)
   - **IF re-validation FAILS:** Report bug, DO NOT proceed
4. **ONLY** proceed to Step 5 after code-refactor checkpoint is true

### STEP 5: SPECIFICATION VALIDATION

After all automated checks pass and code-refactor completes:

1. **READ** `prd.json` for the task's acceptance criteria
2. **READ** relevant GDD documents for design specifications
3. **VERIFY** each acceptance criterion is met in implementation
4. **DOCUMENT** results:
   - Which criteria passed
   - Any gaps between implementation and design
   - Visual/behavioral verification notes

### STEP 6: FINAL DECISION GATE (MANDATORY)

**BEFORE** committing or reporting:

1. **READ ALL checkpoints** from `validation-state.json`
2. **VERIFY** all checkpoints:
   - `codeReview: "PASS"`
   - `typeCheck: "PASS"`
   - `lint: "PASS"`
   - `test: "PASS"`
   - `build: "PASS"`
   - `codeRefactor: true`
3. **DECISION:**
   - **IF any checkpoint = "FAIL":** Status = "FAILED", create bug_report using qa-reporting-bug-reporting skill
   - **IF all checkpoints PASS:** Status = "PASSED", prepare for commit
4. **NEVER** proceed to Step 7 without completing Steps 0-6

### STEP 7: COMMIT & REPORT (Only after passing all gates)

**ONLY** execute after Steps 0-6 complete successfully:

1. **UPDATE** `validation-state.json` with `finalStatus: "PASSED"` or `"FAILED"`
2. **COMMIT** all changes to current branch with `[ralph] [qa] {taskId}: Validation {status}`
3. **IF PASSED:** Merge to main and push
4. **IF FAILED:** DO NOT merge (no push)
5. **SEND** message to PM with validation results:
   - Overall status
   - Checkpoint results summary
   - Bug report (if failed)
   - Observations and notes
6. **RUN** server cleanup using `shared-lifecycle` skill
7. **SEND** final `status_update` to watchdog with `status: "ready"`
8. **EXIT**

## If Blocked

**If** validation cannot proceed due to missing information:

1. **UPDATE** `prd.json` task state with blocker details
2. **UPDATE** state: `state.status = "awaiting_pm"` or `"awaiting_gd"`
3. **SET** `state.lastSeen = "{ISO_TIMESTAMP}"`
4. **SEND** message to PM or Game Designer with details
5. **SEND** `status_update` to watchdog with blocked status
6. **EXIT** and wait for response

---

## Re-Validation Loop

**CRITICAL:** If code-refactor makes changes, you MUST re-run automated checks:

1. **Reset checkpoints:** `typeCheck`, `lint`, `test`, `build` → `null`
2. **Re-execute Step 3** (Automated Checks)
3. **Verify** all checkpoints pass again
4. **Only** proceed to Step 5 after re-validation passes

## Important Reminders

- **NEVER skip Step 2** (code quality pre-check) - catches issues automated tools miss
- **NEVER skip Step 4** (code-refactor gate) - enforced by checkpoint verification
- **ALWAYS update checkpoints** after each step - validation-state.json is source of truth
- **STOP immediately** on any FAIL - do not continue validation
- **RE-VALIDATE after refactor** - automated checks must pass again
- **READ validation_request payload** for file lists - needed for code-refactor invocation

---


## State Transitions

| Current State | Trigger                  | Action                        | Next State    |
| ------------- | ------------------------ | ----------------------------- | ------------- |
| `idle`        | Task assigned            | Initialize state, validate       | `working`     |
| `working`     | All checkpoints pass         | Report PASS to PM, merge to main             | `idle`        |
| `working`     | Any checkpoint fails         | Report FAIL with bug report   | `idle`        |
| `working`     | Criteria unclear         | Ask Game Designer             | `awaiting_gd` |
| `working`     | Test approach unclear    | Ask PM                        | `awaiting_pm` |

## Exit Conditions

**BEFORE exiting, you MUST verify:**

1. ✅ **All checkpoints updated** in validation-state.json
2. ✅ **Code-refactor completed** (`checkpoints.codeRefactor == true`)
3. ✅ **Decision made** based on ALL checkpoints
4. ✅ **Bug report created** if validation failed
5. ✅ **Commit made** with `[ralph] [qa]` prefix
6. ✅ **Message sent** to PM with results
7. ✅ **Status update sent** to watchdog (`ready`/`idle`)
8. ✅ **Server cleanup run** using shared-lifecycle skill
