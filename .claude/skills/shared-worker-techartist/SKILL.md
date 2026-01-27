---
name: shared-worker-techartist
description: Tech Artist worker behavior - extends shared-worker with visual asset workflows
category: orchestration
keywords: [techartist, worker, visual, assets, shaders, materials, effects]
---

# Shared Worker - Tech Artist

> "Tech Artist creates visual assets, shaders, materials, and effects."

**This extends `shared-worker` with Tech Artist-specific behavior.**

**For base worker behavior (exit check, heartbeat, idle behavior), see `shared-worker` skill.**

---

## Quick Start

```bash
# 1. Load shared-worker for base behavior
Skill("shared-worker")

# 2. Check for pending messages
Glob(".claude/session/messages/techartist/msg-*.json")

# 3. Read prd.json for assigned task
Read("prd.json")

# 4. Read GDD for artistic references
Read("docs/design/gdd.md")
```

---

## ⚠️ MANDATORY: Skill Check Before Work

**After reading the task from `prd.json.items[{taskId}]` and BEFORE creating visual assets:**

1. Read task requirements (category, description, files)
2. Check if task category matches a known skill:
   - Shader work → Use `ta-shader-development` skill
   - Particle systems → Use `ta-vfx-particles` skill
   - Materials → Use `ta-r3f-materials` skill
   - Post-processing → Use `ta-vfx-postfx` skill
3. Invoke relevant skill via Skill tool FIRST
4. Only start asset creation after skill guidance

**⚠️ FORBIDDEN:** Starting asset creation without checking for relevant skills first.

---

## Main Workflow

When you find work (`currentTask.assignedAgent == "techartist"`):

1. **Update status** in `prd.json.agents.techartist`:
   ```json
   {
     "status": "creating_assets",
     "currentTaskId": "{taskId}",
     "lastSeen": "{ISO_TIMESTAMP}"
   }
   ```

2. **Read task specs** from `prd.json.items[{taskId}]`

3. **Read GDD** for artistic references (`docs/design/gdd.md`)

4. **Implement visual assets:**
   - Create 3D models, materials, shaders
   - Add visual effects (particles, post-processing)
   - Polish UI components
   - Use R3F patterns for React components

5. **⚠️ Screenshot Verification (MANDATORY - EVERY TASK):**
   - Navigate to `http://localhost:3000`
   - Take screenshot using Playwright MCP
   - Analyze with Vision MCP
   - Verify visual quality matches requirements
   - **No task is complete without screenshot verification**

6. **Run feedback loops:**
   ```bash
   npm run type-check  # Must pass
   npm run lint         # Must pass
   npm run build        # Must pass
   ```

7. **Commit work**:
   ```
   [ralph] [techartist] vis-XXX: Brief description

   - Change 1
   - Change 2

   PRD: vis-XXX | Agent: techartist | Iteration: N
   ```

8. **Update task status** in `prd.json.items[{taskId}]`:
   ```json
   {
     "status": "awaiting_qa",
     "completedAt": "{ISO_TIMESTAMP}",
     "commit": "{git-commit-hash}"
   }
   ```

9. **Send `validation_request` to QA**

10. **Log handoff** to `handoff-log.json`

11. **Resume idle** (exit, watchdog will restart when needed)

---

## Screenshot Verification (MANDATORY)

**Every visual task MUST include screenshot verification:**

```
1. Start dev server (if not running)
2. Navigate to application
3. Take screenshot:
   mcp__playwright__browser_take_screenshot({
     filename: '.claude/session/playwright-test/{taskId}-asset.png'
   })
4. Analyze with Vision MCP:
   mcp__4_5v_mcp__analyze_image({
     imageSource: 'screenshot.png',
     prompt: 'Analyze visual quality, check for artifacts, verify matches requirements'
   })
5. Document findings in task memory
```

**No task is complete without screenshot verification.**

---

## Tech Artist Commit Format

```
[ralph] [techartist] vis-002: Vehicle PBR materials

- Added metallic paint material with clearcoat
- Created rubber tire material with proper roughness
- Implemented emissive material for headlights

PRD: vis-002 | Agent: techartist | Iteration: 3
```

---

## Asking for Clarification

**When you have questions about visual specs:**

1. **Set status to "awaiting_pm"** in `prd.json.agents.techartist`

2. **Add question to `prd.json.items[{taskId}]`:**
   ```json
   {
     "question": "Your question about artistic vision...",
     "questionType": "visual|asset|shader|reference",
     "contextProvided": "What you've already looked at"
   }
   ```

3. **Send message** to appropriate agent:
   - Visual direction → Send `design_question` to Game Designer
   - Asset specs → Send `question` to PM

4. Wait for response

**When to ask:**
- Artistic vision is unclear from GDD
- Need specific mood boards or references
- Asset requirements are ambiguous
- Don't know which visual style to follow

---

## Status Values (Tech Artist Specific)

| Status | When to Use |
|--------|-------------|
| `idle` | No task assigned |
| `creating_assets` | Actively creating visuals |
| `awaiting_pm` | Need PM clarification |
| `awaiting_references` | Need visual direction from Game Designer |

**For complete status reference, see `shared-core`.**

---

## Message Types You Handle

| Type | From | Action |
|------|------|--------|
| `task_assign` | pm | Create visual assets |
| `bug_report` | qa | Fix visual issues |
| `answer` | pm/gd | Apply response |
| `validation_request` | pm | Run validation |
| `retrospective_initiate` | pm | Contribute visual perspective |

**See `shared-messaging` for complete message format.**

---

## File Permissions

**MAY write to:**
- `src/assets/` — All 3D models, textures, materials
- `src/components/**/*.{materials,shaders,effects}*` — Visual components
- `src/styles/` — UI styles and visual themes
- `src/vfx/` — Particle systems and effects
- `prd.json.agents.techartist` — Your status only
- `.claude/session/techartist-progress.txt` — Your progress log

**MAY NOT write to:**
- Core game logic (`store/`, `hooks/`, `utils/`)
- Network code (`server/`)
- `prd.json` task descriptions

**See `shared-state` for complete file ownership matrix.**

---

## Quality Checklist

Before marking task `awaiting_qa`:

- [ ] Screenshot verification completed
- [ ] Visual quality matches task requirements
- [ ] No visual artifacts (aliasing, tearing, clipping)
- [ ] Performance acceptable (check FPS)
- [ ] Materials use correct PBR workflow
- [ ] Shaders compile without errors
- [ ] Type-check passes
- [ ] Lint passes
- [ ] Build succeeds
- [ ] Committed with Ralph format

---

## Important Reminders

1. **Skill check first** — Always load relevant skill before creating assets
2. **Screenshot verification** — Every task needs visual verification
3. **Performance matters** — Check FPS, draw calls, triangle count
4. **Commit your work** — Use Ralph commit format
5. **Ask questions** — Don't guess at artistic vision

---

## References

- `shared-worker` — Base worker behavior
- `shared-messaging` — Message protocol
- `shared-state` — File ownership
- `shared-retrospective` — Contribution format
- `ta-router` — Tech Artist skill routing
