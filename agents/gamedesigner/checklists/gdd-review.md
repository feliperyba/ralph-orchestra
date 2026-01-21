---
name: gdd-review
description: Checklist for reviewing Game Design Documents
category: gamedesign
depends-on: [gdd-creation]
---

# GDD Review Checklist

Use this checklist when reviewing the Game Design Document for completeness and quality.

## Document Structure

### Basic Requirements
- [ ] GDD exists in `docs/design/gdd.md`
- [ ] Document has version number
- [ ] Last updated date is current
- [ ] Author is identified
- [ ] Status is indicated (Draft/Review/Approved)

### Required Sections
- [ ] 1. Overview (High concept, audience, platforms, USPs)
- [ ] 2. Core Gameplay (Game loop, mechanics, win/lose)
- [ ] 3. Mechanics (Movement, combat, interaction, progression)
- [ ] 4. Characters & Classes (Archetypes, abilities, stats)
- [ ] 5. Weapons & Items (Categories, balance)
- [ ] 6. Level Design (Layout, flow, spawns)
- [ ] 7. UI/UX (HUD, menus, controls, accessibility)
- [ ] 8. Progression (Leveling, rewards, economy)
- [ ] 9. Multiplayer (Match structure, teams, network)
- [ ] 10. Audio/Visual (Art style, sound, music)
- [ ] 11. Technical (Constraints, performance, localization)

### Supporting Artifacts
- [ ] `core_loop.md` exists
- [ ] `decision_log.md` exists
- [ ] `open_questions.md` exists
- [ ] `mvd_checklist.md` exists

## Content Quality

### Clarity
- [ ] Language is unambiguous
- [ ] No contradictions within document
- [ ] Technical terms defined
- [ ] Game-specific terms in glossary
- [ ] Cross-references work

### Specificity
- [ ] Mechanics described with numbers
- [ ] Examples provided for complex concepts
- [ ] Edge cases addressed
- [ ] Visual descriptions are detailed
- [ ] Audio descriptions are specific

### Completeness
- [ ] All mechanics documented
- [ ] All systems explained
- [ ] All character types defined
- [ ] All item categories covered
- [ ] Win/lose conditions clear

## Design Quality

### Pillar Compliance
(Use project-appropriate pillars)

- [ ] **Pillar 1 compliance** - [Description]
- [ ] **Pillar 2 compliance** - [Description]
- [ ] **Pixel 3 compliance** - [Description]
- [ ] **Pillar 4 compliance** - [Description]
- [ ] **Pillar 5 compliance** - [Description]

### Balance Considerations
- [ ] Rock-paper-scissors relationships identified
- [ ] Counterplay documented for major mechanics
- [ ] Skill expression opportunities exist
- [ ] Multiple viable playstyles supported

### Player Experience
- [ ] Onboarding is addressed
- ] [ ] Learning curve is appropriate
- [ ] First-time player experience documented
- [ ] Engagement loops are clear

### Technical Feasibility
- [ ] Platform constraints respected
- [ ] Performance targets defined
- [ ] Technical limitations acknowledged
- [ ] Implementation priority suggested

## Supporting Documentation

### Decision Log
- [ ] At least 5 decisions documented
- [ ] Each decision has ID (DEC-NNN)
- [ ] Alternatives considered documented
- [ ] Rationale explained
- [ ] Validation needs identified

### Open Questions
- [ ] Questions are tracked with ID (OQ-NNN)
- [ ] Questions are tagged by category
- [ ] Owner persona assigned
- [ ] Blocker status indicated

### MVD Checklist
- [ ] Must Have items completed (if prototype imminent)
- [ ] Should Have items addressed
- [ ] Nice to Have items tracked

## Review Outcome

### Pass Criteria
GDD is ready when:
- [ ] All Required Sections complete
- [ ] Content Quality standards met
- [ ] Design Quality standards met
- [ ] Supporting Documentation adequate

### Review Notes
```
Reviewer: _____________
Date: _______________
Version: X.X.X

Outcome: [ ] Approve  [ ] Request Changes  [ ] Reject

Notes:
```

---

## Quick Review Summary

### Strengths
[List what the GDD does well]

### Weaknesses
[List what needs improvement]

### Critical Issues
[List any blocking issues]

### Recommendations
[Suggested improvements]
