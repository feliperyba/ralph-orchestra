---
name: worker-task-memory
description: Task memory management for retrospective contributions. Use to track good points, pain points, and decisions during task execution.
category: workflow
keywords: [shared, task-memory, retrospective, tracking, good-points, pain-points, worker]
version: 1.1
changelog: |
  v1.1 - Changed file format to task-{taskId}-memory.md to support multiple concurrent tasks
  v1.0 - Initial version with task memory lifecycle for retrospectives
---

# Worker Task Memory

> "Remember what happened during the task – write to task memory, use it for retrospectives."

## Overview

Task Memory is a temporary file that records your experiences during task execution. When retrospective is triggered, you read ALL your task memory files to populate your contribution, then delete them.

**Problem solved**: Agents lose context between sessions and have nothing specific to contribute to retrospectives.

**Multiple tasks**: Each task gets its own memory file, so agents can work on N tasks simultaneously without mixing memories.

---

## File Structure

```
.claude/session/agents/{agent}/task-{taskId}-memory.md
```

Where:
- `{agent}` is one of: `developer`, `techartist`, `qa`, `gamedesigner`
- `{taskId}` is the PRD task ID (e.g., `P1-004`, `vis-002`)

**Example files:**
- `.claude/session/agents/developer/task-P1-004-memory.md`
- `.claude/session/agents/techartist/task-vis-001-memory.md`
- `.claude/session/agents/qa/task-P1-005-memory.md`

---

## File Format

```markdown
# Task Memory: {taskId} - {title}

**Started**: {timestamp}
**Agent**: {agent}

## Good Points
- [Solutions that worked well]
- [Effective patterns used]

## Pain Points
- [Issues encountered]
- [Difficulties and how resolved]

## Technical Decisions
- [Key decisions made and why]

## Notes
- [Any other notes for retrospective]
```

---

## Task Memory Lifecycle

```
┌─────────────────────────────────────────────────────────────────┐
│  1. TASK START                                                  │
│     - Receive task_assign or asset_assign message              │
│     - CREATE .claude/session/agents/{agent}/task-{taskId}-memory.md
│     - Initialize with task ID, title, timestamp, empty sections│
└─────────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│  2. DURING TASK EXECUTION                                      │
│     - When something notable happens, APPEND to task-{taskId}-memory.md
│     - Good points: solutions that worked well                  │
│     - Pain points: blockers, difficulties, unclear docs        │
│     - Technical decisions: architectural choices, workarounds   │
│     - Notes: context for future reference                      │
└─────────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│  3. RETROSPECTIVE TRIGGERED                                     │
│     - Receive retrospective_initiate message                    │
│     - READ ALL task-*.md files from .claude/session/agents/{agent}/
│     - Use contents to populate retrospective contribution       │
└─────────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│  4. AFTER CONTRIBUTION                                          │
│     - DELETE ALL task-*.md files from .claude/session/agents/{agent}/
│     - Verify files are removed                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Creating Task Memory

**When**: Immediately after receiving `task_assign` or `asset_assign` message.

**Steps**:

1. **Extract taskId** from the message payload (e.g., `P1-004`, `vis-002`)

2. **Create directory** (if not exists):
   ```
   .claude/session/agents/{agent}/
   ```

3. **Create file**: `.claude/session/agents/{agent}/task-{taskId}-memory.md`

4. **Initialize with**:
   ```markdown
   # Task Memory: {taskId} - {title}

   **Started**: {current_timestamp}
   **Agent**: {agent}

   ## Good Points
   _To be filled during task execution_

   ## Pain Points
   _To be filled during task execution_

   ## Technical Decisions
   _To be filled during task execution_

   ## Notes
   _To be filled during task execution_
   ```

**Example for Developer starting task P1-004**:
```markdown
File: .claude/session/agents/developer/task-P1-004-memory.md

# Task Memory: P1-004 - Vehicle Physics Implementation

**Started**: 2026-01-23T10:30:00Z
**Agent**: developer

## Good Points
_To be filled during task execution_

## Pain Points
_To be filled during task execution_

## Technical Decisions
_To be filled during task execution_

