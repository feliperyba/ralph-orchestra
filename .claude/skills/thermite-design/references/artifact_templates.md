# Thermite Artifact Templates

## Session Output Template

```markdown
# Session [N]: [Topic]
**Date:** YYYY-MM-DD
**Type:** Boardroom | Deep Dive | Decision Review
**Participants:** [Persona names]

## Summary
[2-3 sentence overview of what was discussed/decided]

## Decisions Made
| ID | Title | Status | Pillars |
|----|-------|--------|---------|
| DEC-XXX | [Short title] | Decided/Tentative | [Pillar list] |

[Link to full decision in decision_log.md]

## Open Questions Surfaced
- [ ] [Question] (Tagged: #economy #map #balance etc.)

## Artifacts Updated
- [artifact_name.md] - [What changed]

## Action Items
- [ ] **[Owner]:** [Task description]

## Tensions Explored
| Axis | Position A | Position B | Resolution |
|------|------------|------------|------------|
| [Tension name] | [Persona]: [View] | [Persona]: [View] | [How resolved or "Open"] |

## Next Session Recommendation
[Topic] - [Why this should be next]
```

---

## Decision Log Entry Template

```markdown
## Decision: [Short Descriptive Title]
**ID:** DEC-[NNN]
**Date:** YYYY-MM-DD
**Session:** [Session number]
**Status:** Decided | Tentative | Revisit After Playtest
**Pillar(s):** Meaningful Risk | Readable Chaos | Compressed Tension | Earned Mastery | Sustainable Economy

### Context
[1-2 paragraphs on why this question arose and why it matters]

### Decision
[Clear statement of what was decided]

### Alternatives Considered
| Option | Pros | Cons | Why Rejected |
|--------|------|------|--------------|
| [Alt 1] | | | |
| [Alt 2] | | | |

### Dissent
**[Persona name]:** [Their concern]
**Resolution:** [How the concern was addressed or acknowledged]

### Validation Needed
- [ ] [What needs to be tested/prototyped to confirm this works]

### Dependencies
- Blocks: [What this decision enables]
- Blocked by: [What must be decided first]
```

---

## Gear Registry Entry Template

```markdown
## [Item Name]
**ID:** GEAR-[NNN]
**Slot:** Bomb Type | Capacity | Range | Movement | Armor | Utility | Consumable
**Tier:** Starter | Common | Uncommon | Rare | Legendary
**Risk Level:** Low | Medium | High | Very High

### Description
[What this item does in plain language]

### Stats
| Property | Value |
|----------|-------|
| [Stat 1] | [Value] |
| [Stat 2] | [Value] |

### Counterplay
**Countered by:** [What beats this]
**Counters:** [What this beats]

### Skill Expression
**Floor:** [Minimum effectiveness for new player]
**Ceiling:** [Maximum effectiveness for expert]

### Visual Language
**Shape:** [Silhouette description]
**Color:** [Primary/secondary colors]
**Audio cue:** [Distinct sound]

### Economy
**Base value:** [Shrapnel amount]
**Rarity weight:** [Spawn probability]
**Craft requirements:** [If craftable]

### Design Notes
[Why this item exists, what fantasy it fulfills]

### Pillar Check
- [ ] Meaningful Risk: [How this preserves stakes]
- [ ] Readable Chaos: [How this stays parseable]
- [ ] Earned Mastery: [How skill matters]
```

---

## Map Template Spec

```markdown
## Map: [Name]
**ID:** MAP-[NNN]
**Size:** [Tiles x Tiles]
**Player Count:** [Min-Max]
**Match Duration Target:** [Minutes]

### Zone Layout
```
[ASCII art or description of zone distribution]
```

### Zones
| Zone | Risk Level | Loot Tier | Purpose |
|------|------------|-----------|---------|
| Spawn Ring | Safe | Basic | Starting area |
| Mid Zone | Medium | Moderate | Transition/farming |
| Hot Zone | High | High | High-risk high-reward |
| Extraction Areas | Variable | N/A | Escape points |

### Extractions
| Extract | Location | Type | Requirements | Risk |
|---------|----------|------|--------------|------|
| Alpha | [Position] | Timed | None | Low |
| Beta | [Position] | Conditional | [Key/clear AI] | Medium |
| Emergency | [Position] | Always Open | None | Very High |

### Loot Distribution
| Zone | Common % | Uncommon % | Rare % | Marked Room |
|------|----------|------------|--------|-------------|
| Spawn | 80 | 18 | 2 | No |
| Mid | 50 | 40 | 10 | No |
| Hot | 20 | 50 | 30 | Yes |

### Flow Analysis
**Rotation patterns:** [How players typically move]
**Choke points:** [Where conflicts concentrate]
**Camping risks:** [Defensible positions]
**Anti-camping:** [How design discourages static play]

### AI Spawns (if applicable)
| Patrol | Route | Difficulty | Loot |
|--------|-------|------------|------|
| [Name] | [Path] | [Easy/Med/Hard] | [Drop table] |

### Procedural Variation
**Fixed:** [What never changes]
**Variable:** [What randomizes per match]

### Design Notes
[Map narrative, intended experience, teaching moments]
```

