---
name: pm-improvement-self-improvement
description: PM self-improvement during retrospectives - enhance coordination capabilities
category: pm
user-invocable: false
model: inherit
agent: pm
degrees-of-freedom: medium
---

# PM Self-Improvement

> "PM must improve alongside workers - enhance coordination capabilities each retrospective."

**Agile Retrospective:** Continuous improvement applies to coordination processes too.

## When to Use

During `skill_research` phase - PM MUST improve at least ONE of its own skills.

## PM Improvement Areas

| Area | Focus | Research Sources |
|------|-------|------------------|
| **Task Selection** | Dependency analysis, risk prioritization, parallelization | BMAD-METHOD, project management algorithms |
| **Risk Assessment** | Debt detection, scope creep, bottleneck prediction | Risk management frameworks |
| **Communication** | Message clarity, status reporting, handoff protocols | Agent coordination protocols |
| **Design Integration** | GDD-to-PRD translation, task decomposition | Requirements engineering |
| **Facilitation** | Insight extraction, action prioritization | Agile retrospective formats |

## Process

### Step 1: Analyze PM Performance

```
1. Was task assignment optimal?
2. Did I anticipate risks that materialized?
3. Were messages clear and timely?
4. Did I extract tasks from GDD properly?
5. Was retrospective synthesis comprehensive?
```

### Step 2: Identify Priority Improvement

| Impact | Skill Area | Trigger Questions |
|--------|------------|-------------------|
| HIGH | Task Selection | Tasks blocked? Wrong agent? |
| HIGH | Design Integration | PRD gaps vs GDD? |
| MEDIUM | Risk Assessment | Surprises/blockers? |
| MEDIUM | Facilitation | Insights missed? |
| LOW | Communication | Messages misunderstood? |

### Step 3: Research PM Knowledge

```powershell
# MCP GitHub
- bmad-code-org/BMAD-METHOD: orchestration patterns

# MCP Web Search
- "AI agent orchestration best practices"
- "multi-agent PM coordination"

# Internal Analysis
- Review past retrospectives
- Identify PM decision patterns
```

### Step 4: Update PM Skill File

```powershell
# Files to Update (PICK ONE)
- .claude/skills/pm-organization-task-selection/
- .claude/skills/pm-organization-prd-reorganization/
- .claude/skills/pm-retrospective-facilitation/
- .claude/skills/pm-organization-scale-adaptive/
- agents/pm/AGENT.md

git add [updated-file]
git commit -m "Retrospective [N]: Improved PM [skill-area] skill"
```

## Examples

### Example 1: Task Selection

**Issue**: Developer blocked by design approval.

**Fix**: Add prerequisite check to task-selection.

```markdown
## Dependency Verification
Before assigning:
1. Check all dependencies in `passed` or `completed`
2. Verify no `priority: high` tasks blocking
3. Confirm GD approval for design-dependent tasks
```

### Example 2: Design Integration

**Issue**: PRD missing multiplayer sync tasks.

**Fix**: Add GDD scanning pattern.

```markdown
## GDD-to-PRD Extraction
For each GDD section:
1. Identify "must have" features
2. Create one PRD task per feature
3. Set priority: high (core), medium (polish)
4. Add gddReference field
```

### Example 3: Risk Assessment

**Issue**: Physics delayed by version conflict.

**Fix**: Add dependency risk check.

```markdown
## Risk Indicators
Red flags before assignment:
- Package version conflicts
- Missing MCP tools
- Agent skill gaps
```

## Minimum Requirement

**REQUIRED**: At least ONE PM skill file updated per retrospective.

## Checklist

- [ ] PM performance analyzed
- [ ] Priority improvement identified
- [ ] Research completed
- [ ] At least ONE PM skill updated
- [ ] Change committed
- [ ] Next retrospective will validate

---

## References

- [pm-improvement-skill-research](../pm-improvement-skill-research/SKILL.md) - Overall skill improvement
- [pm-organization-task-selection](../pm-organization-task-selection/SKILL.md) - Task selection
- [pm-organization-prd-reorganization](../pm-organization-prd-reorganization/SKILL.md) - Design integration
