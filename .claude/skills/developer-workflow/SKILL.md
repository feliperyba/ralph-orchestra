---
name: developer-workflow
description: Complete Developer workflow orchestration - task research sequence, implementation flow, validation gates, PRD synchronization, exit conditions.
category: workflow
---

# Developer Workflow

> "This skill orchestrates the development workflow sequence. For detailed implementation guidance, see referenced skills."

## Quick Reference

| Phase              | Invoke With                                                                                                                |
| ------------------ | -------------------------------------------------------------------------------------------------------------------------- |
| Worktree Setup     | `Skill("shared-worktree")`                                                                                                 |
| Task Research      | `Skill("dev-research-gdd-reading")`, `Skill("dev-research-codebase-exploration")`, `Skill("dev-research-pattern-finding")` |
| Skill Selection    | `Skill("dev-router")`                                                                                                      |
| E2E Testing        | `Skill("dev-validation-browser-testing")`                                                                                  |
| Quality Gates      | `Skill("dev-validation-quality-gates")`                                                                                    |
| Feedback Loops     | `Skill("dev-validation-feedback-loops")`                                                                                   |
| Git/Commits        | `Skill("dev-coordination-git-protocol")`                                                                                   |
| Task Memory        | `Skill("shared-retrospective")`                                                                                            |
| Retrospective      | `Skill("shared-retrospective")`                                                                                            |
| Context Management | `Skill("shared-context")`                                                                                                  |

---

## Startup Workflow

**You are a WORKER managed by the WATCHDOG orchestrator.**

On agent startup or task assignment:

1. **Worktree check** - `Skill("shared-worktree")`
2. **Process pending messages** (MANDATORY) - Use Glob + Read tools from `.claude/session/messages/developer/msg-*.json`, acknowledge to watchdog
3. **Read current-task-developer.json** - Get current task assignment (v2.0: DO NOT read prd.json)
4. **Load skill router** - `Skill("dev-router")`
5. **Task research** (MANDATORY) - See below
6. **Implement feature** - Following researched patterns
7. **Run feedback loops** - `Skill("dev-validation-feedback-loops")`
8. **Commit and send to QA** - `Skill("dev-coordination-git-protocol")`

> **Message acknowledgment:** `Skill("shared-messaging")` for complete pattern

---

## Dashboard Status Update (Before Every Action)

**CRITICAL: Before starting ANY work action, update your status in current-task-developer.json:**

| Action                      | Update State File Like This                                                         |
| --------------------------- | ---------------------------------------------------------------------------------- |
| **Starting work on task**   | `state.status = "working"` + `id = "{taskId}"` + `state.lastSeen = "{ISO_TIMESTAMP}"` |
| **Blocked by question**     | `state.status = "awaiting_pm"` + `state.lastSeen = "{ISO_TIMESTAMP}"`               |
| **Sending to QA**           | `state.status = "idle"` + `id = null` + `state.lastSeen = "{ISO_TIMESTAMP}"`         |
| **Self-reporting progress** | `state.lastSeen = "{ISO_TIMESTAMP}"`                                                |

**⚠️ V2.0 IMPORTANT:** Workers do NOT update prd.json directly. The PM reads your state file and syncs to prd.json.

**If you don't update:**

- PM thinks you crashed and may reassign your task
- Dashboard shows stale status

---

## Task Research (MANDATORY Before Coding)

**⚠️ BLOCKING RULE: You MUST invoke code-research sub-agent BEFORE writing any code.**

### Step 1: GDD Reading

```
Skill("dev-research-gdd-reading")
```

- Read `docs/design/gdd/index.md` for overview
- Read feature-specific GDD files
- Check decision log and open questions

### Step 2: Codebase Exploration

```
Skill("dev-research-codebase-exploration")
```

- Use Glob to find relevant files
- Use Grep to search for patterns
- Read similar implementations

### Step 3: Pattern Finding

```
Skill("dev-research-pattern-finding")
```

- Document existing patterns
- Identify import patterns, component structure, state management

### Step 4: Invoke code-research sub-agent (optional but recommended)

```
Task({
  subagent_type: "developer-code-research",
  description: "Research patterns for {feature}",
  prompt: "Research existing codebase patterns for implementing {feature}",
  timeout: 300000
})
```

---

## Skill Selection

Load `dev-router` for complete skill catalog:

```
Skill("dev-router")
```

The router provides:

- 31 developer skills in 9 categories (R3F, Multiplayer, Assets, Performance, Patterns, TypeScript, Validation, Research, Coordination)
- Signal-based keyword routing
- 5 sub-agents: orchestrator, code-research, implementation, validation, commit

Always load the correct skill or use the correct sub-agent before working with the tasks. You are working with game mechanics, physics, colyseus.js, r3f and typescript often. Those are primary skills for your work

---

## Implementation Workflow

1. **UPDATE STATE FILE** (MANDATORY - First step)
   - Edit `current-task-developer.json`:
     - `state.status = "working"`
     - `state.currentTaskId = "{taskId}"`
     - `state.lastSeen = "{ISO_TIMESTAMP}"`

2. **CREATE TASK MEMORY** - `Skill("shared-retrospective")`
   - File: `.claude/session/agents/developer/task-{taskId}-memory.md`

