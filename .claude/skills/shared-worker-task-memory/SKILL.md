---
name: shared-worker-task-memory
description: Task memory management for retrospective contributions. Use proactively when starting any task to track good points, pain points, and decisions during execution.
category: infrastructure
tags: [memory, retrospective, tracking, documentation]
dependencies: [shared-worker-retrospective, shared-file-permissions]
---

# Worker Task Memory

> "Remember what happened during the task – write to memory, use for retrospectives."

## When to Use This Skill

Use **proactively**:
- **IMMEDIATELY** when starting a task (create memory file)
- During task execution (append when notable events happen)
- When retrospective is triggered (read ALL memory files)

---

## Quick Start

<examples>
Example 1: Create task memory on assignment
```bash
# When task_assigned received for P1-004
File: .claude/session/agents/developer/task-P1-004-memory.md

# Task Memory: P1-004 - Vehicle Physics Implementation
# **Started**: 2026-01-23T10:30:00Z
# **Agent**: developer
#
# ## Good Points
# _To be filled during task execution_
#
# ## Pain Points
# _To be filled during task execution_
#
# ## Technical Decisions
# _To be filled during task execution_
#
# ## Notes
# _To be filled during task execution_
```

Example 2: Append during execution
```markdown
## Good Points

- Used InstancedMesh for 1000+ objects at 60fps
- TypeScript caught null reference early

## Pain Points

- Rapier docs unclear on collision events – had to inspect source
```

Example 3: Read and delete at retrospective
```bash
# Read ALL task memory files
Dir .claude/session/agents/developer/task-*.md

# Use contents for retrospective contribution

# Delete ALL task memory files after contribution
```
</examples>

---

## File Structure

```
.claude/session/agents/{agent}/task-{taskId}-memory.md
```

| Variable | Values |
|----------|--------|
| `{agent}` | `developer`, `techartist`, `qa`, `gamedesigner` |
| `{taskId}` | PRD task ID (e.g., `P1-004`, `vis-002`) |

---

## Task Memory Lifecycle

```
┌─────────────────────────────────────────────────────────────┐
│  1. TASK START                                               │
│     CREATE task-{taskId}-memory.md with empty sections       │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  2. DURING TASK EXECUTION                                   │
│     APPEND notable events to appropriate sections            │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  3. RETROSPECTIVE TRIGGERED                                  │
│     READ ALL task-*.md files                                │
│     Use contents for retrospective contribution              │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  4. AFTER CONTRIBUTUTION                                     │
│     DELETE ALL task-*.md files                              │
└─────────────────────────────────────────────────────────────┘
```

---

## What to Write

### Good Points
- Solutions that worked well
- Effective patterns
- Things that exceeded expectations

### Pain Points
- Blockers or difficulties
- Unclear/missing documentation
- Issues requiring workarounds

### Technical Decisions
- Architectural choices
- Selection between alternatives
- PRD deviations (with reasons)

### Notes
- Context for future reference
- Questions for PM

---

## Agent-Specific Tracking

| Agent | Tracks |
|-------|--------|
| **Developer** | Code patterns, TypeScript challenges, build issues, architectural decisions |
| **Tech Artist** | Visual techniques, shader issues, performance metrics, asset integration |
| **QA** | Code quality observations, validation difficulties, test gaps, browser issues |
| **Game Designer** | Design decisions, GDD clarity, playtest findings, balancing adjustments |

---

## Memory to Retrospective Mapping

| Task Memory Section | Retrospective Section |
|---------------------|----------------------|
| Good Points | "What Worked Well" |
| Pain Points | "Technical Challenges" / "Areas for Improvement" |
| Technical Decisions | "Implementation Decisions" |
| Notes | "Lessons Learned" |

---

## Important Rules

✅ **DO**:
- Create memory IMMEDIATELY when starting task
- Append throughout execution (not just at end)
- Track which task's memory file you're writing
- Be specific – mention file names, error messages
- Write as soon as something happens
- Read ALL memory files before retrospective
- Delete ALL memory files after contribution

❌ **DON'T**:
- Skip creating task memory
- Write only at end (you'll forget)
- Be vague or generic
- Mix up which task's file you're writing
- Forget to delete after retrospective
- Edit another agent's memory

---

## Complete Example

**Input** - Task Memory:
```markdown
# Task Memory: P1-005 - Multiplayer State Sync

## Good Points
- Colyseus Schema worked perfectly
- Client-side prediction reduced perceived lag

## Pain Points
- Documentation unclear on onChange callbacks
- Initial state caused 500kb payloads

## Technical Decisions
- Chose Schema over JSON (80% bandwidth reduction)
- Animation state is client-authoritative (cosmetics only)
```

**Output** - Retrospective Contribution:
```markdown
### Developer Perspective

**Implementation Decisions**:
- Used Colyseus Schema serialization (80% bandwidth reduction)
- Implemented client-side prediction for movement
- Kept animation state client-authoritative

**Technical Challenges Faced**:
- Colyseus onChange docs unclear – experimented with multiple approaches
- Initial design caused 500kb payloads – refactored to Schema

**What Worked Well**:
- Schema serialization worked perfectly once implemented
- Client-side prediction significantly reduced lag

**Areas for Improvement**:
- Should prototype state size earlier in development
- GDD should specify server-authoritative requirements
```

---

## Verification Checklist

| When | Checklist |
|------|-----------|
| **Starting task** | Memory file created, correct path, initialized |
| **During execution** | Writing notable events, specific details, correct file |
| **Retrospective** | Finding ALL files, reading all, deleting ALL after |

---

## Related Skills

| Skill | Purpose |
|-------|---------|
| `shared-worker-retrospective` | Retrospective contribution format |
| `developer-workflow` | Complete Developer workflow |
| `techartist-workflow` | Complete Tech Artist workflow |
| `qa-workflow` | Complete QA workflow |
