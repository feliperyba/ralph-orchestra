---
name: gamedesigner-workflow
description: Complete Game Designer workflow - skill invocation, GDD creation, playtest flow with GDD review, design sessions, Agile development cycle. MUST load before starting assignments.
category: workflow
model: inherit
user-invocable: true
---

# Game Designer Workflow

> "This skill contains ALL detailed workflows for the Game Designer Agent. Load this BEFORE starting any task."

## File Organization

| File         | Purpose                                                | Size       |
| ------------ | ------------------------------------------------------ | ---------- |
| `AGENT.md`   | Quick Reference: routing, permissions, messages        | ~180 lines |
| `this skill` | ALL detailed workflows: playtest, GDD, design sessions | ~400 lines |

**Use AGENT.md** for: Task routing table, communication protocol, status values, file permissions
**Use this skill** for: Playtest checklist, GDD creation flow, task research, design sessions, retrospective

## 🚨 GOLDEN RULE: PRD Status Synchronization

**⚠️ CRITICAL: The PRD is the SINGLE SOURCE OF TRUTH for all agents. Every status change MUST be immediately reflected in `prd.json`.**

**Whenever your status changes, UPDATE THE PRD IMMEDIATELY.**

| When This Happens                          | Update PRD Like This                                                            | Why                             |
| ------------------------------------------ | ------------------------------------------------------------------------------- | ------------------------------- |
| **Starting design work**                   | `prd.json.agents.gamedesigner.status = "working"`                               | PM knows you're designing       |
| **GDD created/updated**                    | `prd.json.agents.gamedesigner.gddPath = "docs/design/gdd.md"`                   | PM knows GDD is ready           |
| **Playtest requested**                     | `prd.json.agents.gamedesigner.status = "playtesting"`                           | PM knows you're testing         |
| **Playtest complete, starting GDD review** | `prd.json.agents.gamedesigner.status = "reviewing"`                             | PM knows you're reviewing       |
| **GDD review complete**                    | Send `playtest_session_report` + `prd.json.agents.gamedesigner.status = "idle"` | PM receives findings + GDD gaps |
| **Providing acceptance criteria**          | Send `acceptance_criteria` with task details                                    | PM uses for task definition     |
| **Self-reporting progress**                | `prd.json.agents.gamedesigner.lastSeen = {ISO_TIMESTAMP}`                       | Watchdog knows you're alive     |

**⚠️ If you don't update the PRD, the system desyncs:**

- PM assigns design work already in progress
- PM waits for GDD that's complete
- Watchdog thinks you crashed
- Loop locks occur

**Rule of thumb: If your state changes, PRD changes. IMMEDIATELY.**

## Agile Development Cycle

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    GAME DESIGNER AGILE CYCLE                                │
├─────────────────────────────────────────────────────────────────────────────┤
│  PHASE 1: BACKLOG PLANNING → PHASE 2: DESIGN ITERATION →                    │
│  PHASE 3: COLLABORATION → PHASE 4: VALIDATION →                            │
│  PHASE 5: RETROSPECTIVE → (continuous loop)                                 │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Phase 1: Backlog Planning

| Activity                          | Output                          | Tools                  |
| --------------------------------- | ------------------------------- | ---------------------- |
| Review PRD backlog                | Identify design dependencies    | `prd.json`             |
| Estimate design complexity        | T-shirt sizing (S/M/L/XL)       | GDD modules            |
| Identify skill needs              | Flag missing skills             | `gd-skill-gap-analysis`|
| Propose task priorities           | Recommend to PM                 | Message to PM          |

### Phase 2: Design Iteration

| Activity                          | Output                          | Tools                  |
| --------------------------------- | ------------------------------- | ---------------------- |
| Create/update GDD modules         | Design documentation            | `gd-gdd-creation`      |
| Run design sessions               | Decisions, open questions       | `gd-thermite-integration`|
| Define success criteria           | Measurable outcomes             | Acceptance criteria    |
| Document decisions                | Decision log entries            | `docs/design/decision_log.md`|

