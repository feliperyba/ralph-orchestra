# Wizard Skill Catalog

This document provides a complete catalog of all skills available in Ralph Orchestra, organized by agent type and category.

## Developer Skills (dev- prefix)

### R3F & Physics

| Skill | Description | Use When |
|-------|-------------|----------|
| `dev-r3f-r3f-fundamentals` | Core R3F patterns for scene composition | Building any R3F scene |
| `dev-r3f-r3f-physics` | Rapier physics integration | Adding physics to game |
| `dev-r3f-r3f-materials` | Custom material creation | Creating custom materials |

### Multiplayer

| Skill | Description | Use When |
|-------|-------------|----------|
| `dev-multiplayer-server-authoritative` | Server-authoritative architecture principles | Designing multiplayer game |
| `dev-multiplayer-colyseus-server` | Colyseus server setup, room handlers, lifecycle | Setting up multiplayer server |
| `dev-multiplayer-colyseus-client` | Colyseus client SDK for React, connection methods | Connecting to multiplayer server |
| `dev-multiplayer-colyseus-state` | Colyseus state schema definition, types, decorators | Defining room state |
| `dev-multiplayer-prediction-basics` | Client-side prediction and server reconciliation core concepts | Implementing responsive controls |
| `dev-multiplayer-prediction-movement` | Movement prediction with server reconciliation for WASD | Implementing player movement |
| `dev-multiplayer-prediction-shooting` | Shooting prediction with optimistic decals and server rollback | Implementing shooting |
| `dev-multiplayer-anti-cheat-validation` | Input validation and anti-cheat patterns for multiplayer servers | Implementing server-side validation |

### TypeScript

| Skill | Description | Use When |
|-------|-------------|----------|
| `dev-typescript-typescript-basics` | Core TypeScript patterns for game development | Defining types and interfaces |
| `dev-typescript-typescript-advanced` | Advanced TypeScript patterns - generics, utility types, React patterns | Complex type scenarios |

### Development Patterns

| Skill | Description | Use When |
|-------|-------------|----------|
| `dev-patterns-object-pooling` | Object pooling for high-performance R3F components (decals, particles, projectiles) | Performance optimization |
| `dev-patterns-ui-animations` | Game UI and HUD animation patterns with Framer Motion | Animating HUD elements |
| `dev-patterns-coverage-tracking` | Grid-based surface coverage tracking for territorial game mechanics | Territorial mechanics |
| `dev-patterns-mobile-haptics` | Haptic feedback patterns for mobile games using Vibration API | Adding tactile feedback |

### Performance

| Skill | Description | Use When |
|-------|-------------|----------|
| `dev-performance-performance-basics` | Core R3F/Three.js performance optimization principles | FPS drops below 60 |
| `dev-performance-instancing` | Instancing for repeated objects in R3F | Rendering many identical objects |
| `dev-performance-lod-systems` | Level of Detail (LOD) techniques for R3F | Complex models cause FPS drops |
| `dev-performance-mobile-optimization` | Mobile-specific optimization for R3F/Three.js | Targeting mobile devices |

### Asset Loading

| Skill | Description | Use When |
|-------|-------------|----------|
| `dev-assets-vite-asset-loading` | Vite 6 asset loading patterns for React Three Fiber with TypeScript | Loading assets |
| `dev-assets-audio-loading` | Audio loading patterns for R3F/Three.js | Adding sound effects |
| `dev-assets-model-loading` | FBX model loading patterns for R3F with useFBX | Loading 3D models |
| `dev-assets-texture-loading` | Texture loading and optimization for R3F | Loading image textures |

### Research

| Skill | Description | Use When |
|-------|-------------|----------|
| `dev-research-codebase-exploration` | Efficient codebase search using Glob and Grep | Finding files/patterns |
| `dev-research-gdd-reading` | Read Game Design Document for design context | Understanding design requirements |
| `dev-research-pattern-finding` | Find existing code patterns before implementing new features | Pre-coding research |

### Validation

| Skill | Description | Use When |
|-------|-------------|----------|
| `dev-validation-feedback-loops` | Type-check, lint, test, build validation for Developer agent | Before every commit |
| `dev-validation-quality-gates` | Quality standards that must pass before commit | Enforcing standards |
| `dev-validation-browser-testing` | Playwright patterns for browser validation | Browser testing |

### Coordination

| Skill | Description | Use When |
|-------|-------------|----------|
| `dev-coordination-git-protocol` | Git commit format and branch management | Making commits |
| `dev-coordination-message-formats` | JSON schemas for Ralph message system | Agent communication |

---

## Tech Artist Skills (ta- prefix)

### R3F Fundamentals

| Skill | Description | Use When |
|-------|-------------|----------|
| `ta-r3f-fundamentals` | Core R3F patterns for scene composition and game loop | Any R3F work |
| `ta-r3f-r3f-materials` | Material selection, shaders, and visual effects for R3F | Creating materials |
| `ta-r3f-r3f-performance` | Visual performance optimization techniques for R3F and Three.js | Performance issues |
| `ta-r3f-r3f-physics` | Physics integration with Rapier for R3F game development | Physics visualization |

