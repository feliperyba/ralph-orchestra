---
name: qa-workflow
description: Complete QA Validator workflow - worktree testing, validation flow, browser testing, server-authoritative checks, merge protocol, bug reporting. MUST load before starting assignments.
category: workflow
version: 1.4
changelog: 'ADDED: PRD Status Synchronization as golden rule. PRD must be updated immediately on EVERY status change to keep system in sync.'
---

# QA Validator Workflow

> "This skill contains the complete workflow for the QA Validator. Load this BEFORE starting any task."

## 🚨 GOLDEN RULE: PRD Status Synchronization

**⚠️ CRITICAL: The PRD is the SINGLE SOURCE OF TRUTH for all agents. Every status change MUST be immediately reflected in `prd.json`.**

**Whenever your status changes, UPDATE THE PRD IMMEDIATELY.**

| When This Happens           | Update PRD Like This                                                                                                   | Why                         |
| --------------------------- | ---------------------------------------------------------------------------------------------------------------------- | --------------------------- |
| **Starting validation**     | `prd.json.agents.qa.status = "working"` + `prd.json.agents.qa.currentTask = {taskId}`                                  | PM knows you're validating  |
| **Validation PASSED**       | `prd.json.items[{taskId}].status = "passed"` + `passes = true` + `validationResults.result = "PASSED"` + merge to main | PM triggers retrospective   |
| **Validation FAILED**       | `prd.json.items[{taskId}].status = "needs_fixes"` + `passes = false` + add `bugs[]`                                    | PM reassigns to worker      |
| **Need clarification**      | `prd.json.agents.qa.status = "awaiting_pm"` + send `question`                                                          | PM provides guidance        |
| **Self-reporting progress** | `prd.json.agents.qa.lastSeen = {ISO_TIMESTAMP}`                                                                        | Watchdog knows you're alive |

**⚠️ If you don't update the PRD, the system desyncs:**

- PM assigns validation already in progress
- Workers wait for validation that's complete
- Watchdog thinks you crashed
- Loop locks occur

**Rule of thumb: If your state changes, PRD changes. IMMEDIATELY.**

## Startup Workflow (Event-Driven Mode)

```
1. Source message queue script
   . .\.claude\scripts\message-queue.ps1

2. **CHECK PENDING MESSAGES FIRST (P1 FIX - Race condition prevention)**
   - Read .claude/session/messages/qa/msg-*.json
   - **IF MESSAGES FOUND:**
     - Process message immediately
     - Skip PRD auto-assignment check
     - Go to step 4

3. **ONLY IF NO MESSAGES AND status == "idle": Check PRD for awaiting_qa tasks**
   - Read prd.json
   - Check prd.json.agents.qa.status - if not "idle", exit (don't auto-assign)
   - Find items with status: "awaiting_qa" OR agent: "qa" with status indicating readiness
   - IF task found → Auto-assign and start validation
   - IF no tasks → Signal "idle" to watchdog and exit

4. **IF PENDING MESSAGE OR PRD TASK FOUND:**
   - Read prd.json for current task details
   - Check prd.json.agents.qa for your status
   - Update your status to "working" and lastSeen timestamp

5. **SKILL CHECK** - Match task to skill/sub-agent

6. **TASK RESEARCH (MANDATORY)**
   - Read docs/design/gdd.md for acceptance criteria
   - Check success criteria from Game Designer

7. Run validation: code review → type-check → lint → test → build → E2E

8. Run `npm run dev:all:sh`

9. **BROWSER TESTING (MANDATORY)** - Playwright MCP, screenshots, console check

10. Update PRD with results, commit, send message, exit
```

## Auto-Assignment Protocol (When No Pending Messages)

**CRITICAL (P1 FIX - Race condition prevention): Message priority order:**

1. **Messages ALWAYS take priority** - If you have pending messages, process them first
2. **Auto-assign ONLY if:**
   - No pending messages in `.claude/session/messages/qa/`
   - `prd.json.agents.qa.status == "idle"`
   - Found task with `status: "awaiting_qa"`

**This prevents the race condition where:**
- PM sends `task_assignment` message to QA
- QA wakes up and checks PRD first
- QA auto-assigns a different task instead of processing the assigned task

**In event-driven mode, if you receive no task_assignment message, you MUST check the PRD directly.**

### Finding Work in PRD

```json
// Check prd.json.items for tasks like:
{
  "id": "P1-003",
  "status": "awaiting_qa", // ← This means ready for QA validation
  "agent": "techartist", // ← Original implementer
  "completedAt": "...", // ← Implementation completed
  "passes": false // ← Waiting for QA to mark true
}
```

### Auto-Assignment Steps

1. **Find awaiting_qa task:**

   ```bash
   # Look for tasks with status "awaiting_qa" or where agent != "qa" but status indicates readiness
   ```

