---
name: developer-workflow
description: Complete Developer workflow - worktree setup, task research, skill invocation, implementation flow, feedback loops. MUST load before starting assignments.
category: workflow
version: 2.0
changelog: "MAJOR: Added PRD Status Synchronization as golden rule. PRD must be updated immediately on EVERY status change, not just at QA handoff. Prevents loop locks and keeps system in sync."
---

# Developer Workflow

> "This skill contains the complete workflow for the Developer Agent. Load this BEFORE starting any task."

## 🚨 GOLDEN RULE: PRD Status Synchronization

**⚠️ CRITICAL: The PRD is the SINGLE SOURCE OF TRUTH for all agents. Every status change MUST be immediately reflected in `prd.json`.**

**Whenever the Developer's status changes, UPDATE THE PRD IMMEDIATELY.**

| When This Happens | Update PRD Like This | Why |
|-------------------|---------------------|-----|
| **Starting a task** | `prd.json.items[{taskId}].status = "in_progress"` | PM/QA know you're working |
| **Blocked by question** | `prd.json.items[{taskId}].status = "awaiting_pm_clarification"` + send `question` message | PM sees blocker, can respond |
| **Sending to QA** | `prd.json.items[{taskId}].status = "awaiting_qa"` + `passes = false` + send `implementation_complete` | QA picks it up, no loop lock |
| **QA returned bugs** | `prd.json.items[{taskId}].status = "needs_fixes"` + update `notes` | PM knows you're fixing |
| **Fixes complete** | `prd.json.items[{taskId}].status = "awaiting_qa"` + send `implementation_complete` | QA re-validates |
| **Self-reporting progress** | `prd.json.agents.developer.lastSeen = {ISO_TIMESTAMP}` | Watchdog knows you're alive |

**⚠️ If you don't update the PRD, the system desyncs:**
- PM assigns work already in progress
- QA waits for tasks that are done
- Watchdog thinks you crashed
- Loop locks occur

**Rule of thumb: If your state changes, PRD changes. IMMEDIATELY.**

## Startup Workflow

```
0. **GIT WORKTREE SETUP (First time or daily start)**
   - Load worktree skill: `shared/worker-worktree`
   - Check worktree exists: `git worktree list`
   - If NOT exists, create: `git worktree add ../developer-worktree -b developer-worktree`
   - Navigate to worktree: `cd ../developer-worktree`
   - Merge latest from main: `git fetch origin main && git merge origin/main`
   - Resolve any merge conflicts if they occur
   - Verify on correct branch: `git branch --show-current` (should show developer-worktree)

1. Source message queue script
   . .\.claude\scripts\message-queue.ps1

2. Check pending messages
   - Read .claude/session/messages/developer/msg-*.json

3. Read prd.json for current task
   - Check prd.json.session.currentTask for your assignment
   - Check prd.json.agents.developer for your status
   - Update your status and lastSeen timestamp

4. **SKILL CHECK** - Match task to skill/sub-agent

5. **TASK RESEARCH (MANDATORY)**
   - Invoke code-research sub-agent FIRST

6. Implement feature following research findings

7. Run feedback loops before committing

8. Commit with Ralph format, push to developer-worktree branch, update status, send to QA, exit
```

## Task Research Phase (MANDATORY - FIRST STEP)

**⚠️ BLOCKING RULE: You MUST invoke code-research sub-agent BEFORE writing any code.**

```
1. ALWAYS start with research:
   - Read docs/design/gdd/index.md for modular GDD overview
   - Read docs/design/gdd/{module}.md for feature-specific specs:
     • 1_core_identity.md - High concept, design pillars
     • 2_paint_friction_system.md - DEC-100 core mechanic
     • 3_movement_system.md - Arc Raiders vault/slide/mantle
     • 4_territory_control.md - Grid-based territory tracking
     • 5_weapon_system.md - 3 weapons minimum (DEC-201)
     • 6_anchor_system.md - POI transformations
     • 7_economy_system.md - Ink Debt, Underdog Mode
     • 8_ui_hud_system.md - Minimap, HUD, character select
     • 9_accessibility.md - Color blind modes, patterns
     • 10_match_flow.md - Session structure
     • 11_level_design.md - Procedural terrain
     • 12_characters.md - 4 skins, animations
     • 13_multiplayer.md - Colyseus architecture
     • 14_audio_visual.md - Shaders, sound
     • 15_technical_specs.md - Performance, platforms
     • 16_implementation_roadmap.md - 3-phase plan
   - Read docs/design/decision_log.md for design rationale
   - Read docs/design/open_questions.md for unresolved issues
   - Use Grep to find existing implementations
   - Use Read to examine relevant components
   - Use Glob to find related files

2. Invoke code-research sub-agent:
   Task({
     subagent_type: "developer-code-research",
     description: "Research patterns for {task}",
     prompt: "Research existing codebase patterns for implementing {feature}",
     timeout: 300000
   })

3. Process research output:
   - Review existing components
   - Study code examples provided
   - Follow implementation steps
   - Check files to modify

4. Only AFTER research completes, proceed to implementation
```

