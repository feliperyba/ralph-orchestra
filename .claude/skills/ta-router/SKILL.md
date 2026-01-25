---
name: ta-router
description: Routes Tech Artist to appropriate skills and sub-agents based on task category, signals, and domain. Use when starting Tech Artist tasks or determining which skills to load.
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

| Signal in Task | Route To |
|----------------|----------|
| "shader", "glsl", "tsl" | `ta-shader-development`, `ta-shader-sdf` |
| "particle", "gpu", "instanced" | `ta-vfx-particles` |
| "postfx", "bloom", "effect" | `ta-vfx-postfx` |
| "material", "pbr", "texture" | `ta-r3f-materials` |
| "physics", "collision", "rapier" | `ta-r3f-physics` |
| "performance", "fps", "optimize" | `ta-r3f-performance` |
| "camera", "tps", "third-person" | `ta-camera-tps` |
| "asset", "model", "fbx", "gltf" | `ta-assets-workflow`, `ta-assets-pipeline-optimization` |
| "vite 6", "?import" | `ta-assets-workflow-vite-6` |

### Common Skill Combinations

| Task Type | Skill Combination |
|-----------|-------------------|
| Shader Development | `ta-r3f-fundamentals` + `ta-shader-development` + `ta-shader-sdf` |
| VFX Creation | `ta-r3f-fundamentals` + `ta-vfx-particles` + `ta-vfx-postfx` + `ta-r3f-performance` |
| Asset Pipeline | `ta-r3f-fundamentals` + `ta-assets-workflow` + `ta-assets-pipeline-optimization` |
| Performance Optimization | `ta-r3f-fundamentals` + `ta-r3f-performance` + `ta-r3f-materials` |
| UI Polish | `ta-r3f-fundamentals` + `ta-ui-polish` + `ta-ui-debug-helpers` |
| Material Creation | `ta-r3f-fundamentals` + `ta-r3f-materials` + `ta-shader-sdf` |

## Skills Inventory

### R3F Development (5 skills)

| Skill | Purpose |
|-------|---------|
| `ta-r3f-fundamentals` | React Three Fiber core patterns for scene composition and game loop |
| `ta-r3f-materials` | Material selection, shaders, and visual effects for R3F |
| `ta-r3f-performance` | Performance optimization techniques for R3F and Three.js |
| `ta-r3f-physics` | Physics integration with Rapier for R3F game development |
| `ta-validation-typescript` | TypeScript best practices for game development |

### Visual Effects (6 skills)

| Skill | Purpose |
|-------|---------|
| `ta-vfx-particles` | GPU particle systems for high-performance visual effects |
| `ta-vfx-postfx` | Post-processing effects with React Three Fiber |
| `ta-shader-sdf` | Signed Distance Functions for shader-based 3D primitives |
| `ta-shader-development` | GLSL/TSL shader creation process and patterns for R3F |
| `ta-ui-polish` | UI and visual polish checklist for game presentation |
| `ta-ui-debug-helpers` | Debug visualization helpers using drei and Three.js |

### Asset Management (3 skills)

| Skill | Purpose |
|-------|---------|
| `ta-assets-workflow` | Asset creation pipeline and integration workflow for Tech Artist |
| `ta-assets-workflow-vite-6` | Vite 6 asset handling and optimization workflow for Tech Artists |
| `ta-assets-pipeline-optimization` | 3D asset optimization and pipeline management for Vite 6 projects |

### Specialized Systems (3 skills)

| Skill | Purpose |
|-------|---------|
| `ta-camera-tps` | Third-person shooter camera implementation patterns with proper player-relative controls |
| `ta-input-validation` | Player input validation testing patterns for WASD, mouse, and touch controls |
| `ta-networking-visual-feedback` | Visual feedback patterns for server-authoritative multiplayer with client-side prediction |

## Sub-Agents Reference

| Sub-Agent | Purpose |
|-----------|---------|
| `techartist-asset-researcher` | Pre-creation asset discovery - reviews existing assets before creating new ones |
| `techartist-asset-creator` | General 3D/2D asset creation following GDD specifications |
| `techartist-shader-compiler` | GLSL/TSL shader development, testing, and compilation |
| `techartist-particle-system-designer` | GPU particle systems design using instancing and compute shaders |
| `techartist-visual-validator` | Visual quality review (read-only) - validates against GDD specifications |
| `techartist-visual-tester` | Browser visual regression testing with Playwright MCP |
| `techartist-performance-profiler` | GPU/draw call analysis and performance bottleneck identification |
| `techartist-code-quality` | TypeScript/lint quality checks before commit |
| `techartist-orchestrator` | Routes tasks to specialist sub-agents based on domain |

**Invocation:** `Task("techartist-{subagent-name}", { prompt: "...", timeout: 300000 })`

## Routing Protocol

### Step 1: Analyze Task Signals

