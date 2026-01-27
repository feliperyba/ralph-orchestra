---
name: pm-router
description: Routes PM coordinator to appropriate skills and sub-agents based on workflow phase, task category, and signal keywords. Use when starting PM session, assigning tasks, running retrospectives, or managing PRD.
category: coordination
---

# PM Skill Router

> "Right skill for the right phase at the right time."

## Route by Workflow Phase

| Phase                  | Primary Skills                                                       | Sub-Agents                     |
| ---------------------- | -------------------------------------------------------------------- | ------------------------------ |
| **Startup**            | `pm-organization-scale-adaptive`                                     | -                              |
| **Task Selection**     | `pm-organization-task-selection`, `pm-organization-task-research`    | `pm-task-researcher`           |
| **Test Planning**      | `pm-planning-test-planning`                                          | `pm-test-planner`              |
| **Assignment**         | (use selected skills)                                                | -                              |
| **Retrospective**      | `pm-retrospective-facilitation`, `pm-retrospective-playtest-session` | `pm-retrospective-facilitator` |
| **PRD Update**         | `pm-organization-prd-reorganization`                                 | `pm-prd-organizer`             |
| **Skill Research**     | `pm-improvement-skill-research`, `pm-improvement-self-improvement`   | `skill-researcher`             |
| **Architecture Check** | `pm-validation-architecture`                                         | `pm-architecture-validator`    |

## Route by Task Category

| Category             | Agent      | PM Skills to Load                                                     |
| -------------------- | ---------- | --------------------------------------------------------------------- |
| `architectural`      | developer  | `pm-organization-task-research`, `pm-validation-architecture`         |
| `integration`        | developer  | `pm-organization-task-research`                                       |
| `functional`         | developer  | `pm-organization-task-research`                                       |
| `visual`             | techartist | `pm-configuration-asset-coordination`, `pm-configuration-vite-assets` |
| `shader`             | techartist | `pm-configuration-asset-coordination`                                 |
| `polish`             | techartist | `pm-configuration-asset-coordination`                                 |
| Any with multiplayer | developer  | `pm-validation-architecture`                                          |

## Route by Signal Keywords

| Signal in Task                                       | Route To                              |
| ---------------------------------------------------- | ------------------------------------- |
| "asset", "model", "fbx", "texture", "gltf"           | `pm-configuration-asset-coordination` |
| "vite", "public/", "src/assets/"                     | `pm-configuration-vite-assets`        |
| "multiplayer", "server", "colyseus", "authoritative" | `pm-validation-architecture`          |
| "test", "e2e", "validation", "acceptance"            | `pm-planning-test-planning`           |
| "gdd", "design", "mechanic"                          | `pm-organization-prd-reorganization`  |

## All PM Skills

| Skill                                 | Purpose                               | Phase          |
| ------------------------------------- | ------------------------------------- | -------------- |
| `pm-organization-scale-adaptive`      | Adjust planning depth by PRD size     | Startup        |
| `pm-organization-task-selection`      | Priority algorithm for task selection | Task Selection |
| `pm-organization-task-research`       | Codebase research before assignment   | Task Selection |
| `pm-planning-test-planning`           | Collaborative test planning           | Test Planning  |
| `pm-configuration-asset-coordination` | Asset coordination for parallel work  | Assignment     |
| `pm-configuration-vite-assets`        | Vite 6 asset patterns                 | Assignment     |
| `pm-validation-architecture`          | Server-authoritative validation       | Assignment     |
| `pm-retrospective-facilitation`       | Worker retrospective orchestration    | Retrospective  |
| `pm-retrospective-playtest-session`   | Game Designer playtest coordination   | Retrospective  |
| `pm-organization-prd-reorganization`  | GDD-to-PRD task extraction            | PRD Update     |
| `pm-improvement-skill-research`       | Multi-agent skill improvements        | Skill Research |
| `pm-improvement-self-improvement`     | PM self-improvement                   | Skill Research |

## Sub-Agents (via Task tool)

| Sub-Agent                      | Model   | Purpose                                  |
| ------------------------------ | ------- | ---------------------------------------- |
| `pm-task-researcher`           | Haiku   | Codebase research before task assignment |
| `pm-test-planner`              | Inherit | Test planning with QA+GD                 |
| `pm-retrospective-facilitator` | Inherit | Retrospective orchestration              |
| `pm-prd-organizer`             | Inherit | PRD reorganization                       |
| `pm-architecture-validator`    | Haiku   | Architecture gap detection               |
| `skill-researcher`             | Haiku   | Skill improvement research               |

## Priority Order (Reference)

| Category        | Priority    | Examples                               |
| --------------- | ----------- | -------------------------------------- |
| `architectural` | 1 (Highest) | State stores, API design, core systems |
| `integration`   | 2           | API integration, third-party services  |
| `functional`    | 3           | Gameplay mechanics, features           |
| `visual`        | 4           | 3D models, materials, textures         |
| `shader`        | 4           | Shaders, visual effects                |
| `polish`        | 5 (Lowest)  | UI styling, visual refinement          |

## Category to Agent Mapping (Reference)

| Category        | Default Agent |
| --------------- | ------------- |
| `architectural` | developer     |
| `functional`    | developer     |
| `integration`   | developer     |
| `visual`        | techartist    |
| `shader`        | techartist    |
| `polish`        | techartist    |

## Usage

Load this router at PM startup:

```
Skill("pm-router")
```

Then use `pm-workflow` for the full orchestration.

## References

- [pm-workflow](../pm-workflow/SKILL.md) - Full PM workflow
- [shared-core](../shared-core/SKILL.md) - Core orchestration concepts
- [shared-messaging](../shared-messaging/SKILL.md) - Event-driven messaging
