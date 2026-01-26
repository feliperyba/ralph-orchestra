---
name: pm-organization-scale-adaptive
description: Adjust planning depth and agent behavior based on PRD complexity level
category: pm
user-invocable: false
model: inherit
agent: pm
degrees-of-freedom: medium
---

# Scale-Adaptive Planning

> "Right-size the process – small projects need less ceremony, large projects need more structure."

## Quick Start

```javascript
// Determine scale (reads both PRD files v3.1.0+)
const prd = readJson("prd.json");
const backlog = readJson(prd.backlogFile || "prd_backlog.json");
const allItems = [...prd.items, ...backlog.backlogItems];

const taskCount = allItems.filter((i) => !i.passes).length;
const scale = taskCount <= 3 ? 0 : taskCount <= 8 ? 1 : taskCount <= 15 ? 2
             : taskCount <= 30 ? 3 : 4;

const config = SCALE_CONFIG[scale];
```

---

## Decision Framework

| Scale | Tasks | Process | Retrospective | Skill Updates |
|-------|-------|---------|---------------|---------------|
| **0 - Micro** | 1-3 | Minimal | Brief notes | None |
| **1 - Small** | 4-8 | Light | Quick review | Anti-patterns only |
| **2 - Medium** | 9-15 | Standard | Full process | Update relevant |
| **3 - Large** | 16-30 | Comprehensive | Deep analysis | Create new skills |
| **4 - Enterprise** | 31+ | Full methodology | Multi-phase | Full skill suite |

---

## Scale Levels

### Level 0: Micro (1-3 tasks)

- Skip formal retrospective file
- Use inline progress notes
- No skill improvement phase
- Simple: implement → validate → done

### Level 1: Small (4-8 tasks)

- Brief retrospective (inline in progress.txt)
- Quick learnings capture
- Anti-pattern documentation only
- Single-pass validation

### Level 2: Medium (9-15 tasks)

- Full file-based retrospective
- Agent contributions required
- Skill updates for gaps
- Risk identification

### Level 3: Large (16-30 tasks)

- Deep retrospective analysis
- Milestone reviews every 5 tasks
- Create new skill files
- Reference documentation
- Risk heat map tracking

### Level 4: Enterprise (31+ tasks)

- Multi-phase planning
- Sprint boundaries (5-8 tasks per sprint)
- Full skill suite creation
- Architectural decision records
- Quality gates

---

## Scale Detection

```javascript
function detectScale() {
  const prd = readJson("prd.json");
  const backlog = readJson(prd.backlogFile || "prd_backlog.json");
  const allItems = [...prd.items, ...backlog.backlogItems];

  const remaining = allItems.filter((i) => !i.passes).length;

  // Base scale on task count
  let scale = remaining <= 3 ? 0 : remaining <= 8 ? 1 : remaining <= 15 ? 2
            : remaining <= 30 ? 3 : 4;

  // Adjust for complexity
  const complexity = allItems.reduce((sum, i) =>
    sum + (i.category === 'architectural' ? 3 : i.category === 'integration' ? 2 : 1), 0
  );
  if (complexity / allItems.length > 2) scale = Math.min(4, scale + 1);

  return scale;
}
```

---

## Anti-Patterns

| ❌ Don't | ✅ Do |
|----------|-------|
| Apply enterprise process to 3-task projects | Right-size to actual scope |
| Skip retrospectives for large projects | Adjust depth, don't skip |
| Use fixed process regardless of size | Reassess at each retro |
| Ignore scale changes during project | Document in prd.session |

---

## Checklist

**At session start:**
- [ ] Count remaining tasks
- [ ] Calculate complexity score
- [ ] Determine initial scale (0-4)
- [ ] Document in `prd.session.scale`

**At each retrospective:**
- [ ] Reassess remaining tasks
- [ ] Update scale if changed
- [ ] Adjust process depth accordingly

---

## References

- [pm-retrospective-facilitation](../pm-retrospective-facilitation/SKILL.md) - Retro process
- [pm-improvement-skill-research](../pm-improvement-skill-research/SKILL.md) - Skill updates
