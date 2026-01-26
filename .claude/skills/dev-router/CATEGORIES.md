# Developer Skills by Category

Complete index of all 41 developer skills organized by category.

## R3F (3 skills)

### dev-r3f-r3f-fundamentals

**Description:** React Three Fiber core patterns for scene composition and game loop

**Keywords:** r3f, canvas, useframe, scene, component, three, fiber

**Use when:** Setting up R3F scenes, creating 3D components, using useFrame

**Dependencies:** None (base for all R3F skills)

**Path:** `.claude/skills/dev-r3f-r3f-fundamentals/SKILL.md`

---

### dev-r3f-r3f-materials

**Description:** Custom materials, shaders, textures, and visual effects

**Keywords:** material, shader, texture, pbr, glsl, uniform

**Use when:** Creating custom materials, writing shaders, working with textures

**Dependencies:** dev-r3f-r3f-fundamentals

**Path:** `.claude/skills/dev-r3f-r3f-materials/SKILL.md`

---

### dev-r3f-r3f-physics

**Description:** Physics integration with Rapier for R3F

**Keywords:** physics, collision, rapier, rigid body, gravity

**Use when:** Implementing physics, collision detection, gravity

**Dependencies:** dev-r3f-r3f-fundamentals

**Path:** `.claude/skills/dev-r3f-r3f-physics/SKILL.md`

---

## Phaser (10 skills)

### dev-phaser-fundamentals

**Description:** Phaser game configuration, scenes, and lifecycle management

**Keywords:** phaser, scene, preload, create, update, config, game

**Use when:** Setting up Phaser game, creating scenes, game config

**Dependencies:** None (base for all Phaser skills)

**Path:** `.claude/skills/dev-phaser-fundamentals/SKILL.md`

---

### dev-phaser-sprite-management

**Description:** Sprites, sprite sheets, texture atlases, and object pooling for Phaser

**Keywords:** phaser, sprite, sheet, atlas, texture, pool, optimization

**Use when:** Managing sprites, sprite sheets, object pooling, sprite optimization

**Dependencies:** dev-phaser-fundamentals

**Path:** `.claude/skills/dev-phaser-sprite-management/SKILL.md`

---

### dev-phaser-physics-arcade

**Description:** Arcade physics: velocity, acceleration, collision, and bounds

**Keywords:** phaser, arcade, physics, collision, velocity, gravity, body

**Use when:** Implementing Arcade physics, platformers, collision detection

**Dependencies:** dev-phaser-fundamentals

**Path:** `.claude/skills/dev-phaser-physics-arcade/SKILL.md`

---

### dev-phaser-physics-matter

**Description:** Matter.js physics: realistic bodies, constraints, and simulation

**Keywords:** phaser, matter, physics, simulation, constraint, body, realistic

**Use when:** Implementing realistic physics, puzzles, complex interactions

**Dependencies:** dev-phaser-fundamentals

**Path:** `.claude/skills/dev-phaser-physics-matter/SKILL.md`

---

### dev-phaser-input-handlers

**Description:** Keyboard, mouse, touch, and gamepad input management for Phaser

**Keywords:** phaser, input, keyboard, mouse, touch, gamepad, virtual-joystick

**Use when:** Handling player input, keyboard, mouse, touch, gamepad

**Dependencies:** dev-phaser-fundamentals

**Path:** `.claude/skills/dev-phaser-input-handlers/SKILL.md`

---

### dev-phaser-scene-management

**Description:** Scene transitions, data passing, and scene lifecycle management

**Keywords:** phaser, scene, transition, launch, sleep, data-passing, manager

**Use when:** Managing multiple scenes, scene transitions, passing data between scenes

**Dependencies:** dev-phaser-fundamentals

**Path:** `.claude/skills/dev-phaser-scene-management/SKILL.md`

---

### dev-phaser-tilemaps

**Description:** Tilemap loading, parsing, layers, and collision detection

**Keywords:** phaser, tilemap, tiled, layer, collision, tileset

**Use when:** Working with tilemaps, Tiled integration, level design

**Dependencies:** dev-phaser-fundamentals

**Path:** `.claude/skills/dev-phaser-tilemaps/SKILL.md`

---

### dev-phaser-animations

**Description:** Sprite animations, tweens, animation chains, and timeline sequences

**Keywords:** phaser, animation, tween, timeline, sprite-sheet, sequence

**Use when:** Creating sprite animations, tweens, animation sequences

**Dependencies:** dev-phaser-fundamentals, dev-phaser-sprite-management

**Path:** `.claude/skills/dev-phaser-animations/SKILL.md`

---

### dev-phaser-particles

**Description:** Particle emitters for visual effects like fire, smoke, explosions, and magic

**Keywords:** phaser, particles, emitter, vfx, explosion, fire, smoke

**Use when:** Creating particle effects, fire, smoke, explosions, magic

**Dependencies:** dev-phaser-fundamentals

**Path:** `.claude/skills/dev-phaser-particles/SKILL.md`

---

### dev-phaser-ui-creation