### Shaders

| Skill | Description | Use When |
|-------|-------------|----------|
| `ta-shader-development` | GLSL shader creation process and patterns for R3F | Creating shaders |
| `ta-shader-sdf` | Signed Distance Functions for shader-based 3D primitives | SDF geometry |

### VFX

| Skill | Description | Use When |
|-------|-------------|----------|
| `ta-vfx-particles` | GPU particle systems for high-performance visual effects | Particle effects |
| `ta-vfx-postfx` | Post-processing effects with React Three Fiber | Post-processing |

### Camera

| Skill | Description | Use When |
|-------|-------------|----------|
| `ta-camera-tps` | Third-person shooter camera implementation patterns with proper player-relative controls | TPS camera |

### UI & Polish

| Skill | Description | Use When |
|-------|-------------|----------|
| `ta-ui-polish` | UI and visual polish checklist for game presentation | Visual polish |
| `ta-ui-debug-helpers` | Debug visualization helpers using drei and Three.js for game development | Debug panels |

### Assets

| Skill | Description | Use When |
|-------|-------------|----------|
| `ta-assets-workflow` | Asset creation pipeline and integration workflow for Tech Artist | Asset pipeline |
| `ta-assets-pipeline-optimization` | 3D asset optimization and pipeline management for Vite 6 projects | Asset optimization |

### Other

| Skill | Description | Use When |
|-------|-------------|----------|
| `ta-validation-typescript` | TypeScript best practices for game development | Code quality |
| `ta-networking-visual-feedback` | Visual feedback patterns for server-authoritative multiplayer with client-side prediction | Multiplayer VFX |
| `ta-input-validation` | Player input validation testing patterns for WASD, mouse, and touch controls | Control testing |

---

## QA Skills (qa- prefix)

| Skill | Description | Use When |
|-------|-------------|----------|
| `qa-browser-testing` | Playwright MCP for visual and functional validation | All validation |
| `qa-code-review` | Code quality review before validation. Check for @ts-ignore, any types, anti-patterns | Before validation |
| `qa-gameplay-testing` | Browser-based game control and E2E testing using Playwright MCP | Gameplay features |
| `qa-multiplayer-testing` | Multiplayer testing with multi-client browser contexts for server-authoritative validation | Multiplayer features |
| `qa-reporting-bug-reporting` | Bug report format and documentation for failed validations | Failed validations |
| `qa-validation-asset` | Comprehensive asset validation for Vite 6 and React Three Fiber projects | Asset validation |
| `qa-validation-workflow` | Full validation workflow for QA agent - automated checks and browser testing | QA validation |
| `qa-visual-testing` | Visual regression testing and image-based validation using Vision MCP and Playwright | Visual validation |
| `qa-workflow` | Complete QA workflow - worktree testing, validation flow, browser testing, server-authoritative checks, merge protocol | QA process |

---

## PM Skills (pm- prefix)

### Organization

| Skill | Description | Use When |
|-------|-------------|----------|
| `pm-organization-task-selection` | Priority algorithm for selecting next PRD task based on category, dependencies, risk | Task assignment |
| `pm-organization-task-research` | PM task research - pre-assignment codebase research | Before task assignment |
| `pm-organization-scale-adaptive` | 0-4 task planning for small PRDs | 0-4 tasks in PRD |
| `pm-organization-prd-reorganization` | Extract and reorganize PRD tasks based on retrospectives | After retrospectives |

### Improvement

| Skill | Description | Use When |
|-------|-------------|----------|
| `pm-improvement-self-improvement` | Systematic improvement of PM agent's own coordination skills during retrospective | During retrospectives |
| `pm-improvement-skill-research` | MCP-based skill improvement during retrospective - research and update agent skills | During retrospectives |

### Planning

| Skill | Description | Use When |
|-------|-------------|----------|
| `pm-planning-test-planning` | Test planning specialist - collaborate with QA and Game Designer to create comprehensive test plans | Before QA validation |

### Retrospective

| Skill | Description | Use When |
|-------|-------------|----------|
| `pm-retrospective-facilitation` | Facilitate file-based retrospective after task completion with worker agents | After task completion |
| `pm-retrospective-playtest-session` | Request and process playtest session from Game Designer after retrospective | After retrospective |

### Validation

| Skill | Description | Use When |
|-------|-------------|----------|
| `pm-validation-architecture` | Detect and validate client-authoritative vs server-authoritative architecture gaps | Before implementation |

### Configuration

| Skill | Description | Use When |
|-------|-------------|----------|
| `pm-configuration-vite-assets` | Vite 6 asset configuration patterns for React Three Fiber projects | Asset coordination |
| `pm-configuration-asset-coordination` | PM coordination strategies for asset-related development in Vite 6 projects | TA collaboration |

### Workflow

| Skill | Description | Use When |
|-------|-------------|----------|
| `pm-workflow` | Core PM workflow - task selection, assignment, coordination, retrospectives | PM coordination |

---

## Game Designer Skills (gd- prefix)

