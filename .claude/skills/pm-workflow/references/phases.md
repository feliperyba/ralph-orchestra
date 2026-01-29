# Post-Completion Phases (6-Phase Workflow)

> **CRITICAL: After QA passes a task, you MUST complete ALL phases in order before selecting the next task.**
>
> **⚠️ DO NOT EXIT after each phase! Continue immediately to the next phase!**

## Workflow Overview

```
completed (QA passed)
    ↓
Phase 3: PRD Reorganization (MANDATORY)
    ↓
Phase 4: Cleanup Completed Tasks (MANDATORY)
    ↓
Phase 5: Skill Research (MANDATORY)
    ↓
Phase 6: Select Next Task (MANDATORY)
    ↓
task_ready → test_planning → assigned
```

---

## Phase 3: PRD Reorganization (MANDATORY)

**⚠️ CRITICAL: PRD reorganization is MANDATORY after EVERY retrospective!**

**When:** After retrospective synthesis (playtest complete or skipped)

**Action:**

1. **ALWAYS** use `Skill("pm-organization-prd-reorganization")` or Task with `pm-prd-organizer` sub-agent
2. Extract new tasks from GDD if design changed
3. Reorganize backlog based on retrospective findings
4. Update task priorities based on pain points
5. Document any new dependencies discovered
6. Refill `prd.json.items` from backlog if < 5 tasks

**Update PRD:**

```json
prd.session.currentTask.status = "prd_refinement"
prd.session.status = "prd_refinement"
```

**⚠️ DO NOT SKIP THIS PHASE - Even if no changes, you MUST verify and document!**

**Next state:** `cleanup_completed`

**⚠️ CONTINUE immediately to Phase 4! DO NOT EXIT!**

---

## Phase 4: Cleanup Completed Tasks (MANDATORY)

**⚠️ CRITICAL: Clean up completed tasks, DELETE retrospective file, and CLEAR agent state files!**

**When:** After PRD reorganization

**Action:**

1. **Identify all `status: "completed"` tasks** from prd.json
2. **For EACH completed task, CLEAR from agent state files:**
   - Read agent state file where task was last processed
   - Remove task from "completedTasks" array (or clear entire array)
   - Task details are now safely archived in prd_completed.json
3. **Move completed tasks to `prd_completed.json`:**
   - Append task summary with all details
   - Include: taskId, title, agent, completionDate, commits
4. **Remove from `prd.json.items`** - Delete completed task entries
5. **Update counts:** `completedTasks`, `activeQueueSize`
6. **Refill from backlog** if < 5 tasks in prd.json.items

**Update PRD:**

```json
prd.session.stats.completedTasks += {count}
prd.session.stats.activeQueueSize = prd.items.length
```

---

## Phase 6: Select Next Task (MANDATORY)

**When:** After skill research

**Action:**

1. Use `Skill("pm-organization-task-selection")` to select next task
2. **Check if test planning needed**
3. If yes, use Task with `pm-test-planner` sub-agent
4. Assign task to worker
5. **CRITICAL: Send task message to worker**
6. **DO NOT EXIT until task is assigned AND message is sent**

**Update PRD:**

```json
prd.session.currentTask = {newTaskId, title, category}
prd.session.currentTask.status = "assigned"
prd.json.items[{taskId}].status = "assigned"
prd.json.agents.{agent}.status = "working"
```

**Next state:** `assigned` (back to normal workflow)

**✅ AFTER assigning task and sending message: NOW you can EXIT!**

---

## Complete Workflow Diagram

```
<post_completion>
  <phase_3>
    Name: PRD Reorganization
    Trigger: After Phase 2
    Action: Reorganize backlog, extract new tasks, refill items
    MANDATORY: Always execute, even if no changes
    Next: cleanup_completed
  </phase_3>
  <phase_4>
    Name: Cleanup
    Trigger: After Phase 3
    Action: Delete retrospective, move to prd_completed.json, clear state files
    MANDATORY: Always execute
    Next: skill_research
  </phase_4>
  <phase_6>
    Name: Select Next Task
    Trigger: After Phase 5
    Action: Select task, plan tests, assign to worker
    MANDATORY: Send task message before exit
    Next: assigned (back to workflow)
  </phase_6>
</post_completion>
```

---
