---
name: gdd-reading
description: Read Game Design Document for design context
category: research
---

# GDD Reading

> "Understand the design before you build - GDD first, code second."

## When to Use This Skill

Use when:
- Starting a new feature implementation
- Design requirements are unclear
- Need to understand design rationale
- Looking for constraints and limitations
- Checking for open questions related to feature

## Quick Start

```bash
# Read main GDD overview
Read("docs/design/gdd/index.md")

# Read feature-specific spec
Read("docs/design/gdd/{feature}.md")

# Check decision log
Read("docs/design/decision_log.md")

# Check open questions
Read("docs/design/open_questions.md")
```

## Decision Framework

| Need | Read First | Then Check |
|------|------------|------------|
| New feature | `gdd/index.md` | `gdd/{feature}.md` |
| Design rationale | `decision_log.md` | Related feature specs |
| Constraints | Feature spec | `index.md` overview |
| Open questions | `open_questions.md` | Feature spec |

## Essential Files

### Main GDD
- `docs/design/gdd/index.md` - Design overview, game concept
- `docs/design/gdd/game-loop.md` - Core gameplay loop
- `docs/design/gdd/mechanics.md` - Game mechanics reference

### Feature Specifications
- `docs/design/gdd/{feature}.md` - Feature-specific specs
- `docs/design/gdd/systems/{system}.md` - System designs

### Decision Log
- `docs/design/decision_log.md` - Design rationale, past decisions

### Open Questions
- `docs/design/open_questions.md` - Unresolved design issues

## Reading Strategies by Task Type

### Gameplay Feature Tasks

**Read in order:**
1. `gdd/game-loop.md` - Understand where feature fits
2. `gdd/mechanics.md` - Check related mechanics
3. `gdd/{feature}.md` - Feature specification
4. `decision_log.md` - Design rationale

**Extract:**
- Core gameplay impact
- Player interaction patterns
- Win/lose conditions
- Balance considerations

### UI/UX Tasks

**Read in order:**
1. `gdd/index.md` - Visual style overview
2. `gdd/ui/{feature}.md` - UI specifications
3. `gdd/accessibility.md` - Accessibility requirements

**Extract:**
- Visual design language
- Layout patterns
- Interaction guidelines
- Feedback requirements

### Multiplayer Tasks

**Read in order:**
1. `gdd/multiplayer.md` - Multiplayer design
2. `gdd/networking.md` - Network constraints
3. `gdd/{feature}.md` - Feature specification

**Extract:**
- Synchronization requirements
- Latency tolerance
- Conflict resolution
- Fairness considerations

### Performance Tasks

**Read in order:**
1. `gdd/performance.md` - Performance targets
2. `gdd/platforms.md` - Platform constraints
3. `gdd/{feature}.md` - Feature scope

**Extract:**
- FPS targets
- Memory limits
- Load time requirements
- Platform-specific constraints

## Key Information to Extract

### Requirements
```markdown
## Requirements Extracted: {feature}

### Functional Requirements
- {what the feature must do}
- {acceptance criteria}
- {edge cases to handle}

### Non-Functional Requirements
- {performance targets}
- {platform constraints}
- {accessibility requirements}

### User Experience
- {expected player behavior}
- {feedback mechanisms}
- {error handling}
```

### Constraints
```markdown
## Constraints: {feature}

### Technical Constraints
- {performance limitations}
- {platform restrictions}
- {dependency constraints}

### Design Constraints
- {visual style requirements}
- {gameplay limitations}
- {narrative restrictions}
```

### Patterns
```markdown
## Patterns to Follow: {feature}

### Similar Features
- {feature 1} - {file reference}
- {feature 2} - {file reference}

### Shared Patterns
- {pattern 1} - {where it's used}
- {pattern 2} - {where it's used}
```

## If Requirements Are Unclear

### Decision Tree

```
START
  │
  ├─ Is feature in GDD?
  │   ├─ YES → Read feature spec
  │   └─ NO → Check similar features
  │
  ├─ Are acceptance criteria clear?
  │   ├─ YES → Proceed with implementation
  │   └─ NO → Check open_questions.md
  │
  ├─ Is question in open_questions.md?
  │   ├─ YES → Note any updates
  │   └─ NO → Query Game Designer
  │
  └─ Still unclear?
      ├─ Document assumptions
      ├ Flag for PM review
      └─ Proceed with best effort
```

### Query Game Designer When:

- "What should happen when...?" → Behavior unclear
- "What's the visual style?" → Aesthetics undefined
- "What are the edge cases?" → Edge cases not documented
- "How does this interact with...?" → Integration unclear

### Proceed with Assumptions When:

- Similar features have established patterns
- Technical implementation is straightforward
- Assumption can be easily reversed
- Document assumption in code comments

## Code Patterns

### GDD-First Workflow

```xml
<gdd_first_workflow>
1. Task Assigned
2. Read GDD Overview (index.md)
3. Read Feature Spec ({feature}.md)
4. Check Decision Log (design rationale)
5. Check Open Questions (unresolved issues)
6. Extract requirements and constraints
7. Identify similar features and patterns
8. If unclear: Query Game Designer
9. If clear: Proceed with implementation
</gdd_first_workflow>
```

### Information Extraction Template

```markdown
## GDD Research Summary: {taskId}

### Feature Context
- Feature: {feature name}
- Category: {gameplay/UI/multiplayer/etc}
- Priority: {high/medium/low}

### Requirements
- Functional: {key functional requirements}
- Acceptance Criteria: {from GDD}
- Edge Cases: {identified edge cases}

### Constraints
- Performance: {targets/limitations}
- Platform: {specific constraints}
- Design: {visual/gameplay restrictions}

### Design Rationale
- Key decisions: {from decision_log.md}
- Why this approach: {design reasoning}

### Related Features
- Similar to: {existing features}
- Patterns from: {patterns to follow}

### Open Questions
- Unresolved: {any open questions}
- Assumptions made: {document assumptions}
```

## Anti-Patterns

**DON'T:**

- Implement without reading GDD
- Skip decision log (it explains "why")
- Ignore open questions
- Assume design intent
- Implement conflicting patterns

**DO:**

- Always read relevant GDD sections first
- Check decision log for rationale
- Note any open questions
- Query when unclear
- Follow established design patterns

## Checklist

Before implementing:

- [ ] Read `docs/design/gdd/index.md`
- [ ] Read feature-specific spec if exists
- [ ] Checked `decision_log.md` for rationale
- [ ] Checked `open_questions.md` for conflicts
- [ ] Extracted requirements and constraints
- [ ] Identified similar features to reference
- [ ] Queried Game Designer if unclear
- [ ] Documented any assumptions made

## Tips

1. **Start with overview** - Get big picture before diving deep
2. **Read decisions** - Understanding "why" prevents mistakes
3. **Check constraints early** - Technical limits affect implementation
4. **Look for patterns** - Similar features show established approaches
5. **Document assumptions** - Note what you're assuming if unclear
6. **Query early** - Ask Game Designer before going down wrong path

## See Also

- [dev-research-codebase-exploration](../dev-research-codebase-exploration/SKILL.md) — Codebase search patterns
- [dev-research-pattern-finding](../dev-research-pattern-finding/SKILL.md) — Find code patterns
- [dev-router](../dev-router/SKILL.md) — Route to appropriate skills