**Description:** UI containers, text objects, buttons, and DOM element integration

**Keywords:** phaser, ui, interface, text, button, container, dom

**Use when:** Creating game UI, HUD, buttons, DOM integration

**Dependencies:** dev-phaser-fundamentals

**Path:** `.claude/skills/dev-phaser-ui-creation/SKILL.md`

---

## Multiplayer (8 skills)

### dev-multiplayer-server-authoritative

**Description:** Server-authoritative multiplayer architecture principles

**Keywords:** server, authoritative, multiplayer, architecture, backend

**Use when:** Designing ANY multiplayer feature

**Dependencies:** None (foundational for all multiplayer)

**Path:** `.claude/skills/dev-multiplayer-server-authoritative/SKILL.md`

---

### dev-multiplayer-colyseus-server

**Description:** Colyseus server setup, room handlers, lifecycle events

**Keywords:** colyseus, server, room, handler, lifecycle

**Use when:** Setting up Colyseus server, creating room handlers

**Dependencies:** dev-multiplayer-server-authoritative

**Path:** `.claude/skills/dev-multiplayer-colyseus-server/SKILL.md`

---

### dev-multiplayer-colyseus-state

**Description:** Colyseus state schema definition, types, decorators

**Keywords:** schema, state, @type, colyseus, serialization

**Use when:** Defining room state, creating schema types

**Dependencies:** dev-multiplayer-colyseus-server

**Path:** `.claude/skills/dev-multiplayer-colyseus-state/SKILL.md`

---

### dev-multiplayer-colyseus-client

**Description:** Colyseus client SDK for React, connection, events

**Keywords:** client, colyseus, connection, room, events

**Use when:** Connecting to server from React, handling room events

**Dependencies:** dev-multiplayer-server-authoritative

**Path:** `.claude/skills/dev-multiplayer-colyseus-client/SKILL.md`

---

### dev-multiplayer-prediction-basics

**Description:** Client-side prediction and server reconciliation core concepts

**Keywords:** prediction, client-side, reconciliation, lag

**Use when:** Implementing client-side prediction basics

**Dependencies:** dev-multiplayer-server-authoritative, dev-multiplayer-colyseus-client

**Path:** `.claude/skills/dev-multiplayer-prediction-basics/SKILL.md`

---

### dev-multiplayer-prediction-movement

**Description:** Movement prediction with server reconciliation for WASD controls

**Keywords:** movement, prediction, wasd, controls, reconciliation

**Use when:** Implementing WASD movement prediction

**Dependencies:** dev-multiplayer-prediction-basics

**Path:** `.claude/skills/dev-multiplayer-prediction-movement/SKILL.md`

---

### dev-multiplayer-prediction-shooting

**Description:** Shooting prediction with optimistic decals and server rollback

**Keywords:** shooting, prediction, decals, rollback, hit detection

**Use when:** Implementing shooting/hit prediction

**Dependencies:** dev-multiplayer-prediction-basics

**Path:** `.claude/skills/dev-multiplayer-prediction-shooting/SKILL.md`

---

### dev-multiplayer-anti-cheat-validation

**Description:** Input validation and anti-cheat patterns for multiplayer servers

**Keywords:** anti-cheat, validation, input, server

**Use when:** Implementing server-side input validation

**Dependencies:** dev-multiplayer-server-authoritative

**Path:** `.claude/skills/dev-multiplayer-anti-cheat-validation/SKILL.md`

---

## Assets (4 skills)

### dev-assets-audio-loading

**Description:** Audio loading patterns for R3F/Three.js

**Keywords:** audio, sound, music, howler, speaker

**Use when:** Adding sound effects, background music

**Path:** `.claude/skills/dev-assets-audio-loading/SKILL.md`

---

### dev-assets-model-loading

**Description:** FBX model loading patterns with sequential loading

**Keywords:** fbx, model, loading, sequential, useFBX

**Use when:** Loading 3D character models, sequential loading

**Path:** `.claude/skills/dev-assets-model-loading/SKILL.md`

---

### dev-assets-texture-loading

**Description:** Texture loading and optimization for R3F

**Keywords:** texture, image, loading, compression

**Use when:** Loading textures, images for materials

**Path:** `.claude/skills/dev-assets-texture-loading/SKILL.md`

---

### dev-assets-vite-asset-loading

**Description:** Vite 6 asset loading patterns that avoid '?import' query parameter pollution

**Keywords:** vite, asset, loading, ?import

**Use when:** Working with Vite 6 asset handling

**Path:** `.claude/skills/dev-assets-vite-asset-loading/SKILL.md`

---

## Performance (4 skills)

### dev-performance-performance-basics

**Description:** Core R3F/Three.js performance optimization principles

**Keywords:** optimization, fps, performance, rendering

**Use when:** FPS drops below 60, starting optimization

**Dependencies:** None (base for performance)

**Path:** `.claude/skills/dev-performance-performance-basics/SKILL.md`

---

### dev-performance-instancing

**Description:** Instanced rendering for repeated objects in R3F

