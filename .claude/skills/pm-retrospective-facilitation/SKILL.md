---
name: pm-retrospective-facilitation
description: Facilitate worker retrospective after task completion - gather contributions from Developer, Tech Artist, QA
category: pm
user-invocable: false
model: inherit
agent: pm
degrees-of-freedom: medium
---

# Worker Retrospective

> "Quality over speed – every completed task deserves reflection."

**Agile Retrospective:** Iteration review after each task to gather feedback and improve process.

## Quick Start

```
1. Create retrospective.txt → 2. Set "in_retrospective" → 3. Send to workers
→ 4. EXIT → 5. On wake-up: synthesize → 6. Commit → 7. Set "retrospective_synthesized"
```

**Worker contributions go to separate files:**
- `.claude/session/retrospective-developer.json`
- `.claude/session/retrospective-techartist.json`
- `.claude/session/retrospective-qa.json`

---

## When to Use

- When `prd.json.items[{taskId}].status === "passed"` (QA validated)
- Before assigning the next task
- **NEVER skip retrospective**

---

## State Flow

```
passed → in_retrospective → retrospective_synthesized
```

**Next phases** (handled by other skills):
- `retrospective_synthesized` → `playtest_phase` (pm-retrospective-playtest-session)
- `playtest_complete` → `prd_refinement` (pm-organization-prd-reorganization)
- `task_ready` → `skill_research` (pm-improvement-skill-research)
- `completed` → next task

---

## Decision Framework

| Status | Action |
|--------|--------|
| Just passed QA | Create retrospective.txt, set `in_retrospective` |
| Sent messages | **EXIT** - watchdog restarts when messages arrive |
| On wake-up: incomplete | Check state, **EXIT again** if incomplete |
| All 3 workers contributed | Synthesize, **commit**, set `retrospective_synthesized`, **EXIT** |

---

## Process

### Step 1: Create Retrospective File

```markdown
# Retrospective: {TASK_ID} - {TASK_TITLE}

**Started**: {timestamp}
**Task**: {taskId}

---

## Task Summary

**Title**: {title}
**Category**: {category}
**Completed At**: {timestamp}

---

## Retrospective Sections

### Developer Perspective

<!-- WAITING for contribution -->

### Tech Artist Perspective

<!-- WAITING for contribution -->

### QA Perspective

<!-- WAITING for contribution -->

### PM Synthesis

<!-- WAITING for all contributions -->

---

## Completion Status

- [ ] Developer contributed
- [ ] Tech Artist contributed
- [ ] QA contributed
- [ ] PM synthesized
```

### Step 2: Send to Workers

**Send to Developer, Tech Artist, QA (NOT Game Designer):**

```powershell
Send-Message -To "developer" -Type "Retrospective" -Payload @{
    taskId = "{taskId}"
    taskTitle = "{title}"
    retrospectiveFile = ".claude/session/retrospective.txt"
}

Send-Message -To "techartist" -Type "Retrospective" -Payload @{...}
Send-Message -To "qa" -Type "Retrospective" -Payload @{...}
```

Set `prd.json.items[{taskId}].status = "in_retrospective"`

**EXIT** - watchdog wakes you when workers contribute

### Step 3: Synthesize (On Wake-Up)

**When ALL 3 contribution files exist:**

```bash
Read(".claude/session/retrospective-developer.json")
Read(".claude/session/retrospective-techartist.json")
Read(".claude/session/retrospective-qa.json")

# If any missing → EXIT and wait
# All present → merge into retrospective.txt
```

### Step 4: Commit and Exit

```bash
git add .claude/session/retrospective.txt prd.json
git commit -m "[ralph] [pm] {taskId} retrospective: Worker contributions synthesized"

# Set status = "retrospective_synthesized"
# Clean up contribution files
# EXIT
```

---

## PM Synthesis Template

```markdown
### PM Synthesis

**Summary**:
- Task accomplished: {what was done}
- Time taken: {actual vs expected}
- Challenges: {unexpected issues}

**Quality Assessment**:
- Developer insights: {from dev}
- Tech Artist insights: {from TA}
- QA validation: {from qa}

**Risk Identification**:
- Technical risks: {dependencies, performance}
- Project risks: {timeline, complexity}

**PRD Updates**:
- New tasks from findings: {list}
```

---

## Anti-Patterns

| ❌ Don't | ✅ Do |
|----------|-------|
| Skip retrospective for "simple" tasks | Always run retrospective |
| Synthesize before ALL 3 contribute | Wait for all contributions |
| Send to Game Designer | Game Designer in separate playtest phase |
| Use loops/timers to poll | Send, EXIT, let watchdog wake you |
| Forget to commit | Always commit synthesis |

---

## Checklist

**Setup:**
- [ ] Created retrospective.txt with template
- [ ] Set `status = "in_retrospective"`

**Messages:**
- [ ] Sent to Developer, Tech Artist, QA
- [ ] Did NOT send to Game Designer
- [ ] Exited to wait

**Synthesis:**
- [ ] All 3 workers contributed
- [ ] PM synthesis completed
- [ ] **Committed changes**
- [ ] Set `status = "retrospective_synthesized"`
- [ ] Cleaned up contribution files
- [ ] Exited for context reset

---

## References

- [pm-retrospective-playtest-session](../pm-retrospective-playtest-session/SKILL.md) - Playtest phase
- [pm-organization-prd-reorganization](../pm-organization-prd-reorganization/SKILL.md) - PRD refinement
- [pm-improvement-skill-research](../pm-improvement-skill-research/SKILL.md) - Skill research