3. **TASK RESEARCH** - See previous section

4. **SKILL INVOCATION**
   - Load relevant skill(s) from dev-router

5. **IMPLEMENTATION**
   - Create/modify files following researched patterns
   - Use absolute imports (@/ alias)
   - Write decisions to task memory

6. **E2E TEST CREATION** (for new features) - `Skill("dev-validation-browser-testing")`
   - File: `tests/e2e/{feature}-suite.spec.ts`
   - Run: `npm run test:e2e -- -g "test-name"`
   - Skip only for: bug fixes, refactorings, non-visual changes

7. **IF BLOCKED**
   - Update state: `state.status = "awaiting_pm"`
   - Send question to PM using the **Write tool**:

   ```
   Write to: .claude/session/messages/pm/msg-pm-{timestamp}-001.json
   Content:
   {
     "id": "msg-pm-{timestamp}-001",
     "from": "developer",
     "to": "pm",
     "type": "question",
     "priority": "high",
     "payload": {
       "question": "How should I handle X?",
       "context": "Current situation..."
     },
     "timestamp": "{ISO-8601-timestamp}",
     "status": "pending"
   }
   ```

   - Document blocker in task memory
   - Exit and wait

8. **FEEDBACK LOOPS** (MANDATORY) - `Skill("dev-validation-feedback-loops")`

   ```bash
   npm run type-check  # 0 errors
   npm run lint        # 0 warnings
   npm run test        # All pass
   npm run build       # Success
   ```

9. **COMMIT** - `Skill("dev-coordination-git-protocol")`

   ```
   [ralph] [developer] {taskId}: Brief description
   ```

10. **SEND TO QA**

- Update state: `state.status = "idle"`, `id = null`
- Send completion using the **Write tool**:

  ```
  Write to: .claude/session/messages/pm/msg-pm-{timestamp}-001.json
  Content:
  {
    "id": "msg-pm-{timestamp}-001",
    "from": "developer",
    "to": "pm",
    "type": "task_complete",
    "priority": "normal",
    "payload": {
      "taskId": "{taskId}",
      "success": true,
      "summary": "Implementation complete"
    },
    "timestamp": "{ISO-8601-timestamp}",
    "status": "pending"
  }
  ```

- Exit (PM will set task status to awaiting_qa after reading your state file)

---

## Pre-Commit Checklist

- [ ] Worktree verified - `Skill("shared-worktree")`
- [ ] Task research completed (code-research invoked)
- [ ] Implementation follows existing patterns
- [ ] E2E test created for new features - `Skill("dev-validation-browser-testing")`
- [ ] E2E test passes locally
- [ ] All feedback loops pass - `Skill("dev-validation-feedback-loops")`
- [ ] No error suppression - `Skill("dev-validation-quality-gates")`
- [ ] Committed with Ralph format - `Skill("dev-coordination-git-protocol")`
- [ ] Pushed to developer-worktree branch

---

## Exit Conditions

### State File Status Reference (v2.0)

| Scenario         | Your State File (`state.status`) | Message / Write Command                                             |
| ---------------- | ------------------------------- | ------------------------------------------------------------------- |
| Starting work    | `working` + `currentTaskId = "{taskId}"` | (none - just update state file)                                   |
| Blocked/question | `awaiting_pm`                   | Write to messages/pm/msg-pm-{ts}-001.json with type="question"      |
| Sending to QA    | `idle` + `id = null`            | Write to messages/pm/msg-pm-{ts}-001.json with type="task_complete" |
| QA returned bugs | `working` + `currentTaskId = "{taskId}"` | (none - just update state file)                                   |
| Fixes complete   | `idle` + `id = null`            | Write to messages/pm/msg-pm-{ts}-001.json with type="task_complete" |
| Heartbeat        | (unchanged)                     | (update `state.lastSeen` in state file)                             |

**⚠️ V2.0:** Workers update ONLY their state file. PM syncs state to prd.json.

**ALWAYS update your state file before exiting!**

---

## Retrospective Contribution

When `retrospective_initiate` message received:

1. **Read ALL task memory files** - `Skill("shared-retrospective")`
   - Directory: `.claude/session/agents/developer/`
   - Pattern: `task-*.md`

2. **Read retrospective.txt**

3. **Create contribution file** - `Skill("shared-retrospective")`
   - File: `.claude/session/retrospective-developer.json`

4. **Delete ALL task memory files**

5. **Update state file** - Set `state.status = "idle"`

---

## Domain-Specific Skills

For multiplayer features:

```
Skill("dev-multiplayer-server-authoritative")  # Server-authoritative architecture
Skill("dev-multiplayer-colyseus-server")       # Colyseus server setup
Skill("dev-multiplayer-prediction-basics")     # Client-side prediction
```

For performance optimization:

```
Skill("dev-performance-performance-basics")    # Core optimization principles
Skill("dev-performance-instancing")            # InstancedMesh patterns
Skill("dev-patterns-object-pooling")           # Object pooling
```

For R3F development:

```
Skill("dev-r3f-r3f-fundamentals")  # Scene composition, useFrame
Skill("dev-r3f-r3f-physics")       # @react-three/rapier
Skill("dev-r3f-r3f-materials")     # Custom shaders
```
