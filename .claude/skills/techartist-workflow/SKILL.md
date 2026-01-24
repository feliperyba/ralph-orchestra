---
name: techartist-workflow
description: Complete Tech Artist workflow - worktree setup, asset creation flow, visual testing, screenshot verification, feedback loops, QA protocol. MUST load before starting assignments.
category: workflow
version: 1.4
changelog: "ADDED: PRD Status Synchronization as golden rule. PRD must be updated immediately on EVERY status change to keep system in sync."
---

# Tech Artist Workflow

> "This skill contains the complete workflow for the Tech Artist Agent. Load this BEFORE starting any task."

## 🚨 GOLDEN RULE: PRD Status Synchronization

**⚠️ CRITICAL: The PRD is the SINGLE SOURCE OF TRUTH for all agents. Every status change MUST be immediately reflected in `prd.json`.**

**Whenever your status changes, UPDATE THE PRD IMMEDIATELY.**

| When This Happens | Update PRD Like This | Why |
|-------------------|---------------------|-----|
| **Starting asset creation** | `prd.json.items[{taskId}].status = "in_progress"` + `prd.json.agents.techartist.status = "working"` | PM knows you're creating assets |
| **Need design direction** | `prd.json.items[{taskId}].status = "awaiting_gd_clarification"` + send `design_question` to GD | GD provides visual direction |
| **Assets created, ready for QA** | `prd.json.items[{taskId}].status = "awaiting_qa"` + `passes = false` + send `implementation_complete` | QA validates visual quality |
| **QA returned visual bugs** | `prd.json.items[{taskId}].status = "needs_fixes"` + update `notes` with visual issues | PM knows you're fixing |
| **Fixes complete** | `prd.json.items[{taskId}].status = "awaiting_qa"` + send `implementation_complete` | QA re-validates |
| **Self-reporting progress** | `prd.json.agents.techartist.lastSeen = {ISO_TIMESTAMP}` | Watchdog knows you're alive |

**⚠️ If you don't update the PRD, the system desyncs:**
- PM assigns work already in progress
- QA waits for tasks that are done
- Watchdog thinks you crashed
- Loop locks occur

**Rule of thumb: If your state changes, PRD changes. IMMEDIATELY.**

**⚠️ TIMEOUT PROTECTION:** Setting `awaiting_gd_clarification` or `awaiting_gd` is SAFE because:
- The watchdog monitors `prd.json.agents.techartist.lastSeen`
- After 10 minutes (configurable), watchdog sends `agent_timeout` to PM
- PM will receive notification and take action (reassign, clarify, or escalate)
- You won't be stuck forever waiting for Game Designer response
- **Never implement your own timeout logic** - the watchdog handles this

## Startup Workflow

```
0. **GIT WORKTREE SETUP (First time or daily start)**
   - Load worktree skill: `shared/worker-worktree`. use Skill() built-in tool
   - Check worktree exists: `git worktree list`
   - If NOT exists, create: `git worktree add ../techartist-worktree -b techartist-worktree`
   - Navigate to worktree: `cd ../techartist-worktree`
   - Merge latest from main: `git fetch origin main && git merge origin/main`
   - Resolve any merge conflicts if they occur
   - Verify on correct branch: `git branch --show-current` (should show techartist-worktree)

1. Source message queue script
   . .\.claude\scripts\message-queue.ps1

2. Check pending messages
   - Read .claude/session/messages/techartist/msg-*.json

3. Read prd.json for current task
   - Check prd.json.session.currentTask for your assignment
   - Check prd.json.agents.techartist for your status
   - Update your status and lastSeen timestamp

4. **SKILL CHECK** - Match task to skill/sub-agent

5. **ASSET RESEARCH (MANDATORY)**
   - Check src/assets/ for existing assets
   - Invoke asset-researcher sub-agent

6. Request artistic direction from Game Designer if needed

7. Create assets following skill output patterns

8. Test in browser (Playwright), take screenshot, verify with Vision MCP

9. Run feedback loops, commit with Ralph format, push to techartist-worktree branch, send to QA, exit
```

## Task Research (MANDATORY - First Step)

**⚠️ BLOCKING RULE: Check src/assets/ BEFORE requesting new assets**

```
1. ALWAYS check existing assets:
   - src/assets/ - All 3D models, 2D UI elements, audio, fonts
   - Glob for relevant file patterns
   - Read asset manifest if available

2. Read GDD for visual direction:
   - docs/design/gdd/index.md - Modular GDD overview
   - docs/design/gdd/1_core_identity.md - Art direction, color palette
   - docs/design/gdd/12_characters.md - Character models, skins
   - docs/design/gdd/14_audio_visual.md - TSL shaders, VFX, materials
   - docs/design/gdd/8_ui_hud_system.md - UI styling specifications
   - docs/design/gdd/15_technical_specs.md - Asset budgets, performance

3. Invoke asset-researcher:
   Task({
     subagent_type: "techartist-asset-researcher",
     description: "Analyze asset inventory for {asset type} requests",
     prompt: "Review current assets and identify what already exists",
     timeout: 180000
   })

3. Only request NEW assets that don't exist
```

