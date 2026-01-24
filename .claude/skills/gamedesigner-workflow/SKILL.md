---
name: gamedesigner-workflow
description: Complete Game Designer workflow - skill invocation protocol, GDD creation, playtest flow with GDD review, design sessions. MUST load before starting assignments.
category: workflow
version: 3.0
changelog: "v3.0: ADDED GDD REVIEW PHASE during playtest. After gameplay testing, GD must review retrospective pain points, compare implementation vs GDD, identify skill gaps, and propose priority changes. playtest_session_report now includes gddReview, skillGaps, and priorityRecommendations fields. v2.0: Reorganized - Centralized ALL detailed workflows in skill file. AGENT.md is now a quick reference card only."
---

# Game Designer Workflow

> "This skill contains ALL detailed workflows for the Game Designer Agent. Load this BEFORE starting any task."

## File Organization

| File            | Purpose                                   | Size     |
| --------------- | ----------------------------------------- | -------- |
| `AGENT.md`      | Quick Reference: routing, permissions, messages | ~180 lines |
| `this skill`    | ALL detailed workflows: playtest, GDD, design sessions | ~400 lines |

**Use AGENT.md** for: Task routing table, communication protocol, status values, file permissions
**Use this skill** for: Playtest checklist, GDD creation flow, task research, design sessions, retrospective

## 🚨 GOLDEN RULE: PRD Status Synchronization

**⚠️ CRITICAL: The PRD is the SINGLE SOURCE OF TRUTH for all agents. Every status change MUST be immediately reflected in `prd.json`.**

**Whenever your status changes, UPDATE THE PRD IMMEDIATELY.**

| When This Happens | Update PRD Like This | Why |
|-------------------|---------------------|-----|
| **Starting design work** | `prd.json.agents.gamedesigner.status = "working"` | PM knows you're designing |
| **GDD created/updated** | `prd.json.agents.gamedesigner.gddPath = "docs/design/gdd.md"` | PM knows GDD is ready |
| **Playtest requested** | `prd.json.agents.gamedesigner.status = "playtesting"` | PM knows you're testing |
| **Playtest complete, starting GDD review** | `prd.json.agents.gamedesigner.status = "reviewing"` | PM knows you're reviewing |
| **GDD review complete** | Send `playtest_session_report` + `prd.json.agents.gamedesigner.status = "idle"` | PM receives findings + GDD gaps |
| **Providing acceptance criteria** | Send `acceptance_criteria` with task details | PM uses for task definition |
| **Self-reporting progress** | `prd.json.agents.gamedesigner.lastSeen = {ISO_TIMESTAMP}` | Watchdog knows you're alive |

**⚠️ If you don't update the PRD, the system desyncs:**
- PM assigns design work already in progress
- PM waits for GDD that's complete
- Watchdog thinks you crashed
- Loop locks occur

**Rule of thumb: If your state changes, PRD changes. IMMEDIATELY.**

## Startup Workflow

```
1. Source message queue script
   . .\.claude\scripts\message-queue.ps1

2. Check pending messages
   - Read .claude/session/messages/gamedesigner/msg-*.json

3. ⚠️ PROACTIVE PLAYTEST CHECK (MANDATORY - EVERY STARTUP)
   - Read .claude/session/retrospective.txt → Check Action Items for "[ ] Request playtest"
   - Read prd.json → Check session.currentTask.status for "playtest_phase"
   - IF playtest needed → JUMP TO PLAYTEST FLOW immediately (skip to step 9)

4. Check if GDD exists in docs/design/

5. Read prd.json for current task
   - Check prd.json.session.currentTask for your assignment
   - Check prd.json.agents.gamedesigner for your status
   - Update your status and lastSeen timestamp

6. **SKILL CHECK** - Match task to skill/sub-agent

7. **TASK RESEARCH (MANDATORY)**
   - Read GDD, check reference games
   - Check src/assets/ before requesting new assets

8. Invoke appropriate skill/sub-agent

9. PLAYTEST FLOW (if triggered in step 3)
   - See Playtest Flow section below

10. Complete design work, commit with Ralph format, send message, exit
```

