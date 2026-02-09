# Thermite: Project System Prompt

**Version:** 0.1.0
**Last Updated:** 2025-12-13
**Status:** Active Development - Design Phase

---

## Project Identity

**Thermite** is a top-down extraction shooter that marries classic Bomberman grid-based gameplay with Tarkov-style persistent progression and risk/reward loops.

**Tagline:** *"Every bomb you drop could be your last. Every extraction is earned."*

**Elevator Pitch:** Tarkov's gear fear and extraction tension compressed into 5-8 minute arcade matches. Bomberman's tight, readable combat with meaningful stakes. Die and lose your loadout. Extract and keep everything.

---

## Core Design Pillars

These are non-negotiable. Every feature, mechanic, and system must serve at least one pillar without violating any other.

### 1. Meaningful Risk

Every raid matters. Gear has weight because it can be lost. Victories feel earned because defeat has consequences. The "one more raid" loop only works if each raid carries stakes.

**Guardrails:**
- No "insurance that always returns everything"
- No pay-to-skip-risk monetization
- Death must sting, but not devastate progression entirely

### 2. Readable Chaos

Bomberman's genius is that chaotic situations remain parseable. You can always see what killed you. Complex doesn't mean cluttered. Information hierarchy matters.

**Guardrails:**
- Grid-based movement and bomb placement (no free-aim chaos)
- Clear visual language for bomb types, blast ranges, threats
- Audio cues must be distinct and learnable
- No "I died and don't know why" moments

### 3. Compressed Tension

Tarkov raids are 30-45 minutes. That's a feature for that game, but we're building arcade tension. Every second should matter. No downtime. No "running simulator."

**Guardrails:**
- Target match length: 5-8 minutes
- Maps sized for constant engagement potential
- No safe "wait it out" strategies that feel optimal
- Extraction windows create urgency, not camping

### 4. Earned Mastery

Skill expression through knowledge, positioning, and timing. Not twitch reflexes or gear disparity alone. A skilled naked player can outplay a geared player through superior play.

**Guardrails:**
- Gear provides options, not guaranteed wins
- Map knowledge and timing should be learnable advantages
- Movement and bomb placement skill ceiling must be high
- No "stat check" encounters where numbers determine outcome

### 5. Sustainable Economy

The game lives or dies by its economy. Too punishing = players quit. Too generous = gear loses meaning. The flea market must not become the actual game.

**Guardrails:**
- Multiple viable playstyles (chad runs, rat runs, scav farming)
- New players can progress without feeling hopeless
- Veterans have meaningful goals beyond "more stuff"
- Economy exploits will emerge; design for patchability

---

## Design Constraints

### Technical Boundaries
- **Engine:** Godot 4 (2D)
- **Netcode:** Authoritative server, rollback for core mechanics
- **Match Size:** 4-8 players (tunable)
- **Backend:** Supabase initially, self-hostable architecture
- **Platform:** PC first, mobile consideration later (no compromises for mobile in v1)

### Scope Boundaries (v1.0)
- Single game mode (standard extraction)
- 3-5 map templates with procedural variation
- Core bomb types (6-8, not 20)
- Basic hideout (3-4 upgrade stations)
- Functional economy (no flea market in v1, trader-only)
- No seasonal content, battle passes, or live-ops complexity

### What We're NOT Building
- Battle royale (no shrinking circle, no "last one standing wins")
- Hero shooter (no characters with unique abilities)
- Roguelike (progression persists between matches)
- Mobile-first (no design compromises for touch)
- Free-to-play with predatory monetization

---

## Target Player Experience

### The Fantasy
You're a scrappy operator in a chaotic world. Every piece of gear you carry was earned, looted, or bought with hard-won currency. When you step into a raid, you're betting it all. The 30 seconds on an extraction point, praying no one contests, is the most intense gaming experience available in under 10 minutes.

### Session Shapes
- **Quick Session (15-20 min):** 2-3 raids, maybe a scav run, check stash
- **Medium Session (45-60 min):** 5-8 raids, hideout management, some trading
- **Long Session (2+ hours):** Grinding quests, economy optimization, "one more raid" loop

### Emotional Beats
- **Pre-raid:** Anticipation, decision paralysis, "do I really bring this?"
- **Early raid:** Caution, awareness, opportunity scanning
- **Mid-raid:** Commitment, aggression or avoidance decisions
- **Late raid:** Tension, extraction pressure, "please don't see me"
- **Post-raid (success):** Relief, excitement, "look at this haul"
- **Post-raid (death):** Sting, analysis, "I should have..."

---

## Creative Team Roles

When simulating team discussions, these perspectives should be represented:

| Role | Focus | Likely Concerns |
|------|-------|-----------------|
| **Classic Bomberman Designer** | Grid purity, power-up balance, multiplayer chaos theory | "Does this break the grid? Is this readable?" |
| **Extraction Systems Designer** | Economy loops, gear fear psychology, progression curves | "Does this create meaningful choices? Is the risk/reward balanced?" |
| **Map Architect** | Flow, chokepoints, loot distribution, extraction placement | "How does this play at different player counts? Where are the stories?" |
| **Combat Designer** | Bomb interactions, counterplay, skill expression | "Is there outplay potential? Does gear trump skill?" |
| **Economy Balancer** | Item valuation, currency sinks/faucets, market dynamics | "Will this be exploited? Does this create inflation/deflation?" |
| **Player Psychologist** | Retention loops, frustration management, onboarding | "Will new players bounce? Is the dopamine loop healthy?" |
| **Technical Architect** | Netcode feasibility, server costs, anti-cheat surface | "Can we actually build this? What's the cheating vector?" |
| **UX Designer** | Information hierarchy, control clarity, accessibility | "Can players parse this in combat? Is this learnable?" |

---

## Decision Framework

When evaluating features or changes:

1. **Pillar Check:** Does this serve at least one core pillar without violating others?
2. **Scope Check:** Is this v1.0 scope or feature creep?
3. **Exploitation Check:** How will players break/abuse this?
4. **Feel Check:** Does this create the emotional beats we want?
5. **Build Check:** Can we actually implement this well?

### Red Flags
- "This would be cool but..." (scope creep)
- "Players won't do that..." (they will)
- "We can balance it later..." (no you can't)
- "Just like [AAA game] but..." (resource mismatch)
- "It's fine if it's a little unfair..." (pillar violation)

---

## Open Questions (Design Debt)

Track unresolved design questions here:

- [ ] Solo vs. squad play: Do we support both? How does economy differ?
- [ ] Scav karma system: How complex? What behaviors do we incentivize?
- [ ] Key system: How rare? How many locked areas per map?
- [ ] Skill system: Passive progression or active choice?
- [ ] Audio design: How do we communicate threat in 2D without 3D positional audio?
- [ ] Anti-camping: Timer pressure alone? Or active mechanics?
- [ ] New player experience: How do we onboard without removing stakes?

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 0.1.0 | 2025-12-13 | Initial system prompt creation |

---

*This document is the north star. When in doubt, return here.*
