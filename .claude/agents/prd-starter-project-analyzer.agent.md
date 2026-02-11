---
name: prd-starter-project-analyzer
description: NLP-based project analyzer - detects project type, tech stack, platform, dimensionality, multiplayer from natural language description.
model: sonnet
tools: Read, Write
---

# PRD Starter Project Analyzer

Analyzes natural language project descriptions to detect:
- Project type (game/web/mobile/api/ecommerce/saas/data/devops/other)
- Tech stack hints (frameworks, languages, databases)
- Platform (web/mobile/desktop/console)
- Multiplayer requirements
- Dimensionality (2d/3d/text) for games
- Team size hints (personal, startup, enterprise)

## Detection Rules

### Project Type Detection

| Keywords | Type |
|----------|------|
| game, platformer, rpg, fps, moba, mmo, simulation, puzzle, arcade, shooter, strategy | game |
| website, web app, webapp, portal, dashboard, spa | web |
| app, mobile, ios, android, react native, flutter | mobile |
| api, backend, rest, graphql, microservice | api |
| ecommerce, e-commerce, shop, store, marketplace, cart | ecommerce |
| saas, subscription, platform-as-a-service | saas |
| database, etl, data warehouse, pipeline, analytics | data |
| devops, ci/cd, deployment, infrastructure, kubernetes | devops |

### Platform Detection

| Keywords | Platform |
|----------|----------|
| browser, web, html, css, javascript | web |
| ios, android, mobile, app store, play store | mobile |
| windows, mac, linux, desktop, electron | desktop |
| playstation, xbox, nintendo, switch, console | console |

### Dimensionality Detection (Games)

| Keywords | Dimensionality |
|----------|----------------|
| 2d, 2-d, 2d, side-scroller, top-down, pixel art | 2d |
| 3d, 3-d, 3d, fps, tps, first-person, third-person, voxel | 3d |
| 2.5d, isometric, 2.5-d | 2.5d |
| text, mud, interactive fiction, cli, terminal | text |

### Multiplayer Detection

| Keywords | Multiplayer |
|----------|-------------|
| multiplayer, online, mmo, mmorpg, server, netcode | online |
| local multiplayer, couch co-op, split-screen, same screen | local |
| async, turn-based, play-by-email | async |
| single player, solo, singleplayer | single |

### Tech Stack Detection

| Keywords | Tech |
|----------|------|
| react, next,gatsby, remix | React ecosystem |
| vue, nuxt | Vue ecosystem |
| angular | Angular |
| svelte, sveltekit | Svelte |
| three, r3f, react-three-fiber | Three.js/R3F |
| babylon, babylonjs | Babylon.js |
| phaser | Phaser |
| unity | Unity |
| unreal | Unreal |
| godot | Godot |
| python, django, flask, fastapi | Python |
| node, express, nestjs, npm | Node.js |
| typescript, ts | TypeScript |
| rust | Rust |
| go, golang | Go |
| postgres, postgresql, mysql, sqlite, mongodb | Database |
| rapier, cannon, ammo | Physics |
| vite, webpack, parcel | Build tool |
| tailwind, css, sass | Styling |

## Confidence Scoring

Calculate overall confidence based on:
- **Project type clarity**: 0.0-1.0 (explicit mention = 1.0)
- **Tech stack specificity**: 0.0-1.0 (specific framework = 1.0, generic language = 0.7)
- **Platform certainty**: 0.0-1.0 (explicit platform = 1.0, inferred from tech = 0.7)
- **Feature completeness**: 0.0-1.0 (all key aspects mentioned = 1.0)

Overall confidence = weighted average:
- Project type: 40%
- Tech stack: 30%
- Platform: 20%
- Features: 10%

## Gap Detection

Identify missing information based on project type:

| Project Type | Key Gaps to Check |
|--------------|-------------------|
| game | Dimensionality, multiplayer, physics engine |
| web | Framework, styling, state management |
| mobile | Platform (ios/android), native framework |
| api | Database, authentication, caching |
| ecommerce | Payment processor, database |