## Skill Invocation Protocol

### Model Selection Guidelines
- **Haiku** - Research, code review, simple validation (cost-effective)
- **Sonnet** - Most implementation tasks (capable)
- **Opus** - Complex architecture, debugging, creative work
- **Inherit** - Sub-agents use parent's model

### Sub-Agents (invoke via Task tool)

| Sub-Agent | Model | Purpose | When to Use |
|-----------|-------|---------|-------------|
| `orchestrator` | Sonnet | Routes work to specialists | Start of any developer task |
| `code-research` | Haiku | Research patterns before coding | **MANDATORY before all coding** |
| `implementation` | Sonnet | Implement features using R3F/TypeScript | After research completes |
| `validation` | Haiku | Run type-check, lint, test, build | **MANDATORY before commit** |
| `commit` | Haiku | Handle commits, PRD updates, messaging | After validation passes |

### Skills (invoke via `/skill-name` or `Skill("skill-name")`)

| Skill | Purpose |
|-------|---------|
| `worker-worktree` | Git worktree management for parallel development |
| `worker-task-memory` | Task memory for retrospective contributions |
| `developer/r3f/r3f-fundamentals` | React Three Fiber core patterns |
| `developer/r3f/r3f-physics` | @react-three/rapier physics |
| `developer/r3f/r3f-materials` | Custom shader materials |
| `developer/typescript/typescript-basics` | TypeScript best practices |
| `developer/multiplayer/prediction-basics` | Client-side prediction |
| `developer/multiplayer/server-authoritative` | Server-authoritative multiplayer |

## Implementation Workflow

```
1. CREATE TASK MEMORY (MANDATORY - on task start)
   - Load `shared/worker-task-memory` skill
   - Extract taskId from message (e.g., P1-004)
   - Create directory: .claude/session/agents/developer/
   - Create file: .claude/session/agents/developer/task-{taskId}-memory.md
   - Initialize with taskId, title, timestamp, empty sections
   → PRD UPDATE: prd.json.items[{taskId}].status = "in_progress"

2. TASK RESEARCH (MANDATORY)
   Task("developer-code-research", { prompt: "Research patterns for {task}" })
   → WRITE TO MEMORY: Document research findings, patterns discovered

3. SKILL INVOCATION
   - Load relevant skill for guidance
   - Example: Skill("developer-r3f-fundamentals")

4. IMPLEMENTATION
   - Create/modify files following researched patterns
   - Use absolute imports (@/ alias)
   - TypeScript only, functional components
   - Follow R3F patterns (useFrame, useThree)
   → WRITE TO MEMORY: Document technical decisions made

5. IF BLOCKED (need clarification)
   → PRD UPDATE: prd.json.items[{taskId}].status = "awaiting_pm_clarification"
   → MESSAGE: Send `question` to PM
   → WRITE TO MEMORY: Document blocker in Pain Points section
   → EXIT: Wait for PM response

6. FEEDBACK LOOPS (MANDATORY before commit)
   Task("developer-validation", { prompt: "Run validation for {task}" })
   → WRITE TO MEMORY: Document any issues found and resolutions

7. COMMIT TO WORKTREE BRANCH
   git add .
   git commit -m "[ralph] [developer] feat-XXX: description"
   git push origin developer-worktree
   → WRITE TO MEMORY: Document any build/git issues

8. SEND TO QA
   → PRD UPDATE: prd.json.items[{taskId}].status = "awaiting_qa"
   → PRD UPDATE: prd.json.items[{taskId}].passes = false
   → MESSAGE: Send `implementation_complete` to QA
   → AGENT STATUS: prd.json.agents.developer.status = "idle"
   → EXIT
```

## Quality Standards (NON-NEGOTIABLE)

### Code Quality Rules
- **NO** `any` types without justification
- **NO** `@ts-ignore` or `@ts-expect-error`
- **NO** `eslint-disable`
- **NO** `as any` type assertions
- **NO** non-null assertions (the ! operator)

