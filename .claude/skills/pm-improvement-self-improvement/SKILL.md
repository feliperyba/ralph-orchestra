---
name: pm-improvement-self-improvement
description: PM self-improvement patterns and reflection practices
category: improvement
---

# PM Self-Improvement

> "The PM must model continuous learning - you cannot orchestrate what you don't practice."

## When to Use This Skill

Use during `skill_research` phase to improve PM's own capabilities.

## PM Skill Areas for Self-Improvement

| Area | Skills to Improve | Triggers |
|-------|-------------------|-----------|
| Task Selection | pm-organization-task-selection, prioritization algorithms | Tasks skipped, wrong priority order |
| PRD Management | pm-organization-prd-reorganization, lifecycle management | Completed tasks not moved, backlog not refilled |
| Coordination | shared-worktree, parallel assignment | Build conflicts between agents |
| Communication | Agent communication protocols, message routing | Missed messages, delayed responses |

## Self-Improvement Reflection Framework

After each task cycle, reflect on these areas:

### 1. Task Assignment Quality

```markdown
**Self-Assessment Questions**:
- Did I select the highest priority unblocked task?
- Were all dependencies verified before assignment?
- Did I check for parallel assignment opportunities?
- Was the task moved from backlog to active queue properly?

**Improvement Actions**:
- Update task selection algorithm in pm-organization-task-selection
- Add new prioritization rules based on learnings
- Document edge cases encountered
```

### 2. PRD Lifecycle Management

```markdown
**Self-Assessment Questions**:
- Were completed tasks moved to prd_completed.json promptly?
- Was the backlog refilled when items dropped below 5?
- Are the stats (completed, pending, backlog) accurate?
- Did I maintain the 3-file lifecycle correctly?

**Improvement Actions**:
- Update cleanup procedures in pm-workflow
- Add PRD lifecycle automation
- Improve stats tracking accuracy
```

### 3. Agent Coordination

```markdown
**Self-Assessment Questions**:
- Did I detect when both Developer and Tech Artist were idle?
- Did I check for file conflicts before parallel assignment?
- Were status updates sent correctly to watchdog?
- Did I prevent worktree conflicts?

**Improvement Actions**:
- Update conflict detection in pm-organization-task-selection
- Improve parallel assignment checks
- Document safe parallel task combinations
```

### 4. Communication Quality

```markdown
**Self-Assessment Questions**:
- Were my messages clear and actionable?
- Did I use proper message format and IDs?
- Were status updates sent at appropriate times?
- Did I respond to questions from agents promptly?

**Improvement Actions**:
- Update message templates in shared-core
- Improve response timeliness
- Document communication patterns
```

## PM Anti-Patterns to Avoid

❌ **DON'T:**

- Skip skill improvement after task completion
- Only improve worker skills, never your own
- Assign tasks without checking dependencies
- Forget to move completed tasks from active queue
- Ignore parallel assignment opportunities
- Leave completed tasks in prd.json too long

✅ **DO:**

- Always improve at least one PM skill per retrospective
- Verify PRD lifecycle after every task completion
- Check for parallel work opportunities before single assignment
- Move completed tasks to prd_completed.json promptly
- Keep stats accurate across all PRD files
- Send status updates when starting and finishing work

## Self-Improvement Triggers

| Trigger | Action |
|----------|--------|
| Task failed after 3 retries | Analyze why, improve task spec |
| QA found bugs in "clean" code | Review code review patterns |
| Agent asked for clarification | Update relevant skill |
| PRD reorganization needed | Improve prd-reorganization patterns |
| Worktree conflict occurred | Improve conflict detection |
| Missed parallel opportunity | Add parallel check to task selection |

## Continuous Learning Checklist

After each retrospective, verify:

- [ ] **PM Skill Improved** - At least one PM skill updated
- [ ] **Reflection Documented** - Self-assessment completed
- [ ] **Pattern Identified** - New anti-pattern added
- [ ] **Research Conducted** - MCP tools used for learning
- [ ] **Committed** - All improvements committed to git

## Reference

- [pm-workflow](../pm-worflow/) — Complete PM workflow
- [pm-organization-task-selection](../pm-organization-task-selection/) — Task assignment
- [pm-organization-prd-reorganization](../pm-organization-prd-reorganization/) — PRD lifecycle
- [shared-core](../shared-core/) — Communication protocols

---

## Skill Improvement Sources

**Research from feat-027 (Star Rating Preview)**:
- Learned: Phaser UI animation patterns, real-time updates
- Applied to: ta-ui-polish, qa-phaser-unit-testing, dev-typescript-advanced, gd-gdd-creation
- PM Lesson: Always document UI animation specifications in GDD for clarity