**Keywords:** instancing, InstancedMesh, many objects

**Use when:** Rendering many identical objects

**Dependencies:** dev-performance-performance-basics

**Path:** `.claude/skills/dev-performance-instancing/SKILL.md`

---

### dev-performance-lod-systems

**Description:** Level of Detail (LOD) techniques for R3F

**Keywords:** lod, level of detail, distance

**Use when:** Complex models cause FPS drops

**Dependencies:** dev-performance-performance-basics

**Path:** `.claude/skills/dev-performance-lod-systems/SKILL.md`

---

### dev-performance-mobile-optimization

**Description:** Mobile-specific optimization for R3F/Three.js

**Keywords:** mobile, android, ios, touch, battery

**Use when:** Targeting mobile devices

**Dependencies:** dev-performance-performance-basics

**Path:** `.claude/skills/dev-performance-mobile-optimization/SKILL.md`

---

## Patterns (4 skills)

### dev-patterns-object-pooling

**Description:** Object pooling for high-performance R3F components

**Keywords:** pool, performance, gc, optimization, reuse

**Use when:** Creating/destroying objects every frame

**Path:** `.claude/skills/dev-patterns-object-pooling/SKILL.md`

---

### dev-patterns-ui-animations

**Description:** Game UI and HUD animation patterns with Framer Motion

**Keywords:** animation, ui, framer motion, hud

**Use when:** Animating UI elements, HUD components

**Path:** `.claude/skills/dev-patterns-ui-animations/SKILL.md`

---

### dev-patterns-mobile-haptics

**Description:** Haptic feedback patterns for mobile games using Vibration API

**Keywords:** haptics, vibration, touch, mobile

**Use when:** Adding tactile feedback to mobile controls

**Path:** `.claude/skills/dev-patterns-mobile-haptics/SKILL.md`

---

### dev-patterns-coverage-tracking

**Description:** Grid-based surface coverage tracking for territorial game mechanics

**Keywords:** territory, coverage, grid, surface

**Use when:** Implementing territory control mechanics

**Path:** `.claude/skills/dev-patterns-coverage-tracking/SKILL.md`

---

## TypeScript (2 skills)

### dev-typescript-typescript-basics

**Description:** Core TypeScript patterns for game development

**Keywords:** typescript, types, interfaces

**Use when:** Defining types, interfaces, basic TypeScript

**Dependencies:** None (base for TypeScript)

**Path:** `.claude/skills/dev-typescript-typescript-basics/SKILL.md`

---

### dev-typescript-typescript-advanced

**Description:** Advanced TypeScript patterns - generics, utility types, React patterns

**Keywords:** typescript, generics, utility-types, react

**Use when:** Complex type scenarios, generics, utility types

**Dependencies:** dev-typescript-typescript-basics

**Path:** `.claude/skills/dev-typescript-typescript-advanced/SKILL.md`

---

## Validation (3 skills)

### dev-validation-feedback-loops

**Description:** Type-check, lint, test, build validation for Developer agent

**Keywords:** validation, feedback, type-check, lint, test, build

**Use when:** Validating code before committing

**Path:** `.claude/skills/dev-validation-feedback-loops/SKILL.md`

---

### dev-validation-browser-testing

**Description:** E2E test creation for Developer using Playwright API

**Keywords:** e2e, testing, playwright, browser

**Use when:** Creating E2E tests for features

**Path:** `.claude/skills/dev-validation-browser-testing/SKILL.md`

---

### dev-validation-quality-gates

**Description:** Quality standards that must pass before commit

**Keywords:** quality gates, review, standards

**Use when:** Reviewing code quality

**Path:** `.claude/skills/dev-validation-quality-gates/SKILL.md`

---

## Research (3 skills)

### dev-research-codebase-exploration

**Description:** Efficient codebase search using Glob and Grep

**Keywords:** search, glob, grep, explore

**Use when:** Finding files, searching codebase

**Path:** `.claude/skills/dev-research-codebase-exploration/SKILL.md`

---

### dev-research-gdd-reading

**Description:** Read Game Design Document for design context

**Keywords:** gdd, design, requirements, specs

**Use when:** Need design specifications for a feature

**Path:** `.claude/skills/dev-research-gdd-reading/SKILL.md`

---

### dev-research-pattern-finding

**Description:** Find existing code patterns before implementing new features

**Keywords:** pattern, existing, similar, reference

**Use when:** Finding how similar features are implemented

**Path:** `.claude/skills/dev-research-pattern-finding/SKILL.md`

---

## Coordination (2 skills)

### dev-coordination-git-protocol

**Description:** Git commit format and branch management

**Keywords:** git, commit, branch, worktree

**Use when:** Committing code, managing branches

**Path:** `.claude/skills/dev-coordination-git-protocol/SKILL.md`

---

### dev-coordination-message-formats

**Description:** JSON schemas for Ralph message system

**Keywords:** message, json, schema, format

**Use when:** Sending messages between agents

**Path:** `.claude/skills/dev-coordination-message-formats/SKILL.md`