## Task Research (MANDATORY - First Step)

**Always check:**
- `docs/design/gdd/index.md` - Modular GDD overview and table of contents
- `docs/design/gdd/{module}.md` - Feature-specific design documents:
  • 1_core_identity.md - High concept, design pillars, game loop
  • 2_paint_friction_system.md - DEC-100 core mechanic, friction values
  • 3_movement_system.md - Arc Raiders vault/slide/mantle specs
  • 4_territory_control.md - Grid system, scoring, height multiplier
  • 5_weapon_system.md - 3 weapons minimum (DEC-201)
  • 6_anchor_system.md - POI transformations (DEC-101/203)
  • 7_economy_system.md - Ink Debt, Underdog Mode
  • 8_ui_hud_system.md - Minimap, HUD, character select
  • 9_accessibility.md - Color blind modes, pattern overlays (DEC-206)
  • 10_match_flow.md - Session structure, bot system
  • 11_level_design.md - Procedural terrain, POI placement
  • 12_characters.md - 4 skin variants, animations
  • 13_multiplayer.md - Colyseus architecture, schemas
  • 14_audio_visual.md - TSL shaders, sound design
  • 15_technical_specs.md - Performance targets, platforms
  • 16_implementation_roadmap.md - 3-phase plan (16 weeks)
- `docs/design/decision_log.md` - Design rationale (DEC-XXX decisions)
- `docs/design/open_questions.md` - Unresolved issues (OQ-XXX)
- `docs/design/images-references/` - Splatoon/Arc Raiders screenshots
- `src/assets/` - Existing assets before requesting new ones

**Decision tree:**
- Requirements clear → Proceed with design
- Design unclear → Use thermite-facilitator sub-agent
- Visual reference needed → Use visual-reference-researcher sub-agent
- Asset request needed → Use asset-analyst sub-agent FIRST

## GDD Creation Flow

```
1. CREATE TASK MEMORY (MANDATORY - on task start)
   - Load `shared/worker-task-memory` skill
   - Extract taskId from message (e.g., P1-004)
   - Create directory: .claude/session/agents/gamedesigner/
   - Create file: .claude/session/agents/gamedesigner/task-{taskId}-memory.md
   - Initialize with taskId, title, timestamp, empty sections
   → PRD UPDATE: prd.json.agents.gamedesigner.status = "working"

2. TASK RESEARCH (MANDATORY)
   - Check if GDD exists
   - Read README.md, prd.json
   - Research similar games
   → WRITE TO MEMORY: Document research findings, references found

3. INVOKE SKILL/SUB-AGENT
   Task("gamedesigner-gdd-documenter", { prompt: "Create GDD structure" })
   → WRITE TO MEMORY: Document design decisions made

4. DESIGN SESSIONS (if needed)
   Task("gamedesigner-thermite-facilitator", {
     prompt: "Boardroom Retreat for [topic]"
   })
   → WRITE TO MEMORY: Document persona insights, decisions

5. DOCUMENT DECISIONS
   - Update docs/design/decision_log.md
   - Track open_questions.md
   → WRITE TO MEMORY: Document any unresolved questions

6. COMMIT AND NOTIFY PM
   - Send gdd_ready message
```

## Playtest Flow (MANDATORY for Retrospective - v3.0 with GDD Review)

**⚠️ PROACTIVE INITIATION**: Don't wait for a message! Check these conditions on EVERY startup:

**COMPREHENSIVE PLAYTEST EXECUTION CHECKLIST (13 steps - includes GDD review):**