---

## Economy Model Template

```markdown
# Economy Model v[X.X]
**Last Updated:** YYYY-MM-DD
**Owner:** Sarah Okonkwo

## Currencies
| Currency | Acquisition | Primary Use | Velocity Target |
|----------|-------------|-------------|-----------------|
| Shrapnel | Every raid, selling | Basic items, repairs | High |
| Cores | Extractions, quests | High-tier, hideout | Medium |
| Keys | Rare spawns | Locked areas/extracts | Low |

## Faucets (Currency Entering System)
| Source | Currency | Amount/Event | Frequency |
|--------|----------|--------------|-----------|
| Raid survival | Shrapnel | [X] | Per raid |
| Successful extract | Cores | [X] | Per extract |
| Quest completion | Both | Variable | Per quest |
| Selling loot | Shrapnel | Item value | Constant |

## Sinks (Currency Leaving System)
| Sink | Currency | Cost | Purpose |
|------|----------|------|---------|
| Gear purchase | Shrapnel | Variable | Primary sink |
| Hideout upgrade | Cores | [X] per level | Long-term sink |
| Insurance | Shrapnel | [X]% item value | Risk mitigation |
| Repairs | Shrapnel | [X] per use | Maintenance |

## Rebuild Curves
| Starting Point | Target State | Raids Required | Time Estimate |
|----------------|--------------|----------------|---------------|
| Zero (wiped) | Basic loadout | [X] | [Y] minutes |
| Basic | Mid-tier | [X] | [Y] minutes |
| Mid-tier | Full kit | [X] | [Y] minutes |

## Value Hierarchy
| Tier | Example Items | Shrapnel Value | Extract Rate |
|------|---------------|----------------|--------------|
| Common | Standard bomb, basic vest | 100-500 | 60% |
| Uncommon | Remote det, speed boots | 500-2000 | 40% |
| Rare | Piercing bomb, blast vest | 2000-10000 | 20% |
| Legendary | [TBD] | 10000+ | 5% |

## Exploit Surface Analysis
| Potential Exploit | Likelihood | Impact | Mitigation |
|-------------------|------------|--------|------------|
| [Exploit 1] | High/Med/Low | Severity | Prevention method |

## Balance Levers
| Lever | Current Value | Tuning Range | Impact |
|-------|---------------|--------------|--------|
| Loot spawn rates | [X] | [Range] | Inflation/deflation |
| Extraction bonus | [X] | [Range] | Risk incentive |
| Insurance return rate | [X]% | [Range] | Death penalty |
```

---

## Core Loop Spec Template

```markdown
# Core Loop Specification v[X.X]
**Last Updated:** YYYY-MM-DD
**Owners:** Viktor Volkov, Shinji Tanaka

## Loop Overview
```
STASH → LOADOUT → RAID → EXTRACT/DIE → STASH
         │                      │
         └── Economy & Progression ──┘
```

## Pre-Raid Phase
**Duration:** [Target time]
**Player Actions:**
1. Review stash
2. Select loadout
3. Choose insurance (optional)
4. Queue for match

**Emotional Beat:** Anticipation, decision paralysis, "do I really bring this?"

## Raid Phase: Minute-by-Minute

### 0:00-0:30 — Spawn
**State:** Players spawn on outer ring
**Objective:** Orient, plan route
**Threats:** Minimal (spawn protection?)
**Emotional Beat:** Caution, awareness

### 0:30-2:00 — Early Raid
**State:** Players spread, farm edge
**Objective:** Gather resources, avoid early fights
**Threats:** Other players, basic AI
**Emotional Beat:** Opportunity scanning, measured risk

### 2:00-4:00 — Mid Raid
**State:** Push toward center or extract
**Objective:** Commit to strategy (loot vs. leave)
**Threats:** Increased player density, better AI
**Emotional Beat:** Commitment, aggression or avoidance

### 4:00-6:00 — Late Raid
**State:** Extraction windows active
**Objective:** Survive, reach extract
**Threats:** Maximum, desperate players
**Emotional Beat:** Tension, "please don't see me"

### 6:00-8:00 — Overtime (if applicable)
**State:** Forced extraction pressure
**Objective:** Get out NOW
**Threats:** Environmental? Closing zones?
**Emotional Beat:** Panic, desperation

## Post-Raid Phase

### On Extraction
1. Loot added to stash
2. XP awarded
3. Quest progress updated
4. Stats recorded
**Emotional Beat:** Relief, excitement, "look at this haul"

### On Death
1. Loadout lost (except container items?)
2. Insurance timer starts (if insured)
3. Stats recorded
4. Return to stash (diminished)
**Emotional Beat:** Sting, analysis, "I should have..."

## Grid Contract
| Property | Value | Notes |
|----------|-------|-------|
| Tile size | [X] pixels | Visual |
| Movement speed | [X] tiles/sec | Base |
| Bomb arm time | [X] ms | Time to place |
| Bomb fuse time | [X] ms | Default detonation |
| Blast duration | [X] ms | Danger window |

## State Transitions
[State diagram or description of valid state changes]
```

