---
name: pm-organization-prd-reorganization
description: Extract and reorganize PRD tasks from GDD updates and retrospective findings
category: pm
user-invocable: false
model: inherit
agent: pm
degrees-of-freedom: medium
---

# PRD Reorganization

> "Translate design updates and retrospectives into actionable tasks."

## When to Use

During `prd_analysis` phase (after retrospective, before skill research):

```
passed → in_retrospective → prd_analysis → skill_research → completed
```

**Triggered by:**
- GDD update from Game Designer
- Retrospective findings (gaps, debt, bugs)
- Process improvements
- Technical debt items

---

## PRD Backlog Architecture (v3.1.0+)

| File | Contains | Size |
|------|----------|------|
| `prd.json` | Top 5 active queue | ~5 tasks |
| `prd_backlog.json` | Remaining backlog | ~70 tasks |

**When reorganizing:**
- Read both files for complete picture
- TIER_0/TIER_1 → `prd.json.items`
- Lower priority → `prd_backlog.json.backlogItems`
- Maintain max 5 in `prd.json`

---

## GDD-to-PRD Extraction

### Step 1: Read GDD

```
READ docs/design/gdd.md
```

### Step 2: Parse Sections

| GDD Section | Task Category |
|-------------|---------------|
| Gameplay | architectural |
| UI/UX | functional |
| Multiplayer | architectural |
| Audio | functional |
| Visuals | visual |
| Performance | technical_debt |

### Step 3: Check Coverage

For each requirement, check if PRD covers it:

```javascript
const allItems = [...prd.items, ...backlog.backlogItems];

// Search for related task by keyword
// Check if acceptanceCriteria covers requirement
// Mark: COVERED / PARTIALLY_COVERED / NOT_COVERED
```

### Step 4: Create Missing Tasks

```json
{
  "id": "design-001",
  "title": "Implement core gameplay loop from GDD",
  "category": "architectural",
  "priority": "high",
  "status": "pending",
  "passes": false,
  "agent": "developer",
  "dependencies": [],
  "gddReference": "docs/design/gdd.md#2",
  "acceptanceCriteria": ["Player can move with WASD", "Player can jump"]
}
```

**Task ID pattern:** `design-NNN` for GDD-derived tasks.

---

## Retrospective-to-PRD

| Finding Type | Action |
|--------------|--------|
| Implementation gap | Create task to complete |
| Design deviation | Create task to align |
| Technical debt | Create task (category: technical_debt) |
| Process issue | Update AGENT.md |
| Bug found | Create task (category: bug_fix) |

**Task ID pattern:** `retro-NNN` for retrospective-derived tasks.

---

## Reorganization Workflow

```
1. READ docs/design/gdd.md
2. READ .claude/session/retrospective.txt
3. READ prd.json + prd_backlog.json

4. EXTRACT requirements from GDD
5. EXTRACT action items from retrospective

6. FOR each item:
   a. Check if covered by existing task
   b. If NOT: CREATE new task
   c. If PARTIAL: UPDATE existing

7. REORGANIZE priorities and dependencies

8. DETERMINE placement:
   - TIER_0/1 → prd.json
   - Others → prd_backlog.json

9. WRITE both files
10. COMMIT with summary
11. SEND prd_reorganized message
```

---

## Task Creation Guidelines

### Decomposition

**✓ DO:** Break down large features
```
"Implement player movement" →
  - design-001: "WASD movement"
  - design-002: "Jump mechanics"
  - design-003: "Sprint mechanics"
```

**✗ DON'T:** Create monolithic tasks
```
"Implement all player movement and combat"
```

### Acceptance Criteria

**✓ GOOD:** Specific and testable
```
"Player velocity matches input within 0.1s"
"Jump height reaches 2 meters"
```

**✗ BAD:** Vague and untestable
```
"Movement feels good"
"Make jumping work better"
```

---

## Checklist

Before completing `prd_analysis`:

- [ ] All GDD requirements have PRD tasks
- [ ] All retrospective findings addressed
- [ ] Dependencies are acyclic (check both files)
- [ ] No duplicate tasks (check both files)
- [ ] All new tasks have acceptance criteria
- [ ] prd.json and prd_backlog.json are valid JSON
- [ ] prd.json.items.length <= 5
- [ ] Changes committed to git
- [ ] Workers notified via prd_reorganized message

---

## prd_reorganized Message

```json
{
  "type": "prd_reorganized",
  "from": "pm",
  "timestamp": "<ISO timestamp>",
  "summary": {
    "newTasks": 3,
    "updatedTasks": 2,
    "gddVersion": "1.2.0",
    "newTaskIds": ["design-001", "design-002", "retro-001"]
  }
}
```

---

## References

- [pm-retrospective-facilitation](../pm-retrospective-facilitation/SKILL.md) - Retro findings
- [pm-organization-task-selection](../pm-organization-task-selection/SKILL.md) - Task assignment
- [pm-organization-scale-adaptive](../pm-organization-scale-adaptive/SKILL.md) - Scale detection