```
STEP 1: DETECT playtest needed (proactive check - EVERY STARTUP)
   - Read .claude/session/retrospective.txt
   - Look for "[ ] Request playtest session from Game Designer" in Action Items
   - Read prd.json
   - Look for session.currentTask.status = "playtest_phase"
   - Look for session.retro.active = true with pending playtest action
   - Read prd.json items.{taskId}.acceptanceCriteria
   - IF any condition true → IMMEDIATELY INITIATE PLAYTESTING

STEP 2: START DEV SERVERS (MANDATORY - must be running for full playtest)
   - Run: npm run dev:all:sh (starts both client on :3000 and server on :2567)
   - Wait for: "Vite ready" and "Colyseus server listening" messages
   - Verify: http://localhost:3000 is accessible
   - IF servers fail to start → Report infrastructure issue to PM

STEP 3: UPDATE PRD status
   → prd.json.agents.gamedesigner.status = "playtesting"
   → prd.json.agents.gamedesigner.currentTaskId = "{taskId from retrospective/PRD}"

STEP 4: CREATE task memory file
   → .claude/session/agents/gamedesigner/task-{taskId}-playtest-memory.md

STEP 5: CHARACTER SELECTION TEST
   - Navigate to localhost:3000
   - Take screenshot: character-selection.png
   - Verify: Character model visible (3D rendered)
   - Verify: All character types load (navigate with arrows)
   - Check console: NO FBXLoader errors, NO "Cannot find version number"
   - Enter player name, click "Select Character"

STEP 6: LOBBY TEST
   - Verify: Lobby loads, player name displayed
   - Verify: Server connection succeeds (no "Connection Error")
   - Check console: Colyseus connection successful
   - Take screenshot: lobby.png
   - Proceed to game when ready

STEP 7: GAME SCENE TEST (CRITICAL - Full gameplay validation)
   - Verify: Game scene renders with character
   - Take screenshot: game-scene.png
   - Check console: NO errors, character loaded successfully

   KEYBOARD/MOUSE CONTROLS TEST (MUST test each):
   - W/A/S/D: Movement in all directions
   - Space: Jump (character moves up)
   - Space x2: Double jump (if applicable)
   - Mouse: Camera rotation (left/right look)
   - Shift: Sprint (if applicable)
   - RMB: Aim mode (camera zooms in)
   - X key: Shoulder swap (if applicable)
   - Esc: Pause menu (if applicable)

STEP 8: ACCEPTANCE CRITERIA VALIDATION
   - Read prd.json items.{currentTask}.acceptanceCriteria
   - For EACH criterion:
     * Test in game
     * Mark pass/fail in memory
     * Document evidence (screenshot/console log)
   - Calculate: pass % = (passed / total) * 100

STEP 9: VISION MCP ANALYSIS
   - Analyze all screenshots for visual quality
   - Check: Character proportions, animation smoothness
   - Check: UI readability, HUD clarity
   - Check: Visual glitches, missing assets

STEP 10: GDD REVIEW PHASE (NEW v3.0 - MANDATORY BEFORE SENDING REPORT)
   → prd.json.agents.gamedesigner.status = "reviewing"

   10.1 RETROSPECTIVE ANALYSIS:
   - Read: .claude/session/retrospective.txt
   - Extract: Pain points from Developer, Tech Artist, QA sections
   - Identify: Worker struggles with GDD (unclear specs, missing references)
   - Catalog: Repeated questions about design
   - Note: Implementation deviations from GDD

   10.2 GAME STATE REVIEW:
   - Compare: Actual gameplay vs GDD specifications
   - Check: docs/design/gdd/ modules for outdated content
   - Verify: Acceptance criteria alignment with GDD
   - Use: Vision MCP to analyze screenshots vs GDD visual specs

   10.3 GAP ANALYSIS:
   - Identify: GDD sections needing updates (modules, acceptance criteria, specs)
   - Catalog: Missing specifications (values, patterns, behaviors)
   - Identify: Missing skills workers need (use gd-skill-gap-analysis)
   - Propose: Task priority adjustments based on playtest findings
   - Update: GDD files if changes are clear and unambiguous

   Use Skills:
   - Skill("gd-playtest-gdd-review") for GDD review process
   - Skill("gd-skill-gap-analysis") for skill gap identification

STEP 11: SEND playtest_session_report with NEW STRUCTURE:
   - taskId: "{taskId}"
   - taskTitle: "{title}"
   - playedBy: "gamedesigner"
   - playedAt: "{ISO_TIMESTAMP}"
   - result: "PASS" | "FAIL"
   - criteriaTested: [list of criteria with results]
   - issuesFound: [problems identified]
   - screenshots: [filenames]
   - **gddReview (NEW):**
     - modulesReviewed: [GDD sections checked]
     - updatesNeeded: [tasks requiring GDD clarification]
     - gddUpdatesMade: [GDD files updated directly]
   - **skillGaps (NEW):**
     - agent: "developer" | "techartist"
     - missingSkill: "skill-name"
     - description: "what workers struggled with"
     - proposedSkill: {skill structure}
   - **priorityRecommendations (NEW):**
     - taskId: "task-id"
     - currentTier: "TIER_X"
     - recommendedTier: "TIER_Y"
     - reason: "justification for change"
   - overallAssessment: "summary of findings"
   → Send to: .claude/session/messages/pm/msg-pm-{timestamp}-{seq}.json

STEP 12: UPDATE PRD status
   → prd.json.agents.gamedesigner.status = "idle"
   → prd.json.agents.gamedesigner.currentTaskId = null
   → prd.json.agents.gamedesigner.lastSeen = {ISO_TIMESTAMP}
```

