---
name: gamedesigner-workflow
description: Complete Game Designer workflow - skill invocation protocol, GDD creation, playtest flow, design sessions. MUST load before starting assignments.
category: workflow
version: 1.2
changelog: "ADDED: PRD Status Synchronization as golden rule. PRD must be updated immediately on EVERY status change to keep system in sync."
---

# Game Designer Workflow

> "This skill contains the complete workflow for the Game Designer Agent. Load this BEFORE starting any task."

## 🚨 GOLDEN RULE: PRD Status Synchronization

**⚠️ CRITICAL: The PRD is the SINGLE SOURCE OF TRUTH for all agents. Every status change MUST be immediately reflected in `prd.json`.**

**Whenever your status changes, UPDATE THE PRD IMMEDIATELY.**

| When This Happens | Update PRD Like This | Why |
|-------------------|---------------------|-----|
| **Starting design work** | `prd.json.agents.gamedesigner.status = "working"` | PM knows you're designing |
| **GDD created/updated** | `prd.json.agents.gamedesigner.gddPath = "docs/design/gdd.md"` | PM knows GDD is ready |
| **Playtest requested** | `prd.json.agents.gamedesigner.status = "playtesting"` | PM knows you're testing |
| **Playtest complete** | Send `playtest_session_report` + `prd.json.agents.gamedesigner.status = "idle"` | PM receives findings |
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

3. Check if GDD exists in docs/design/

4. Read prd.json for current task
   - Check prd.json.session.currentTask for your assignment
   - Check prd.json.agents.gamedesigner for your status
   - Update your status and lastSeen timestamp

5. **SKILL CHECK** - Match task to skill/sub-agent

6. **TASK RESEARCH (MANDATORY)**
   - Read GDD, check reference games
   - Check src/assets/ before requesting new assets

7. Invoke appropriate skill/sub-agent

8. Complete design work, commit with Ralph format, send message, exit
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

## Playtest Flow (MANDATORY for Retrospective)

```
1. RECEIVE playtest_session_request from PM
   → CREATE/UPDATE task memory file for playtest session

2. USE PLAYWRIGHT MCP
   - Navigate to localhost:3000
   - Test gameplay mechanics
   - Take 3+ screenshots: start, during, end
   → WRITE TO MEMORY: Document gameplay observations, issues found

3. USE VISION MCP
   - Analyze screenshots for GDD compliance
   - Validate game state
   → WRITE TO MEMORY: Document compliance findings, deviations

4. SEND playtest_session_report with:
   - screenshots: [filenames]
   - playwrightUsed: true
   - visionMcpUsed: true
   - findings: observations
   - gddCompliance: "pass" | "fail"
   - issues: problems found
   - recommendations: improvements
```

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