Extract signals from task:
- `task.category` - Primary category indicator
- `task.title` - Contains key terms
- `task.acceptanceCriteria` - Domain-specific requirements

### Step 2: Determine Skill Sequence

```javascript
function getSkillSequence(task) {
  const skills = [];
  const text = `${task.category} ${task.title} ${task.acceptanceCriteria?.join(' ')}`.toLowerCase();

  // Always start with fundamentals for R3F tasks
  if (/r3f|three|visual|shader|vfx|asset|performance|ui|camera/.test(text)) {
    skills.push('ta-r3f-fundamentals');
  }

  // Shader signals
  if (/shader|glsl|tsl|sdf/.test(text)) {
    skills.push('ta-shader-development', 'ta-shader-sdf');
  }

  // VFX signals
  if (/particle|gpu|instanced|vfx/.test(text)) {
    skills.push('ta-vfx-particles');
  }
  if (/postfx|bloom|effect|blur/.test(text)) {
    skills.push('ta-vfx-postfx');
  }

  // Material signals
  if (/material|pbr|texture/.test(text)) {
    skills.push('ta-r3f-materials');
  }

  // Physics signals
  if (/physics|collision|rapier|rigid/.test(text)) {
    skills.push('ta-r3f-physics');
  }

  // Performance signals
  if (/performance|fps|optimize|mobile/.test(text)) {
    skills.push('ta-r3f-performance');
  }

  // Asset signals
  if (/asset|model|fbx|gltf|glb/.test(text)) {
    skills.push('ta-assets-workflow', 'ta-assets-pipeline-optimization');
  }
  if (/vite[ -]?6|\?import/.test(text)) {
    skills.push('ta-assets-workflow-vite-6');
  }

  // UI signals
  if (/ui|polish|presentation|debug/.test(text)) {
    skills.push('ta-ui-polish', 'ta-ui-debug-helpers');
  }

  // Camera signals
  if (/camera|tps|third[ -]?person/.test(text)) {
    skills.push('ta-camera-tps');
  }

  // Networking signals
  if (/network|multiplayer|feedback|prediction/.test(text)) {
    skills.push('ta-networking-visual-feedback');
  }

  // TypeScript validation (always include for code tasks)
  if (/typescript|type|interface/.test(text) || skills.length > 1) {
    skills.push('ta-validation-typescript');
  }

  return [...new Set(skills)]; // Deduplicate
}
```

### Step 3: Load Core Skills First

```markdown
**Core workflow skills (load before domain skills):**

1. `shared/worker-worktree` - Git worktree management
2. `shared/worker-task-memory` - Task memory for retrospectives
3. `ta-router` - This routing skill (already loaded)
```

### Step 4: Load Domain Skills

```markdown
**After core skills, load domain skills from Step 2 output:**

Example for shader task:
1. Skill("ta-r3f-fundamentals")
2. Skill("ta-shader-development")
3. Skill("ta-shader-sdf")
```

### Step 5: Invoke Sub-Agent (if needed)

```markdown
**For complex tasks, use specialized sub-agents:**

- Asset research → `techartist-asset-researcher`
- Shader compilation → `techartist-shader-compiler`
- Particle systems → `techartist-particle-system-designer`
- Visual validation → `techartist-visual-validator`
- Performance analysis → `techartist-performance-profiler`
```

## Skill Dependencies

```
                    ┌─────────────────────────────────┐
                    │   ta-r3f-fundamentals (BASE)    │
                    └─────────────────────────────────┘
                                      │
        ┌─────────────────────────────┼─────────────────────────────┐
        │                             │                             │
        ▼                             ▼                             ▼
┌───────────────┐           ┌───────────────┐           ┌───────────────┐
│ ta-r3f-materials│           │ ta-r3f-physics │           │ ta-r3f-performance│
└───────────────┘           └───────────────┘           └───────────────┘
        │                             │                             │
        ▼                             ▼                             ▼
┌───────────────┐           ┌───────────────┐           ┌───────────────┐
│ ta-shader-*   │           │ ta-camera-tps │           │ ta-vfx-*      │
│ ta-ui-*       │           │               │           │               │
└───────────────┘           └───────────────┘           └───────────────┘

┌───────────────┐           ┌───────────────┐
│ ta-assets-*   │───────────▶│ ta-r3f-fundamentals │
└───────────────┘           └───────────────┘

┌─────────────────────────────────────────────────────┐
│ ta-validation-typescript (standalone)                │
│ Load with any code task                              │
└─────────────────────────────────────────────────────┘
```

**Rule:** Always load `ta-r3f-fundamentals` before any other TA domain skill.

## References

- [techartist-workflow](../techartist-workflow/SKILL.md) - Complete Tech Artist workflow
- [agents/techartist/AGENT.md](../../../agents/techartist/AGENT.md) - Tech Artist agent instructions
- [skills-best-practices](../../../docs/skills-best-practices.md) - Skill creation guidelines