**⚠️ CRITICAL REMINDER (v3.0):**
- Start servers with `npm run dev:all:sh` BEFORE playtesting
- Test ALL keyboard/mouse controls in game scene
- Validate against acceptance criteria in PRD
- **MANDATORY: Conduct GDD review BEFORE sending report (STEP 10)**
- **MANDATORY: Include gddReview, skillGaps, priorityRecommendations in report**
- Game must be PLAYABLE to pass playtest
- Document EVERYTHING for retrospective contribution

## Design Session Flow

```
1. TASK RESEARCH
   - Review existing design docs
   - Identify discussion topics

2. INVOKE THERMITE-FACILITATOR
   Task({
     subagent_type: "gamedesigner-thermite-facilitator",
     description: "Run design session for [topic]",
     prompt: "Facilitate Boardroom Retreat about [problem]"
   })

3. EXTRACT DECISIONS AND UPDATE GDD
```

## Reference Games

**Primary inspirations - reference these when defining success criteria:**

| Game | Developer | Key Aspects |
|------|-----------|-------------|
| **Splatoon** | Nintendo | Territory control, paint visualization, UI/HUD, character movement, fast-paced combat |
| **Arc Raiders** | Embark Studios | Third-person camera, movement (vault/mantle/slide), tactical positioning, cover gameplay |

**When to reference:**
- **Splatoon**: UI/HUD, paint/territory visualization, movement feel, win conditions
- **Arc Raiders**: Camera follow distance, movement transitions, tactical combat, sprint responsiveness

## Thermite Design Integration

### Design Pillars (Non-Negotiable)

Every design decision must serve at least one pillar:

1. **Meaningful Risk** - Every action matters, gear has weight
2. **Readable Chaos** - Chaotic but parseable, clear visual language
3. **Compressed Tension** - 5-8 minute matches (or project-appropriate)
4. **Earned Mastery** - Skill beats gear
5. **Sustainable Economy** - Patchable, not exploitable

### Expert Personas (8)

| Persona | Domain | Key Question |
|---------|--------|--------------|
| Shinji Tanaka | Classic Arcade | "Is this readable in 2 seconds?" |
| Viktor Volkov | Extraction/Economy | "Does risk feel real AND survivable?" |
| Elena Vasquez | Map Architecture | "Does space create decisions?" |
| Marcus Chen | Combat Balance | "What beats this?" |
| Sarah Okonkwo | Economy | "Where does currency leave?" |
| Dr. Maya Reyes | Player Psychology | "What does first death teach?" |
| Wei Zhang | Technical | "What happens at 150ms latency?" |
| Jordan Ellis | UX/Accessibility | "Can colorblind players distinguish?" |