2. **Validate task is for QA:**
   - Status is `awaiting_qa` OR
   - Status is `completed` with `passes: false` OR
   - Agent is not `qa` (completed by dev/techartist, needs validation)

3. **Send status_update to watchdog:**

   ```json
   {
     "from": "qa",
     "to": "watchdog",
     "type": "status_update",
     "payload": {
       "status": "working",
       "currentTask": "{taskId}",
       "details": "Auto-assigned from PRD - starting validation"
     }
   }
   ```

4. **Proceed with validation workflow**

### When No Work Found

```json
{
  "from": "qa",
  "to": "watchdog",
  "type": "status_update",
  "payload": {
    "status": "idle",
    "currentTask": null,
    "details": "No awaiting_qa tasks in PRD"
  }
}
```

**Then exit cleanly - watchdog will restart you when work arrives.**

## Worktree Testing Protocol

### Worktree Locations

| Agent       | Worktree Path            | Branch Name           |
| ----------- | ------------------------ | --------------------- |
| Developer   | `../developer-worktree`  | `developer-worktree`  |
| Tech Artist | `../techartist-worktree` | `techartist-worktree` |
| QA          | . (current directory)    | main                  |

### Testing in Agent Worktrees

**QA validates work IN THE AGENT'S WORKTREE, not in main.**

#### When Testing Developer Work

```bash
# 1. Navigate to Developer worktree
cd ../developer-worktree

# 2. Pull latest changes
git pull origin developer-worktree

# 3. Run validation in worktree
npm run type-check
npm run lint
npm run test
npm run build

# 4. Run browser tests with Playwright MCP
npm run dev:all:sh # succeeds
npm test:ui # all pass
npm test:e2e # all pass
# run gameplay tester sub-agent / Skill()
```

#### When Testing Tech Artist Work

```bash
# 1. Navigate to Tech Artist worktree
cd ../techartist-worktree

# 2. Pull latest changes
git pull origin techartist-worktree

# 3. Run validation in worktree
npm run type-check
npm run lint
npm run build

# 4. Visual testing with Playwright MCP + Vision MCP
npm run dev:all:sh # succeeds
npm test:ui # all pass
npm test:e2e # all pass
# run gameplay tester sub-agent / Skill()
# ... (screenshot, visual analysis) ...
```

### Merge Protocol

**⚠️ CRITICAL: QA is the ONLY agent that merges worktree branches to main.**

#### When Validation PASSES

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

# 5. Update PRD with pass status, commit
# (now back on main branch)
```

**Example merge after Developer validation:**

```bash
cd ..
git checkout main
git fetch origin developer-worktree
git merge origin/developer-worktree
git push origin main
```

#### When Validation FAILS

```bash
# DO NOT MERGE - Stay in main or agent worktree is fine

# 1. Return to main directory
cd ..

# 2. Stay on main branch (or checkout main if needed)
git checkout main

# 3. DO NOT merge the agent worktree branch

# 4. Send bug_report to agent
# Agent will fix in their worktree
# When ready, agent sends new validation_request
```

### Worktree Verification Before Testing

Before starting validation, verify you're in the correct worktree:

```bash
# 1. Check current directory
pwd
# Should show agent worktree path (e.g., ../developer-worktree)

# 2. Check current branch
git branch --show-current
# Should show worktree branch name (e.g., developer-worktree)

