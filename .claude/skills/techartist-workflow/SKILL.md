---
name: techartist-workflow
description: Complete Tech Artist workflow - worktree setup, asset creation flow, visual testing, screenshot verification, feedback loops, QA protocol. Routes to specialized skills.
---

# Tech Artist Workflow

> "Complete Tech Artist workflow - routes to specialized skills instead of duplicating content."

## Quick Start

```
1. Load core skills: Skill("shared-worker-worktree"), Skill("shared-worker-task-memory")
2. Load router: Skill("ta-router")
3. Follow workflow steps below
```

## Master Branch Coordination

**⚠️ CRITICAL**: You work in `../techartist-worktree/` branch.

**All coordination operations MUST target master branch.**

For detailed worktree setup, PRD updates, and message patterns:
→ Load Skill("shared-worker-worktree")

**What Goes Where:**

| Operation | Target |
|-----------|--------|
| Code/assets | Worktree branch |
| PRD/messages | Master branch |

**Key Reminders:**
- Source config: `. .\.claude\scripts\ralph-config.ps1`
- Use `Get-MasterPrdPath`, `Get-MasterSessionPath` helpers
- If state changes, PRD changes IMMEDIATELY

## Startup Workflow

```
0. Worktree Setup
   → Use Skill("shared-worker-worktree")

1. Source Config
   . .\.claude\scripts\ralph-config.ps1

2. Check Messages
   → Use Skill("shared-worker-worktree") for message queue patterns
   → Delete messages after processing (prevents watchdog restart loop)

3. Read PRD
   → Check prd.json.session.currentTask
   → Update prd.json.agents.techartist status and lastSeen

4. Load Skills
   → Skill("ta-router") - determines domain skills needed
   → Skill("shared-worker-worktree")
   → Skill("shared-worker-task-memory")

5. Asset Research (MANDATORY)
   → Check src/assets/ for existing assets
   → Invoke techartist-asset-researcher sub-agent

6. Create Asset
   → Follow patterns from loaded domain skills

7. Test
   → Visual verification (Playwright MCP screenshot)
   → Skill("shared-validation-feedback-loops")

8. Commit
   → Push to techartist-worktree branch
   → Send validation_request to QA
```

## Task Research (MANDATORY)

**⚠️ BLOCKING RULE: Check src/assets/ BEFORE requesting new assets**

```
1. Check existing assets: src/assets/ (models, textures, audio, fonts)

2. Read GDD for visual direction:
   - docs/design/gdd/1_core_identity.md (art direction, colors)
   - docs/design/gdd/14_audio_visual.md (shaders, VFX, materials)
   - docs/design/gdd/12_characters.md (character models)

3. Invoke asset-researcher sub-agent:
   Task("techartist-asset-researcher", {
     prompt: "Review current assets and identify what already exists"
   })

4. Only request NEW assets that don't exist
```

## Asset Creation Flow

```
1. CREATE TASK MEMORY
   → Use Skill("shared-worker-task-memory")
   → Create .claude/session/agents/techartist/task-{taskId}-memory.md

2. TASK RESEARCH
   → Invoke techartist-asset-researcher
   → Write findings to task memory

3. LOAD DOMAIN SKILLS
   → Use Skill("ta-router") to determine required skills
   → Examples: Skill("ta-shader-development"), Skill("ta-vfx-particles"), Skill("ta-assets-workflow")

4. CREATE ASSET
   → Follow skill-provided patterns
   → Write technical decisions to task memory

5. VISUAL VERIFICATION
   → Navigate to localhost:3000 via Playwright MCP
   → Take screenshot: {taskId}-asset.png
   → Write visual quality observations to task memory

6. FEEDBACK LOOPS
   → Load Skill("shared-validation-feedback-loops")
   → Run type-check, lint, test, build
   → Write any errors/fixed to task memory

7. COMMIT AND SEND TO QA
```

## Visual Testing (MANDATORY)

**⚠️ No task complete without visual verification.**

1. Navigate to localhost:3000 via Playwright MCP
2. Take screenshot: `{taskId}-asset.png`
3. For E2E test patterns → Invoke `techartist-visual-tester` sub-agent
4. Verify console is clean (no errors/warnings)

**E2E test creation:**
```bash
# Invoke visual-tester sub-agent for test patterns
Task("techartist-visual-tester", {
  prompt: "Create E2E visual test for {taskId}"
})
```

## QA Testing Protocol

### When to Send to QA

Send `validation_request` to QA when:
- ✅ All acceptance criteria implemented
- ✅ Screenshot verification passed
- ✅ Feedback loops passed (type-check, lint, build)
- ✅ Console clean (no errors)
- ✅ Committed with `[ralph] [techartist]` prefix

### QA Validation Message Format

```json
File: .claude/session/messages/qa/msg-qa-{timestamp}-{seq}.json
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
    "files": ["src/path/to/file1.ts"],
    "acceptanceCriteria": ["Criterion 1", "Criterion 2"],
    "screenshot": ".claude/session/playwright-test/{taskId}-asset.png",
    "gddReference": "docs/design/gdd/{section}.md"
  },
  "timestamp": "{UTC-timestamp}",
  "status": "pending"
}
```

