# Skill Mapping Reference

This document maps PRD task categories and types to their corresponding skills and sub-agents for each agent role.

## Purpose

- Help agents select the correct skill based on task type
- Provide consistency in skill invocation across the system
- Serve as a reference for task assignment decisions

---

## PM Coordinator

### Task Category → Skill Mapping

| Task Category        | Skill(s) to Use                          | Sub-Agent (if needed)       |
| -------------------- | ---------------------------------------- | --------------------------- |
| Task Selection       | `/pm-task-selection`                     | `pm-task-researcher`        |
| Test Planning        | `/pm-test-planner` (skill)               | `pm-test-planner` (sub)     |
| Retrospective        | `/pm-retrospective`                      | `pm-retrospective-facilitator` |
| Playtest Session     | `/pm-playtest-session`                   | -                           |
| PRD Reorganization   | `/pm-prd-reorganization`                 | `pm-prd-organizer`          |
| Skill Improvement    | `/pm-skill-improvement`                  | `pm-skill-researcher`       |
| Scale-Adaptive Plan  | `/pm-scale-adaptive`                     | -                           |
| Architecture Valid.  | `/pm-architecture-validation`            | `pm-architecture-validator` |

### Category → Agent Assignment

| Category        | Default Agent | Examples                               |
| --------------- | ------------- | -------------------------------------- |
| `architectural` | developer     | State stores, Colyseus rooms            |
| `functional`    | developer     | Gameplay mechanics, physics, networking |
| `integration`   | developer     | API integration, multiplayer            |
| `visual`        | techartist    | 3D models, materials, lighting          |
| `shader`        | techartist    | GLSL shaders, VFX                       |
| `polish`        | techartist    | UI styling, particles                   |

---

## Developer Agent

### Task Type → Skill Mapping

| Task Category               | Skill(s) to Use                              | Sub-Agent (if needed)         |
| --------------------------- | ------------------------------------------- | ----------------------------- |
| R3F Scene/Game Loop         | `dev-r3f-r3f-fundamentals`                   | -                             |
| Physics/Collision           | `dev-r3f-r3f-physics`                         | -                             |
| Multiplayer/Networking      | `dev-multiplayer-server-authoritative`      | -                             |
| Colyseus Framework          | `dev-multiplayer-colyseus-server`           | -                             |
| Client Prediction          | `dev-multiplayer-prediction-basics`         | -                             |
| State Management            | `dev-typescript-typescript-basics`           | -                             |
| Custom Materials            | `dev-r3f-r3f-materials`                      | `implementation`              |
| Performance Issues         | `dev-performance-performance-basics`         | `implementation`              |
| Object Pooling             | `dev-patterns-object-pooling`                | -                             |
| UI/HUD Animations          | `dev-patterns-ui-animations`                  | -                             |
| Territory Coverage         | `dev-patterns-coverage-tracking`             | -                             |
| Mobile Haptics             | `dev-patterns-mobile-haptics`                | -                             |
| Asset Loading (Vite 6)     | `dev-assets-vite-asset-loading`              | -                             |

### Sub-Agents (New Architecture)

| Sub-Agent         | Model   | When to Use                     |
| ----------------- | ------- | ------------------------------- |
| `orchestrator`    | Sonnet  | Start of any developer task     |
| `code-research`   | Haiku   | Before ALL coding (mandatory)   |
| `implementation`  | Sonnet  | After research completes        |
| `validation`      | Haiku   | Before commit (mandatory)       |
| `commit`          | Haiku   | After validation passes         |

---

## QA Agent

### Task Type → Sub-Agent Mapping

| Task Type               | Sub-Agent(s) to Use                    | Skill(s) to Reference               |
| ----------------------- | -------------------------------------- | ----------------------------------- |
| All Tasks               | `browser-validator` (MANDATORY)     | `qa/browser/testing`               |
| Multiplayer Features    | `multiplayer-validator`             | `qa/multiplayer/testing`           |
| Visual/UI Changes       | `visual-regression-tester`          | `qa/visual/testing`                |
| Gameplay Features       | `gameplay-tester`                   | `qa/gameplay/testing`              |
| Bug Reporting           | - (use skill)                          | `qa/reporting/bug-reporting`       |
| Asset Validation        | - (use skill)                          | `qa/validation/asset`              |
| General Validation      | - (use skill)                          | `qa/validation/workflow`           |

### Validation Order (Strict)

1. **Code Review** - Check for @ts-ignore, any types, anti-patterns
2. **Type-Check** - `npm run type-check` — 0 errors
3. **Lint** - `npm run lint` — 0 warnings
4. **Tests** - `npm run test` — all pass
5. **Build** - `npm run build` — succeeds
6. **Browser Testing** - Playwright MCP (NEVER optional)
7. **Multiplayer** - Server-authoritative check (if applicable)

---

## Tech Artist Agent

### Asset Type → Skill Mapping

| Asset Type               | Skill(s) to Use                              | Sub-Agent (if needed)            |
| ------------------------ | ------------------------------------------- | ------------------------------- |
| R3F Scene Setup          | `ta-r3f-fundamentals`                       | `asset-creator`                  |
| Materials/PBR            | `ta-r3f-materials`                          | `asset-creator`                  |
| Physics Assets           | `ta-r3f-physics`                            | `asset-creator`                  |
| GLSL/TSL Shaders         | `ta-shader-development`                      | `shader-compiler`                |
| SDF Geometry             | `ta-shader-sdf`                             | `shader-compiler`                |
| Particle Systems         | `ta-vfx-particles`                           | `particle-system-designer`       |
| Post-Processing          | `ta-vfx-postfx`                             | `shader-compiler`                |
| Third-Person Camera      | `ta-camera-tps`                              | `asset-creator`                  |
| UI Polish                | `ta-ui-polish`                              | `asset-creator`                  |
| Performance Issues       | `ta-r3f-performance`                         | `performance-profiler`           |
| Debug Visualization      | `ta-ui-debug-helpers`                        | -                               |
| Asset Pipeline           | `ta-assets-workflow`                         | -                               |
| Asset Optimization       | `ta-assets-pipeline-optimization`           | `performance-profiler`           |
| Type Safety              | `ta-validation-typescript`                   | `code-quality`                   |
| Feedback Loops           | `ta-validation-feedback-loops`               | `code-quality`                   |
| Input Validation         | `ta-input-validation`                        | -                               |
| Networked Feedback       | `ta-networking-visual-feedback`              | -                               |

