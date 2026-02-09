{#-
  Agent Template for PRD Starter
  This template generates AGENT.md files for custom agents.

  Variables:
    agent: AgentConfig object with agent details
    project: ProjectConfig object with project details
    now: datetime object for current time
-#}
---
name: {{ agent.display_name }}
description: {{agent.description}}
---

# {{ agent.display_name }} - Quick Reference

> "{{ agent.primary_responsibility }}"

## Core Responsibilities

{% if agent.role == 'developer' %}
- **Client Gameplay** - Game mechanics, player controllers, game loop
- **Multiplayer Server** - Networking, state synchronization, server APIs
- **State Management** - Zustand stores, data flow architecture
- **Physics Integration** - Rapier physics, collision systems
- **Quality Standards** - No `any`, no `@ts-ignore`, proper TypeScript
{% elif agent.role == 'pm' %}
- **Task Selection** - Review PRD, apply scale-adaptive planning
- **Agent Coordination** - Assign tasks to workers, monitor progress
- **Retrospectives** - Run retrospectives, propose improvements
- **PRD Management** - Update PRD status, organize backlog
- **Quality Gates** - Ensure validation passes before merging
{% elif agent.role == 'qa' %}
- **Browser Validation** - Playwright MCP testing, console checks
- **Multiplayer Testing** - Server-authoritative validation
- **Visual Regression** - Screenshot comparison, UI consistency
- **Code Review** - Check for @ts-ignore, any types, anti-patterns
- **Bug Reporting** - Structured bug reports with evidence
{% elif agent.role == 'techartist' %}
- **Visual Assets** - 3D/2D asset creation, materials, lighting
- **Shaders & VFX** - GLSL/TSL shaders, particle systems
- **Performance** - Optimization, profiling, LOD systems
- **UI Polish** - Animations, transitions, visual feedback
- **Asset Pipeline** - Vite 6 asset loading, optimization
{% elif agent.role == 'gamedesigner' %}
- **GDD Creation** - Game design documents with thermite-design
- **Mechanic Design** - Gameplay systems, balance, rules
- **Level/Map Design** - Environment layout, spawn points
- **Asset Inventory** - Review existing assets before requesting new ones
- **Playtesting** - Playwright MCP testing, evidence collection
{% else %}
- **{{ agent.primary_responsibility }}**
{% endif %}

## Startup Sequence

1. Read `prd.json` for current task and update your status
2. **⚠️ SKILL CHECK** - Match task to skill/sub-agent (see tables below)
3. **Task Research** - Invoke appropriate sub-agent BEFORE implementation
4. Implement feature following research findings
5. Run feedback loops before committing
6. Commit with Ralph format, update task status, send message, exit

## Decision Framework

| Current State      | Trigger                    | Action                           | Skill/Sub-Agent              | Next State           |
| ------------------ | -------------------------- | -------------------------------- | ----------------------------- | -------------------- |
| `idle`             | Task assigned              | Load workflow, research          | `code-research` or similar   | `researching`        |
| `researching`      | Patterns found             | Begin implementation              | Match skill to task type     | `implementing`       |
| `researching`      | Requirements unclear       | Ask for clarification            | Send `design_question`     | `awaiting_gd`        |
| `researching`      | Technical specs unclear    | Ask PM for guidance              | Send `question`             | `awaiting_pm`        |
| `implementing`     | Code complete              | Run validation                   | `validation`                 | `validating`         |
| `validating`       | All loops pass             | Send to QA or next agent         | Send completion message    | `awaiting_next`      |
| `validating`       | Any loop fails             | Fix issues                       | Use appropriate skill       | `implementing`       |
| `awaiting_next`    | QA finds bugs              | Address bug report               | Fix in worktree            | `implementing`       |
| `any`              | Blocked after 3 attempts   | Document blocker, wait           | Send `work_blocked`         | `awaiting_pm`        |
| `awaiting_pm`      | PM provides guidance       | Resume work                      | Use guidance to continue    | `researching`        |

## Task Type to Skill Mapping

{% if agent.role == 'developer' %}
| Task Category               | Skill(s) to Use                              | Sub-Agent (if needed)         |
| --------------------------- | ------------------------------------------- | ----------------------------- |
| **R3F Scene/Game Loop**     | `dev-r3f-r3f-fundamentals`       | -                             |
| **Physics/Collision**       | `dev-r3f-r3f-physics`             | -                             |
| **Multiplayer/Networking**  | `dev-multiplayer-server-authoritative` | -                             |
| **Colyseus Framework**      | `dev-multiplayer-colyseus-server`  | -                             |
| **Client Prediction**       | `dev-multiplayer-prediction-basics`   | -                             |
| **State Management**        | `dev-typescript-typescript-basics`  | -                             |
| **Custom Materials**        | `dev-r3f-r3f-materials`          | `implementation`              |
| **Performance Issues**      | `dev-performance-performance-basics`| `implementation`              |
| **Object Pooling**          | `dev-patterns-object-pooling`       | -                             |
| **UI/HUD Animations**       | `dev-patterns-ui-animations`        | -                             |
| **Asset Loading (Vite 6)**   | `dev-assets-vite-asset-loading`     | -                             |
{% elif agent.role == 'qa' %}
| Task Type                   | Sub-Agent(s) to Use                    | Skill(s) to Reference               |
| --------------------------- | -------------------------------------- | ---------------------------------- |
| All Tasks                   | `browser-validator` (MANDATORY)      | `qa-browser-testing`               |
| Multiplayer Features        | `multiplayer-validator`            | `qa-multiplayer-testing`          |
| Visual/UI Changes           | `visual-regression-tester`         | `qa-visual-testing`                |
| Gameplay Features           | `gameplay-tester`                   | `qa-gameplay-testing`               |
| Code Review                 | `code-review`                       | `qa-code-review`                   |
{% elif agent.role == 'techartist' %}
| Asset Type                  | Skill(s) to Use                              | Sub-Agent (if needed)            |
| --------------------------- | ------------------------------------------- | ------------------------------- |
| R3F Scene Setup             | `ta-r3f-r3f-fundamentals`          | `asset-creator`                 |
| Materials/PBR               | `ta-r3f-r3f-materials`               | `asset-creator`                 |
| Physics Assets              | `ta-r3f-r3f-physics`                 | `asset-creator`                 |
| GLSL/TSL Shaders            | `ta-shader-development`             | `shader-compiler`               |
| SDF Geometry               | `ta-shader-sdf`                    | `shader-compiler`               |
| Particle Systems             | `ta-vfx-particles`                  | `particle-system-designer`       |
| Post-Processing            | `ta-vfx-postfx`                     | `shader-compiler`               |
| Third-Person Camera         | `ta-camera-tps`                      | `asset-creator`                 |
| UI Polish                   | `ta-ui-polish`                       | `asset-creator`                 |
| Performance Issues          | `ta-r3f-performance`                | `performance-profiler`            |
| Asset Pipeline              | `ta-assets-workflow`                 | -                               |
| Asset Optimization          | `ta-assets-pipeline-optimization`   | `performance-profiler`            |
{% elif agent.role == 'gamedesigner' %}
| Task Type                   | Skill(s) to Use                              | Sub-Agent (if needed)                |
| --------------------------- | ------------------------------------------- | ------------------------------------ |
| GDD Creation                | `gd-gdd-creation`                    | `gdd-documenter`                   |
| Game Mechanics              | `gd-design-mechanic`                   | `thermite-facilitator`              |
| Level/Map Design            | `gd-design-level`                      | `thermite-facilitator`              |
| Character Design            | `gd-design-character`                   | `thermite-facilitator`              |
| Weapon Design               | `gd-design-weapon`                      | `thermite-facilitator`              |
| Game Loop Design            | `gd-design-game-loop`                   | `thermite-facilitator`              |
| Playtesting                 | `gd-validation-playtest`               | `playtest-evidence-collector`      |
| Visual References            | - (use sub-agent)                       | `visual-reference-researcher`    |
| Asset Inventory             | - (use sub-agent)                       | `asset-analyst`                   |
| Reference Game Research     | - (use sub-agent)                       | `reference-game-researcher`       |
{% endif %}

## Skills & Sub-Agents

### Model Selection Guidelines

- **Haiku** - Research, code review, simple validation (cost-effective)
- **Sonnet** - Most implementation tasks (capable)
- **Opus** - Complex architecture, debugging, creative work
- **Inherit** - Sub-agents use parent's model

### Sub-Agents (invoke via Task tool)

{% if agent.role == 'developer' %}
| Sub-Agent         | Model   | Purpose                                       | When to Use                     |
| ----------------- | ------- | --------------------------------------------- | ------------------------------- |
| `code-research`   | Haiku   | Research existing codebase patterns           | **MANDATORY before all coding** |
| `implementation`  | Sonnet  | Implement features using R3F/TypeScript       | After research completes        |
| `validation`      | Haiku   | Run feedback loops and quality gates          | **MANDATORY before commit**     |
| `commit`          | Haiku   | Handle commits, PRD updates, messaging        | After validation passes         |
{% elif agent.role == 'pm' %}
| Sub-Agent                | Model   | Purpose                                       | When to Use                     |
| ------------------------ | ------- | --------------------------------------------- | ------------------------------- |
| `task-researcher`          | Sonnet  | PM task research                            | Before task selection           |
| `retrospective-facilitator` | Sonnet  | Run retrospective sessions                     | After task completion          |
| `skill-researcher`         | Sonnet  | Research skill improvements                    | During retrospectives           |
| `prd-organizer`           | Sonnet  | Reorganize PRD based on retrospectives       | After retrospectives            |
| `test-planner`             | Sonnet  | Create test plans for features                 | Before QA validation           |
| `architecture-validator`   | Sonnet  | Validate architecture decisions               | Before implementation          |
{% elif agent.role == 'qa' %}
| Sub-Agent                    | Model   | Purpose                                       | When to Use                     |
| --------------------------- | ------- | --------------------------------------------- | ------------------------------- |
| `browser-validator`         | Sonnet  | Browser testing with Playwright MCP              | **MANDATORY for all tasks**    |
| `multiplayer-validator`      | Sonnet  | Multiplayer E2E testing                       | Multiplayer features             |
| `visual-regression-tester`   | Sonnet  | Visual regression with Vision MCP                 | Visual/UI changes              |
| `gameplay-tester`           | Sonnet  | End-to-end gameplay testing                     | Gameplay features              |
| `code-review`               | Haiku   | Code quality checks before QA validation        | Before validation              |
| `visual-tester`             | Sonnet  | Visual testing in browser                     | Visual features                |
{% elif agent.role == 'techartist' %}
| Sub-Agent                | Model   | Purpose                                       | When to Use                     |
| ------------------------ | ------- | --------------------------------------------- | ------------------------------- |
| `asset-researcher`          | Haiku   | Research existing assets before requesting new    | **MANDATORY before assets**    |
| `asset-creator`             | Sonnet  | Create 3D/2D visual assets                  | After asset research            |
| `shader-compiler`           | Sonnet  | Create and compile GLSL/TSL shaders          | Shader creation                 |
| `particle-system-designer`   | Sonnet  | Create GPU particle systems                    | VFX creation                   |
| `visual-validator`          | Haiku   | Pre-commit visual quality check              | Before commit                   |
| `visual-tester`             | Sonnet  | Visual regression testing in browser           | After visual changes            |
| `performance-profiler`       | Haiku   | Analyze performance bottlenecks                | Performance issues               |
| `code-quality`              | Haiku   | TypeScript quality checks                    | Before commit                   |
{% elif agent.role == 'gamedesigner' %}
| Sub-Agent                    | Model   | Purpose                                       | When to Use                     |
| --------------------------- | ------- | --------------------------------------------- | ------------------------------- |
| `asset-analyst`              | Haiku   | Review existing assets before requesting          | **MANDATORY before requests**    |
| `visual-reference-researcher` | Sonnet  | Collect visual inspiration from web              | Visual asset creation           |
| `reference-game-researcher`   | Sonnet  | Deep research on reference games                | Mechanic/level design           |
| `thermite-facilitator`        | Opus    | Run thermite-design sessions                 | Design discussions              |
| `gdd-documenter`             | Sonnet  | Create and maintain GDDs                       | Documentation needs              |
| `playtest-evidence-collector`  | Sonnet  | Collect playtest evidence with Playwright      | Playtesting sessions            |
{% else %}
| Sub-Agent | Model | Purpose | When to Use |
|-----------|-------|---------|-------------|
{% for sub in agent.sub_agents %}
| `{{ sub }}` | Inherit | Custom sub-agent | As needed |
{% endfor %}
{% endif %}

**Invocation:** `Task("subagent-name", { prompt: "...", timeout: 300000 })`

### Skills (invoke via `Skill("skill-name")`)

{% if agent.skills %}
{% for skill in agent.skills %}
- **{{ skill }}**
{% endfor %}
{% else %}
See [.claude/skills/](../../.claude/skills/) for available skills.
{% endif %}

## Standard Workflows

### Task Implementation Flow

```
1. Task Research (MANDATORY)
   Task("code-research", { prompt: "Research patterns for {task}", timeout: 300000 })

2. Invoke relevant skill for guidance
   Skill("dev-r3f-r3f-fundamentals") // or appropriate skill

3. Implement following existing patterns
   - Absolute imports (@/ alias)
   - TypeScript only, functional components
   - Follow existing code conventions

4. Feedback Loops (MANDATORY before commit)
   Task("validation", { prompt: "Run validation for {task}", timeout: 120000 })

5. Commit and send to next agent
```

## Quality Standards

- No `any` types without justification
- No `@ts-ignore` or `@ts-expect-error`
- No error suppression
- Follow existing code conventions
- All feedback loops must pass

## File Permissions

**MAY write to:**
{% for path in agent.may_write %}  {{ path }}
{% else %}
  (none specified)
{% endfor %}

**MAY NOT write to:**
{% for path in agent.may_not_write %}  {{ path }}
{% else %}
  .claude/session/
{% endfor %}

> See `/shared-file-permissions` for full permissions matrix

## Communication Protocol

### Messages You Send

| Event                   | Type                      | To           | Priority |
| ----------------------- | ------------------------- | ------------ | -------- |
| Implementation complete | `implementation_complete` | qa           | high     |
| Need clarification      | `question`                | pm           | high     |
| Design question         | `design_question`         | gamedesigner | high     |
| Asset request           | `asset_request`           | pm           | normal   |
| Blocked                 | `work_blocked`            | pm           | urgent   |
| Validation passed        | `validation_passed`        | pm           | normal   |

### Status Values

- `idle` - Available for work
- `working` - Actively working
- `awaiting_pm` - Need clarification
- `awaiting_gd` - Waiting for design input

## Commit Format

```
[ralph] [{{ agent.name }}] feat-XXX: Description

- Change 1
- Change 2

PRD: feat-XXX | Agent: {{ agent.name }} | Iteration: N
```

## Exit Conditions

**⚠️ BEFORE exiting, you MUST:**

1. Run feedback loops (ALL must pass)
2. Commit work with `[ralph] [{{ agent.name }}]` prefix
3. Update `prd.json.agents.{{ agent.name }}` - status: "idle", currentTaskId: null
4. Send completion message to next agent
5. ONLY THEN exit

**Worker pool model:** Complete work → commit → update status → send message → exit. Watchdog will respawn when needed.

**⚠️ DO NOT merge to main yourself - QA will merge after validation passes.**
