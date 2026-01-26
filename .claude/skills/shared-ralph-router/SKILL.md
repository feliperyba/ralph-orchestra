---
name: shared-ralph-router
description: Routes to appropriate Ralph skills based on agent role and task signals. Use proactively to determine which skills to load for a given task or agent.
category: orchestration
tags: [routing, skills, agent, coordination]
dependencies: [shared-ralph-core]
---

# Ralph Skill Router

> "Right skill for the right agent at the right time."

## When to Use This Skill

Use **when**:
- Determining which skills to load for an agent
- Routing tasks to appropriate domain skills
- Identifying skill dependencies

Use **proactively**:
- At agent startup to load appropriate skills
- At task assignment to determine required skills

---

## Quick Start

<examples>
Example 1: Route by agent role
```
PM → task-selection, retrospective, scale-adaptive
Developer → r3f-fundamentals, feedback-loops, typescript
QA → validation-workflow, browser-testing, bug-reporting
TechArtist → r3f-materials, shader-sdf, postfx-effects
```

Example 2: Route by task category
```
architectural → typescript-patterns, r3f-fundamentals
integration → domain-specific (physics, materials)
visual → r3f-materials, shader-sdf, postfx
shader → shader-sdf, glsl, gpu-cost-optimizer
```

Example 3: Route by signal keywords
```
"physics, collision" → r3f-physics
"shader, material" → r3f-materials
"performance, fps" → r3f-performance
"component, scene" → r3f-fundamentals
```
</examples>

---

## Routing by Agent Role

| Agent | Core Skills |
|-------|-------------|
| **PM** | `task-selection`, `retrospective`, `scale-adaptive` |
| **Developer** | `r3f-fundamentals`, `feedback-loops`, `typescript-patterns` |
| **QA** | `validation-workflow`, `browser-testing`, `bug-reporting` |
| **GameDesigner** | `gdd-creation`, `thermite-integration`, `mechanic-design` |
| **TechArtist** | `r3f-fundamentals`, `r3f-materials`, `shader-sdf`, `postfx` |

---

## Routing by Task Category

| Category | Developer Skills | QA Focus | TechArtist Skills |
|-----------|------------------|----------|-------------------|
| `architectural` | `typescript-patterns`, `r3f-fundamentals` | Full validation | `typescript-patterns` |
| `integration` | Domain-specific | Cross-browser | `r3f-materials` |
| `functional` | `r3f-fundamentals`, `feedback-loops` | Acceptance criteria | - |
| `visual` | - | Visual QA | `r3f-materials`, `postfx` |
| `shader` | - | Shader testing | `shader-sdf`, `glsl` |
| `effects` | - | Effects testing | `particles-gpu`, `postfx` |

---

## Signal Keyword Routing

| Signal | Route To |
|--------|----------|
| "physics", "collision", "rigid body" | `r3f-physics` |
| "shader", "material", "texture" | `r3f-materials` |
| "performance", "fps", "optimization" | `r3f-performance` |
| "component", "scene", "canvas" | `r3f-fundamentals` |
| "type", "interface", "generic" | `typescript-patterns` |

---

## Common Skill Combinations

| Purpose | Combination |
|---------|--------------|
| Game feature | `r3f-fundamentals + r3f-physics + feedback-loops` |
| Visual polish | `r3f-fundamentals + r3f-materials + r3f-performance` |
| Performance | `r3f-performance + r3f-materials` |
| New component | `r3f-fundamentals + typescript-patterns + code-quality` |

---

## Skill Dependencies

```
r3f-materials ──────┐
                    ├──▶ r3f-fundamentals
r3f-physics ────────┤
                    │
r3f-performance ────┘

validation-workflow ──┬──▶ browser-testing
                      └──▶ bug-reporting

retrospective ────────────▶ skill-improvement
```

---

## Related Skills

| Skill | Purpose |
|-------|---------|
| `shared-ralph-core` | Session structure |
| `shared-validation-feedback-loops` | Quality gates |