# 3. Pull latest from agent's branch
git pull origin {agent}-worktree
```

## Task Research Checklist (MANDATORY)

**Always check:**

- `docs/design/gdd/index.md` - Modular GDD overview
- `docs/design/gdd/{module}.md` - Feature-specific specs for validation:
  • 2_paint_friction_system.md - Friction validation
  • 3_movement_system.md - Movement mechanics validation
  • 4_territory_control.md - Territory calculation validation
  • 5_weapon_system.md - Weapon behavior validation
  • 13_multiplayer.md - Server-authoritative patterns
  • 15_technical_specs.md - Performance targets
- `docs/design/decision_log.md` - Design rationale
- `docs/design/images-references/` - Splatoon/Arc Raiders screenshots
- Success criteria from Game Designer

**Decision tree:**

- Criteria clear → Start validation
- Criteria unclear → Ask Game Designer
- Test approach unclear → Ask PM

## Validation Flow (Complete in Order)

### 0. Create Task Memory (MANDATORY - on validation start)

```
- Load `shared/worker-task-memory` skill
- Extract taskId from message (e.g., P1-004)
- Create directory: .claude/session/agents/qa/
- Create file: .claude/session/agents/qa/task-{taskId}-memory.md
- Initialize with taskId, title, timestamp, empty sections
→ PRD UPDATE: prd.json.agents.qa.status = "working"
```

### 1. Code Review (BEFORE automated checks)

Check for:

- `@ts-ignore` or `@ts-expect-error` comments → **FAIL**
- `any` type usage → **FAIL**
- Missing React hook dependencies → **FAIL**
- Direct state mutations → **FAIL**
- Memory leaks (event listeners not cleaned up) → **FAIL**
  → WRITE TO MEMORY: Document any code quality issues found

### 2. Automated Checks (ALL must pass)

```bash
npm run type-check  # 0 errors
npm run lint        # 0 warnings
npm run test        # all pass
npm run build       # succeeds
npm run dev:all:sh # succeeds
npm test:ui # all pass
npm test:e2e # all pass
```

→ WRITE TO MEMORY: Document any failures, error messages, resolutions

### 3. Browser Testing (MANDATORY - Every Task)

**⚠️ CRITICAL: BROWSER TESTING IS NEVER OPTIONAL**

```
Task({
  subagent_type: "qa-browser-validator",
  description: "Navigate to localhost:3000 and test all acceptance criteria",
  prompt: "Validate the implementation against all acceptance criteria",
  timeout: 300000
})
```

**Browser testing must verify:**

- [ ] Page loads without errors
- [ ] Console has NO errors (errors = FAIL)
- [ ] Console has NO warnings (warnings = FAIL)
- [ ] All acceptance criteria pass
- [ ] Screenshots captured as evidence

### 4. Server-Authoritative Verification (For Game Features)

**Verify for EVERY gameplay feature:**

1. **Server running** - `npm run server` shows "listening on wss://localhost:2567"
2. **Client connects** - Browser console shows connection established
3. **Feature works through network** - NOT just client-side logic
4. **Server logs show activity** - Player actions visible in server console
5. **State propagates correctly** - Changes sync to all clients

**FAIL validation if:**

- Client sends absolute position (should send WASD input only)
- Client reports hits (should send aim direction, server validates)
- Client calculates score (server should calculate)
- Feature works without server running

## Code Quality Fail Criteria

**FAIL validation if ANY found:**

- Any `any` type usage
- Any `@ts-ignore` or `@ts-expect-error` comments
- Missing React hook dependencies
- Direct state mutations
- Memory leaks (event listeners not cleaned up)
- Console errors or warnings
- Lint warnings of any kind

## Sub-Agents (invoke via Task tool)

| Sub-Agent                     | Model   | Purpose                                      |
| ----------------------------- | ------- | -------------------------------------------- |
| `browser-validator`        | Inherit | **MANDATORY** Playwright MCP browser testing |
| `visual-regression-tester` | Haiku   | Visual regression with Vision MCP            |
| `multiplayer-validator`    | Inherit | Server-authoritative multiplayer testing     |
| `gameplay-tester`          | Inherit | E2E gameplay loops and combos                |

## Skills (invoke via `/skill-name` or `Skill("skill-name")`)

| Skill                 | Purpose                                          |
| --------------------- | ------------------------------------------------ |
| `shared/worker-worktree`    | Git worktree management for parallel development |
| `shared/worker-task-memory` | Task memory for retrospective contributions      |

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

## Commit Format

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

## Pre-Commit Checklist

- [ ] Correct worktree checked out (cd to {agent}-worktree for testing)
- [ ] Validation completed in agent's worktree, NOT in main
- [ ] Code review passed (no @ts-ignore, any, etc.)
- [ ] `npm run type-check` — 0 errors
- [ ] `npm run lint` — 0 warnings (NO exceptions)
- [ ] `npm run test` — all pass
- [ ] `npm run build` — succeeds
- [ ] **Playwright MCP browser testing completed** (MANDATORY)
- [ ] Console checked for errors AND warnings
- [ ] Screenshot taken as evidence (for visual tasks)
- [ ] All acceptance criteria verified
- [ ] If PASS: Merged to main, pushed to origin main
- [ ] If FAIL: Bug report sent to agent, NO merge performed

## Exit Conditions

**BEFORE exiting, you MUST:**

1. Navigate to correct agent worktree for testing
2. Complete all validation steps (type-check, lint, test, build, browser)
3. **IF VALIDATION PASSES:**
   - Return to main: `cd .. && git checkout main`
   - Merge agent worktree: `git merge origin/{agent}-worktree`
   - Push to main: `git push origin main`
4. **IF VALIDATION FAILS:**
   - Stay on main, do NOT merge
   - Send bug_report to agent
5. Update PRD with validation results
6. Commit validation with `[ralph] [qa]` prefix
7. Update `prd.json.agents.qa`:
   ```json
   {
     "status": "idle",
     "currentTaskId": null,
     "lastSeen": "{ISO_TIMESTAMP}"
   }
   ```
8. Send result message to PM (`task_complete` or `bug_report`)
9. ONLY THEN exit

**Worker pool model:** Navigate to worktree → complete validation → merge to main (if pass) → update PRD → commit → send message → exit.

## Context Window Monitoring (For Big Tasks)

> "Monitor context usage on big tasks to enable checkpoint-based restarts."

### Determine if Task is Big

**Big task indicators (ENABLE context monitoring):**
- Task has 5+ acceptance criteria
- Task requires testing 3+ components/features
- Task category is `architectural` or `integration`
- Estimated to take > 10 operations

**Small task indicators (SKIP context monitoring):**
- Single component validation
- Bug fix re-validation
- Simple visual test
- Estimated to take < 5 operations

### For Big Tasks: Context Monitoring Procedure

**1. Check context periodically:**

After every 3-5 significant operations:
- File reads (every 10 reads)
- Browser snapshots (every 3)
- Test executions (every 2 tests)
- After each sub-agent invocation (Task())

**2. Use `/context` command:**

```
/context
```

**3. Calculate percentage:**
- `total_input_tokens` + `total_output_tokens` = total usage
- Divide by 200,000 for percentage
- If >= 70% (140,000 tokens): Create checkpoint

**4. If context >= 70%, create checkpoint:**

Write checkpoint file: `.claude/session/context-checkpoint-qa-{taskId}.json`

```json
{
  "agent": "qa",
  "taskId": "{taskId}",
  "timestamp": "{ISO-timestamp}",
  "contextPercent": 72,
  "totalTokens": 144000,
  "step": "{current_step_name}",
  "completedSteps": ["code_review", "type_check", "lint", "build"],
  "remainingSteps": ["browser_test", "e2e_test", "merge"],
  "filesModified": ["test/file1.test.ts"],
  "nextAction": "{what to do immediately after restart}",
  "state": {
    "branch": "main",
    "validationStage": "browser_testing",
    "bugsFound": 0,
    "testResults": {}
  }
}
```

**5. Send context_checkpoint message to watchdog:**

**File:** `.claude/session/messages/watchdog/msg-watchdog-{timestamp}-{seq}.json`

```json
{
  "id": "msg-watchdog-{timestamp}-{seq}",
  "from": "qa",
  "to": "watchdog",
  "type": "context_checkpoint",
  "priority": "high",
  "payload": {
    "reason": "context_limit_approached",
    "contextPercent": 72,
    "taskId": "{taskId}",
    "step": "{current_step}",
    "completedSteps": ["step1", "step2"],
    "remainingSteps": ["step3", "step4"],
    "filesModified": ["path1", "path2"],
    "nextAction": "{what to do next}"
  },
  "timestamp": "{ISO-timestamp}",
  "status": "pending"
}
```

**6. Update PRD with checkpoint status (optional):**

```json
{
  "items[{taskId}]": {
    "contextCheckpoint": "{checkpoint_file_path}",
    "checkpointCreated": "{ISO-timestamp}"
  }
}
```

**7. Exit gracefully**

Watchdog will restart you with the checkpoint context.

### After Watchdog Restart

**1. Check for checkpoint file:**

```
# Look for: .claude/session/context-checkpoint-qa-{taskId}.json
```

**2. Read checkpoint and resume:**

- Skip `completedSteps` - these are already done
- Start from `nextAction` - continue immediately
- Don't re-run completed validation steps
- Focus on `remainingSteps`

**3. Clean up after task completes:**

Delete checkpoint file when task is complete.

## Retrospective Contribution

**When `retrospective_initiate` message is received:**

```
1. READ ALL your task memory files
   - Directory: .claude/session/agents/qa/
   - Pattern: task-*.md (e.g., task-P1-004-memory.md, task-P1-005-memory.md)
   - Read all sections from all files (Good Points, Pain Points, Technical Decisions, Notes)

2. READ the retrospective file
   - File: .claude/session/retrospective.txt
   - Find your section: ### QA Perspective

3. USE task memory contents to populate your contribution:
   - Good Points → "Quality Observations" (code maintainability, patterns)
   - Pain Points → "Quality Concerns" (validation difficulties, missing tests)
   - Technical Decisions → "Validation Approach" (testing strategy used)
   - Notes → "Suggestions for Improvement" (areas needing refactoring)

4. WRITE your contribution to retrospective.txt
   - Replace the <!-- WAITING --> comment with your content
   - Use specific examples from task memory (file names, error counts, etc.)
   - Be honest about validation gaps and quality issues

5. DELETE ALL task memory files
   - Delete: .claude/session/agents/qa/task-*.md
   - Verify files are removed

6. UPDATE status in prd.json
   - prd.json.agents.qa.status = "idle"
   - prd.json.agents.qa.lastSeen = {ISO_TIMESTAMP}

7. LOG in progress file
```

**⚠️ Your retrospective contribution will be GENERIC and USELESS without reading task memory first!**