### If Blocked (Need Clarification)

**⚠️ ALWAYS update PRD when blocked - don't just exit silently!**

1. Document blocker in `prd.json.items[{taskId}].notes`
2. Update `prd.json.items[{taskId}].status = "awaiting_pm_clarification"`
3. Send `question` message to PM
4. Update `prd.json.agents.developer.status = "awaiting_pm"`
5. Exit and wait for PM response

**Example blocker scenarios:**
- Requirements unclear → Ask for clarification
- Technical specs missing → Request specifications
- Design question → Send to Game Designer via PM
- Asset needed → Request from Tech Artist via PM

**⚠️ TIMEOUT PROTECTION:** Setting `awaiting_pm` is SAFE because:
- The watchdog monitors `prd.json.agents.developer.lastSeen`
- After 10 minutes (configurable), watchdog sends `agent_timeout` to PM
- PM will receive notification and take action (reassign, clarify, or escalate)
- You won't be stuck forever waiting for a response
- **Never implement your own timeout logic** - the watchdog handles this

## Server-Authoritative Architecture

**MUST be server-authoritative for:**
- Player movement/position
- Shooting/hit detection
- Score calculation
- Game state changes
- Spawn/death logic

**Client-authoritative acceptable for:**
- Offline development/testing (temporary)
- Pure visual effects
- UI-only features

## Feedback Loops (MANDATORY Before Commit)

```bash
npm run type-check  # Must have 0 errors
npm run lint        # Must have 0 warnings
npm run test        # All must pass
npm run build       # Must succeed
```

If any feedback loop fails:
1. Fix the issue
2. Re-run all loops
3. Only commit when ALL pass

## Commit Format

```
[ralph] [developer] feat-XXX: Brief description

- Change 1
- Change 2

PRD: feat-XXX | Agent: developer | Iteration: N
```

## Pre-Commit Checklist

- [ ] Worktree verified (`git worktree list` shows developer-worktree)
- [ ] In worktree directory (`pwd` shows developer-worktree path)
- [ ] On developer-worktree branch (`git branch --show-current`)
- [ ] Main merged into worktree (`git log` shows recent main commits)
- [ ] Task research completed (code-research invoked)
- [ ] Implementation follows existing patterns
- [ ] `npm run type-check` — 0 errors
- [ ] `npm run lint` — 0 warnings
- [ ] `npm run test` — all pass
- [ ] `npm run build` — succeeds
- [ ] NO error suppression used (`@ts-ignore`, `eslint-disable`, etc.)
- [ ] Server processes killed (ports 2567, 3000 freed)
- [ ] Pushed to developer-worktree branch (`git push origin developer-worktree`)

## Exit Conditions

**⚠️ BEFORE exiting, you MUST update BOTH the task status AND your agent status.**

### Successful Completion (Sending to QA)

1. Complete task research (code-research invoked)
2. Implement feature following researched patterns
3. Run feedback loops (ALL must pass)
4. Commit work with `[ralph] [developer]` prefix
5. Push to developer-worktree branch: `git push origin developer-worktree`
6. **Update task status in `prd.json.items[{taskId}]`:**
   ```json
   {
     "status": "awaiting_qa",
     "passes": false
   }
   ```
7. **Update agent status in `prd.json.agents.developer`:**
   ```json
   {
     "status": "idle",
     "currentTaskId": null,
     "lastSeen": "{ISO_TIMESTAMP}"
   }
   ```
8. Send `implementation_complete` message to QA
9. Send `status_update` to watchdog
10. ONLY THEN exit

### Blocked (Need PM Clarification)

1. Document blocker in `prd.json.items[{taskId}].notes`
2. **Update task status:**
   ```json
   {
     "status": "awaiting_pm_clarification"
   }
   ```
3. **Update agent status:**
   ```json
   {
     "status": "awaiting_pm",
     "lastSeen": "{ISO_TIMESTAMP}"
   }
   ```
4. Send `question` message to PM
5. Send `status_update` to watchdog
6. Exit and wait for PM response

### QA Returned Bugs (Need Fixes)

1. Read QA bug report from message
2. **Update task status:**
   ```json
   {
     "status": "in_progress"
   }
   ```
3. **Update agent status:**
   ```json
   {
     "status": "working",
     "lastSeen": "{ISO_TIMESTAMP}"
   }
   ```
4. Fix bugs based on QA feedback
5. Run feedback loops
6. Commit fixes
7. When fixes complete → return to "Successful Completion" flow

