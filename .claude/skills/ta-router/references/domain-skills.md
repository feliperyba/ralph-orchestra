# Tech Artist Domain Skills

Complete catalog of Tech Artist domain skills.

## By Category

### architectural

| Skill | Purpose |
|-------|---------|
| `ta-r3f-fundamentals` | R3F core patterns, scene composition, game loop |
| `ta-validation-typescript` | TypeScript best practices for game development |

### visual

| Skill | Purpose |
|-------|---------|
| `ta-r3f-materials` | Material selection, shaders, visual effects |
| `ta-shader-sdf` | Signed Distance Functions for shader-based 3D primitives |
| `ta-vfx-postfx` | Post-processing effects with R3F |

### shader

| Skill | Purpose |
|-------|---------|
| `ta-shader-development` | GLSL/TSL shader creation, compilation, testing |

### vfx

| Skill | Purpose |
|-------|---------|
| `ta-vfx-particles` | GPU particle systems for visual effects |
| `ta-foliage-instancing` | GPU instanced grass and vegetation with wind animation |

### asset

| Skill | Purpose |
|-------|---------|
| `ta-assets-workflow` | Asset creation pipeline and integration workflow |
| `ta-assets-pipeline-optimization` | 3D asset optimization and pipeline management |
| `ta-assets-workflow-vite-6` | Vite 6 asset handling and optimization |

### performance

| Skill | Purpose |
|-------|---------|
| `ta-r3f-performance` | Performance optimization techniques for R3F and Three.js |
| `ta-r3f-physics` | Physics integration with Rapier for R3F game development |

### ui

| Skill | Purpose |
|-------|---------|
| `ta-ui-polish` | UI and visual polish checklist for game presentation |
| `ta-ui-debug-helpers` | Debug visualization helpers using drei and Three.js |

### camera

| Skill | Purpose |
|-------|---------|
| `ta-camera-tps` | Third-person shooter camera implementation |

### networking

| Skill | Purpose |
|-------|---------|
| `ta-networking-visual-feedback` | Visual feedback for server-authoritative multiplayer |

### input

| Skill | Purpose |
|-------|---------|
| `ta-input-validation` | Player input validation testing patterns |

### specialized

| Skill | Purpose |
|-------|---------|
| `ta-water-shader` | Gerstner wave simulation with foam and caustics |
| `ta-paint-territory` | Splatoon-style paint system with RenderTexture tracking |
| `ta-procedural-terrain` | Procedural terrain generation algorithms (Perlin, Simplex, Diamond-Square, caldera) |

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

**Rule:** Always load `ta-r3f-fundamentals` before other TA skills for R3F tasks.

## Common Combinations

| Task Type | Skills |
|-----------|--------|
| Shader Development | `ta-r3f-fundamentals` + `ta-shader-development` |
| VFX Creation | `ta-r3f-fundamentals` + `ta-vfx-particles` + `ta-vfx-postfx` |
| Asset Pipeline | `ta-r3f-fundamentals` + `ta-assets-workflow` |
| Material Creation | `ta-r3f-fundamentals` + `ta-r3f-materials` |
| Terrain System | `ta-r3f-fundamentals` + `ta-terrain-mesh` + `ta-water-shader` |
| Procedural Terrain | `ta-procedural-terrain` + `ta-terrain-mesh` (NEW - research-based algorithms) |
| Foliage System | `ta-r3f-fundamentals` + `ta-foliage-instancing` |
| TPS Camera | `ta-r3f-fundamentals` + `ta-camera-tps` |
| Paint System | `ta-r3f-fundamentals` + `ta-paint-territory` |
| Physics Setup | `ta-r3f-fundamentals` + `ta-r3f-physics` |
| Performance Work | `ta-r3f-performance` + `ta-assets-pipeline-optimization` |