### Phase 3: Collaboration

| Activity                          | Output                          | Tools                  |
| --------------------------------- | ------------------------------- | ---------------------- |
| Answer design questions           | Clarifications to workers       | Message responses      |
| Provide visual references         | Art direction for Tech Artist   | `visual-reference-researcher`|
| Review asset inventory           | Use existing vs. request new    | `asset-analyst`        |
| Validate implementations          | Design answers to Dev/QA        | GDD comparison         |

### Phase 4: Validation

| Activity                          | Output                          | Tools                  |
| --------------------------------- | ------------------------------- | ---------------------- |
| Playtest via Playwright MCP       | Evidence collection             | `gd-validation-playtest`|
| GDD review vs. implementation     | Gap analysis                    | `gd-playtest-gdd-review`|
| Identify skill gaps               | Skill proposals                 | `gd-skill-gap-analysis`|
| Recommend priority adjustments    | Task reordering                 | Message to PM          |

### Phase 5: Retrospective

| Activity                          | Output                          | Tools                  |
| --------------------------------- | ------------------------------- | ---------------------- |
| Review task memory                | Contribution content            | `shared-worker-task-memory`|
| Analyze pain points               | Improvement proposals           | Retrospective.txt      |
| Identify skill gaps               | New skill proposals             | `gd-skill-gap-analysis`|
| Propose GDD updates               | Design refinements              | GDD modules            |

**Agile Principles Applied:**

- **Iterative Design** - GDD evolves through sprints, not waterfall
- **Continuous Validation** - Playtest every iteration, not just at end
- **Evidence-Based** - Screenshots, Vision MCP analysis, not opinions
- **Collaborative** - Design sessions involve all relevant personas
- **Adaptive Planning** - Priorities adjust based on playtest findings

## Startup Workflow (V2)

```
1. Load router skill (MANDATORY - first step)
   Skill("gd-router")

2. Connect to watchdog (V2 - PRE-INITIALIZED)
   - Named pipe connection via agent-runtime.ps1 (automatic)
   - Messages received via Enter-AgentLoop
   - No file-based message queues

3. Check and process pending messages (MANDATORY - prevents watchdog restart loop)
   - In V2, messages are received via named pipe (ralph-gamedesigner-main)
   - Enter-AgentLoop automatically receives and processes messages
   - Process each message based on type (WorkAssign, Query, etc.)

4. ⚠️ PROACTIVE PLAYTEST CHECK (MANDATORY - EVERY STARTUP)
   - Read .claude/session/retrospective.txt → Check Action Items for "[ ] Request playtest"
   - Read prd.json → Check session.currentTask.status for "playtest_phase"
   - IF playtest needed → JUMP TO PLAYTEST FLOW immediately (skip to step 10)

5. Check if GDD exists in docs/design/

6. Read prd.json for current task
   - Check prd.json.session.currentTask for your assignment
   - Check prd.json.agents.gamedesigner for your status
   - Update your status and lastSeen timestamp

7. **SKILL CHECK** - Match task to skill/sub-agent using gd-router

8. **TASK RESEARCH (MANDATORY)**
   - Read GDD, check reference games
   - Check src/assets/ before requesting new assets

9. Invoke appropriate skill/sub-agent

10. PLAYTEST FLOW (if triggered in step 4)
    - See Playtest Flow section below

11. Complete design work, commit with Ralph format, send message, exit
```

## Task Research (MANDATORY - First Step)

**Always check:**

- `docs/design/gdd/index.md` - Modular GDD overview and table of contents
- `docs/design/gdd/{module}.md` - Feature-specific design documents (project-specific modules)
- `docs/design/decision_log.md` - Design rationale (DEC-XXX decisions)
- `docs/design/open_questions.md` - Unresolved issues (OQ-XXX)
- `docs/design/reference-games.md` - Reference game analysis (document per project)
- `src/assets/` - Existing assets before requesting new ones

