# Task Handoff Patterns

> When a task moves between agents, the task JSON MUST move between agent state files.

## Handoff Summary Table

| Handoff         | From Agent  | To Agent  | PM Action                                           |
| --------------- | ----------- | --------- | --------------------------------------------------- |
| Implementation  | Developer   | QA        | Copy task to QA, clear from Developer, update PRD   |
| Asset Complete  | Tech Artist | QA        | Copy task to QA, clear from Tech Artist, update PRD |
| Validation Pass | QA          | PM        | Trigger retrospective, later clear from all         |
| Validation Fail | QA          | Developer | Update with bugs, reassign to Developer             |
| Task Complete   | Any         | Archive   | Add to prd_completed.json, clear from all           |

---

## Developer → QA Handoff (Most Common)

**Trigger:** Developer sends `implementation_complete` message

```bash
# Step 1: Read developer state file
Read: .claude/session/current-task-developer.json

# Step 2: Copy task JSON from developer
Extract task object (id, title, description, acceptanceCriteria, etc.)

# Step 3: MOVE task to QA state file
Read: .claude/session/current-task-qa.json
Paste task JSON to QA's task fields
Update QA state:
  - status: "working"
  - currentTaskId: "{taskId}"
  - lastSeen: "{NOW}"

# Step 4: Clear developer's task
Set developer task.id = null
Set developer task.title = "No active task"
Add task to developer's "completedTasks" array

# Step 5: Update developer state
  - status: "idle"
  - currentTaskId: null
  - lastSeen: "{NOW}"

# Step 6: Update prd.json
prd.json.items[{taskId}].status = "awaiting_qa"
prd.json.agents.developer.status = "idle"
prd.json.agents.qa.status = "working"

# Step 7: Send validation_request message to QA
Write to: .claude/session/messages/qa/msg-qa-{timestamp}.json
```

**Example Message:**

```json
{
  "id": "msg-qa-2024-01-27T001-001",
  "from": "pm",
  "to": "qa",
  "type": "validation_request",
  "priority": "normal",
  "payload": {
    "taskId": "arch-001",
    "message": "Developer completed implementation. Please validate."
  },
  "timestamp": "2024-01-27T12:00:00.000Z",
  "status": "pending"
}
```

---

## Tech Artist → QA Handoff

**Trigger:** Tech Artist sends `asset_complete` message

```bash
# Same pattern as Developer → QA, but:
# - Read from current-task-techartist.json
# - Write to current-task-qa.json
# - Clear Tech Artist's task fields
# - Update prd.json.agents.techartist.status = "idle"
```

---

## QA Completion → Archive

**Trigger:** QA sends `task_complete` (validation PASS)

```bash
# Step 1: Read QA state file
Read: .claude/session/current-task-qa.json

# Step 2: Move task to QA's completedTasks
Add task object to QA's "completedTasks" array
Clear QA's active task fields (id=null, title="No active task")

# Step 3: Update QA state
  - status: "idle"
  - currentTaskId: null
  - lastSeen: "{NOW}"

# Step 4: Update prd.json
prd.json.items[{taskId}].status = "completed"
prd.json.items[{taskId}].passes = true
prd.json.items[{taskId}].validatedAt = "{NOW}"
prd.json.agents.qa.status = "idle"

# Step 5: Send task_complete message to PM
```

**After Retrospective (Phase 4):**

```bash
# Step 6: Add task to prd_completed.json
Append task summary with all details (taskId, title, agent, completionDate, commits)

# Step 7: CLEAR task from ALL agent state files
Remove from developer's "completedTasks" array (or clear entire array)
Remove from QA's "completedTasks" array
Remove from techartist's "completedTasks" array (if applicable)

# Step 8: Delete task from prd.json.items
Delete prd.json.items[{taskId}]
```

---

## Validation Fail → Reassign

**Trigger:** QA sends `task_complete` (validation FAIL)

```bash
# Step 1: Read QA state file
Read: .claude/session/current-task-qa.json

# Step 2: Update task with bug reports
Add bug findings to task.bugs array
Update task.attempts += 1

# Step 3: Check if max attempts reached
if task.attempts >= 3:
  Set task.status = "blocked"
  Log for escalation
else:
  # Step 4: MOVE task back to developer
  Copy task JSON to current-task-developer.json
  Update developer state:
    - status: "working"
    - currentTaskId: "{taskId}"
    - lastSeen: "{NOW}"

  # Step 5: Clear QA's task fields
  Set QA task.id = null
  Set QA task.title = "No active task"

  # Step 6: Update both states
  Update developer state: status="working"
  Update QA state: status="idle", currentTaskId=null

  # Step 7: Update prd.json
  prd.json.items[{taskId}].status = "needs_fixes"
  prd.json.items[{taskId}].passes = false
  prd.json.agents.developer.status = "working"
  prd.json.agents.qa.status = "idle"

  # Step 8: Send task message to developer
```

---

## Critical Reminders

- ✅ **ALWAYS** copy the FULL task JSON between state files
- ✅ **ALWAYS** update both agent state objects
- ✅ **ALWAYS** update prd.json atomically
- ✅ **ALWAYS** send the appropriate message
- ❌ **NEVER** leave task in both agent's state files simultaneously
- ❌ **NEVER** update state file without updating prd.json
