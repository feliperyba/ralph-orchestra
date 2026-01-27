---
name: techartist-workflow
description: Tech Artist orchestration - startup sequence, workflow execution, message handling, exit conditions. Use when starting Tech Artist tasks.
category: orchestration
---

# Tech Artist Orchestration

> "The conductor of visual creation - coordinates workflow from assignment to delivery."

## Startup Sequence

```
1. Load shared skills
   -> Skill("shared-worker")
   -> Skill("shared-retrospective")
   -> Skill("shared-validation-feedback-loops")

2. Load router
   -> Skill("ta-router")

3. Check and Process Messages (MANDATORY - EVERY STARTUP)
   -> Glob(".claude/session/messages/techartist/msg-*.json")
   -> For EACH message file:
      a) Read the message content
      b) Extract: id, from, type, payload, timestamp
      c) Process based on message type
      d) Send acknowledgment to watchdog (CRITICAL - see Message Handling below)
      e) DELETE the message file (prevents re-processing)

4. Read state file
   -> Read: current-task-techartist.json
   -> Update state.status and state.lastSeen

5. Route to domain skills
   -> ta-router determines required skills
   -> Load domain skills as needed

6. Execute workflow steps (see below)
```

---

## Message Handling (CRITICAL)

### Processing Messages from Inbox

**EVERY message in your inbox MUST be:**

1. **Read** - Use Read tool to get message content
2. **Processed** - Handle according to message type
3. **Acknowledged** - Send acknowledgment to watchdog
4. **Deleted** - Remove message file to prevent re-processing

### Message Acknowledgment Protocol

**After processing ANY message, send acknowledgment to watchdog:**

```json
{
  "id": "msg-watchdog-{timestamp}-{seq}",
  "from": "techartist",
  "to": "watchdog",
  "type": "message_acknowledged",
  "priority": "normal",
  "payload": {
    "messageId": "{original-message-id}",
    "status": "processed"
  },
  "timestamp": "{ISO-8601-UTC}",
  "status": "pending"
}
```

**Write acknowledgment to:** `.claude/session/messages/watchdog/msg-watchdog-{timestamp}-{seq}.json`

**IMPORTANT:** Use the exact `id` from the original message in the `payload.messageId` field. This allows watchdog to track and delete the message properly.

### Message Types to Handle

| Type           | From       | Action                                  |
| -------------- | ---------- | --------------------------------------- |
| `task_assign`  | pm         | Update status, begin work               |
| `wake_up`      | pm         | Resume work on current task             |
| `question`     | pm         | Research and respond                    |
| `retrospective_initiate` | pm | Send contribution (see retrospective section) |

### Example: Processing a task_assign Message

```
1. Glob: .claude/session/messages/techartist/msg-*.json
2. Read: msg-techartist-20260127-120000-001.json
3. Extract: taskId, title, acceptanceCriteria from payload
4. Update current-task-techartist.json: state.status = "working"
5. Update current-task-techartist.json: state.currentTaskId = "{taskId}"
6. Send acknowledgment to watchdog (see format above)
7. DELETE: msg-techartist-20260127-120000-001.json
8. Begin work
```

---

## Workflow Steps

```
,============================================================================.
| 1. UPDATE STATUS                                                          |
|    -> Edit current-task-techartist.json                                    |
|    -> state.status = "working"                                            |
|    -> state.currentTaskId = "{taskId}"                                    |
|    -> state.lastSeen = "{ISO_TIMESTAMP}"                                  |
+----------------------------------------------------------------------------+
| 2. TASK RESEARCH (MANDATORY)                                              |
|    -> Check src/assets/ for existing                                       |
|    -> Task("task-researcher", {...})                           |
|    -> Write findings to task memory                                        |
+----------------------------------------------------------------------------+
| 3. LOAD DOMAIN SKILLS                                                      |
|    -> Use ta-router to determine skills                                     |
|    -> Load only required skills                                            |
+----------------------------------------------------------------------------+
| 4. CREATE ASSET                                                            |
|    -> Follow patterns from domain skills                                   |
|    -> Write technical decisions to task memory                             |
+----------------------------------------------------------------------------+
| 5. VISUAL VERIFICATION                                                     |
|    -> Navigate localhost:3000 via Playwright                               |
|    -> Take screenshot: .claude/session/playwright-test/{taskId}-asset.png  |
|    -> Verify console clean                                                 |
+----------------------------------------------------------------------------+

### Server Detection (Before Visual Verification)

**⚠️ CRITICAL: Check for existing servers before starting new ones.**

```bash
# Check if dev server is running (port 3000)
netstat -an | grep :3000 || lsof -i :3000