## Sub-Agents (invoke via Task tool)

| Sub-Agent | Model | Purpose |
|-----------|-------|---------|
| `orchestrator` | Sonnet | Routes tasks to specialists |
| `thermite-facilitator` | Inherit | Multi-persona design sessions |
| `playtest-evidence-collector` | Inherit | **MANDATORY** Playwright + Vision MCP playtesting |
| `visual-reference-researcher` | Haiku | Web search + image analysis |
| `gdd-documenter` | Inherit | GDD creation and maintenance |
| `asset-analyst` | Haiku | Read-only asset inventory |
| `reference-game-researcher` | Haiku | Splatoon/Arc Raiders analysis |

**Invocation:** `Task("gamedesigner-{subagent-name}", { prompt: "...", timeout: 300000 })`

## Skills (invoke via `/skill-name` or `Skill("skill-name")`)

| Skill | Purpose |
|-------|---------|
| `shared/worker-task-memory` | Task memory for retrospective contributions |
| `gamedesigner/gdd/creation` | GDD creation and structure |
| `gamedesigner/thermite/integration` | Thermite design skill usage |
| `gamedesigner/design/mechanic` | Game mechanics documentation |
| `gamedesigner/design/level` | Map and level design |
| `gamedesigner/design/character` | Character and class design |
| `gamedesigner/design/weapon` | Weapon and item design |
| `gamedesigner/design/game-loop` | Core gameplay loop design |
| `gamedesigner/validation/playtest` | Playwright + Vision MCP playtesting |
| **`gd-playtest-gdd-review` (NEW v3.0)** | **GDD review during playtest phase** |
| **`gd-skill-gap-analysis` (NEW v3.0)** | **Analyze pain points, identify skill gaps** |

## Commit Format

```
[ralph] [gamedesigner] {task-id}: Brief description

- Change 1
- Change 2

PRD: {task-id} | Agent: gamedesigner | Iteration: N
```

## Exit Conditions

**⚠️ BEFORE exiting, you MUST:**

1. Complete all design work using appropriate skills/sub-agents
2. Check `src/assets/` if making asset requests
3. Commit work with `[ralph] [gamedesigner]` prefix
4. Update `prd.json.agents.gamedesigner`:
   ```json
   {
     "status": "idle",
     "currentTaskId": null,
     "lastSeen": "{ISO_TIMESTAMP}"
   }
   ```
5. Send result message to PM
6. ONLY THEN exit

**Worker pool model:** Complete work → commit → send message → exit.

## Retrospective Contribution

**When `retrospective_initiate` message is received:**

```
1. READ ALL your task memory files
   - Directory: .claude/session/agents/gamedesigner/
   - Pattern: task-*.md (e.g., task-P1-004-memory.md, task-P1-005-memory.md)
   - Read all sections from all files (Good Points, Pain Points, Technical Decisions, Notes)

2. READ the retrospective file
   - File: .claude/session/retrospective.txt
   - Find your section: ### Game Designer Perspective

3. USE task memory contents to populate your contribution:
   - Good Points → "Design Decisions That Worked" (effective mechanics)
   - Pain Points → "Design Challenges" (unclear specs, conflicting requirements)
   - Technical Decisions → "Design Rationale" (why certain choices were made)
   - Notes → "Lessons Learned" (what to improve in GDD)

4. WRITE your contribution to retrospective.txt
   - Replace the <!-- WAITING --> comment with your content
   - Use specific examples from task memory (GDD sections, playtest findings)
   - Be honest about design gaps and ambiguities

5. DELETE ALL task memory files
   - Delete: .claude/session/agents/gamedesigner/task-*.md
   - Verify files are removed

6. UPDATE status in prd.json
   - prd.json.agents.gamedesigner.status = "idle"
   - prd.json.agents.gamedesigner.lastSeen = {ISO_TIMESTAMP}

7. LOG in progress file
```

**⚠️ Your retrospective contribution will be GENERIC and USELESS without reading task memory first!**
