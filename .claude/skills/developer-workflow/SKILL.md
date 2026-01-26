---
name: developer-workflow
description: Complete Developer workflow orchestration - worktree coordination, task research, implementation, validation, commit. Use proactively when starting development work or when unclear about the development process flow.
category: workflow
tags: [development, agile, workflow]
dependencies:
  [
    shared-worker-worktree,
    shared-validation-feedback-loops,
    shared-worker-task-memory,
    dev-router,
  ]
---

# Developer Workflow

> "Research patterns → Implement → Validate → Commit - Never suppress errors."

## When to Use This Skill

Use **when**:

- Starting development work on a task
- Unclear about the development process sequence
- Need to reference research, validation, or commit procedures

Use **proactively**:

- At the start of every development task
- When blocked and need to understand next steps
- Before committing to ensure all steps are complete

---

## Quick Start

<examples>
Example 1: New feature implementation
```
1. Worktree check → Skill("shared-worker-worktree")
2. Research patterns → Task("developer-code-research", ...)
3. Implement → Create files following patterns
4. Validate → Skill("shared-validation-feedback-loops")
5. Commit → [ralph] [developer] feat-001: description
```

Example 2: Bug fix

```
1. Worktree check → Skill("shared-worker-worktree")
2. Research bug patterns → Task("developer-code-research", ...)
3. Implement fix → Modify files
4. Validate → Skill("shared-validation-feedback-loops")
5. Commit → [ralph] [developer] bug-001: fix description
```

Example 3: Multiplayer feature

```
1. Worktree check → Skill("shared-worker-worktree")
2. Research server-authoritative patterns → Skill("dev-multiplayer-server-authoritative")
3. Implement → Server + client code
4. Validate → Skill("shared-validation-feedback-loops")
5. Multiplayer test → Skill("dev-validation-browser-testing")
6. Commit → [ralph] [developer] feat-002: multiplayer feature
```

</examples>

---

## Development Cycle (Agile-Inspired)

### Phase 1: Sprint Planning (Task Start)

```
Worktree check → Read PRD → Research patterns → Load skills
```

1. Verify worktree: `Skill("shared-worker-worktree")`
2. Read `prd.json` for task assignment
3. Load skill router: `Skill("dev-router")`
4. **MANDATORY**: Research existing patterns

### Phase 2: Sprint Execution (Implementation)

```
Create task memory → Implement → Test → Validate
```

1. Create task memory: `Skill("shared-worker-task-memory")`
2. Follow researched patterns
3. Create E2E tests for new features
4. Run quality gates

### Phase 3: Definition of Done

```
All acceptance criteria ✓ + Quality gates pass ✓ + No error suppression
```

- [ ] All acceptance criteria met
- [ ] Type-check passes (0 errors)
- [ ] Lint passes (0 warnings)
- [ ] Tests pass (all green)
- [ ] Build succeeds
- [ ] No error suppression used

### Phase 4: Sprint Review (Commit)

```
Commit → Update PRD → Send to QA → Exit
```

1. Commit with Ralph format
2. Update PRD: `status = "awaiting_qa"`, `passes = false`
3. Send `WorkComplete` to PM
4. Push to `developer-worktree` branch
5. Exit (watchdog will respawn)

---

## Task Research (MANDATORY)

**⚠️ BLOCKING RULE: You MUST research codebase patterns BEFORE writing code.**

### Research Steps

| Step                    | Skill/Sub-Agent                              | Purpose             |
| ----------------------- | -------------------------------------------- | ------------------- |
| 1. GDD Reading          | `Skill("dev-research-gdd-reading")`          | Design requirements |
| 2. Codebase Exploration | `Skill("dev-research-codebase-exploration")` | Find relevant files |
| 3. Pattern Finding      | `Skill("dev-research-pattern-finding")`      | Identify patterns   |
| 4. Code Research        | `Task("developer-code-research", ...)`       | Deep research       |

### Code Research Invocation