## Notes
_To be filled during task execution_
```

---

## Writing to Task Memory

**When**: During task execution, when something notable happens.

### What to Write

**Good Points** - Write when:
- A solution works particularly well
- A pattern proves effective
- Something exceeds expectations
- A skill or library saves time

**Pain Points** - Write when:
- Encountering a blocker or difficulty
- Documentation is unclear or missing
- A pattern causes issues
- Something takes longer than expected
- You need to implement a workaround

**Technical Decisions** - Write when:
- Making an architectural choice
- Choosing between alternatives
- Implementing a workaround
- Deciding not to follow PRD exactly (and why)

**Notes** - Write when:
- Remembering something for later
- Noting context for future reference
- Recording a question for PM

### How to Append

**Read the current file** (task-{taskId}-memory.md), then **append to the appropriate section**:

```markdown
## Good Points
_To be filled during task execution_
- Used React Three Fiber's InstancedMesh for performance – rendered 1000+ objects at 60fps
- TypeScript strict mode caught a potential null reference early

## Pain Points
_To be filled during task execution_
- Rapier documentation unclear on collision event handling – had to inspect source code
- Initial approach used individual meshes – performance was terrible at 15fps

## Technical Decisions
_To be filled during task execution_
- Chose InstancedMesh over individual meshes for performance (1000+ objects)
- Decided to use Rapier's collision events instead of manual distance checks
```

**⚠️ Important: Always append to the correct task's memory file.**
- Working on P1-004? Append to `task-P1-004-memory.md`
- Working on vis-001? Append to `task-vis-001-memory.md`
- Multiple tasks active? Track which file belongs to which task

### Agent-Specific Examples

**Developer** tracks:
- Code patterns that worked well
- TypeScript challenges faced
- Build issues and resolutions
- Architectural decisions made
- Library integration difficulties

**Tech Artist** tracks:
- Visual techniques that were effective
- Shader compilation issues
- Performance optimizations (draw calls, triangle count)
- Asset integration challenges
- Material/texture decisions

**QA** tracks:
- Code quality observations
- Validation difficulties (false positives, missing tests)
- Test coverage gaps
- Browser testing issues
- Unclear acceptance criteria

**Game Designer** tracks:
- Design decisions made
- GDD clarity issues
- Playtest findings
- Mechanics that need refinement
- Balancing adjustments

---

## Reading Task Memory

**When**: Immediately after receiving `retrospective_initiate` message.

**Steps**:

1. **Find ALL task memory files**:
   ```
   Directory: .claude/session/agents/{agent}/
   Pattern: task-*.md
   ```

2. **Read each task memory file**:
   - Example: `task-P1-004-memory.md`
   - Example: `task-P1-005-memory.md`
   - Combine all contents into your retrospective

3. **Map contents to retrospective sections**:
   | Task Memory Section | Retrospective Section |
   |---------------------|----------------------|
   | Good Points | "What Worked Well" |
   | Pain Points | "Technical Challenges Faced" / "Areas for Improvement" |
   | Technical Decisions | "Implementation Decisions" |
   | Notes | "Lessons Learned" |

4. **Use the combined content** to write detailed, specific contribution

**Example mapping with multiple tasks**:
```
Task Memory (P1-004):                  →  Retrospective:
- "InstancedMesh gave 60fps"           →  "What Worked Well: Used InstancedMesh pattern for high-performance rendering"

