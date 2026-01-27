---
name: qa-workflow
description: Complete QA Validator workflow orchestration. References specialized skills for each validation step. Load at session startup for full protocol.
category: orchestration
---

# QA Validator Workflow

> "Orchestration layer for QA validation - delegate to specialized skills for each step."

**This skill contains orchestration only. Individual skills contain implementation details.**

---

## Session Startup

```
0. WATCHDOG ARCHITECTURE (READ THIS FIRST)

You are a WORKER managed by the WATCHDOG orchestrator.

**Watchdog spawns you when messages exist in your queue.**
**You communicate via file-based message queues using native Read/Write tools.**

┌─────────────────────────────────────────────────────────────────────┐
│                        WATCHDOG (Orchestrator)                       │
│  - Spawns workers when messages exist in their queues               │
│  - Routes messages via file queues                                 │
│  - Monitors worker health                                           │
└─────────────────────────────────────────────────────────────────────┘
        ▲
        │ (spawns when messages exist)
        │
┌───────────────┐
│ QA Worker     │
│ (You/Claude)  │
└───────────────┘
```

1. Load this skill: Skill("qa-workflow")
2. Load qa-router: Skill("qa-router") - See available tools
3. Check for pending messages (P1 FIX - Use acknowledgment pattern):

   Use the **Glob + Read tools** to read from `.claude/session/messages/qa/msg-*.json`

   **Complete message processing pattern:**

   ```
   1. Use Glob: .claude/session/messages/qa/msg-*.json
   2. For each file: Read the file content
   3. Parse JSON (fields: id, from, to, type, payload, timestamp, status)
   4. Store messageId for acknowledgment
   5. Process messages based on type field
   6. Send acknowledgment to watchdog (P1 FIX - REQUIRED):
      Write to: .claude/session/messages/watchdog/msg-watchdog-{timestamp}-{seq}.json
      {
        "id": "msg-watchdog-{timestamp}-{seq}",
        "from": "qa",
        "to": "watchdog",
        "type": "message_acknowledged",
        "priority": "normal",
        "payload": {
          "originalMessageId": "{original_message_id}",
          "status": "processed"
        },
        "timestamp": "{ISO-8601-timestamp}",
        "status": "pending"
      }
   7. Delete the message file after sending acknowledgment
   ```

   **Why acknowledgment is required:**
   - Watchdog marks messages as "delivered" when sending to you
   - Watchdog waits for acknowledgment before deleting the message
   - Without acknowledgment, watchdog may re-deliver messages (causing duplicates)
   - With acknowledgment, watchdog knows you successfully processed the message

4. Begin validation workflow

---

## MANDATORY: Port Detection Before Browser Testing

**⚠️ CRITICAL: Vite dev server may run on different ports (3000, 3001, 5173, etc.)**

Before ANY browser interaction or E2E test:

```bash
# Method 1: Check listening ports
netstat -an | grep LISTEN | grep -E ":(3000|3001|5173|8080)"

# Method 2: Try curl to detect Vite
curl -s http://localhost:3000 | grep -q "vite" && echo "PORT=3000" || \
curl -s http://localhost:3001 | grep -q "vite" && echo "PORT=3001" || \
curl -s http://localhost:5173 | grep -q "vite" && echo "PORT=5173"
```

**E2E tests** in `playwright.config.ts` should automatically detect the port.

**Manual MCP validation** requires you to use the detected port in navigation.

## Multi-Agent Playwright Considerations

**⚠️ IMPORTANT: When multiple agents use Playwright MCP simultaneously**

Standard `@playwright/mcp` shares a single browser instance. In Ralph Orchestra with parallel agents:

1. **Use `playwright-parallel-mcp`** for isolated browser sessions per agent
2. **Configuration:**
   ```json
   {
     "mcpServers": {
       "playwright": {
         "command": "npx",
         "args": ["playwright-parallel-mcp"],
         "env": { "MAX_SESSIONS": "5" }
       }
     }
   }
   ```
3. **Usage:** Create session per agent with `create_session`, use sessionId in all calls

