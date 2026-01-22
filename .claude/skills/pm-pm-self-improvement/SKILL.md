---
title: PM Self-Improvement
category: coordination
description: Systematic improvement of PM agent's own coordination skills during retrospectives
version: 1.0.0
---

# PM Self-Improvement

The PM agent must continuously improve its own coordination capabilities, not just worker agent skills. This skill defines the PM's self-improvement process during the `skill_research` phase.

## When to Use

Use this skill during the `skill_research` phase of each retrospective cycle. The PM must improve at least ONE of its own skills in addition to improving worker agent skills.

## PM Skill Improvement Areas

### 1. Task Selection Algorithms

**Goal**: Improve how the PM selects and assigns tasks from the PRD.

**Areas to Research**:
- Dependency graph analysis for optimal task ordering
- Risk-based task prioritization
- Agent capability matching
- Parallelization opportunities

**Research Sources**:
- BMAD-METHOD orchestration patterns
- Project management algorithms (CPM, PERT)
- Agile task refinement techniques

### 2. Risk Assessment

**Goal**: Better identify and mitigate project risks before they become blockers.

**Areas to Research**:
- Technical debt detection patterns
- Scope creep identification
- Integration risk analysis
- Bottleneck prediction

**Research Sources**:
- Software project risk management frameworks
- Technical debt metrics and quantification
- Dependency analysis tools and techniques

### 3. Stakeholder Communication

**Goal**: More effective coordination patterns between agents and with the human user.

**Areas to Research**:
- Message clarity and precision
- Status reporting granularity
- Expectation management
- Handoff protocols

**Research Sources**:
- Agent coordination protocols (agents.md, agent-skills.md)
- Distributed systems communication patterns
- Agile ceremony facilitation

### 4. Design Integration (GDD-to-PRD)

**Goal**: Better translate Game Design Documents into actionable PRD tasks.

**Areas to Research**:
- Design document parsing and comprehension
- Requirement extraction techniques
- Task decomposition patterns
- Design validation criteria

**Research Sources**:
- GDD creation best practices (Game Designer agent skills)
- Requirements engineering methodology
- User story decomposition techniques

### 5. Retrospective Facilitation

**Goal**: Run more effective retrospectives that generate actionable insights.

**Areas to Research**:
- Facilitation techniques for distributed agents
- Insight extraction patterns
- Action item prioritization
- Continuous improvement frameworks

**Research Sources**:
- Agile retrospective formats
- Kaizen and continuous improvement
- Team dynamics in distributed systems

## PM Self-Improvement Process

During `skill_research` phase:

### Step 1: Analyze PM Performance

Review the retrospective for PM-specific issues:

```powershell
# PM Performance Questions
1. Was task assignment optimal? (task-selection.md)
2. Did I anticipate risks that materialized? (risk assessment)
3. Were messages clear and timely? (communication)
4. Did I extract tasks from GDD properly? (design integration)
5. Was the retrospective synthesis comprehensive? (facilitation)
```

### Step 2: Identify Priority Improvement

Select ONE PM skill area with the highest impact:

```markdown
| Impact | Skill Area               | Trigger Questions                          |
|--------|--------------------------|--------------------------------------------|
| HIGH   | Task Selection           | Tasks blocked, wrong agent assigned?       |
| HIGH   | Design Integration       | PRD gaps vs GDD?                           |
| MEDIUM | Risk Assessment          | Surprises/blockers occurred?               |
| MEDIUM | Retrospective Facilitation | Insights missed or shallow?              |
| LOW    | Communication           | Messages misunderstood or delayed?         |
```

### Step 3: Research PM Knowledge

Use MCP tools to research:

```powershell
# Research via MCP GitHub
- bmad-code-org/BMAD-METHOD: orchestration patterns

# Research via MCP Web Search
- "AI agent orchestration best practices"
- "multi-agent PM coordination"
- "requirements extraction from design docs"

# Internal Analysis
- Review past retrospectives in .claude/session/retrospective-history/
- Identify patterns in PM decisions that could be improved
```

### Step 4: Update PM Skill File

Apply findings to the relevant PM skill:

```powershell
# Files to Update (PICK ONE)
- agents/pm/skills/task-selection.md
- agents/pm/skills/prd-reorganization.md
- agents/pm/skills/retrospective.md
- agents/pm/skills/scale-adaptive.md
- agents/pm/AGENT.md

# Commit Pattern
git add agents/pm/skills/[updated-file].md
git commit -m "Retrospective [N]: Improved PM [skill-area] skill"
```

### Step 5: Update PM Behavior (if needed)

If the improvement requires AGENT.md changes:

```powershell
# Update AGENT.md with new:
- State flow changes
- Message type handling
- Coordination patterns
- Decision criteria
```

## PM Skill Quality Checklist

After each self-improvement, verify:

- [ ] The updated skill has measurable improvement criteria
- [ ] The skill includes concrete examples or patterns
- [ ] The improvement is integrated into AGENT.md if needed
- [ ] The change is committed with descriptive message
- [ ] Next retrospective will validate the improvement

## PM Skill Improvement Examples

### Example 1: Task Selection Improvement

**Issue Found**: Developer got stuck because task required design approval first.

**Improvement**: Add prerequisite check to task-selection.md

```markdown
## Dependency Verification

Before assigning a task:
1. Check all dependencies are in `passed` or `completed` status
2. Verify no tasks with `priority: high` are blocking
3. Confirm Game Designer has approved design-dependent tasks
```

### Example 2: Design Integration Improvement

**Issue Found**: PRD missing tasks for GDD section on multiplayer sync.

**Improvement**: Add GDD scanning pattern to prd-reorganization.md

```markdown
## GDD-to-PRD Extraction Pattern

For each GDD section:
1. Identify "must have" features
2. Create at least one PRD task per feature
3. Set priority: high for core gameplay, medium for polish
4. Add gddReference field linking back to source
```

### Example 3: Risk Assessment Improvement

**Issue Found**: Physics integration delayed due to Rapier version conflict.

**Improvement**: Add dependency risk check to scale-adaptive.md

```markdown
## Risk Indicators

Red flags before task assignment:
- Package version conflicts
- Missing MCP tools for required research
- Agent skill gaps for task complexity
```

## Minimum Self-Improvement Per Retrospective

**REQUIRED**: At least ONE PM skill file updated per retrospective cycle.

This ensures the PM agent improves at the same rate as worker agents.

## Related Skills

- [skill-improvement.md](./skill-improvement.md) - Overall skill improvement coordination
- [retrospective.md](./retrospective.md) - When self-improvement occurs
- [task-selection.md](./task-selection.md) - Core PM capability
- [prd-reorganization.md](./prd-reorganization.md) - Design integration