```javascript
Task({
  subagent_type: "developer-code-research",
  description: "Research patterns for {feature}",
  prompt: "Research existing codebase patterns for implementing {feature}",
  timeout: 300000,
});
```

---

## Implementation Steps

| Step | Action             | Skill Reference                    |
| ---- | ------------------ | ---------------------------------- |
| 1    | Create task memory | `shared-worker-task-memory`        |
| 2    | Load domain skills | `dev-router`                       |
| 3    | Implement feature  | Follow researched patterns         |
| 4    | Create E2E tests   | `dev-validation-browser-testing`   |
| 5    | Run quality gates  | `shared-validation-feedback-loops` |

### If Blocked

- PRD: `status = "awaiting_pm_clarification"`
- Send `Query` to PM or Game Designer
- Document blocker in task memory
- Exit and wait

---

## Quality Gates (MANDATORY)

```bash
npm run type-check  # 0 errors
npm run lint        # 0 warnings
npm run test        # All pass
npm run build       # Success
```

### Quality Standards

**NEVER without PM approval:**

- `@ts-ignore` or `// eslint-disable`
- `any` type without justification
- Non-null assertions
- Commenting out failing tests

**Always:**

- Fix root cause of errors
- Add proper types
- Update tests for behavior changes

---

## Pre-Commit Checklist

- [ ] Worktree verified
- [ ] Task research completed
- [ ] Implementation follows existing patterns
- [ ] E2E test created (for new features)
- [ ] All feedback loops pass
- [ ] No error suppression used
- [ ] Committed with Ralph format
- [ ] Pushed to `developer-worktree` branch

---

## Status Reference

| Scenario         | Task Status                 | Agent Status  | Message              |
| ---------------- | --------------------------- | ------------- | -------------------- |
| Starting work    | `in_progress`               | `working`     | (none)               |
| Blocked/question | `awaiting_pm_clarification` | `awaiting_pm` | `Query` to PM        |
| Sending to QA    | `awaiting_qa`               | `idle`        | `WorkComplete` to PM |
| QA returned bugs | `in_progress`               | `working`     | (none)               |
| Fixes complete   | `awaiting_qa`               | `idle`        | `WorkComplete` to PM |

---

## Context Window Management

For big tasks (5+ acceptance criteria, 3+ files, architectural):

```
Skill("shared-context-management")
```

- Check context at `/context` command
- Create checkpoint when >= 70%
- Follow worker resumption procedure

---

## Retrospective Contribution

When `Retrospective` message received:

1. Read all task memory files from `.claude/session/agents/developer/`
2. Read `retrospective.txt`
3. Create contribution: `.claude/session/retrospective-developer.json`
4. Delete all task memory files
5. Send `Retrospective` message back to PM

---

## Domain-Specific Skills

### Multiplayer

```
Skill("dev-multiplayer-server-authoritative")  # Architecture
Skill("dev-multiplayer-colyseus-server")       # Colyseus server
Skill("dev-multiplayer-prediction-basics")     # Client prediction
```

### Performance

```
Skill("dev-performance-performance-basics")    # Core principles
Skill("dev-performance-instancing")            # InstancedMesh
Skill("dev-patterns-object-pooling")           # Object pooling
```

### R3F

```
Skill("dev-r3f-r3f-fundamentals")  # Scene composition
Skill("dev-r3f-r3f-physics")       # @react-three/rapier
Skill("dev-r3f-r3f-materials")     # Custom shaders
```

---

## Related Skills

| Skill                              | Purpose                    |
| ---------------------------------- | -------------------------- |
| `shared-worker-worktree`           | Git worktree management    |
| `shared-validation-feedback-loops` | Quality gates              |
| `shared-worker-task-memory`        | Task documentation         |
| `shared-worker-retrospective`      | Retrospective contribution |
| `shared-context-management`        | Context reset              |
| `dev-router`                       | Complete skill catalog     |
| `docs/powershell/v2-architecture.md` | 🆕 V2 infrastructure docs |
| `.claude/protocols/event-driven.md`    | 🆕 V2 event-driven protocol |