## Asset Creation Flow

```
1. CREATE TASK MEMORY (MANDATORY - on task start)
   - Load `shared/worker-task-memory` skill
   - Extract taskId from message (e.g., vis-001)
   - Create directory: .claude/session/agents/techartist/
   - Create file: .claude/session/agents/techartist/task-{taskId}-memory.md
   - Initialize with taskId, title, timestamp, empty sections
   → PRD UPDATE: prd.json.items[{taskId}].status = "in_progress"

2. TASK RESEARCH (MANDATORY)
   Task("techartist-asset-researcher", { prompt: "Find existing assets" })
   → WRITE TO MEMORY: Document assets found, patterns discovered

3. INVOKE SKILL/SUB-AGENT
   - Example: Task("techartist-shader-compiler", { prompt: "Create PBR shader" })
   - Skills: Skill("techartist/r3f/fundamentals")

4. CREATE ASSET
   - Follow skill-provided patterns
   - Create in src/assets/ or appropriate directory
   - Test locally if possible
   → WRITE TO MEMORY: Document technical decisions, shader choices

5. VISUAL VERIFICATION (MANDATORY)
   - Navigate to localhost:3000 via Playwright MCP
   - Take screenshot: {taskId}-asset.png
   - Analyze via Vision MCP
   → WRITE TO MEMORY: Document visual quality observations

6. FEEDBACK LOOPS (MANDATORY)
   - Run type-check, lint, build
   - Fix any issues
   → WRITE TO MEMORY: Document any compilation errors, fixes

7. COMMIT AND SEND TO QA
```

## Visual Testing with MCP (MANDATORY)

**⚠️ NO TASK COMPLETE WITHOUT SCREENSHOT VERIFICATION**

```typescript
// Navigate and screenshot
mcp__playwright__browser_navigate('http://localhost:3000');
mcp__playwright__browser_take_screenshot({
  filename: '.claude/session/playwright-test/{taskId}-asset.png',
});

// Analyze visual quality
mcp__4_5v_mcp__analyze_image({
  imageSource: '.claude/session/playwright-test/{taskId}-asset.png',
  prompt: 'Analyze for material quality, shader effects, GDD compliance',
});
```

**Visual verification must include:**

- [ ] Screenshot taken at localhost:3000
- [ ] Vision MCP analysis completed
- [ ] Material/shader quality verified
- [ ] GDD compliance checked
- [ ] Console checked for errors (must be empty)

## QA Testing Protocol

**After completing your work, you MUST send it to QA for validation.**

### When to Send to QA

Send `validation_request` to QA when:

- ✅ All acceptance criteria are implemented
- ✅ Screenshot verification passed
- ✅ Feedback loops (type-check, lint, build) passed
- ✅ Console has no errors
- ✅ Work is committed with `[ralph] [techartist]` prefix

### What QA Will Validate

QA will run these checks on your work:

| Check            | Description                        | Your Responsibility                  |
| ---------------- | ---------------------------------- | ------------------------------------ |
| **TypeScript**   | `npm run type-check` - 0 errors    | Fix any type errors before sending   |
| **Lint**         | `npm run lint` - 0 warnings        | Fix any lint warnings before sending |
| **Build**        | `npm run build` - succeeds         | Ensure build passes before sending   |
| **Browser Test** | Playwright MCP visual verification | Screenshot must show working visual  |
| **Console**      | No errors or warnings              | Console must be clean                |
| **Performance**  | 60 FPS maintained                  | Optimize if needed                   |

### QA Validation Message Format

Send this message structure to QA:

```json
File: .claude/session/messages/qa/msg-qa-{timestamp}-{seq}.json
Content:
{
  "id": "msg-qa-{timestamp}-{seq}",
  "from": "techartist",
  "to": "qa",
  "type": "validation_request",
  "priority": "normal",
  "payload": {
    "taskId": "{taskId}",
    "title": "{Task Title}",
    "category": "shader|visual|asset",
    "files": ["src/path/to/file1.ts", "src/path/to/file2.ts"],
    "acceptanceCriteria": [
      "Criterion 1",
      "Criterion 2"
    ],
    "screenshot": ".claude/session/playwright-test/{taskId}-asset.png",
    "gddReference": "docs/design/gdd/{section}.md"
  },
  "timestamp": "{UTC-timestamp}",
  "status": "pending"
}
```

