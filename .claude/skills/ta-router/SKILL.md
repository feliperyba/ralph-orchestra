---
name: ta-router
description: Routes Tech Artist to domain skills based on task category and signal keywords. Use when starting Tech Artist tasks to determine which skills to load.
category: routing
---

# Tech Artist Skill Router

> "Right skill for the right visual task."

## Quick Route

### By Task Category

| Category | Skills |
|----------|--------|
| `architectural` | `ta-r3f-fundamentals`, `ta-validation-typescript` |
| `visual` | `ta-r3f-materials`, `ta-shader-sdf`, `ta-vfx-postfx` |
| `shader` | `ta-shader-development`, `ta-shader-sdf` |
| `vfx` | `ta-vfx-particles`, `ta-vfx-postfx` |
| `asset` | `ta-assets-workflow`, `ta-assets-pipeline-optimization` |
| `performance` | `ta-r3f-performance`, `ta-r3f-physics` |
| `ui` | `ta-ui-polish`, `ta-ui-debug-helpers` |
| `camera` | `ta-camera-tps` |
| `networking` | `ta-networking-visual-feedback` |

### By Signal Keywords

| Signal | Route To |
|--------|----------|
| "shader", "glsl", "tsl" | `ta-shader-development`, `ta-shader-sdf` |
| "particle", "gpu", "instanced" | `ta-vfx-particles`, `ta-foliage-instancing` |
| "postfx", "bloom", "effect" | `ta-vfx-postfx` |
| "material", "pbr", "texture" | `ta-r3f-materials` |
| "physics", "collision", "rapier" | `ta-r3f-physics` |
| "water", "ocean", "gerstner" | `ta-water-shader` |
| "foliage", "grass", "vegetation" | `ta-foliage-instancing` |
| "paint", "territory", "splat" | `ta-paint-territory` |

### Common Combinations

| Task Type | Skills |
|-----------|--------|
| Shader Development | `ta-r3f-fundamentals` + `ta-shader-development` |
| VFX Creation | `ta-r3f-fundamentals` + `ta-vfx-particles` + `ta-vfx-postfx` |
| Asset Pipeline | `ta-r3f-fundamentals` + `ta-assets-workflow` |
| Material Creation | `ta-r3f-fundamentals` + `ta-r3f-materials` |
| Terrain System | `ta-r3f-fundamentals` + `ta-shader-sdf` + `ta-water-shader` |

## Routing Protocol

```
1. Analyze task signals
   -> task.category
   -> task.title keywords
   -> task.acceptanceCriteria keywords

2. Determine skill sequence
   -> Always start with ta-r3f-fundamentals for R3F tasks
   -> Add domain-specific skills based on signals

3. Load skills
   -> Skill("ta-r3f-fundamentals")
   -> Skill("{domain-skill-1}")
   -> Skill("{domain-skill-2}")
```

## Research Guides

**Before creating assets, check:**

| Topic | Guide | When to Use |
|-------|-------|-------------|
| Terrain shaders | `docs/research/terrain-shader-research.md` | SDF terrain, heightmaps |
| Paint effects | `docs/research/paint-shader-research.md` | Wet paint, splat decals |
| Weapons | `docs/research/weapons-loading-research.md` | Weapon models, accessories |
| Characters | `docs/research/character-models-research.md` | Character skins, animations |

## GDD Research

**Before creating, always read:**

- `docs/design/gdd/1_core_identity.md` - Art direction, colors
- `docs/design/gdd/14_audio_visual.md` - Shaders, VFX, materials
- `docs/design/gdd/12_characters.md` - Character models
- `docs/design/gdd/8_ui_hud_system.md` - UI styling

## Skill Hierarchy

```
                    ta-r3f-fundamentals (BASE)
                              |
        +---------------------+---------------------+
        |                     |                     |
   ta-r3f-materials     ta-r3f-physics       ta-r3f-performance
        |                     |                     |
   ta-shader-*          ta-camera-tps         ta-vfx-*
   ta-ui-*
```

**Rule:** Always load `ta-r3f-fundamentals` before other TA skills.

## Sub-Agents

For sub-agent catalog, see: [subagents.md](subagents.md)

## Domain Skills

For complete skill catalog, see: [domain-skills.md](domain-skills.md)

## See Also

- [ta-orchestration](../ta-orchestration/SKILL.md) - Workflow execution
- [AGENT.md](../../agents/techartist/AGENT.md) - Agent role and permissions
