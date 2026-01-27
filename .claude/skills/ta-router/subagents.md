# Tech Artist Sub-Agents

Specialized agents for visual asset tasks.

## Catalog

| Sub-Agent                             | Purpose                           | When to Use               |
| ------------------------------------- | --------------------------------- | ------------------------- |
| `techartist-asset-researcher`         | Pre-creation asset discovery      | Before creating any asset |
| `techartist-asset-creator`            | General 3D/2D asset creation      | Creating models, textures |
| `techartist-shader-compiler`          | GLSL/TSL shader development       | Writing custom shaders    |
| `techartist-particle-system-designer` | GPU particle systems              | Particle effects          |
| `techartist-visual-validator`         | Visual quality review (read-only) | Art review                |
| `techartist-visual-tester`            | Browser visual regression         | E2E visual tests          |
| `techartist-performance-profiler`     | GPU/draw call analysis            | Performance issues        |
| `techartist-code-quality`             | TypeScript/lint checks            | Before commit             |

## Invocation Pattern

### Basic Invocation

```typescript
Task('techartist-{subagent-name}', {
  prompt: 'Detailed task description...',
  model: 'sonnet', // Optional: haiku for quick tasks, sonnet for complex
});
```

### With Context Injection

```typescript
Task('techartist-asset-creator', {
  prompt: `
    Task: ${taskId}
    Category: ${category}
    Acceptance Criteria:
    - ${criteria1}
    - ${criteria2}

    GDD Art Direction:
    - Color palette: ${colors}
    - Style: ${style}
  `,
  model: 'sonnet',
});
```

## Sub-Agent Details

### techartist-asset-researcher

**Purpose:** Reviews `src/assets/` before creating new assets to prevent duplication.

**When to Use:**

- Before creating ANY new asset
- When unsure if similar asset exists
- When starting a new asset category

**Typical Prompt:**

```
Research existing assets for:
- Task: vis-002 (Vehicle PBR materials)
- Category: visual

Search src/assets/ for:
1. Similar materials (car, vehicle, paint)
2. Relevant texture patterns
3. Naming conventions used

Return:
- Existing similar assets (with paths)
- Recommended file path for new asset
- Asset naming pattern
```

**Returns:**

- Existing similar assets (with paths)
- Recommended file paths
- Asset naming conventions

---

### techartist-asset-creator

**Purpose:** Creates 3D models, textures, and visual assets following GDD specifications.

**When to Use:**

- Creating 3D models (characters, vehicles, props)
- Generating textures (materials, patterns)
- Building shader materials

**Related Skills:**

- `Skill("ta-r3f-fundamentals")` - Scene composition
- `Skill("ta-r3f-materials")` - Material setup
- `Skill("ta-shader-development")` - Custom shaders

**Typical Prompt:**

```
Create asset for:
- Task: vis-003 (Character model)
- Category: character
- GDD Style: Stylized, low-poly

Specifications:
- Poly count: < 5000
- Textures: Color map, normal map
- Animation: Idle, run, jump

Output:
- src/assets/models/character/hero.glb
- src/components/assets/CharacterModel.tsx
```

---

### techartist-shader-compiler

**Purpose:** Develops GLSL/TSL shaders with proper vertex/fragment structure and Three.js integration.

**When to Use:**

- Writing custom shader materials
- Implementing visual effects
- Creating SDF-based geometry

**Related Skills:**

- `Skill("ta-shader-sdf")` - SDF patterns
- `Skill("ta-r3f-fundamentals")` - R3F integration

**Typical Prompt:**

```
Create shader for:
- Task: vis-005 (Water surface)
- Effect: Gerstner waves with foam

Requirements:
- Animated waves (time-based)
- Foam at wave peaks
- Fresnel reflections

Output:
- src/components/shaders/WaterMaterial.tsx
- Vertex and fragment shaders
- TypeScript wrapper with uniforms
```

**Deliverables:**

- Vertex/fragment shader code
- Three.js/R3F integration
- Uniform declarations
- TypeScript type definitions

---

### techartist-particle-system-designer

**Purpose:** Creates GPU-accelerated particle effects using instanced rendering, texture atlases, and compute shaders.

**When to Use:**

- Creating fire/smoke effects
- Implementing weather systems
- Building magical/sci-fi VFX

**Related Skills:**

- `Skill("ta-vfx-particles")` - Particle patterns
- `Skill("ta-vfx-postfx")` - Post-processing
- `Skill("ta-r3f-performance")` - GPU optimization

