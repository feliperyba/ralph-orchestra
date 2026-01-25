---
name: developer-workflow
description: Complete Developer workflow orchestration - worktree coordination, task research sequence, skill invocation flow, PRD synchronization, exit conditions. Reference other skills for detailed implementation guidance.
category: workflow
keywords: [dev, workflow, development, process, tasks, implementation, git, worktree]
version: 3.0
changelog: "MAJOR REFACTOR: Removed 400+ lines of duplication. Now a thin orchestration layer that references specialized skills."
---

# Developer Workflow

> "This skill orchestrates the development workflow sequence. For detailed implementation guidance, see referenced skills."

## Quick Reference

| Phase | Invoke With |
|-------|-------------|
| Worktree Setup | `Skill("shared-worker-worktree")` |
| Task Research | `Skill("dev-research-gdd-reading")`, `Skill("dev-research-codebase-exploration")`, `Skill("dev-research-pattern-finding")` |
| Skill Selection | `Skill("dev-router")` |
| E2E Testing | `Skill("dev-validation-browser-testing")` |
| Quality Gates | `Skill("dev-validation-quality-gates")` |
| Feedback Loops | `Skill("dev-validation-feedback-loops")` |
| Git/Commits | `Skill("dev-coordination-git-protocol")` |
| Task Memory | `Skill("shared-worker-task-memory")` |
| Retrospective | `Skill("shared-worker-retrospective")` |
| Context Management | `Skill("shared-context-management")` |

---

## Worktree and Master Coordination

**CRITICAL**: You work in a git worktree (`../developer-worktree/`). All code goes to worktree branch, all coordination targets master branch.

For complete worktree setup and master branch coordination:
```
Skill("shared-worker-worktree")
```

---

## Startup Workflow

On agent startup or task assignment:

1. **Worktree check** - Verify in correct worktree → `Skill("shared-worker-worktree")`
2. **Source message queue script** - Initialize message queue
3. **Process pending messages** (MANDATORY) - Prevents watchdog restart loop
4. **Read prd.json** - Get current task assignment
5. **Load skill router** - `Skill("dev-router")`
6. **Task research** (MANDATORY) - See below
7. **Implement feature** - Following researched patterns
8. **E2E test creation** - For new features → `Skill("dev-validation-browser-testing")`
9. **Run feedback loops** - `Skill("dev-validation-feedback-loops")`
10. **Commit and send to QA** - `Skill("dev-coordination-git-protocol")`

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

---

## Implementation Workflow

1. **CREATE TASK MEMORY** - `Skill("shared-worker-task-memory")`
   - File: `.claude/session/agents/developer/task-{taskId}-memory.md`
   - PRD update: `prd.json.items[{taskId}].status = "in_progress"`

2. **TASK RESEARCH** - See previous section

3. **SKILL INVOCATION**
   - Load relevant skill(s) from dev-router

4. **IMPLEMENTATION**
   - Create/modify files following researched patterns
   - Use absolute imports (@/ alias)
   - Write decisions to task memory

5. **E2E TEST CREATION** (for new features) - `Skill("dev-validation-browser-testing")`
   - File: `tests/e2e/{feature}-suite.spec.ts`
   - Run: `npm run test:e2e -- -g "test-name"`
   - Skip only for: bug fixes, refactorings, non-visual changes

6. **IF BLOCKED**
   - PRD: `status = "awaiting_pm_clarification"`
   - Send `question` message to PM
   - Document blocker in task memory
   - Exit and wait

7. **FEEDBACK LOOPS** (MANDATORY) - `Skill("dev-validation-feedback-loops")`
   ```bash
   npm run type-check  # 0 errors
   npm run lint        # 0 warnings
   npm run test        # All pass
   npm run build       # Success
   ```

8. **COMMIT** - `Skill("dev-coordination-git-protocol")`
   ```
   [ralph] [developer] {taskId}: Brief description
   ```

9. **SEND TO QA**
   - PRD: `status = "awaiting_qa"`, `passes = false`
   - Send `implementation_complete` message to QA
   - Agent status: `idle`
   - Exit

---

## Quality Standards

```
Skill("dev-validation-quality-gates")
```
- No `any` types, `@ts-ignore`, `eslint-disable`, `as any`, non-null assertions
- Proper test coverage
- Meaningful names, no console.log in production

---

## Pre-Commit Checklist

- [ ] Worktree verified - `Skill("shared-worker-worktree")`
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

### PRD Status Reference

| Scenario | Task Status | Agent Status | Message |
|----------|-------------|--------------|---------|
| Starting work | `in_progress` | `working` | (none) |
| Blocked/question | `awaiting_pm_clarification` | `awaiting_pm` | `question` to PM |
| Sending to QA | `awaiting_qa` | `idle` | `implementation_complete` to QA |
| QA returned bugs | `in_progress` | `working` | (none) |
| Fixes complete | `awaiting_qa` | `idle` | `implementation_complete` to QA |
| Heartbeat | (unchanged) | (update `lastSeen`) | `status_update` |

**ALWAYS update BOTH task status AND agent status before exiting!**

---

## Context Window Monitoring

For big tasks (5+ acceptance criteria, 3+ files, architectural):

```
Skill("shared-context-management")
```
- Context checking with `/context` command
- Checkpoint creation when >= 70%
- Worker resumption procedure

---

## Retrospective Contribution

When `retrospective_initiate` message received:

1. **Read ALL task memory files** - `Skill("shared-worker-task-memory")`
   - Directory: `.claude/session/agents/developer/`
   - Pattern: `task-*.md`

2. **Read retrospective.txt**

3. **Create contribution file** - `Skill("shared-worker-retrospective")`
   - File: `.claude/session/retrospective-developer.json`

4. **Delete ALL task memory files**

5. **Update PRD status** to `idle`

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