### MANDATORY Sub-Agents

| Sub-Agent                | When to Use                      |
| ------------------------ | -------------------------------- |
| `orchestrator`           | Use proactively for all tasks     |
| `asset-researcher`       | Before creating assets (mandatory)|
| `asset-creator`          | General 3D/2D asset creation      |
| `shader-compiler`        | Shader creation                  |
| `particle-system-designer` | Particle effects                |
| `visual-validator`       | Pre-commit validation            |
| `visual-tester`          | Browser visual regression        |
| `performance-profiler`   | Performance issues               |
| `code-quality`           | Before commit (quality gates)    |

**Invocation:** `Task("techartist-{subagent-name}", { prompt: "...", timeout: 300000 })`

---

## Game Designer Agent

### Task Type → Skill Mapping

| Task Type               | Skill(s) to Use                              | Sub-Agent (if needed)                |
| ----------------------- | ------------------------------------------- | ------------------------------------ |
| GDD Creation            | `gd-gdd-creation`                           | `gdd-documenter`                     |
| Game Mechanics          | `gd-design-mechanic`                         | `thermite-facilitator`                |
| Level/Map Design        | `gd-design-level`                            | `thermite-facilitator`                |
| Character Design        | `gd-design-character`                        | `thermite-facilitator`                |
| Weapon Design           | `gd-design-weapon`                           | `thermite-facilitator`                |
| Game Loop Design        | `gd-design-game-loop`                        | `thermite-facilitator`                |
| Playtesting             | `gd-validation-playtest`                     | `playtest-evidence-collector`         |
| Visual References       | - (use sub-agent)                           | `visual-reference-researcher`         |
| Asset Inventory         | - (use sub-agent)                           | `asset-analyst`                       |
| Reference Game Research | - (use sub-agent)                           | `reference-game-researcher`           |
| Design Sessions         | `gd-thermite-integration`                     | `thermite-facilitator`                |

### MANDATORY Sub-Agents

| Sub-Agent                    | When to Use                      |
| ---------------------------- | -------------------------------- |
| `orchestrator`               | Use proactively for all tasks     |
| `asset-analyst`               | Before requesting assets (MANDATORY)|
| `visual-reference-researcher` | Visual inspiration collection   |
| `reference-game-researcher`   | Reference game deep dives        |
| `thermite-facilitator`        | Design discussions               |
| `gdd-documenter`              | GDD creation and maintenance     |
| `playtest-evidence-collector` | Playtest validation (MANDATORY)  |

**Invocation:** `Task("gamedesigner-{subagent-name}", { prompt: "...", timeout: 300000 })`

---

## Model Selection Guidelines (All Agents)

| Model | Use Case                                     |
|-------|----------------------------------------------|
| Haiku | Research, validation, simple testing (cost-effective) |
| Sonnet| Most implementation/coordination tasks (capable) |
| Opus  | Complex retrospectives, creative visual work, debugging |
| Inherit| Sub-agents use parent's model |

---

## Shared Skills (All Agents)

| Skill                   | Purpose                                      |
| ----------------------- | -------------------------------------------- |
| `/worker-worktree`      | Git worktree management for parallel development |
| `/ralph-core`           | Session structure, exit conditions          |
| `/ralph-event-protocol` | Event-driven messaging                       |
| `/file-permissions`     | Permissions matrix                           |
| `/context-management`   | Context reset procedures                     |
| `/worker-task-memory`   | Task memory for retrospective contributions   |
| `/worker-retrospective`  | Retrospective contribution format            |

---

## Decision Framework Reference

Each agent now has a formal decision framework in their AGENT.md:

- [PM Agent](../agents/pm/AGENT.md#decision-framework) - Task assignment, retrospective flow
- [Developer Agent](../agents/developer/AGENT.md#decision-framework) - Implementation flow
- [QA Agent](../agents/qa/AGENT.md#decision-framework) - Validation flow
- [Tech Artist Agent](../agents/techartist/AGENT.md#decision-framework) - Asset creation flow
- [Game Designer Agent](../agents/gamedesigner/AGENT.md#decision-framework) - Design flow

---

## Quick Reference: Task Category → Agent → Skill

| PRD Category | Agent       | First Skill to Load               |
| ------------ | ----------- | --------------------------------- |
| `architectural` | developer  | `dev-r3f-r3f-fundamentals`       |
| `functional`  | developer  | `dev-r3f-r3f-fundamentals`       |
| `integration` | developer  | `dev-multiplayer-server-authoritative` |
| `visual`      | techartist | `ta-r3f-materials`                |
| `shader`      | techartist | `ta-shader-development`           |
| `polish`      | techartist | `ta-ui-polish`                    |
| `gdd`         | gamedesigner| `gd-gdd-creation`                |
| `playtest`    | gamedesigner| `gd-validation-playtest`         |

---

*Last updated: 2026-01-24*
*Related: [Agent Workflows Analysis](../.claude/plans/harmonic-marinating-hoare.md)*