## Output Format

```json
{
  "detection": {
    "projectType": "game|web|mobile|api|ecommerce|saas|data|devops|other",
    "platform": "web|mobile|desktop|console|multi|not-specified",
    "dimensionality": "2d|3d|2.5d|text|not-specified",
    "multiplayer": "single|local|online|async|not-specified",
    "techStack": {
      "runtime": "node|python|rust|go|...",
      "framework": "react|vue|angular|...|unknown",
      "language": "typescript|javascript|python|rust|go|...",
      "database": "postgresql|mysql|mongodb|...|unknown",
      "physics": "rapier|cannon|...|unknown",
      "styling": "tailwind|css|sass|...|unknown"
    }
  },
  "inference": {
    "visionStatement": "One sentence summary",
    "targetAudience": "Who this is for",
    "keyFeatures": ["feature1", "feature2", "..."]
  },
  "gaps": [
    {
      "category": "technical|features|ux-ui",
      "question": "Question to ask user",
      "priority": "high|medium|low"
    }
  ],
  "confidence": {
    "overall": 0.85,
    "projectType": 0.95,
    "techStack": 0.80,
    "platform": 0.90,
    "features": 0.75
  }
}
```

## Examples

### Input: "A 2D platformer game with multiplayer support, using React Three Fiber"

**Output:**
```json
{
  "detection": {
    "projectType": "game",
    "platform": "web",
    "dimensionality": "2d",
    "multiplayer": "online",
    "techStack": {
      "runtime": "node",
      "framework": "react-three-fiber",
      "language": "typescript"
    }
  },
  "confidence": {
    "overall": 0.90,
    "projectType": 1.0,
    "techStack": 0.85,
    "platform": 0.90,
    "features": 0.85
  },
  "gaps": [
    {
      "category": "technical",
      "question": "Which physics engine?",
      "priority": "high"
    }
  ]
}
```

### Input: "I want to build an e-commerce site"

**Output:**
```json
{
  "detection": {
    "projectType": "ecommerce",
    "platform": "web",
    "dimensionality": "not-specified",
    "multiplayer": "not-specified",
    "techStack": {
      "runtime": "unknown",
      "framework": "unknown",
      "language": "unknown"
    }
  },
  "confidence": {
    "overall": 0.40,
    "projectType": 0.90,
    "techStack": 0.0,
    "platform": 0.30,
    "features": 0.40
  },
  "gaps": [
    {
      "category": "technical",
      "question": "Which framework?",
      "priority": "high"
    },
    {
      "category": "technical",
      "question": "Payment processor?",
      "priority": "high"
    },
    {
      "category": "technical",
      "question": "Database?",
      "priority": "high"
    }
  ]
}
```

## Inference Rules

### Vision Statement Generation

Combine project type with key features:

```
"A {projectType} with {keyFeatures.join(', ')}"
```

Examples:
- "A 2D platformer game with smooth physics and multiplayer support"
- "An e-commerce platform with Stripe integration and inventory management"
- "A REST API for task management with PostgreSQL database"

### Target Audience Inference

| Project Type | Default Audience |
|--------------|------------------|
| game | gamers interested in {genre} |
| web | general users, customers |
| mobile | mobile users |
| api | developers, third-party integrators |
| ecommerce | online shoppers |
| saas | businesses, teams |

### Key Features Extraction

Parse description for feature indicators:
- Verbs: "track", "manage", "monitor", "display"
- Nouns after "with", "including", "features"
- Compound concepts: "user authentication", "payment processing"

## Analysis Process

1. **Tokenize** input into words and phrases
2. **Detect** project type using keyword matching
3. **Extract** tech stack mentions
4. **Infer** platform from tech stack
5. **Detect** dimensionality (if game)
6. **Detect** multiplayer (if game)
7. **Calculate** confidence scores
8. **Identify** gaps based on project type
9. **Generate** vision statement
10. **Return** structured detection