| Skill | Description | Use When |
|-------|-------------|----------|
| `gd-gdd-creation` | Game Design Document creation and structure | Creating GDD |
| `gd-design-character` | Character and class design documentation | Designing characters |
| `gd-design-game-loop` | Core gameplay loop design documentation | Designing game loop |
| `gd-design-level` | Map and level design documentation | Designing levels |
| `gd-design-mechanic` | Game mechanics documentation and design | Designing mechanics |
| `gd-design-weapon` | Weapon and item design documentation | Designing weapons |
| `gd-assets-impact-analysis` | Analyzing asset impact on gameplay and player experience | Before requesting assets |
| `gd-thermite-integration` | Integration with thermite-design skill for structured game design sessions | Design discussions |
| `gd-validation-playtest` | Playwright-based game playtesting and design validation | Playtesting |

---

## Shared Skills (shared- prefix)

| Skill | Description | Use When |
|-------|-------------|----------|
| `shared-ralph-core` | Core Ralph Orchestra concepts | All agents |
| `shared-ralph-coordinator` | PM coordinator in event-driven multi-agent mode | PM coordination |
| `shared-ralph-coordinator-single` | PM coordinator in single-agent orchestration mode | PM coordination |
| `shared-ralph-event-protocol` | Event-driven messaging | Event-driven mode |
| `shared-ralph-handoff` | Handoff protocol for single-agent orchestration mode | Sequential mode |
| `shared-ralph-hitl` | Single iteration mode for learning the flow before going AFK | Learning |
| `shared-ralph-router` | Routes to appropriate Ralph skills based on agent role and task signals | Skill routing |
| `shared-ralph-worker` | Worker pool architecture - agents complete work → commit → update status → send message → exit | Worker lifecycle |
| `shared-ralph-worker-single` | Single-agent orchestration mode worker | Sequential workers |
| `shared-ralph-worker-techartist` | Tech Artist worker loop - execute visual asset tasks assigned by coordinator | TA worker |
| `shared-ralph-worker-gamedesigner` | Game Designer worker for event-driven orchestration | GD worker |
| `shared-worker-protocol` | Worker pool architecture with watchdog orchestrator | All workers |
| `shared-worker-worktree` | Git worktree setup and management for parallel agent development | Parallel work |
| `shared-worker-task-memory` | Task memory management for retrospective contributions | Retrospectives |
| `shared-worker-retrospective` | Retrospective contribution format for Developer, Tech Artist, QA, and Game Designer worker agents | Retrospectives |
| `shared-validation-feedback-loops` | Type-check, lint, test, build validation sequence | Before commits |
| `shared-file-permissions` | File read/write permissions for all Ralph agents | All agents |
| `shared-atomic-updates` | Atomic file update patterns to prevent corruption | File operations |
| `shared-auxiliary-scripts` | Auxiliary script management rules for Ralph agents | Script management |
| `shared-message-handling` | Pending message delivery and processing for Ralph agents - watchdog restart, message reading | Message handling |
| `shared-message-acknowledgment` | Message acknowledgment protocol for worker agents - confirm message receipt to PM | Worker protocol |
| `shared-heartbeat-protocol` | Heartbeat update protocol for Ralph agents - when/how to update prd.json.agents | Status updates |
| `shared-context-management` | Context window auto-reset procedures for Ralph agents | Context management |
| `shared-cancel-ralph` | Cancel active Ralph loop and preserve progress | Stopping loop |

---

## Routing Skills

| Skill | Description | Use When |
|-------|-------------|----------|
| `r3f-router` | Routes to appropriate R3F skills based on task requirements | R3F tasks |

---

## Special Skills

| Skill | Description | Use When |
|-------|-------------|----------|
| `thematic-doc-generator` | Generate comprehensive, publication-quality technical manuals with thematic storytelling using multi-agent orchestration | Themed documentation |
| `developer-workflow` | Complete Developer workflow - worktree setup, task research, skill invocation, implementation flow, feedback loops | Developer agent |
| `techartist-workflow` | Complete Tech Artist workflow - worktree setup, asset creation flow, visual testing, screenshot verification, feedback loops | Tech Artist agent |
| `qa-workflow` | Complete QA workflow - worktree testing, validation flow, browser testing, server-authoritative checks, merge protocol | QA agent |
| `pm-workflow` | Complete PM workflow - task assignment, retrospective orchestration, PRD management | PM agent |
| `gamedesigner-workflow` | Complete Game Designer workflow - skill invocation protocol, GDD creation, playtest flow | Game Designer agent |
| `ralph` | Core Ralph Orchestra skill with complete instructions | Starting Ralph |
| `ralph-prd-starter` | Project-agnostic agent setup wizard for Ralph Orchestra with Quick Start, Standard, and Expert modes | Initial setup |
| `glm-plan-usage:usage-query` | Query GLM Coding Plan usage statistics for the current account | Usage queries |

---

## See Also

- [Wizard Presets](wizard-presets.md) - Preset documentation
- [Wizard Sub-Agent Catalog](wizard-subagent-catalog.md) - Sub-agent catalog
- [../.claude/skills/ralph-prd-starter/SKILL.md](../.claude/skills/ralph-prd-starter/SKILL.md) - Wizard skill documentation
