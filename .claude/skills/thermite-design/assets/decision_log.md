# Thermite Decision Log

**Purpose:** Track all design decisions, their rationale, alternatives considered, and validation status.

---

## Decision: Grid-Based Movement is Non-Negotiable
**ID:** DEC-001
**Date:** 2025-12-13
**Session:** 1
**Status:** Decided
**Pillar(s):** Readable Chaos, Earned Mastery

### Context
The core question of whether Thermite should maintain strict grid-based movement like classic Bomberman, or adopt free-form movement for more "modern" feel. This is foundational and affects every other system.

### Decision
Strict grid-based movement and bomb placement. No diagonal movement, no free-aim. The grid is sacred.

### Alternatives Considered
| Option | Pros | Cons | Why Rejected |
|--------|------|------|--------------|
| Free-form movement | Modern feel, more skill expression | Breaks readability, impossible to parse chaos | Violates Pillar 2 (Readable Chaos) |
| Hybrid (grid bombs, free movement) | Compromise | Confusing, inconsistent | Worst of both worlds |

### Dissent
**Viktor Volkov:** Initial concern that grid constraints might feel dated or limit skill expression.
**Resolution:** Marcus Chen demonstrated that positioning/timing skill ceiling remains high within grid. Grid creates different skill expression, not less.

### Validation Needed
- [ ] Prototype grid movement and confirm it "feels" right at target speeds

---

## Decision: Gear Creates Options, Not Dominance
**ID:** DEC-002
**Date:** 2025-12-13
**Session:** 1
**Status:** Decided
**Pillar(s):** Earned Mastery, Meaningful Risk

### Context
How powerful should gear advantages be? If gear is too strong, new players get stomped. If too weak, gear loses meaning and the economy collapses.

### Decision
Gear amplifies skill, doesn't replace it. Every piece of gear changes tactical options but has readable counters. A skilled player with starter gear can beat an average player with top gear through superior play.

### Alternatives Considered
| Option | Pros | Cons | Why Rejected |
|--------|------|------|--------------|
| Strong gear advantages | More Tarkov-like, gear fear amplified | Skill compression, P2W adjacent | Violates Pillar 4 |
| Cosmetic-only gear | Perfectly fair | No meaningful economy, no gear fear | Violates Pillar 1 |

### Dissent
**Viktor Volkov:** Worried this makes gear feel meaningless compared to Tarkov.
**Resolution:** The difference is in TIME. Tarkov can have bigger gear gaps because raids are long enough to outmaneuver. Our 6-minute matches need tighter balance to prevent steamrolls.

### Validation Needed
- [ ] Playtest gear tier differentials and measure win rates

---

## Decision: Death Must Be Legible
**ID:** DEC-003
**Date:** 2025-12-13
**Session:** 1
**Status:** Decided
**Pillar(s):** Readable Chaos, Earned Mastery

### Context
Bomberman chaos happens fast. Players can die in frames. If deaths feel random or unexplainable, players quit. Tarkov deaths usually have clear causes (gunshot, grenade). How do we achieve this in faster-paced top-down combat?

### Decision
Every death must teach. Implement visual threat indicators, brief danger zone previews on bomb placement, and post-death replay (3-5 seconds showing what killed you).

### Alternatives Considered
| Option | Pros | Cons | Why Rejected |
|--------|------|------|--------------|
| No indicators (classic Bomberman) | Pure, punishing, "git gud" | New player exodus, violates retention | Dr. Reyes: "Mystery deaths = uninstalls" |
| Heavy indicators (full blast preview) | Very readable | Removes tension, too easy to avoid | Shinji: "Removes prediction skill" |

### Dissent
**Shinji Tanaka:** Concerned that indicators reduce skill ceiling.
**Resolution:** Jordan Ellis proposed brief/subtle indicators that teach over time but don't trivialize in-moment decisions. The learning happens across sessions, not within a single bomb placement.

### Validation Needed
- [ ] A/B test indicator visibility levels
- [ ] Track new player retention with different indicator intensities

---

## Decision: Map is the Curriculum
**ID:** DEC-004
**Date:** 2025-12-13
**Session:** 1
**Status:** Decided
**Pillar(s):** Earned Mastery, Meaningful Risk

### Context
How do we teach players the game without heavy tutorials? How do we create natural progression without explicit "levels"?

### Decision
Risk zones are geographically distributed. Map edges are safer, lower reward. Center is dangerous, high reward. New players naturally learn the edges first, then push deeper as confidence grows. The map teaches the game.

### Alternatives Considered
| Option | Pros | Cons | Why Rejected |
|--------|------|------|--------------|
| Uniform loot distribution | Simple | No learning curve, no "deep" push | Removes progression feel |
| Explicit tutorials | Clear teaching | Boring, kills arcade pacing | Shinji: "Tutorial = design failure" |

### Dissent
None significant. Team aligned quickly on this.

### Validation Needed
- [ ] Map template review to ensure edge-to-center gradient is clear
- [ ] New player tracking to confirm learning curve matches design intent

---

## Decision: Template + Variation for Maps
**ID:** DEC-005
**Date:** 2025-12-13
**Session:** 1
**Status:** Decided
**Pillar(s):** Readable Chaos, Compressed Tension

### Context
Pure procedural generation risks unplayable layouts. Pure hand-crafted maps get "solved" quickly. How do we balance replayability with quality?

### Decision
Hand-craft map skeletons (walls, zones, extraction positions). Procedurally generate contents (loot spawns, which extraction is active, AI patrol routes). Structure is designed, flesh is randomized.

### Alternatives Considered
| Option | Pros | Cons | Why Rejected |
|--------|------|------|--------------|
| Full procgen | Infinite variety | Validation nightmare, unplayable layouts | Wei: "One bad spawn = crash reports" |
| All hand-crafted | Perfect quality | Gets solved, less replayability | Elena: "Optimal route after 5 games" |

### Dissent
**Elena Vasquez:** Initially wanted more procedural freedom for variety.
**Resolution:** Wei Zhang's validation concerns won out. Templates can be validated offline. Runtime only populates known-good structures.

### Validation Needed
- [ ] Template validation tooling before adding new maps

---

## Decision: 15-20 Minute Rebuild Floor
**ID:** DEC-006
**Date:** 2025-12-13
**Session:** 1
**Status:** Tentative
**Pillar(s):** Meaningful Risk, Sustainable Economy

### Context
If a player loses everything, how long until they're "back in the game"? Too long and they quit. Too short and death means nothing.

### Decision
A completely wiped player should be able to rebuild to a basic functional loadout in 15-20 minutes of careful edge-farming play. This is the economic floor.

### Alternatives Considered
| Option | Pros | Cons | Why Rejected |
|--------|------|------|--------------|
| 5-minute rebuild | Low frustration | Death meaningless, economy too generous | Violates Pillar 1 |
| 60-minute rebuild | Hardcore, gear fear maximized | Player quits after wipe | Dr. Reyes: "Quit spiral" |

### Dissent
**Viktor Volkov:** Worried 15-20 minutes might still be too generous, reducing tension.
**Resolution:** This is tentative. Needs economy modeling and playtest data. May adjust.

### Validation Needed
- [ ] Sarah's economy model with explicit rebuild curves
- [ ] Playtest tracking of post-wipe retention

---

*End of Session 1 Decisions*