Task Memory (P1-005):                  →  Retrospective:
- "Colyseus Schema worked well"        →  "What Worked Well: Colyseus Schema serialization reduced bandwidth by 80%"
```

---

## Deleting Task Memory

**When**: Immediately after writing retrospective contribution to `retrospective.txt`.

**Steps**:

1. **Find ALL task memory files**:
   ```
   Directory: .claude/session/agents/{agent}/
   Pattern: task-*.md
   ```

2. **Delete ALL task memory files**:
   - Delete: `task-P1-004-memory.md`
   - Delete: `task-P1-005-memory.md`
   - Delete any matching `task-*.md` files

3. **Verify** files are removed (check with Glob or Read tool)

4. **Continue** with retrospective workflow (update status, log, etc.)

---

## Important Rules

✅ **DO:**

- Create task memory IMMEDIATELY when starting a task (use task-{taskId}-memory.md format)
- Append to memory throughout execution (not just at end)
- Track which task's memory file you're writing to
- Be specific – mention file names, error messages, exact issues
- Write to memory as soon as something happens (don't wait)
- Read ALL task memory files before writing retrospective contribution
- Delete ALL task memory files after contribution is complete

❌ **DON'T:**

- Skip creating task memory
- Write to memory only at the end (you'll forget details)
- Be vague or generic
- Mix up which task's memory file you're writing to
- Forget to delete memory after retrospective
- Edit another agent's task memory file
- Create task memory in wrong location

---

## Complete Example

### Developer Task Memory Example

**File**: `.claude/session/agents/developer/task-P1-005-memory.md`

```markdown
# Task Memory: P1-005 - Multiplayer Room State Synchronization

**Started**: 2026-01-23T14:15:00Z
**Agent**: developer

## Good Points
- Colyseus's `Schema` serialization worked perfectly for state sync
- Used @colyseus/schema `ArraySchema` for player list – type-safe and efficient
- Client-side prediction reduced perceived lag significantly

## Pain Points
- Colyseus documentation on `onChange` callbacks was unclear – had to test multiple approaches
- Initial state structure caused 500kb payloads – had to refactor to use `Schema`
- TypeScript types for Colyseus state weren't exported – had to create custom types

## Technical Decisions
- Chose Colyseus `Schema` over raw JSON for bandwidth (80% reduction)
- Implemented client-side prediction for movement despite added complexity
- Decided NOT to sync animation state to server (client-authoritative for cosmetics)

## Notes
- Need to ask PM about weapon fire synchronization – current approach feels laggy
- GDD doesn't specify if physics should be server-authoritative
```

### Resulting Retrospective Contribution

```markdown
### Developer Perspective

**Implementation Decisions**:

- Used Colyseus `Schema` serialization instead of raw JSON for state sync (80% bandwidth reduction)
- Chose `ArraySchema` for player list to maintain type safety
- Implemented client-side prediction for movement despite added complexity
- Decided to keep animation state client-authoritative (cosmetics only)

**Technical Challenges Faced**:

- Colyseus documentation on `onChange` callbacks unclear – had to experiment with multiple approaches
- Initial state design caused 500kb payloads – required major refactor to `Schema`
- TypeScript types not exported from Colyseus – created custom type definitions

**What Worked Well**:

- `Schema` serialization worked perfectly once implemented
- Client-side prediction significantly reduced perceived lag
- Type-safe player list with `ArraySchema`

**Areas for Improvement**:

- GDD should specify server-authoritative requirements for physics
- Weapon fire synchronization approach needs review – feels laggy
- Should prototype state size earlier in development

**Lessons Learned**:

- Always prototype state payload size before committing to approach
- Client-side prediction worth the complexity for fast-paced games
- Need clearer specification on what must be server-authoritative

_**Contributed by**: Developer Agent | 2026-01-23T15:45:00Z_
```

---

## Verification Checklist

Before starting a task:
- [ ] Task memory file created at correct path: `.claude/session/agents/{agent}/task-{taskId}-memory.md`
- [ ] File name includes task ID (e.g., `task-P1-004-memory.md`)
- [ ] File initialized with task ID, title, timestamp
- [ ] Empty sections ready for appending

During task execution:
- [ ] Writing to memory when notable events happen
- [ ] Being specific with file names, error messages
- [ ] Appending to correct section
- [ ] Writing to the correct task's memory file (multiple tasks possible)

When retrospective triggered:
- [ ] Finding ALL task memory files (pattern: `task-*.md`)
- [ ] Reading all task memory files
- [ ] Using contents to populate contribution
- [ ] Deleting ALL task memory files after contribution

---

## Reference

- [`worker-retrospective.md`](worker-retrospective.md) — How to contribute to retrospectives
- [`developer-workflow.md`](developer-workflow.md) — Complete Developer workflow
- [`techartist-workflow.md`](techartist-workflow.md) — Complete Tech Artist workflow
- [`qa-workflow.md`](qa-workflow.md) — Complete QA workflow