### QA Response Types

| Response | Action |
|----------|--------|
| `task_complete` | ✅ Passed - no action |
| `bug_report` | ❌ Failed - fix and resubmit |

### If QA Finds Bugs

1. Read bug report
2. Fix all issues
3. Re-run feedback loops → Use Skill("shared-validation-feedback-loops")
4. Take new screenshot
5. Commit: `[ralph] [techartist] {taskId}: Fix for QA bugs`
6. Send new `validation_request`

### Common QA Failures

| Issue | Prevention |
|-------|------------|
| Console errors | Check console before sending |
| Shader compilation fails | Test in browser first |
| Visual doesn't match GDD | Verify against GDD specs |
| Performance < 60 FPS | Task("techartist-performance-profiler", { prompt: "analyze performance" }) |
| `any` types | Use proper TypeScript types |
| Missing screenshot | Always take screenshot first |

## Sub-Agents (invoke via Task tool)

| Sub-Agent | Purpose |
|-----------|---------|
| `asset-researcher` | Pre-creation asset discovery |
| `asset-creator` | General 3D/2D asset creation |
| `shader-compiler` | GLSL/TSL shader development |
| `particle-system-designer` | GPU particle systems |
| `visual-validator` | Visual quality review (read-only) |
| `visual-tester` | Browser visual regression |
| `performance-profiler` | GPU/draw call analysis |
| `code-quality` | TypeScript/lint quality checks |

**Invocation:** `Task("techartist-{subagent-name}", { prompt: "...", timeout: 300000 })`

## Skills Reference

**For complete skill inventory and routing tables, see:** [ta-router](../ta-router/SKILL.md)

**Quick reference by domain (use Skill() to load):**

| Domain | Skills |
|--------|--------|
| **Core** | `Skill("shared-worker-worktree")`, `Skill("shared-worker-task-memory")`, `Skill("ta-router")` |
| **R3F** | `Skill("ta-r3f-fundamentals")`, `Skill("ta-r3f-materials")`, `Skill("ta-r3f-physics")` |
| **Visual** | `Skill("ta-vfx-particles")`, `Skill("ta-vfx-postfx")`, `Skill("ta-ui-polish")` |
| **Shader** | `Skill("ta-shader-development")`, `Skill("ta-shader-sdf")` |
| **Assets** | `Skill("ta-assets-workflow")`, `Skill("ta-assets-pipeline-optimization")` |
| **Validation** | `Skill("ta-validation-typescript")`, `Skill("shared-validation-feedback-loops")` |

## Pre-Commit Checklist

**Worktree:**
- [ ] In techartist-worktree (`pwd` confirms)
- [ ] On techartist-worktree branch
- [ ] Main merged into worktree

**Visual Quality:**
- [ ] Matches GDD specifications
- [ ] Shaders compile without errors
- [ ] Performance within budget

**Validation:**
- [ ] E2E visual test created → Task("techartist-visual-tester", { prompt: "create E2E test" })
- [ ] Feedback loops pass → Skill("shared-validation-feedback-loops")

**Final:**
- [ ] Dev server cleaned up
- [ ] Pushed to techartist-worktree branch

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

**⚠️ DO NOT merge to main yourself - QA will merge after validation.**

## Context Window Monitoring (For Big Tasks)

### Determine if Task is Big

**Enable monitoring if:**
- 5+ acceptance criteria
- 3+ assets (models, materials, shaders)
- Task category is `architectural` or `shader`
- Estimated > 10 operations

### Monitoring Procedure

**1. Check context after every 3-5 operations:**
- File writes, shader compilations, asset imports, sub-agent calls

**2. Use `/context` command**
- If >= 70% (140,000 tokens), create checkpoint

**3. Create checkpoint:**
```json
File: .claude/session/context-checkpoint-techartist-{taskId}.json
{
  "agent": "techartist",
  "taskId": "{taskId}",
  "timestamp": "{ISO-timestamp}",
  "contextPercent": 72,
  "step": "{current_step}",
  "completedSteps": ["step1", "step2"],
  "remainingSteps": ["step3", "step4"],
  "filesModified": ["path1", "path2"],
  "nextAction": "{what to do next}"
}
```

**4. Send context_checkpoint message to watchdog:**
```json
File: .claude/session/messages/watchdog/msg-watchdog-{timestamp}.json
{
  "from": "techartist",
  "to": "watchdog",
  "type": "context_checkpoint",
  "payload": { "taskId": "{taskId}", "step": "{step}", "nextAction": "{action}" }
}
```

**5. Exit** - Watchdog will restart with checkpoint context

### After Restart

1. Read checkpoint file
2. Skip `completedSteps`
3. Start from `nextAction`
4. Delete checkpoint after task completes

## Retrospective Contribution

When `retrospective_initiate` message received:

→ Use Skill("shared-worker-task-memory") for complete protocol

**Summary:**
1. READ all `task-*.md` files from `.claude/session/agents/techartist/`
2. WRITE contribution to `retrospective.txt`
3. DELETE all task memory files
4. UPDATE status in prd.json
