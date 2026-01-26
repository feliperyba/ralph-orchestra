---
name: pm-organization-task-research
description: Codebase research for PM task assignment - understand patterns, dependencies, and complexity before assigning
category: pm
user-invocable: true
model: haiku
agent: pm
degrees-of-freedom: high
---

# PM Task Research

> "Research before assignment - prevent misallocation and blockers."

## When to Use

Before assigning tasks to understand:
- Existing patterns in the codebase
- Files/components the task will touch
- Potential blockers or dependencies
- Which agent should handle the task
- Complexity estimate

---

## Research Process

1. Use `Grep` to find related implementations
2. Use `Read` to examine relevant files
3. Use `Glob` to find related components
4. Provide **structured summary** (not raw exploration)

---

## What to Research

| Area | Questions |
|------|-----------|
| **Existing Patterns** | What similar implementations exist? |
| **Dependencies** | What files/components will this task touch? |
| **Blockers** | Are there blocking issues or missing dependencies? |
| **Agent Fit** | Should this go to Developer or Tech Artist? |
| **Complexity** | Micro/Simple/Medium/Complex? |

---

## Agent Selection Guide

| Category | Default Agent | Reassign If... |
|----------|---------------|---------------|
| `architectural` | developer | Visual-heavy → techartist |
| `functional` | developer | Shader/VFX → techartist |
| `integration` | developer | - |
| `visual` | techartist | Logic-heavy → developer |
| `shader` | techartist | - |
| `polish` | techartist | Functional changes → developer |

---

## Complexity Estimation

| Level | Criteria | Example |
|-------|----------|---------|
| **Micro** | Single line, config change | Fix typo, change value |
| **Simple** | Single file, well-defined | Add utility function |
| **Medium** | 2-5 files, coordination | Add feature to system |
| **Complex** | 5+ files, new patterns | New system, refactoring |

---

## Output Format

```markdown
## Task Research: {TASK_ID}

### Task Summary
- **Title:** {title}
- **Category:** {category}
- **Description:** {brief}

### Existing Patterns
- Pattern 1: {location} - {description}
- Pattern 2: {location} - {description}

### Dependencies
- {file/path} - {reason}

### Files Modified
- {file/path} - {change}

### Blockers
- {none or list with severity}

### Recommended Agent
- {developer|techartist} - {justification}

### Complexity
- {Micro|Simple|Medium|Complex} - {justification}

### Implementation Notes
- {gotchas, areas requiring care}
```

---

## Important

- Keep analysis concise and actionable
- Don't return verbose file contents
- Focus on what PM needs for assignment
- Flag critical issues prominently
- Be realistic about complexity

---

## References

- [pm-organization-task-selection](../pm-organization-task-selection/SKILL.md) - Priority algorithm
- [dev-research-codebase-exploration](../dev-research-codebase-exploration/SKILL.md) - Exploration patterns