**If Playwright MCP is already in use by another agent:**
- Use `npx playwright test` directly instead of MCP tools
- Wait for the other agent to complete validation
- Coordinate via PM to schedule sequential validation

See `qa-mcp-helpers` skill for full details on parallel Playwright setup.

---

---

## Validation Workflow (In Order)

```

┌─────────────────────────────────────────────────────────────────────────────┐
│ VALIDATION WORKFLOW │
├─────────────────────────────────────────────────────────────────────────────┤
│ │
│ ┌─────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ │
│ │ MESSAGE │───►│ TEST │───►│ CODE │───►│ VALID │ │
│ │ QUEUE │ │ COVERAGE │ │ REVIEW │ │ CHECKS │ │
│ └─────────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘ │
│ │ │ │ │
│ ▼ ▼ ▼ │
│ ┌─────────┐ ┌──────────┐ ┌──────────────┐ │
│ │ Tests │ │ ALL │ │ BROWSER │ │
│ │ exist? │ │ PASS │ │ TEST │ │
│ └────┬────┘ └────┬─────┘ └──────────────┘ │
│ │ │ │ │
│ ┌────┴─────┐ │ │ │
│ ▼ ▼ ▼ ▼ │
│ ┌─────────┐ ┌──────────┐ ┌──────────────┐ │
│ │ CREATE │ │ FIX │ │ PLAYWRIGHT │ │
│ │ TESTS │ │ TESTS │ │ MCP │ │
│ └─────────┘ └──────────┘ └──────────────┘ │
│ │ │ │ │
│ └──────────────┴──────────────┴────────────────────┘ │
│ │ │
│ ▼ │
│ ┌──────────────────┐ │
│ │ SERVER CLEANUP │◄── MANDATORY│
│ │ (always run) │ │
│ └──────────────────┘ │
│ │ │
│ ▼ │
│ ┌──────────────────┐ │
│ │ REPORT RESULT │ │
│ └──────────────────┘ │
│ │
└─────────────────────────────────────────────────────────────────────────────┘

```

**⚠️ MANDATORY GATE: E2E Tests Must Complete**

**Running E2E tests is NON-NEGOTIABLE.**

- E2E tests MUST complete even if automated checks (type-check, lint, test, build) fail
- If automated checks fail → report bugs AND run E2E tests to document visual state
- NO exceptions for "blocked by test failure"
- If E2E tests unavailable → FAIL validation with severity "critical"

**⚠️ MANDATORY CLEANUP: Always run server cleanup before reporting results.**

Use `shared-lifecycle` skill for proper server management.

---

## Step-by-Step Skills Reference

| Step | Skill / Sub-Agent | Purpose |
|------| ----------------- | ------- |
| **1. Task Assignment** | `shared-messaging` | Process messages, auto-assign from current-task-qa.json |
| **2. Worktree Setup** | `shared-worktree` | Navigate to agent worktree |
| **3. Task Memory** | `shared-retrospective` | Create task memory file |
| **4. Test Coverage** | `qa-test-creation` | **MANDATORY:** Check/create E2E tests - CANNOT PASS without them |
| **5. Test Execution** | `qa-validation-workflow` | Run tests, analyze failures |
| **6. Code Review** | `qa-code-review` | Check code quality before checks |
| **7. Browser Testing** | `qa-browser-testing` + sub-agent | Playwright MCP validation |
| **8. Result Reporting** | `qa-reporting-bug-reporting` | Report pass/fail to PM |

---

## Sub-Agents (invoke via Task tool)

| Sub-Agent | Model | Purpose | When to Invoke |
|-----------|------- |---------| ---------------|
| `test-creator` | Sonnet | Create unit/E2E tests | Tests missing (from qa-test-creation) |
| `browser-validator` | Inherit | Basic Playwright MCP | Every validation (MANDATORY) |
| `gameplay-tester` | Inherit | E2E gameplay loops | Gameplay features |
| `multiplayer-validator` | Inherit | Server-authoritative tests | Multiplayer features |
| `visual-regression-tester` | Haiku | Visual regression with Vision MCP | Visual/UI changes |

---

## Quick Decision Tree

