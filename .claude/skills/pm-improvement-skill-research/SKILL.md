---
name: pm-improvement-skill-research
description: Multi-agent skill improvement during retrospectives - research and update all agent skills
category: pm
user-invocable: false
model: inherit
agent: pm
degrees-of-freedom: medium
---

# Skill Improvement

> "Continuous learning – improve ALL agent capabilities based on real-world experience."

**Agile Principle:** Teams improve through retrospectives - agents do too.

## Mandatory: After Every Retrospective

**This is NOT optional.** After synthesizing retrospective:

1. Set `currentTask.status = "skill_research"`
2. **RESEARCH** using MCP tools
3. **UPDATE** at least ONE skill file per agent (PM, Developer, Tech Artist, QA, Game Designer)
4. **COMMIT** the improvements
5. **THEN** set task to `"completed"`

**Minimum**: At least **FIVE** skill files updated (one per agent).

**PM must also improve at least ONE of its OWN skills.**

---

## When to Use

During `skill_research` phase when:
- Task revealed knowledge gaps
- New patterns/anti-patterns discovered
- External references could help
- Agent struggled with specific domain

---

## Quick Start

```
1. Identify skill gaps for ALL FIVE agents
2. Use MCP (WebSearch, GitHub) to research
3. Update at least ONE skill per agent
4. PM improves at least ONE of its own skills
5. Commit improvements
```

---

## Agent Skill Priority Matrix

| Agent | Skills | When to Trigger |
|-------|--------|-----------------|
| **PM** | task-selection, retrospective, prd-reorganization, self-improvement | Assignment issues, retro gaps, PRD issues |
| **Developer** | r3f-fundamentals, validation-loops, typescript-basics, r3f-physics | Code quality, build fails, type errors |
| **Tech Artist** | r3f-materials, shader-development, assets-workflow, ui-polish | Visual issues, shader errors, asset problems |
| **QA** | validation-workflow, browser-testing, bug-reporting | Missed bugs, incomplete validation |
| **Game Designer** | gdd-creation, thermite-integration, validation-playtest | GDD unclear, playtest issues |

---

## Decision Framework

| Signal | Action |
|--------|--------|
| Developer asked many clarifications | Improve Developer fundamentals skill |
| QA missed edge cases | Add testing patterns to QA skill |
| Performance issues | Research optimization skill |
| New library/API used | Create reference doc |
| Anti-pattern repeated | Add anti-pattern section |
| PM assignment struggled | Improve PM task-selection |
| PRD not reorganized | Improve PM prd-reorganization |
| GDD gaps in implementation | Improve GD gdd-creation |

---

## Progressive Process

### Level 1: Identify Gaps

For ALL FIVE agents, identify missing skills.

### Level 2: Research with MCP

**Reference URLs:**
- https://agent-skills.md/ - Community skill patterns
- https://github.com/bmad-code-org/BMAD-METHOD - Methodology

**Web Search Queries:**
- "React Three Fiber best practices 2026"
- "Three.js mobile optimization"
- "Rapier physics collision guide"

### Level 3: Update Agent Skills

**PM (MUST improve at least one):**
- `.claude/skills/pm-organization-task-selection/`
- `.claude/skills/pm-retrospective-facilitation/`
- `.claude/skills/pm-organization-prd-reorganization/`

**Developer:**
- `.claude/skills/dev-r3f-r3f-fundamentals/`
- `.claude/skills/dev-validation-feedback-loops/`
- `.claude/skills/dev-typescript-typescript-basics/`

**Tech Artist:**
- `.claude/skills/ta-r3f-materials/`
- `.claude/skills/ta-shader-development/`
- `.claude/skills/ta-assets-workflow/`

**QA:**
- `.claude/skills/qa-validation-workflow/`
- `.claude/skills/qa-browser-testing/`
- `.claude/skills/qa-reporting-bug-reporting/`

**Game Designer:**
- `.claude/skills/gd-gdd-creation/`
- `.claude/skills/gd-thermite-integration/`
- `.claude/skills/gd-validation-playtest/`

---

## Skill Update Template

```markdown
---
name: {skill-name}
description: {one-line with triggers}
category: {development|validation|optimization}
agent: {pm|developer|techartist|qa|gamedesigner}
---

# {Skill Title}

## When to Use
- {trigger 1}
- {trigger 2}

## Quick Start
{minimal example}

## Anti-Patterns
❌ **DON'T:** {mistake}
✅ **DO:** {practice}
```

---

## Anti-Patterns

| ❌ Don't | ✅ Do |
|----------|-------|
| Skip skill improvement | Always improve after retro |
| Only improve one agent | Improve ALL FIVE agents |
| Forget PM's own skills | PM improves too |
| Update without research | Research before updating |
| Add duplicate content | Cross-reference first |

---

## Minimum Requirements Checklist

- [ ] At least ONE PM skill updated (MANDATORY)
- [ ] At least ONE Developer skill updated
- [ ] At least ONE Tech Artist skill updated
- [ ] At least ONE QA skill updated
- [ ] At least ONE Game Designer skill updated
- [ ] Total: At least FIVE skills improved
- [ ] All improvements committed

---

## References

- [pm-retrospective-facilitation](../pm-retrospective-facilitation/SKILL.md) - Retro process
- [pm-organization-prd-reorganization](../pm-organization-prd-reorganization/SKILL.md) - PRD reorganization
- [pm-improvement-self-improvement](../pm-improvement-self-improvement/SKILL.md) - PM self-improvement
