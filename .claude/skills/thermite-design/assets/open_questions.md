# Thermite Open Questions Backlog

**Purpose:** Track unresolved design questions with ownership and priority.
**Last Updated:** 2025-12-13

---

## Blocking (Must Resolve Before Prototype)

- [ ] **OQ-001:** What is the "container" equivalent? (Secure slot that survives death)
  - Tags: #economy #death-rules #core-loop
  - Raised: Session 1 (Viktor)
  - Owner: Viktor Volkov + Sarah Okonkwo
  - Blocker for: Death rules finalization, economy model
  - Notes: Tarkov's gamma container is controversial but essential for risk calibration

- [ ] **OQ-002:** Do AI enemies exist in v1?
  - Tags: #scope #core-loop #ai
  - Raised: Session 1 (Pre-session)
  - Owner: Wei Zhang + Viktor Volkov
  - Blocker for: Map design, difficulty curve, server architecture
  - Notes: Significant scope implication either way

- [ ] **OQ-003:** Solo vs. squad play support?
  - Tags: #scope #matchmaking #balance
  - Raised: Session 1 (Pre-session)
  - Owner: Marcus Chen + Dr. Maya Reyes
  - Blocker for: Match structure, economy scaling, balance approach
  - Notes: Squad play creates massive balance and economy complexity

---

## Important (Should Resolve Before Alpha)

- [ ] **OQ-004:** How does audio communicate threat in 2D without 3D positional audio?
  - Tags: #audio #ux #accessibility
  - Raised: Session 1 (Pre-session)
  - Owner: Jordan Ellis
  - Notes: Critical for accessibility, may need visual fallback system

- [ ] **OQ-005:** What prevents camping being optimal?
  - Tags: #balance #map-design #anti-camping
  - Raised: Session 1
  - Owner: Elena Vasquez + Marcus Chen
  - Notes: Timer pressure alone? Active mechanics? Map design?

- [ ] **OQ-006:** Insurance mechanics details
  - Tags: #economy #death-rules
  - Raised: Session 1 (Viktor reference)
  - Owner: Sarah Okonkwo + Viktor Volkov
  - Notes: Return rate, timing, cost structure

- [ ] **OQ-007:** Scav karma system complexity
  - Tags: #ai #economy #player-behavior
  - Raised: Session 1 (Pre-session)
  - Owner: Viktor Volkov + Dr. Maya Reyes
  - Notes: What behaviors do we incentivize? How complex?

---

## Exploratory (Can Iterate Post-Launch)

- [ ] **OQ-008:** Key system design
  - Tags: #economy #map-design #progression
  - Raised: Session 1 (Pre-session)
  - Owner: Elena Vasquez + Sarah Okonkwo
  - Notes: How rare? How many locked areas per map? Persistence?

- [ ] **OQ-009:** Skill/progression system
  - Tags: #progression #balance #long-term
  - Raised: Session 1 (Pre-session)
  - Owner: Marcus Chen + Dr. Maya Reyes
  - Notes: Passive progression vs. active choice vs. none in v1

- [ ] **OQ-010:** Flea market design (v2+)
  - Tags: #economy #future #trading
  - Raised: Session 1 (Pre-session)
  - Owner: Sarah Okonkwo
  - Notes: Explicitly out of v1 scope, but should inform v1 economy

- [ ] **OQ-011:** Hideout upgrade depth
  - Tags: #progression #economy #scope
  - Raised: Session 1 (Pre-session)
  - Owner: Viktor Volkov
  - Notes: Basic (3-4 stations) in v1, but what are they?

---

## Resolved Questions

*None yet*

---

## How to Add Questions

New questions should include:
- Unique ID (OQ-XXX)
- Clear question statement
- Tags for categorization
- Session where raised
- Owner persona(s)
- Blocker status if applicable
- Contextual notes

Move to "Resolved" section when answered, with link to decision ID.