**⚠️ DO NOT merge to main yourself - QA will merge after validation passes.**

## Complete PRD Status Reference

| Scenario | Task Status | Agent Status | Message | Notes |
|----------|-------------|--------------|---------|-------|
| Starting work | `in_progress` | `working` | (none) | Begin task |
| Blocked/question | `awaiting_pm_clarification` | `awaiting_pm` | `question` to PM | Wait for response |
| Sending to QA | `awaiting_qa` | `idle` | `implementation_complete` to QA | Work complete |
| QA passed | (PM sets to `completed`) | (already idle) | (none) | PM handles |
| QA returned bugs | `in_progress` | `working` | (none) | Resume fixing |
| Fixes complete | `awaiting_qa` | `idle` | `implementation_complete` to QA | Re-validate |
| Heartbeat | (unchanged) | (update `lastSeen`) | `status_update` to watchdog | Every action |

**⚠️ ALWAYS update BOTH task status AND agent status before exiting!**

## Context Window Monitoring (For Big Tasks)

> "Monitor context usage on big tasks to enable checkpoint-based restarts."

### Determine if Task is Big

**Big task indicators (ENABLE context monitoring):**
- Task has 5+ acceptance criteria
- Task requires 3+ files to be created/modified
- Task category is `architectural` or `integration`
- Estimated to take > 10 operations

**Small task indicators (SKIP context monitoring):**
- Single file change
- Bug fix with clear scope
- Simple refactor
- Estimated to take < 5 operations

### For Big Tasks: Context Monitoring Procedure

**1. Check context periodically:**

After every 3-5 significant operations:
- File writes (every 3 writes)
- Code edits (every 2 edits)
- Tool calls (every 5 calls)
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

Write checkpoint file: `.claude/session/context-checkpoint-developer-{taskId}.json`

```json
{
  "agent": "developer",
  "taskId": "{taskId}",
  "timestamp": "{ISO-timestamp}",
  "contextPercent": 72,
  "totalTokens": 144000,
  "step": "{current_step_name}",
  "completedSteps": ["task_research", "skill_loading", "file_setup"],
  "remainingSteps": ["implementation", "feedback_loops", "commit"],
  "filesModified": ["src/file1.ts", "src/file2.ts"],
  "nextAction": "{what to do immediately after restart}",
  "state": {
    "branch": "developer-worktree",
    "commits": 1,
    "currentFunction": "{function_name}",
    "linesAdded": 145
  }
}
```

**5. Send context_checkpoint message to watchdog:**

**File:** `.claude/session/messages/watchdog/msg-watchdog-{timestamp}-{seq}.json`

```json
{
  "id": "msg-watchdog-{timestamp}-{seq}",
  "from": "developer",
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
# Look for: .claude/session/context-checkpoint-developer-{taskId}.json
```

**2. Read checkpoint and resume:**

- Skip `completedSteps` - these are already done
- Start from `nextAction` - continue immediately
- Don't re-read files in `filesModified` (you just worked on them)
- Focus on `remainingSteps`

**3. Clean up after task completes:**

Delete checkpoint file when task is complete.

## Retrospective Contribution

**When `retrospective_initiate` message is received:**

```
1. READ ALL your task memory files
   - Directory: .claude/session/agents/developer/
   - Pattern: task-*.md (e.g., task-P1-004-memory.md, task-P1-005-memory.md)
   - Read all sections from all files (Good Points, Pain Points, Technical Decisions, Notes)

2. READ the retrospective file
   - File: .claude/session/retrospective.txt
   - Find your section: ### Developer Perspective

3. USE task memory contents to populate your contribution:
   - Good Points → "What Worked Well"
   - Pain Points → "Technical Challenges Faced" / "Areas for Improvement"
   - Technical Decisions → "Implementation Decisions"
   - Notes → "Lessons Learned"

4. WRITE your contribution to retrospective.txt
   - Replace the <!-- WAITING --> comment with your content
   - Use specific examples from task memory (file names, error messages, etc.)
   - Be honest about challenges and shortcuts taken

5. DELETE ALL task memory files
   - Delete: .claude/session/agents/developer/task-*.md
   - Verify files are removed

6. UPDATE status in prd.json
   - prd.json.agents.developer.status = "idle"
   - prd.json.agents.developer.lastSeen = {ISO_TIMESTAMP}

7. LOG in progress file
```

**⚠️ Your retrospective contribution will be GENERIC and USELESS without reading task memory first!**