```

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

```

                    TESTS FAIL
                        │
        ┌───────────────┴───────────────┐
        │                               │
    Test Code Issue?              Game Code Issue?
        │ YES                          │ YES
        ▼                               ▼

Fix and Re-run Create Bug Report
(QA can edit) (Return to Developer)

````

### How to Distinguish Test vs Game Code Issues

| Symptom | Type | Action |
| ------- | ---- | ------ |
| Selector not found (`getByRole` fails) | Test code | Fix selector in test |
| Timeout waiting for element | Test code | Adjust wait/timeout |
| Assertion shows wrong value | Game code | Bug report |
| Console error in game logic | Game code | Bug report |
| Visual mismatch | Game code | Bug report |
| Test setup fails | Test code | Fix test setup |

### Test Code Issues (QA Fixes)

- Incorrect selectors (`getByRole`, `getByLabel`)
- Missing `await` on async operations
- Incorrect test data setup
- Race conditions in test timing
- Page object model issues

### Game Code Issues (Bug Report)

- Business logic not working
- UI not rendering correctly
- Console errors from application code
- Performance issues
- Accessibility violations

---

## State File Status Updates (v2.0)

Update `current-task-qa.json` immediately when status changes:

| Event | Update State File |
| ------- | ------ |
| Starting validation | `state.status = "working"` + `state.currentTaskId = "{taskId}"` |
| Validation PASSED | Include in bug_report message (PM sets passed in prd.json) |
| Validation FAILED | Include bugs in bug_report message (PM updates prd.json) |
| Finishing | `state.status = "idle"` |

**⚠️ V2.0:** QA does NOT update prd.json directly. Send status via message to PM, who syncs to prd.json.

---

## Merge Protocol

Check which agent task you are validating

**When PASSED:**
```bash
cd ..
git checkout main
git merge origin/{agent}-worktree
git push origin main
````

**When FAILED:**

```bash
# Stay on main, do NOT merge
# Send bug_report to agent
```

---

## Commit Format

**PASS:**

```
[ralph] [qa] {taskId}: Validation PASSED

- TypeScript: pass
- Lint: pass
- Tests: pass
- Build: pass
- E2E: pass
- Browser: pass

All acceptance criteria verified.

PRD: {taskId} | Agent: qa | Iteration: N
```

**FAIL:**

```
[ralph] [qa] {taskId}: Validation FAILED

- {failed_check}: FAIL

Bug: {brief description}
See bug_report message payload for full report.

PRD: {taskId} | Agent: qa | Iteration: N
```

---

## Context Reset

For big tasks (5+ acceptance criteria, 3+ components):

- Use `Skill("shared-context")`
- Monitor with `/context` command
- Create checkpoint if >= 70% capacity

---

## Server Lifecycle Management

**Use `shared-lifecycle` skill for proper server management.**

Before running E2E tests, always check/start the dev server:

```bash
# MANDATORY: First detect which port Vite is using
netstat -an | grep LISTEN | grep -E ":(3000|3001|5173|8080)"
# OR: curl -s http://localhost:3000 | grep -q "vite" && echo "3000" || curl -s http://localhost:3001 | grep -q "vite" && echo "3001"

# Check if server already running on detected port
lsof -ti:3000 2>/dev/null || lsof -ti:3001 2>/dev/null || npm run dev:all:sh &
```

**MANDATORY CLEANUP after all tests complete (pass OR fail):**

Use the cleanup pattern from `shared-lifecycle` skill to ensure:

- Dev server is stopped
- Ports are released
- No orphaned processes remain

---

## Exit Conditions

**BEFORE exiting, you MUST:**

1. Complete all validation steps (type-check, lint, test, build, e2e, browser)
2. **IF VALIDATION PASSES:** Merge to main and push
3. **IF VALIDATION FAILS:** Send bug_report to PM (no merge)
4. Update state file with validation results
5. Commit with `[ralph] [qa]` prefix
6. Send result message to PM
7. Update `current-task-qa.json`: `state.status = "idle"`
8. **MANDATORY:** Run server cleanup (shared-lifecycle)

---