---

## Open Questions Template

```markdown
# Open Questions Backlog
**Last Updated:** YYYY-MM-DD

## Blocking (Must resolve before prototype)
- [ ] **OQ-001:** [Question] 
  - Tags: #core-loop #economy
  - Raised: Session [N]
  - Owner: [Persona]
  - Blocker for: [What this blocks]

## Important (Should resolve before alpha)
- [ ] **OQ-002:** [Question]
  - Tags: #balance #ux
  - Raised: Session [N]
  - Owner: [Persona]

## Exploratory (Can iterate)
- [ ] **OQ-003:** [Question]
  - Tags: #future #nice-to-have
  - Raised: Session [N]
  - Owner: [Persona]

---

## Resolved Questions
- [x] **OQ-000:** [Question]
  - Resolution: [Answer/Decision ID]
  - Resolved: Session [N]
```

---

## MVD Checklist Template

```markdown
# Minimum Viable Design Checklist
**Target:** Green light for prototype development
**Status:** [X]/[Y] items complete

## Must Have (Blocks Development)
- [ ] **Core loop** documented minute-by-minute
  - Status: Not started | In progress | Complete
  - Document: core_loop.md
  
- [ ] **Grid contract** defined
  - Status: Not started | In progress | Complete
  - Document: core_loop.md#grid-contract
  
- [ ] **Loadout system** scoped (slots, starter kit, tiers)
  - Status: Not started | In progress | Complete
  - Document: gear_registry.md
  
- [ ] **Death rules** codified
  - Status: Not started | In progress | Complete
  - Document: core_loop.md#on-death
  
- [ ] **Map template** with zones
  - Status: Not started | In progress | Complete
  - Document: map_templates.md
  
- [ ] **Extraction mechanic** specified
  - Status: Not started | In progress | Complete
  - Document: core_loop.md#extraction
  
- [ ] **AI presence** decided
  - Status: Not started | In progress | Complete
  - Decision: DEC-XXX

## Should Have (Blocks Polish)
- [ ] Bomb types (6-8) with counterplay
- [ ] Economy curves modeled
- [ ] Visual language guide started
- [ ] Audio design approach
- [ ] Netcode architecture

## Nice to Have (Can Iterate)
- [ ] Full gear registry
- [ ] All map templates  
- [ ] Hideout details
- [ ] Skill/progression system

---

## Gate Criteria
**Prototype green light when:**
1. All "Must Have" items complete
2. No blocking open questions remain
3. Creative team sign-off recorded
```

---

## Tech Spec Template

```markdown
# Technical Specification v[X.X]
**Last Updated:** YYYY-MM-DD
**Owner:** Wei Zhang

## Architecture Overview
```
[Diagram or description]
```

## Stack
| Layer | Technology | Rationale |
|-------|------------|-----------|
| Engine | Godot 4 (2D) | Open source, capable |
| Netcode | [Approach] | [Why] |
| Backend | [Tech] | [Why] |
| Database | [Tech] | [Why] |

## Netcode Approach
**Model:** Authoritative server | Client-side prediction | Rollback
**Tick rate:** [X] Hz
**Latency budget:** [X] ms acceptable

### What Syncs
| Data | Sync Method | Priority |
|------|-------------|----------|
| Player position | [Method] | Critical |
| Bomb placement | [Method] | Critical |
| Loot state | [Method] | High |
| UI state | [Method] | Low |

### Latency Handling
**At 50ms:** [Expected behavior]
**At 100ms:** [Expected behavior]
**At 150ms+:** [Degradation strategy]

## Anti-Cheat Surface
| Attack Vector | Risk | Mitigation |
|---------------|------|------------|
| Wallhacks | High | Server-authoritative visibility |
| Speed hacks | High | Server-side validation |
| Loot ESP | Medium | Information hiding |

## Server Cost Model
| Scenario | Estimated Cost | Notes |
|----------|----------------|-------|
| 100 CCU | $X/month | |
| 1000 CCU | $X/month | |
| 10000 CCU | $X/month | |

## Performance Targets
| Metric | Target | Minimum |
|--------|--------|---------|
| Client FPS | 60 | 30 |
| Server tick | [X]ms | [Y]ms |
| Match start | <[X]s | |

## Infrastructure
**Hosting:** [Provider]
**Regions:** [List]
**Scaling:** [Strategy]
```
