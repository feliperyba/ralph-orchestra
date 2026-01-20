---
name: skill-improvement
description: MCP-based skill improvement during retrospective - research and update agent skills
category: coordination
depends-on: [retrospective]
---

# Skill Improvement Skill

> "Continuous learning – improve agent capabilities based on real-world experience."

## When to Use This Skill

Use during retrospective phase when:

- A task revealed knowledge gaps in Developer or QA skills
- New patterns or anti-patterns were discovered
- External references could improve success rate
- Agent struggled with a specific domain (R3F, physics, shaders)

## Quick Start

```markdown
## Retrospective: Skill Improvement Check

1. Identify skill gaps from task experience
2. Use MCP (WebSearch, fetch) to research best practices
3. Update relevant SKILLS.md or skill files
4. Document changes in action items
```

## Decision Framework

| Signal                              | Action                                      |
| ----------------------------------- | ------------------------------------------- |
| Developer asked many clarifications | Improve Developer SKILLS.md with patterns   |
| QA missed edge cases                | Add testing patterns to QA SKILLS.md        |
| Performance issues discovered       | Research and add optimization skill         |
| New library/API used                | Create reference doc in agent's references/ |
| Anti-pattern repeated               | Add explicit anti-pattern section           |

## Progressive Guide

### Level 1: Identify Skill Gaps

During retrospective synthesis, identify gaps:

```markdown
### Skill Gap Analysis

**Developer Gaps**:

- [ ] Missing: R3F instancing patterns
- [ ] Unclear: Shader uniform management

**QA Gaps**:

- [ ] Missing: WebGL performance profiling
- [ ] Unclear: Mobile device testing

**Domain Gaps**:

- [ ] Need: Physics collision layers reference
- [ ] Need: Material comparison table
```

### Level 2: Research with MCP

Use available MCP tools to research:

```markdown
## Research Tasks

### Reference URLs to Fetch

- https://agent-skills.md/skills/Bbeierle12/Skill-MCP-Claude/r3f-fundamentals
- https://agent-skills.md/skills/wollfoo/setup-factory/threejs
- https://agent-skills.md/skills/ovachiever/droid-tings/threejs-graphics-optimizer
- https://github.com/bmad-code-org/BMAD-METHOD

### Web Search Queries

- "React Three Fiber best practices 2026"
- "Three.js mobile optimization techniques"
- "Rapier physics collision layers guide"
```

### Level 3: Update Agent Skills

Create or update skill files based on research:

**Files to Update:**

- `agents/developer/SKILLS.md` — Core developer competencies
- `agents/developer/skills/*.md` — Domain-specific skills
- `agents/developer/references/*.md` — Deep-dive documentation
- `agents/qa/SKILLS.md` — Core QA competencies
- `.claude/skills/*.md` — Shared skills

**Update Template:**

```markdown
---
name: { { skill-name } }
description: { { one-line with triggers } }
category: { { development|validation|optimization } }
depends-on: [{ { related-skills } }]
---

# {{Skill Title}}

## When to Use

- {{trigger 1}}
- {{trigger 2}}

## Quick Start

{{minimal example}}

## Anti-Patterns

❌ **DON'T:** {{common mistake}}
✅ **DO:** {{best practice}}

## Reference

- {{external-url}} — {{description}}
```

### Level 4: Scale-Adaptive Updates

Adjust skill depth based on PRD complexity:

| PRD Size   | Skill Update Depth                        |
| ---------- | ----------------------------------------- |
| 1-5 tasks  | Minimal — add anti-patterns only          |
| 6-15 tasks | Standard — update relevant skills         |
| 16+ tasks  | Deep — create new skill files, references |

## Anti-Patterns

❌ **DON'T:**

- Skip skill improvement even if task passed
- Update skills without verifying information
- Add duplicate content already in skills
- Create skills for one-off edge cases

✅ **DO:**

- Research before updating
- Verify patterns work in practice
- Cross-reference multiple sources
- Focus on reusable patterns

## Checklist

During retrospective, check:

- [ ] Any knowledge gaps identified?
- [ ] Any anti-patterns repeated?
- [ ] Any new domain encountered?
- [ ] MCP research completed?
- [ ] Skill files updated?
- [ ] Changes documented in action items?

## Reference URLs for Research

### Agent Skills Directory

- https://agent-skills.md/skills/Bbeierle12/Skill-MCP-Claude/r3f-fundamentals
- https://agent-skills.md/skills/xenitV1/claude-code-maestro/game-development
- https://agent-skills.md/skills/anthropics/skills/frontend-design
- https://agent-skills.md/skills/xenitV1/claude-code-maestro/nodejs-best-practices
- https://agent-skills.md/skills/alinaqi/claude-bootstrap/nodejs-backend
- https://agent-skills.md/skills/skillcreatorai/Ai-Agent-Skills/javascript-typescript
- https://agent-skills.md/skills/samhvw8/dot-claude/3d-graphics
- https://agent-skills.md/skills/wollfoo/setup-factory/threejs
- https://agent-skills.md/skills/Bbeierle12/Skill-MCP-Claude/building-router
- https://agent-skills.md/skills/Bbeierle12/Skill-MCP-Claude/structural-physics
- https://agent-skills.md/skills/Bbeierle12/Skill-MCP-Claude/r3f-materials
- https://agent-skills.md/skills/Bbeierle12/Skill-MCP-Claude/terrain-integration
- https://agent-skills.md/skills/ovachiever/droid-tings/threejs-graphics-optimizer

### Method References

- https://github.com/bmad-code-org/BMAD-METHOD — Scale-adaptive agent methodology

## Reference

- [agents/pm/skills/retrospective.md](retrospective.md) — Retrospective process
- [agents/pm/skills/scale-adaptive.md](scale-adaptive.md) — Scale-adaptive planning