### QA Response Types

| Response        | Action Required                              |
| --------------- | -------------------------------------------- |
| `task_complete` | ✅ Validation PASSED - no action needed      |
| `bug_report`    | ❌ Validation FAILED - fix bugs and resubmit |

### If QA Finds Bugs

1. Read the bug report from QA
2. Fix all reported issues
3. Re-run feedback loops (type-check, lint, build)
4. Take new screenshot showing fixes
5. Commit with `[ralph] [techartist] {taskId}: Fix for QA bugs`
6. Send new `validation_request` to QA

### Common QA Failures for Visual Work

| Issue                    | How to Prevent                               |
| ------------------------ | -------------------------------------------- |
| Console errors           | Check console before sending                 |
| Shader compilation fails | Test in browser before sending               |
| Visual doesn't match GDD | Verify against GDD specs                     |
| Performance < 60 FPS     | Profile with performance-profiler |
| `any` types in code      | Use proper TypeScript types                  |
| Missing screenshot       | Always take screenshot before sending        |

### Example: Sending to QA

```
# After committing your work:

1. Create validation request message
   Write tool: .claude/session/messages/qa/msg-qa-{timestamp}.json

2. Include all payload fields:
   - taskId, title, category
   - Files created/modified
   - Acceptance criteria
   - Screenshot path
   - GDD reference

3. Send status_update to watchdog
   Write tool: .claude/session/messages/watchdog/msg-watchdog-{timestamp}.json
   payload: { status: "idle", lastTask: "{taskId}" }

4. Exit (worker pool model)
```

## Sub-Agents (invoke via Task tool)

| Sub-Agent                        | Model   | Purpose                           |
| -------------------------------- | ------- | --------------------------------- |
| `orchestrator`                   | Sonnet  | Routes tasks to specialists       |
| `asset-researcher`               | Haiku   | Pre-creation asset discovery      |
| `asset-creator`                  | Sonnet  | General 3D/2D asset creation      |
| `shader-compiler`                | Inherit | GLSL/TSL shader development       |
| `particle-system-designer`       | Inherit | GPU particle systems              |
| `visual-validator`               | Haiku   | Visual quality review (read-only) |
| `visual-tester`                  | Haiku   | Browser visual regression         |
| `performance-profiler`           | Haiku   | GPU/draw call analysis            |
| `code-quality`                   | Haiku   | TypeScript/lint quality checks    |

**Invocation:** `Task("techartist-{subagent-name}", { prompt: "...", timeout: 300000 })`

## Skills (invoke via `/skill-name` or `Skill("skill-name")`)

| Skill                              | Purpose                                          |
| ---------------------------------- | ------------------------------------------------ |
| `shared/worker-worktree`                 | Git worktree management for parallel development |
| `shared/worker-task-memory`              | Task memory for retrospective contributions      |
| `techartist/r3f/fundamentals`      | React Three Fiber core patterns                  |
| `techartist/r3f/materials`         | Materials, PBR, textures                         |
| `techartist/r3f/physics`           | Physics for assets                               |
| `techartist/r3f/performance`       | Performance optimization                         |
| `techartist/shader/development`    | Shader creation process                          |
| `techartist/shader/sdf`            | Signed distance functions                        |
| `techartist/vfx/particles`         | GPU particle systems                             |
| `techartist/vfx/postfx`            | Post-processing effects                          |
| `techartist/camera/tps`            | Third-person camera patterns                     |
| `techartist/ui/polish`             | UI, presentation standards                       |
| `techartist/ui/debug-helpers`      | Debug visualization                              |
| `techartist/validation/typescript` | Type safety for visual code                      |
| `techartist/validation/feedback-loops` | Type-check, lint, test, build              |
| `techartist/assets/workflow`       | Asset creation pipeline                          |
| `techartist/assets/pipeline-optimization` | 3D asset optimization                    |
| `techartist/networking/visual-feedback` | Multiplayer visual feedback                 |
| `techartist/input/validation`      | Player input validation                          |

## Pre-Commit Checklist

- [ ] Worktree verified (`git worktree list` shows techartist-worktree)
- [ ] In worktree directory (`pwd` shows techartist-worktree path)
- [ ] On techartist-worktree branch (`git branch --show-current`)
- [ ] Main merged into worktree (`git log` shows recent main commits)
- [ ] Visual matches GDD specifications
- [ ] Shaders compile without errors
- [ ] Performance within budget
- [ ] Screenshot taken (Playwright MCP)
- [ ] Visual analysis completed (Vision MCP)
- [ ] `npm run type-check` — 0 errors
- [ ] `npm run lint` — 0 warnings
- [ ] `npm run build` — succeeds
- [ ] Dev server cleaned up after testing
- [ ] Pushed to techartist-worktree branch (`git push origin techartist-worktree`)

