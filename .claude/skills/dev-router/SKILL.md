---
name: dev-router
description: Developer agent skill router - routes to 31 dev skills by category and signal keywords, manages 5 sub-agents.
category: routing
---

# Developer Skill Router

> "Right skill, right sub-agent, right time."

## When to Use This Skill

Use when:

- Starting any development task
- Deciding which skills to load
- Determining which sub-agent to invoke
- Combining multiple skills for complex features

## Quick Route by Category

| Category             | Skills                                                                                                                                                     | Signal Keywords                                               |
| -------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------- |
| **R3F** (3)          | r3f-fundamentals, r3f-materials, r3f-physics                                                                                                               | scene, canvas, mesh, material, shader, physics, collision     |
| **Multiplayer** (8)  | server-authoritative, colyseus-server, colyseus-state, colyseus-client, prediction-basics, prediction-movement, prediction-shooting, anti-cheat-validation | multiplayer, server, colyseus, network, sync, prediction, lag |
| **Assets** (4)       | audio-loading, model-loading, texture-loading, vite-asset-loading                                                                                          | asset, load, fbx, gltf, audio, sound, texture, image          |
| **Performance** (4)  | performance-basics, instancing, lod-systems, mobile-optimization                                                                                           | fps, slow, optimize, performance, mobile, instance, lod       |
| **Patterns** (4)     | object-pooling, ui-animations, mobile-haptics, coverage-tracking                                                                                           | pool, reuse, animation, haptic, vibration, territory          |
| **TypeScript** (2)   | typescript-basics, typescript-advanced                                                                                                                     | type, interface, generic, utility, infer                      |
| **Validation** (3)   | feedback-loops, browser-testing, quality-gates                                                                                                             | validate, test, type-check, lint, e2e                         |
| **Research** (3)     | codebase-exploration, gdd-reading, pattern-finding                                                                                                         | research, find, search, explore, existing code                |
| **Coordination** (2) | git-protocol, message-formats                                                                                                                              | commit, branch, git, message, json                            |

## Quick Route by Signal

### R3F Signals

| Signal                                 | Load Skill                 |
| -------------------------------------- | -------------------------- |
| physics, collision, rigid body, rapier | `dev-r3f-r3f-physics`      |
| material, shader, texture, pbr         | `dev-r3f-r3f-materials`    |
| scene, canvas, useFrame, component     | `dev-r3f-r3f-fundamentals` |

### Multiplayer Signals

| Signal                               | Load Skill                              |
| ------------------------------------ | --------------------------------------- |
| server authoritative, client-server  | `dev-multiplayer-server-authoritative`  |
| colyseus server, room handler        | `dev-multiplayer-colyseus-server`       |
| room state, schema, @type            | `dev-multiplayer-colyseus-state`        |
| colyseus client, connection          | `dev-multiplayer-colyseus-client`       |
| client prediction, lag compensation  | `dev-multiplayer-prediction-basics`     |
| movement prediction, wasd prediction | `dev-multiplayer-prediction-movement`   |
| shooting prediction, hit prediction  | `dev-multiplayer-prediction-shooting`   |
| anti-cheat, input validation         | `dev-multiplayer-anti-cheat-validation` |

### Asset Signals

| Signal                         | Load Skill                      |
| ------------------------------ | ------------------------------- |
| fbx, model, useFBX, 3d model   | `dev-assets-model-loading`      |
| audio, sound, music, howler    | `dev-assets-audio-loading`      |
| texture, image, TextureLoader  | `dev-assets-texture-loading`    |
| vite 6, asset loading, ?import | `dev-assets-vite-asset-loading` |

### Performance Signals

| Signal                                  | Load Skill                            |
| --------------------------------------- | ------------------------------------- |
| fps, performance, slow                  | `dev-performance-performance-basics`  |
| instancing, InstancedMesh, many objects | `dev-performance-instancing`          |
| lod, level of detail                    | `dev-performance-lod-systems`         |
| mobile, android, ios, touch             | `dev-performance-mobile-optimization` |

### Pattern Signals

| Signal                             | Load Skill                       |
| ---------------------------------- | -------------------------------- |
| object pool, reuse, recycle        | `dev-patterns-object-pooling`    |
| ui animation, framer motion        | `dev-patterns-ui-animations`     |
| haptics, vibration, touch feedback | `dev-patterns-mobile-haptics`    |
| territory, coverage, grid tracking | `dev-patterns-coverage-tracking` |

### TypeScript Signals

| Signal                       | Load Skill                |
| ---------------------------- | ------------------------- |
| typescript, type, interface  | `dev-typescript-basics`   |
| generic, utility type, infer | `dev-typescript-advanced` |

### Validation Signals

| Signal                                  | Load Skill                       |
| --------------------------------------- | -------------------------------- |
| validate, type-check, lint, test, build | `dev-validation-feedback-loops`  |
| e2e test, playwright, browser test      | `dev-validation-browser-testing` |
| quality gates, review code              | `dev-validation-quality-gates`   |

### Research Signals

| Signal                                 | Load Skill                          |
| -------------------------------------- | ----------------------------------- |
| research, find patterns, existing code | `dev-research-codebase-exploration` |
| gdd, design specs, requirements        | `dev-research-gdd-reading`          |
| find similar, how is this done         | `dev-research-pattern-finding`      |

### Coordination Signals

| Signal                        | Load Skill                         |
| ----------------------------- | ---------------------------------- |
| commit, git, branch, worktree | `dev-coordination-git-protocol`    |
| message format, json schema   | `dev-coordination-message-formats` |

## Sub-Agents

| Sub-Agent      | Model  | Purpose                     | When to Invoke              |
| -------------- | ------ | --------------------------- | --------------------------- |
| orchestrator   | Sonnet | Routes work to specialists  | Start of complex tasks      |
| code-research  | Haiku  | Research existing patterns  | **MANDATORY before coding** |
| implementation | Sonnet | Implement features          | After research              |
| validation     | Haiku  | Run feedback loops          | **MANDATORY before commit** |
| commit         | Haiku  | Handle commits, PRD updates | After validation            |

### Sub-Agent Invocation

```javascript
Task({
  subagent_type: 'developer-code-research',
  description: 'Research patterns for {feature}',
  prompt: 'Research existing codebase patterns for {feature}',
  timeout: 300000,
});
```

## Common Skill Combinations

### Game Feature

```
r3f-fundamentals + r3f-physics + typescript-basics + feedback-loops
```

### Multiplayer Feature

```
server-authoritative + colyseus-server + colyseus-state + colyseus-client + prediction-basics
```

### Asset Loading

```
vite-asset-loading + model-loading + texture-loading + audio-loading
```

### Performance Optimization

```
performance-basics + instancing + lod-systems + object-pooling
```

### UI Implementation

```
typescript-basics + ui-animations + browser-testing
```

## Skill Dependencies

```
r3f-materials ─────┐
                  ├──▶ r3f-fundamentals
r3f-physics ───────┤
                  │
performance ──────┘

server-authoritative ──▶ colyseus-server ──▶ colyseus-state ──▶ colyseus-client
                                     │
prediction-basics ───────────────────┘
    ├──▶ prediction-movement
    └──▶ prediction-shooting
```