**Typical Prompt:**

```
Design particle system for:
- Task: vis-007 (Fire effect)
- Effect: Realistic fire with smoke

Requirements:
- Particle count: 5000+
- GPU instanced rendering
- Additive blending
- Color gradient: white → yellow → orange → red

Output:
- src/components/vfx/FireParticles.tsx
- Particle texture (generated or reference)
- Performance benchmarks
```

**Creates Using:**

- Instanced rendering
- Texture atlases
- Compute shaders (if needed)

---

### techartist-visual-validator

**Purpose:** Read-only review of visual assets against GDD specifications. Does not modify files.

**When to Use:**

- Art review before delivery
- Validating against GDD requirements
- Checking visual consistency

**Typical Prompt:**

```
Review visual asset:
- Task: vis-002
- Asset: src/assets/models/character/hero.glb

Validate against GDD:
- docs/design/gdd/12_characters.md
- docs/design/gdd/1_core_identity.md (colors)

Check:
- [ ] Model loads correctly
- [ ] Colors match palette
- [ ] Scale is correct
- [ ] No obvious visual defects

Report issues only. Do not modify files.
```

**Constraint:** Read-only - never modifies files

---

### techartist-visual-tester

**Purpose:** Automated visual regression testing using Playwright MCP.

**When to Use:**

- E2E visual validation
- Screenshot comparison
- Browser-based testing

**Typical Prompt:**

```
Run visual test for:
- Task: vis-002
- URL: http://localhost:3000 (detect port first if different)

Steps:
1. Detect port: netstat -an | grep LISTEN | grep -E ":(3000|3001|5173|8080)"
2. Navigate to URL with detected port
3. Wait for asset to load
4. Take screenshot: .claude/session/playwright-test/vis-002-asset.png
5. Check console for errors
6. Verify visual quality

Report:
- Screenshot path
- Console errors (if any)
- Visual assessment
```

**Uses MCP:** Playwright browser automation

---

### techartist-performance-profiler

**Purpose:** Analyzes GPU time, draw calls, texture memory, and rendering bottlenecks.

**When to Use:**

- FPS drops below 60
- Targeting mobile optimization
- Debugging performance issues

**Related Skills:**

- `Skill("ta-r3f-performance")` - Optimization patterns

**Typical Prompt:**

```
Profile performance for:
- Task: vis-004 (Foliage system)
- Issue: FPS drops on mobile

Analyze:
- Draw call count
- GPU time per frame
- Texture memory usage
- Polygon count
- Instancing usage

Recommend:
- Optimization opportunities
- LOD implementation points
- Texture compression needs
```

**Analyzes:**

- GPU time
- Draw calls
- Texture memory
- Rendering bottlenecks

---

### techartist-code-quality

**Purpose:** TypeScript/lint validation before commit. Checks for `@ts-ignore` usage, `any` types, and anti-patterns.

**When to Use:**

- Before committing work
- After code changes
- Quality gate validation

**Typical Prompt:**

```
Validate code quality for:
- Task: vis-002
- Files: src/components/assets/VehiclePaint.tsx

Check for:
- [ ] No @ts-ignore (without justification)
- [ ] No any types (without justification)
- [ ] Proper TypeScript types
- [ ] No obvious anti-patterns
- [ ] Follows project conventions

Run:
- npm run type-check
- npm run lint

Report:
- Type check results
- Lint issues
- Recommended fixes
```

**Checks For:**

- `@ts-ignore` usage
- `any` types
- Anti-patterns
- Lint violations

## Workflow Integration

### Standard Workflow

```
1. techartist-asset-researcher
   → Check for existing assets

2. techartist-asset-creator OR techartist-shader-compiler
   → Create the asset

3. techartist-visual-validator
   → Review against GDD

4. techartist-code-quality
   → Validate TypeScript/lint

5. techartist-performance-profiler (if needed)
   → Check performance

6. techartist-visual-tester
   → E2E validation
```

### Quick Reference for Sub-Agent Selection

| Need                    | Sub-Agent                  |
| ----------------------- | -------------------------- |
| Find existing assets    | `asset-researcher`         |
| Create 3D model/texture | `asset-creator`            |
| Write GLSL/TSL shader   | `shader-compiler`          |
| Build particle system   | `particle-system-designer` |
| Review visual quality   | `visual-validator`         |
| Test in browser         | `visual-tester`            |
| Profile performance     | `performance-profiler`     |
| Check code quality      | `code-quality`             |
