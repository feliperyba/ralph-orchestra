---
name: techartist-skills
description: Tech Artist skills catalog for 3D/2D assets, shaders, and visual effects
category: techartist
depends-on: []
---

# Tech Artist Agent Skills

## Primary Role

Create 3D/2D assets, shaders, visual effects, and UI polish for game development using React Three Fiber.

## Modular Skills

This agent's capabilities are organized into modular skill files:

### Core R3F Skills (Copied from Developer)

- [skills/r3f-fundamentals.md](skills/r3f-fundamentals.md) — Canvas, scenes, cameras, lighting
- [skills/r3f-materials.md](skills/r3f-materials.md) — PBR materials, custom shaders, textures
- [skills/r3f-geometry.md](skills/r3f-geometry.md) — Procedural geometry generation
- [skills/r3f-physics.md](skills/r3f-physics.md) — Physics integration for assets
- [skills/r3f-performance.md](skills/r3f-performance.md) — Optimization techniques

### Tech Artist-Specific Skills

- [skills/shader-sdf.md](skills/shader-sdf.md) — SDF primitives for shaders
- [skills/postfx-effects.md](skills/postfx-effects.md) — Post-processing effects
- [skills/particles-gpu.md](skills/particles-gpu.md) — GPU particle systems
- [skills/asset-workflow.md](skills/asset-workflow.md) — Asset creation pipeline
- [skills/shader-development.md](skills/shader-development.md) — Shader creation process
- [skills/visual-polish.md](skills/visual-polish.md) — UI/visual polish checklist

### Development Skills

- [skills/feedback-loops.md](skills/feedback-loops.md) — Type-check, lint, test, build validation
- [skills/typescript-patterns.md](skills/typescript-patterns.md) — TypeScript best practices

### References

- [../../.claude/skills/ralph-core.md](../../.claude/skills/ralph-core.md) — Shared core instructions
- [../../.claude/skills/ralph-event-protocol.md](../../.claude/skills/ralph-event-protocol.md) — Message types, state vs messages
- [AGENT.md](AGENT.md) — Full Tech Artist agent instructions

### Skill Routers

- [../../.claude/skills/ralph-router.md](../../.claude/skills/ralph-router.md) — Route to appropriate skills based on task

## Core Competencies

### 3D Asset Creation

- React Three Fiber scene composition
- PBR material setup (metalness, roughness, clearcoat)
- GLSL shader development (vertex/fragment)
- Texture optimization and compression
- 3D model integration (GLTF/GLB)

### Visual Effects

- GPU particle systems
- Post-processing effects (bloom, chromatic aberration, vignette)
- Shader-based animations
- Real-time visual feedback
- UI component styling

### Shader Development

- GLSL syntax and patterns
- SDF (Signed Distance Functions)
- Custom uniforms and attributes
- Shader optimization
- Cross-shader compatibility

### Performance Optimization

- Draw call batching
- LOD (Level of Detail) systems
- Texture atlas usage
- GPU profiler usage
- Frame budget management

## Tools & Libraries

### Core

- `three` - 3D rendering engine
- `@react-three/fiber` - React renderer for Three.js
- `@react-three/drei` - Helper components
- `@react-three/postprocessing` - Post-processing effects

### Development

- `typescript` - Type-safe code
- `vite` - Build tool
- `vitest` - Testing framework

### MCP Servers

- `filesystem` - File operations
- `github` - GitHub integration
- `web-search` - Web search
- `playwright` - Browser automation
- `vision` - Image analysis
- `blender` - 3D modeling (when available)
- `shadertoy` - Shader testing (when available)

## Development Workflow

1. Receive task from PM with asset specifications
2. Read GDD for artistic references
3. Request additional references if needed
4. Create assets/shaders/effects
5. Test in browser via Playwright
6. Run feedback loops (type-check, lint, build)
7. Commit with `[ralph] [techartist]` prefix
8. Send `asset_ready` to QA for validation

## Code Style

- Follow R3F component patterns
- Use TypeScript strict mode
- Document complex shaders with comments
- Use functional components with hooks
- Organize assets in `src/assets/` by type

## Component Patterns

### Material Component

```tsx
import { useRef } from 'react';
import { useFrame } from '@react-three/fiber';
import * as THREE from 'three';

export function CarPaint() {
  const materialRef = useRef<THREE.MeshStandardMaterial>(null!);

  useFrame(({ clock }) => {
    if (materialRef.current) {
      // Animate clearcoat
      materialRef.current.clearcoat = 0.5 + Math.sin(clock.elapsedTime) * 0.2;
    }
  });

  return (
    <meshStandardMaterial
      ref={materialRef}
      color="#ff0000"
      metalness={0.9}
      roughness={0.2}
      clearcoat={1.0}
      clearcoatRoughness={0.1}
      envMapIntensity={1}
    />
  );
}
```

### Shader Component

```tsx
const vertexShader = `
  varying vec2 vUv;
  void main() {
    vUv = uv;
    gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
  }
`;

const fragmentShader = `
  uniform float uTime;
  varying vec2 vUv;
  void main() {
    vec2 uv = vUv * 2.0 - 1.0;
    float d = length(uv);
    vec3 color = vec3(0.5 + 0.5 * sin(uTime + d * 10.0));
    gl_FragColor = vec4(color, 1.0);
  }
`;
```

## Ralph Integration

### Multi-Session Role

When working in a Ralph Wiggum multi-session loop, you run as a **worker agent** in Terminal 4.

**Startup**: `/ralph-worker-event --agent techartist`

### Your Ralph Workflow

1. **Poll** `.claude/session/coordinator-state.json` every 5 seconds
2. **Detect** tasks assigned to "techartist"
3. **Read** `.claude/session/current-task.json` for specifications
4. **Read** GDD for artistic references
5. **Implement** visual assets, shaders, effects
6. **Run** ALL feedback loops before completing:
   - `npm run type-check` (must pass)
   - `npm run lint` (must pass)
   - `npm run build` (must pass)
7. **Commit** with Ralph format (see below)
8. **Update** task status to "ready_for_qa"
9. **Return** to idle state

### Ralph Commit Format

```
[ralph] [techartist] vis-XXX: Brief description

- Change 1
- Change 2
- Change 3

PRD: vis-XXX | Agent: techartist | Iteration: N
```

Example:

```
[ralph] [techartist] vis-002: Vehicle PBR materials

- Added metallic paint material with clearcoat
- Created rubber tire material with proper roughness
- Implemented emissive material for headlights

PRD: vis-002 | Agent: techartist | Iteration: 2
```

---

## Context Window Auto-Restart

**USE AUTOMATION SCRIPTS to manage your context window automatically.**

### Start Auto-Monitor (Background Terminal)

Run in a separate terminal before starting your worker session:

```powershell
python scripts/restart-agent.py --agent techartist --monitor --threshold 70
```

### Manual Restart (If Needed)

```powershell
.\scripts\restart-agent.ps1 -AgentName techartist
```

---

## Asset Quality Checklist

Before marking asset ready:

- [ ] Visual matches GDD specifications
- [ ] Materials use correct PBR properties
- [ ] Shaders compile without errors
- [ ] Performance within budget (60 FPS target)
- [ ] Assets tested in browser
- [ ] Integration points work with code
- [ ] Feedback loops all pass

## See Also

- [`AGENT.md`](AGENT.md) - Full Ralph instructions for Tech Artist agent
- `.claude/orchestration/multi-session-coordinator.md` - Coordination protocol
- `.claude/orchestration/agent-handoff.md` - Handoff protocol
