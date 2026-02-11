---
name: gd-design-level
description: Map and level design documentation. Use when designing map layouts, creating level templates, placing loot and spawns, designing flow and pacing, or creating navigation systems.
---

# Level Design

## Map Template Format

```markdown
## Map: [Name]
**ID:** MAP-[NNN]
**Size:** [Dimensions]
**Player Count:** [Min-Max]
**Match Duration:** [Minutes]

### Zone Layout
[ASCII art or visual description]

### Zones
| Zone | Risk Level | Loot Tier | Purpose |
|------|------------|-----------|---------|
| [Name] | [Level] | [Tier] | [Function] |

### Extraction Points
| Extract | Location | Type | Requirements | Risk |
|---------|----------|------|--------------|------|
| [Name] | [Position] | [Type] | [Needs] | [Level] |

### Loot Distribution
| Zone | Common % | Uncommon % | Rare % |
|------|----------|------------|--------|
| [Name] | [X%] | [X%] | [X%] |

### Flow Analysis
**Rotation patterns:** [How players move]
**Choke points:** [Conflict locations]
**Camping risks:** [Defensible spots]
**Anti-camping:** [Mitigations]

### AI Spawns (if applicable)
| Patrol | Route | Difficulty | Loot |
|--------|-------|------------|------|
| [Name] | [Path] | [Level] | [Drops] |
```

## Level Design Principles

### Flow

Players should move through the space with purpose:

- **Clear paths** - Intuitive routes between areas
- **Multiple options** - No single "correct" way
- **Decision points** - Players choose their path
- **Risk gradient** - Danger increases with reward

### Landmarks

Players should orient themselves easily:

- **Silhouettes** - Distinct visual shapes
- **Lighting** - Key areas highlighted
- **Audio cues** - Sounds indicate location
- **Unique features** - Memorable elements

### Pacing

Match the intended experience:

- **Buildup** - Start slow, increase intensity
- **Peaks** - High-tension moments
- **Breathing room** - Brief downtime
- **Climax** - Final push to objective

## Level Design Process

### Step 1: Concept Sketch

Create a rough layout showing:
- Overall shape
- Major zones
- Key landmarks
- Spawn/extract points

### Step 2: Zone Definition

Define each area by:
- Primary purpose
- Risk level
- Loot quality
- Flow role

### Step 3: Connection Design

Create paths between zones:
- Main routes (obvious)
- Alternative routes (hidden)
- Shortcuts (risk/reward)
- Choke points (conflict areas)

### Step 4: Loot Placement

Place rewards following:
- Risk gradient (deeper = better)
- Exploration reward (off-path = bonus)
- Flow guidance (loot attracts movement)
- Balance considerations (not all in one spot)

### Step 5: Playtest Validation

Test and iterate:
- Do players flow as intended?
- Are there camping spots?
- Is loot distributed fairly?
- Are spawns safe?

## Common Level Patterns

### Arena

Symmetrical, focused on fair competition:
- Central conflict zone
- Mirrored starting positions
- Clear sightlines
- Equal distance to objectives

### Linear

Progressive, narrative-driven:
- Clear forward path
- Branching side areas
- Setpiece encounters
- Progressive difficulty

### Open World

Exploration-focused:
- Non-linear progression
- Multiple objectives
- Fast travel points
- Dynamic events

### Hub and Spoke

Central base with destinations:
- Central safe zone
- Radiating paths
- Distinct themed areas
- Return to hub mechanic

## JSON Level Data Format

### Standard Level JSON Structure

When implementing levels in JSON format for Phaser 3 games:

```json
{
  "id": "level001",
  "name": "Tutorial - First Shot",
  "description": "Learn the basics with an impossible-to-fail tutorial shot",
  "birds": ["red", "red", "red"],
  "starThresholds": {
    "one": 5000,
    "two": 32000,
    "three": 72000
  },
  "pigs": [
    { "x": 800, "y": 500, "type": "small" }
  ],
  "blocks": [
    { "x": 750, "y": 500, "material": "glass", "rotation": 0 }
  ],
  "ground": { "y": 550 },
  "slingshot": { "x": 200, "y": 450 }
}
```

### Level Design Best Practices for JSON

1. **Progressive Difficulty**
   - Early levels: Tutorial patterns, single solution
   - Mid levels: Multiple valid approaches
   - Late levels: Complex structures requiring mastery

2. **Star Threshold Formula**
   ```javascript
   2-star: 30,000 + (level × 2,000)
   3-star: 60,000 + (level × 6,000)
   ```

3. **Bird Allocation**
   - Tutorial levels: 3 birds (fail-proof)
   - Practice levels: 3-4 birds
   - Complexity levels: 4-5 birds
   - Mastery levels: 5-7 birds

4. **Validation Checklist**
   - [ ] All x/y coordinates within world bounds
   - [ ] All material types are valid (glass, wood, stone, explosive)
   - [ ] All pig types are valid (small, medium, large)
   - [ ] All bird types are valid (red, yellow, black, white, blue)
   - [ ] Star thresholds follow progressive formula
   - [ ] At least 2 valid solutions exist
   - [ ] Level is solvable within bird count

### Level Documentation Template

```markdown
## Level {N}: {Name}

**Difficulty:** Tutorial | Practice | Complexity | Mastery | Challenge
**Target Time:** 30-90 seconds
**Birds:** {count} × {type}
**Pigs:** {count}

### Solution Paths
1. **Brute Force (1-star):** {description}
2. **Strategic (2-star):** {description}
3. **Optimal (3-star):** {description}

### Design Notes
- {key mechanic introduction}
- {difficulty considerations}
- {fail-safes for tutorial levels}
```

## Level Review Checklist

Before marking a level complete:

- [ ] Layout supports target player count
- [ ] Spawns are safe and accessible
- [ ] Extractions are balanced
- [ ] Loot distribution is fair
- [ ] Flow creates meaningful choices
- [ ] Landmarks provide orientation
- [ ] Choke points have counterplay
- [ ] Performance is acceptable
- [ ] Art style is consistent
- [ ] JSON format is valid
- [ ] Coordinates are within bounds
- [ ] Materials and types are valid
- [ ] Star thresholds follow formula
- [ ] Multiple solutions exist
- [ ] Level is solvable

## Reference

- [JSON Schema Validation](https://ajv.js.org/) — Validate level data structure
- [Phaser JSON Loading](https://photonstorm.github.io/phaser3-docs/Phaser.Cache.BaseCache.html) — Cache API for JSON