# Alternative: Try curl to detect Vite
curl -s http://localhost:3000 | grep -q "vite" && echo "RUNNING" || echo "NOT_RUNNING"
```

**Decision Tree:**

```
                    Server already running?
                            |
            ┌───────────────┴───────────────┐
            │                               │
         YES                            NO
            │                               │
            ▼                               ▼
   Use existing server              Start in background
   Navigate to localhost:3000       Capture shell_id for cleanup
                                    TaskStop after validation
```

**For E2E tests (`npm run test:e2e`):** Playwright manages servers automatically. DO NOT start manually.

**For manual visual verification:** If server not running, start with background process and cleanup after.

+----------------------------------------------------------------------------+
| 6. FEEDBACK LOOPS                                                          |
|    -> Skill("shared-validation-feedback-loops")                             |
|    -> type-check, lint, build                                              |
+----------------------------------------------------------------------------+
| 7. COMMIT AND EXIT                                                         |
|    -> See [Exit Conditions](#exit-conditions) below                        |
`============================================================================'
```

## Terrain-Specific Workflow

**For terrain refactor tasks (test-fix-terrain-001, terrain-phase-002 through 009):**

1. **Read the implementation plan** first:
   - `docs/implementation/terrain-refactor-plan.md`
   - Identify which phase you're working on
   - Follow the checklist for that phase

2. **Create isolated test scene** before implementation:
   - Each terrain component has its own test scene
   - Test scenes allow visual validation without full game

3. **Use E2E tests for validation** (NOT MCP):
   - Playwright tests in `tests/e2e/terrain-system.spec.ts`
   - Take screenshots at each phase
   - Save to `test-results/terrain/phaseX-{component}/`

4. **Component Dependencies** (follow this order):
   ```
   Phase 1: TerrainMesh (foundation)
      ↓
   Phase 2: WaterPlane (sibling)
      ↓
   Phase 3: GrassInstancer (uses TerrainMesh height)
      ↓
   Phase 4: PaintOverlay (sibling)
      ↓
   Phase 5: TerritoryGrid (CPU-based, independent)
      ↓
   Phase 6: Integration (TerrainGameScene orchestrator)
   ```

5. **Required Skills for Each Phase**:
   - Phase 1: `Skill("ta-terrain-mesh")`
   - Phase 2: `Skill("ta-water-shader")`
   - Phase 3: `Skill("ta-foliage-instancing")`
   - Phase 4: `Skill("ta-paint-territory")`
   - Phase 5: `Skill("ta-territory-grid-cpu")`
   - All phases: `Skill("ta-terrain-testing")` for E2E patterns

## State Machine

| Current State | Trigger           | Action           | Next State    |
| ------------- | ----------------- | ---------------- | ------------- |
| `idle`        | Task assigned     | Research assets  | `researching` |
| `researching` | Assets exist      | Report to PM     | `idle`        |
| `researching` | New asset needed  | Check direction  | `planning`    |
| `researching` | Direction unclear | Request GD input | `awaiting_gd` |
| `planning`    | Direction clear   | Create asset     | `creating`    |
| `creating`    | Asset complete    | Visual validate  | `validating`  |
| `validating`  | Visual approved   | Browser test     | `testing`     |
| `testing`     | Test pass         | Send to QA       | `awaiting_qa` |
| `validating`  | Issues found      | Fix issues       | `creating`    |
| `awaiting_qa` | Bugs found        | Fix bugs         | `creating`    |
| `any`         | Budget unclear    | Ask PM           | `awaiting_pm` |
| `awaiting_pm` | Guidance provided | Resume           | `researching` |
| `awaiting_gd` | Answer provided   | Resume           | `planning`    |

## Dashboard Status Updates

**Before ANY action, update your state file:**

```json
// Use Edit tool on current-task-techartist.json
{
  "state": {
    "status": "working|awaiting_pm|awaiting_gd|idle",
    "currentTaskId": "{taskId}|null",
    "lastSeen": "{ISO-8601-timestamp}"
  }
}
```

**⚠️ V2.0:** Tech Artist does NOT update prd.json directly. PM syncs from your state file.

## Exit Conditions

**BEFORE exiting, you MUST:**

1. Screenshot via Playwright MCP (file: `.claude/session/playwright-test/{taskId}-asset.png`)
2. Console clean (no errors/warnings)
3. Commit: `[ralph] [techartist] {taskId}: Description`
4. Push: `git push origin techartist-worktree`
5. Update `current-task-techartist.json`: `state.status = "idle"`
6. Send `implementation_complete` message to PM (use Write tool)
7. **CRITICAL: Acknowledge and delete ALL processed messages:**
   - For each message file you processed: Send acknowledgment to watchdog
   - Then DELETE each message file from `.claude/session/messages/techartist/`

### Sending Completion to PM

```json
// Write to: .claude/session/messages/pm/msg-pm-{timestamp}-001.json
{
  "id": "msg-pm-{timestamp}-001",
  "from": "techartist",
  "to": "pm",
  "type": "implementation_complete",
  "priority": "normal",
  "payload": {
    "taskId": "{taskId}",
    "success": true,
    "summary": "Asset created and validated"
  },
  "timestamp": "{ISO-8601-UTC}",
  "status": "pending"
}
```

### Acknowledging Processed Messages

```json
// For EACH message you processed, write to: .claude/session/messages/watchdog/msg-watchdog-{timestamp}-{seq}.json
{
  "id": "msg-watchdog-{timestamp}-{seq}",
  "from": "techartist",
  "to": "watchdog",
  "type": "message_acknowledged",
  "priority": "normal",
  "payload": {
    "messageId": "{ORIGINAL_MESSAGE_ID}",
    "status": "processed"
  },
  "timestamp": "{ISO-8601-UTC}",
  "status": "pending"
}
```

**IMPORTANT:** Use the exact `id` from the original message in `payload.messageId`. After sending acknowledgment, DELETE the original message file.

## QA Validation Message

```json
// Write to: .claude/session/messages/qa/msg-qa-{timestamp}-001.json
{
  "id": "msg-qa-{timestamp}-001",
  "from": "pm",
  "to": "qa",
  "type": "validation_request",
  "priority": "normal",
  "payload": {
    "taskId": "{taskId}",
    "title": "{Task Title}",
    "category": "shader|visual|asset",
    "files": ["src/path/to/file1.ts"],
    "acceptanceCriteria": ["Criterion 1", "Criterion 2"],
    "screenshot": ".claude/session/playwright-test/{taskId}-asset.png"
  },
  "timestamp": "{ISO-8601-timestamp}",
  "status": "pending"
}
```

## If QA Finds Bugs

**When you receive a bug report message from QA:**

1. **Read** the bug report message
2. **Acknowledge** the message to watchdog (using original message ID)
3. **DELETE** the bug report message file
4. Fix all issues
5. Run feedback loops
6. Take new screenshot
7. Commit with fix message
8. Send `implementation_complete` to PM
9. **Remember:** Acknowledge and delete the bug report message!

## Context Window Monitoring

**Enable for:**

- 5+ acceptance criteria
- 3+ assets
- `architectural` or `shader` category

**Procedure:**

1. Check `/context` after 3-5 operations
2. If >=70%, create checkpoint
3. Update state file with checkpoint reference
4. Send message to watchdog with restart context. Exit - watchdog restarts with restored context

## Retrospective Contribution

When `retrospective_initiate` received:

-> Skill("shared-retrospective")

## See Also

- [ta-router](../ta-router/SKILL.md) - Domain skill routing
- [ta-terrain-mesh](../ta-terrain-mesh/SKILL.md) - NEW: Mesh-based terrain generation
- [ta-territory-grid-cpu](../ta-territory-grid-cpu/SKILL.md) - NEW: CPU territory tracking
- [ta-terrain-testing](../ta-terrain-testing/SKILL.md) - NEW: E2E testing patterns for terrain
- [shared-worker](../shared-worker/SKILL.md) - Message handling and worktree management
- [shared-retrospective](../shared-retrospective/SKILL.md) - Task memory and retrospective contributions