**Decision tree:**

- Requirements clear → Proceed with design
- Design unclear → Use thermite-facilitator sub-agent
- Visual reference needed → Use visual-reference-researcher sub-agent
- Asset request needed → Use asset-analyst sub-agent FIRST

## GDD Creation Flow

**For GDD document structure template, sections, and maintenance guidelines:**
→ `Skill("gd-gdd-creation")`

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

**⚠️ PROACTIVE INITIATION**: Don't wait for a message! Check these conditions on EVERY startup:

**For detailed Playwright MCP usage, Vision MCP game state detection, code examples, and validation patterns:**
→ `Skill("gd-validation-playtest")`

**HIGH-LEVEL CHECKLIST (13 steps - quick reference during startup):**

```
STEP 1: DETECT playtest needed (proactive check - EVERY STARTUP)
   - Read .claude/session/retrospective.txt → Look for "[ ] Request playtest session from Game Designer"
   - Read prd.json → Look for session.currentTask.status = "playtest_phase"
   - IF true → IMMEDIATELY INITIATE PLAYTESTING

STEP 2: START DEV SERVERS
   - Run: npm run dev:all:sh (client :3000, server :2567)
   - Wait for "Vite ready" and "server listening"
   - Verify: http://localhost:3000 accessible

STEP 3: UPDATE PRD status
   → prd.json.agents.gamedesigner.status = "playtesting"
   → prd.json.agents.gamedesigner.currentTaskId = "{taskId}"

STEP 4: CREATE task memory file
   → .claude/session/agents/gamedesigner/task-{taskId}-playtest-memory.md

STEP 5-9: GAMEPLAY TESTING
   → Use gd-validation-playtest for detailed Playwright MCP patterns:
   - Character selection test (3D model, console check)
   - Lobby test (server connection)
   - Game scene test (character render, controls)
   - Keyboard/mouse controls (WASD, Space, Shift, RMB, etc.)
   - Acceptance criteria validation
   - Vision MCP analysis for visual quality

STEP 10: GDD REVIEW PHASE (MANDATORY BEFORE SENDING REPORT)
   → prd.json.agents.gamedesigner.status = "reviewing"
   - Retrospective analysis (read pain points from workers)
   - Game state review (compare vs GDD specs)
   - Gap analysis (identify missing specs/skills)
   - Use: Skill("gd-playtest-gdd-review") for detailed process
   - Use: Skill("gd-skill-gap-analysis") for skill identification

STEP 11: SEND playtest_session_report (V2)
   → Send via message to PM
   Include: gddReview, skillGaps, priorityRecommendations

STEP 12: UPDATE PRD status
   → prd.json.agents.gamedesigner.status = "idle"
   → prd.json.agents.gamedesigner.currentTaskId = null
   → prd.json.agents.gamedesigner.lastSeen = {ISO_TIMESTAMP}
```

**For Playwright code examples, Vision MCP patterns, game state detection, and visual validation:**
→ `Skill("gd-validation-playtest")`

**⚠️ CRITICAL REMINDER:**

- Start servers with `npm run dev:all:sh` BEFORE playtesting
- Use Playwright MCP for all testing (no manual workarounds)
- Test ALL keyboard/mouse controls in game scene
- Validate against acceptance criteria in PRD
- **MANDATORY: Conduct GDD review BEFORE sending report (STEP 10)**
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

## Thermite Design Integration

**For full persona details (expertise, signature phrases, tensions), session types, and artifact templates:**
→ `Skill("gd-thermite-integration")`

### Design Pillars (Quick Reference - Non-Negotiable)

Every design decision must serve at least one pillar:

1. **Meaningful Risk** - Every action matters, gear has weight
2. **Readable Chaos** - Chaotic but parseable, clear visual language
3. **Compressed Tension** - 5-8 minute matches (or project-appropriate)
4. **Earned Mastery** - Skill beats gear
5. **Sustainable Economy** - Patchable, not exploitable

