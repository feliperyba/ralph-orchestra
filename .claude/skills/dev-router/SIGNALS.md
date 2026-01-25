# Signal Keyword Matching Guide

Matches task descriptions and PRD items to appropriate skills using keyword detection.

## How Signal Matching Works

```javascript
function routeDevSkills(task) {
  const text = `${task.title} ${task.description} ${task.acceptanceCriteria}`.toLowerCase();
  const skills = new Set();

  // Check each category's signal patterns
  // Add matching skills to Set
  // Return array of skills
}
```

## R3F Signal Patterns

### r3f-fundamentals (base skill)

**Always include** when any R3F work is detected.

**Signals:** scene, canvas, component, mesh, geometry, useframe, usethree, drei, camera, light, render, shader, material, react three fiber, r3f, three.js

### r3f-physics

**Signals:** physics, collision, collider, rigid body, rapier, cannon, force, impulse, gravity, sensor, trigger, joint

### r3f-materials

**Signals:** material, shader, texture, pbr, matcap, glsl, uniform, fragment, vertex, transparent, metalness, roughness, normal, displacement

## Multiplayer Signal Patterns

### server-authoritative (foundational)

**Signals:** multiplayer, server authoritative, client-server, network validation, backend, socket

**When detected:** Always add colyseus-server, colyseus-state, colyseus-client

### colyseus-server

**Signals:** colyseus server, room handler, oncreate, onjoin, server side, backend room

### colyseus-state

**Signals:** room state, schema, @type, mapschema, arrayschema, state synchronization, decorator

### colyseus-client

**Signals:** colyseus client, connection, joinorcreate, room.onmessage, onstatechange, client side

### prediction-basics

**Signals:** prediction, client-side prediction, lag compensation, reconciliation, optimistic update

### prediction-movement

**Signals:** movement prediction, wasd prediction, input smoothing, position prediction

### prediction-shooting

**Signals:** shooting prediction, hit prediction, fire lag, shoot prediction, projectile prediction

### anti-cheat-validation

**Signals:** anti-cheat, input validation, server validation, cheat detection, sanitize

## Asset Signal Patterns

### model-loading

**Signals:** fbx, model, usefbx, 3d model, character model, load model, .fbx

### audio-loading

**Signals:** audio, sound, music, howler, speaker, playsound, load audio, .mp3, .wav

### texture-loading

**Signals:** texture, image, textureloader, load texture, .png, .jpg, .webp

### vite-asset-loading

**Signals:** vite 6, asset loading, ?import, import.meta.url, static asset

## Performance Signal Patterns

### performance-basics (base skill)

**Signals:** fps, slow, optimize, performance, lag, stuttering

**When detected:** Check for specific performance sub-skills

### instancing

**Signals:** instancing, instancedmesh, many objects, same geometry, repeated objects, draw calls

### lod-systems

**Signals:** lod, level of detail, distance optimization, high poly, low poly

### mobile-optimization

**Signals:** mobile, android, ios, touch, battery, responsive, devicepixelratio

## Pattern Signal Patterns

### object-pooling

**Signals:** object pool, reuse objects, recycle, pool, bullet shells, decals, particles

### ui-animations

**Signals:** ui animation, framer motion, hud animation, transition, animate

### mobile-haptics

**Signals:** haptics, vibration, vibrate, touch feedback, navigator.vibrate

### coverage-tracking

**Signals:** territory, coverage, grid, surface tracking, paint, capture

## TypeScript Signal Patterns

### typescript-basics (base skill)

**Signals:** typescript, type, interface, enum

**When detected:** Check if advanced patterns needed

### typescript-advanced

**Signals:** generic, utility type, infer, mapped type, conditional type, pick, omit, partial

## Validation Signal Patterns

### feedback-loops

**Signals:** validate, type-check, lint, test, build, feedback loop

### browser-testing

**Signals:** e2e test, playwright, browser test, automated test, test.spec

### quality-gates

**Signals:** quality gates, review code, code review, standards check

## Research Signal Patterns

### codebase-exploration

**Signals:** research, find, search, explore, where is, show me files

### gdd-reading

**Signals:** gdd, game design document, design specs, requirements

### pattern-finding

**Signals:** find patterns, existing code, similar feature, how is this done, reference

## Coordination Signal Patterns

### git-protocol

**Signals:** commit, git, branch, worktree, merge, push

### message-formats

**Signals:** message format, json schema, message protocol

## Routing Algorithm

```javascript
function routeDevSkills(task) {
  const text = `${task.title} ${task.description}`.toLowerCase();
  const skills = [];

  // R3F check
  if (/scene|canvas|useframe|three/i.test(text)) {
    skills.push('dev-r3f-r3f-fundamentals');
    if (/physics|collision|rapier/i.test(text)) {
      skills.push('dev-r3f-r3f-physics');
    }
    if (/material|shader|texture/i.test(text)) {
      skills.push('dev-r3f-r3f-materials');
    }
  }

  // Multiplayer check
  if (/multiplayer|server|colyseus/i.test(text)) {
    skills.push('dev-multiplayer-server-authoritative');
    skills.push('dev-multiplayer-colyseus-server');
    skills.push('dev-multiplayer-colyseus-state');
    skills.push('dev-multiplayer-colyseus-client');
    if (/prediction/i.test(text)) {
      skills.push('dev-multiplayer-prediction-basics');
    }
  }

  // Asset check
  if (/fbx|model/i.test(text)) skills.push('dev-assets-model-loading');
  if (/audio|sound/i.test(text)) skills.push('dev-assets-audio-loading');
  if (/texture|image/i.test(text)) skills.push('dev-assets-texture-loading');

  // Performance check
  if (/fps|performance|optimize/i.test(text)) {
    skills.push('dev-performance-performance-basics');
    if (/instance|many object/i.test(text)) {
      skills.push('dev-performance-instancing');
    }
  }

  // Pattern check
  if (/pool|reuse/i.test(text)) skills.push('dev-patterns-object-pooling');
  if (/animation/i.test(text)) skills.push('dev-patterns-ui-animations');

  // TypeScript check
  if (/typescript|type|interface/i.test(text)) {
    skills.push('dev-typescript-typescript-basics');
    if (/generic|utility|infer/i.test(text)) {
      skills.push('dev-typescript-typescript-advanced');
    }
  }

  return skills;
}
```