## Commit Format

```
[ralph] [techartist] vis-XXX: Brief description

- Asset 1 created
- Material 2 configured

PRD: vis-XXX | Agent: techartist | Iteration: N
```

## Exit Conditions

**⚠️ BEFORE exiting, you MUST:**

1. Take screenshot via Playwright MCP (MANDATORY)
2. Check console for errors (must be empty)
3. Commit work with `[ralph] [techartist]` prefix
4. Push to techartist-worktree branch: `git push origin techartist-worktree`
5. Update `prd.json.agents.techartist`:
   ```json
   {
     "status": "idle",
     "currentTaskId": null,
     "lastSeen": "{ISO_TIMESTAMP}"
   }
   ```
6. Send `validation_request` to QA
7. ONLY THEN exit

**Worker pool model:** Complete work → verify visually → commit → push to worktree branch → send message → exit.

**⚠️ DO NOT merge to main yourself - QA will merge after validation passes.**

## Context Window Monitoring (For Big Tasks)

> "Monitor context usage on big tasks to enable checkpoint-based restarts."

### Determine if Task is Big

**Big task indicators (ENABLE context monitoring):**
- Task has 5+ acceptance criteria
- Task requires creating 3+ assets (models, materials, shaders)
- Task category is `architectural` or `shader`
- Estimated to take > 10 operations

**Small task indicators (SKIP context monitoring):**
- Single asset creation
- Material tweak
- Simple shader update
- Estimated to take < 5 operations

### For Big Tasks: Context Monitoring Procedure

**1. Check context periodically:**

After every 3-5 significant operations:
- File writes (every 3 writes)
- Shader compilations (every 2)
- Asset imports/reads (every 5)
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

Write checkpoint file: `.claude/session/context-checkpoint-techartist-{taskId}.json`

```json
{
  "agent": "techartist",
  "taskId": "{taskId}",
  "timestamp": "{ISO-timestamp}",
  "contextPercent": 72,
  "totalTokens": 144000,
  "step": "{current_step_name}",
  "completedSteps": ["research", "model_creation", "material_setup"],
  "remainingSteps": ["shader_development", "visual_testing", "polish"],
  "filesModified": ["src/assets/model.glb", "src/materials/custom.ts"],
  "nextAction": "{what to do immediately after restart}",
  "state": {
    "branch": "techartist-worktree",
    "assetsCreated": ["model.glb"],
    "shadersCompiled": 1,
    "currentStage": "shaders"
  }
}
```

**5. Send context_checkpoint message to watchdog:**

**File:** `.claude/session/messages/watchdog/msg-watchdog-{timestamp}-{seq}.json`

```json
{
  "id": "msg-watchdog-{timestamp}-{seq}",
  "from": "techartist",
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
# Look for: .claude/session/context-checkpoint-techartist-{taskId}.json
```

**2. Read checkpoint and resume:**

- Skip `completedSteps` - these are already done
- Start from `nextAction` - continue immediately
- Don't re-create assets already made
- Focus on `remainingSteps`

**3. Clean up after task completes:**

Delete checkpoint file when task is complete.

## Retrospective Contribution

**When `retrospective_initiate` message is received:**

```
1. READ ALL your task memory files
   - Directory: .claude/session/agents/techartist/
   - Pattern: task-*.md (e.g., task-vis-001-memory.md, task-vis-002-memory.md)
   - Read all sections from all files (Good Points, Pain Points, Technical Decisions, Notes)

2. READ the retrospective file
   - File: .claude/session/retrospective.txt
   - Find your section: ### Tech Artist Perspective

3. USE task memory contents to populate your contribution:
   - Good Points → "What Worked Well" (visual techniques that were effective)
   - Pain Points → "Challenges Faced" (shader issues, performance problems)
   - Technical Decisions → "Implementation Decisions" (material choices, optimizations)
   - Notes → "Lessons Learned" (shader patterns to reuse)

4. WRITE your contribution to retrospective.txt
   - Replace the <!-- WAITING --> comment with your content
   - Use specific examples from task memory (shader names, performance metrics, etc.)
   - Be honest about visual quality issues and shortcuts

5. DELETE ALL task memory files
   - Delete: .claude/session/agents/techartist/task-*.md
   - Verify files are removed

6. UPDATE status in prd.json
   - prd.json.agents.techartist.status = "idle"
   - prd.json.agents.techartist.lastSeen = {ISO_TIMESTAMP}

7. LOG in progress file
```

**⚠️ Your retrospective contribution will be GENERIC and USELESS without reading task memory first!**