### Expert Personas (8)

| Persona        | Domain             | Key Question                          |
| -------------- | ------------------ | ------------------------------------- |
| Shinji Tanaka  | Classic Arcade     | "Is this readable in 2 seconds?"      |
| Viktor Volkov  | Extraction/Economy | "Does risk feel real AND survivable?" |
| Elena Vasquez  | Map Architecture   | "Does space create decisions?"        |
| Marcus Chen    | Combat Balance     | "What beats this?"                    |
| Sarah Okonkwo  | Economy            | "Where does currency leave?"          |
| Dr. Maya Reyes | Player Psychology  | "What does first death teach?"        |
| Wei Zhang      | Technical          | "What happens at 150ms latency?"      |
| Jordan Ellis   | UX/Accessibility   | "Can colorblind players distinguish?" |

## Sub-Agents (invoke via Task tool)

**See [gd-router](../gd-router/SKILL.md) for complete sub-agent reference.**

| Sub-Agent                     | Model   | Purpose                                           |
| ----------------------------- | ------- | ------------------------------------------------- |
| `thermite-facilitator`        | Inherit | Multi-persona design sessions                     |
| `playtest-evidence-collector` | Inherit | **MANDATORY** Playwright + Vision MCP playtesting |
| `gdd-documenter`              | Inherit | GDD creation and maintenance                      |
| `gdd-review-analyst`          | Inherit | GDD review during playtest phase                  |
| `skill-gap-analyst`           | Haiku   | Analyze pain points, identify skill gaps          |
| `asset-analyst`               | Haiku   | Read-only asset inventory                         |
| `visual-reference-researcher` | Haiku   | Web search + image analysis                       |

**Invocation:** `Task("gamedesigner-{subagent-name}", { prompt: "...", timeout: 300000 })`

## Skill Routing

**Use `gd-router` for all skill selection.** The router contains complete routing tables by keyword, category, and common combinations.

See [gd-router](../gd-router/SKILL.md) for:

- Quick route by keyword
- Routing by design category
- All available skills and sub-agents
- Common skill combinations
- Skill dependencies

### Quick Skill Reference

| Task Type                       | Use This Skill                       |
| ------------------------------- | ------------------------------------ |
| **GDD Structure/Template**      | `Skill("gd-gdd-creation")`           |
| **Thermite Design Sessions**    | `Skill("gd-thermite-integration")`   |
| **Mechanic Documentation**      | `Skill("gd-design-mechanic")`        |
| **Map/Level Design**            | `Skill("gd-design-level")`           |
| **Character/Class Design**      | `Skill("gd-design-character")`       |
| **Weapon/Item Design**          | `Skill("gd-design-weapon")`          |
| **Game Loop Design**            | `Skill("gd-design-game-loop")`       |
| **Asset Impact Analysis**       | `Skill("gd-assets-impact-analysis")` |
| **Playwright Playtesting**      | `Skill("gd-validation-playtest")`    |
| **GDD Review (Playtest Phase)** | `Skill("gd-playtest-gdd-review")`    |
| **Skill Gap Analysis**          | `Skill("gd-skill-gap-analysis")`     |
| **Router**                      | `Skill("gd-router")`                 |
| **Task Memory**                 | `Skill("shared-worker-task-memory")` |

**Core Skills:**

| Skill                       | Purpose                                                            |
| --------------------------- | ------------------------------------------------------------------ |
| `gd-router`                 | **MANDATORY - Load first** Routes to appropriate skills/sub-agents |
| `shared-worker-task-memory` | Task memory for retrospective contributions                        |

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

## Retrospective Contribution (V2)

**When `Retrospective` message is received from PM:**

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

7. SEND `Retrospective` message back to PM with your contribution
```

**⚠️ Your retrospective contribution will be GENERIC and USELESS without reading task memory first!**
