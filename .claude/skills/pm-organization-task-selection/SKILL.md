---
name: pm-organization-task-selection
description: Priority algorithm for selecting next PRD task based on category, dependencies, and parallel work opportunities
category: pm
user-invocable: false
model: inherit
agent: pm
degrees-of-freedom: medium
---

# Task Selection

> "Fail fast on risky work – tackle hard problems before easy wins."

## Quick Start

```javascript
// 1. Read both PRD files (v3.1.0+)
const prd = readJson("prd.json");
const backlog = readJson(prd.backlogFile || "prd_backlog.json");
const allItems = [...prd.items, ...backlog.backlogItems];

// 2. Filter incomplete and unblocked
const incomplete = allItems.filter((item) => !item.passes);
const unblocked = incomplete.filter((item) =>
  item.dependencies.every((depId) => allItems.find((i) => i.id === depId)?.passes)
);

// 3. Sort by priority and select first
const next = unblocked.sort(priorityComparator)[0];
```

---

## Priority Order

| Priority | Category | Examples |
|----------|----------|----------|
| 1 (Highest) | `architectural` | State stores, API design, core systems |
| 2 | `integration` | API integration, multiplayer |
| 3 | `spike` / `unknown` | Exploratory work, reduces uncertainty |
| 4 | `functional` | Standard feature implementation |
| 5 (Lowest) | `polish` | UI, optimization, documentation |

---

## Parallel Assignment Check (MANDATORY)

**⚠️ FIRST: Check if BOTH Developer and Tech Artist are idle for parallel work.**

### Conditions

| Condition | Check |
|-----------|-------|
| Both agents idle | `prd.agents.developer.status === "idle"` AND `prd.agents.techartist.status === "idle"` |
| Non-conflicting paths | Tasks in different directories (e.g., `src/hooks/` vs `src/assets/`) |
| No shared deps | Tasks don't depend on same dependencies |

### Conflict Detection

| Developer Category | Tech Artist Category | Safe? |
|-------------------|---------------------|-------|
| `architectural` (src/hooks, src/stores) | `visual` (src/assets) | ✅ Yes |
| `functional` (src/server) | `shader` (src/vfx) | ✅ Yes |
| `integration` (src/utils) | `polish` (src/styles) | ✅ Yes |
| `architectural` (components) | `visual` (components) | ❌ No - same directory |

### Parallel Algorithm

```javascript
if (developerIdle && techartistIdle) {
  const devTask = findNextTaskForAgent("developer", allItems);
  const artistTask = findNextTaskForAgent("techartist", allItems);

  if (!areTasksConflicting(devTask, artistTask)) {
    assignTask(devTask, "developer");  // 5-step process
    assignTask(artistTask, "techartist");  // 5-step process
    return "parallel_assigned";
  }
}
// Fall through to single-task selection
```

---

## PRD Backlog Architecture (v3.1.0+)

| File | Contains | Size | Who Reads |
|------|----------|------|-----------|
| `prd.json` | Top 5 active queue | ~5 tasks | All agents |
| `prd_backlog.json` | Remaining backlog | ~70 tasks | PM, Game Designer |

**Refill when active queue < 5 tasks:**

```javascript
if (prd.items.length < 5) {
  const backlog = readJson(prd.backlogFile);
  const candidates = backlog.backlogItems.filter(item =>
    !item.passes && item.dependencies.every(depId =>
      allItems.find(t => t.id === depId)?.passes === true
    )
  ).sort(priorityComparator);

  if (candidates.length > 0) {
    const toMove = candidates[0];
    backlog.backlogItems = backlog.backlogItems.filter(i => i.id !== toMove.id);
    prd.items.push(toMove);
    writeJson("prd_backlog.json", backlog);
    writeJson("prd.json", prd);
  }
}
```

---

## Category → Agent Mapping

| Category | Default Agent | Reassign If... |
|----------|---------------|----------------|
| `architectural` | developer | Visual-heavy → techartist |
| `functional` | developer | Shader/VFX work → techartist |
| `integration` | developer | - |
| `visual` | techartist | Logic-heavy → developer |
| `shader` | techartist | - |
| `polish` | techartist | Functional changes → developer |

---

## Assignment Checklist

Before assigning:

- [ ] `prd.session.currentTask === null`
- [ ] NOT in retrospective/playtest phases
- [ ] Previous task status is `"completed"`
- [ ] Acceptance criteria exists (from Game Designer)
- [ ] All dependencies have `passes: true`
- [ ] Worker heartbeats fresh (< 60s)

**⚠️ Phases that MUST complete before assignment:**

```
passed → in_retrospective → retrospective_synthesized
       → playtest_phase → playtest_complete
       → prd_refinement → task_ready
       → skill_research → completed
```

---

## Anti-Patterns

| ❌ Don't | ✅ Do |
|----------|-------|
| Select tasks with unmet dependencies | Verify deps have `passes: true` |
| Assign while currentTask not null | Wait for `"completed"` status |
| Skip retrospective for speed | Complete all phases |
| Assign parallel tasks with same paths | Check for conflicts |
| Only read prd.json | Read both PRD files |
| Skip backlog refill | Auto-refill when < 5 tasks |

---

## 5-Step Atomic Assignment

1. Update PRD: `status: "assigned"`, `assignedAt`, `agent`
2. Update `prd.session.currentTask`
3. Update `prd.agents.{agent}` status
4. Send message via named pipe
5. Log to `.claude/session/handoff-log.json`

---

## References

- [pm-workflow](../pm-workflow/SKILL.md) - Full PM workflow
- [pm-organization-task-research](../pm-organization-task-research/SKILL.md) - Codebase research
- [shared-ralph-core](../shared-ralph-core/SKILL.md) - Core concepts
