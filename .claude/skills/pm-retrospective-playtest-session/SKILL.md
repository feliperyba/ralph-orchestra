---
name: pm-retrospective-playtest-session
description: Request and process playtest session from Game Designer after retrospective synthesis
category: pm
user-invocable: false
model: inherit
agent: pm
degrees-of-freedom: medium
---

# Playtest Session

> "Validate implementation through focused Game Designer playtesting."

**Agile Principle:** Validate working software with stakeholders before proceeding.

## Quick Start

```
1. Send Playtest request → 2. Set "playtest_phase" → 3. EXIT
→ 4. Process report → 5. Update PRD → 6. Set "playtest_complete"
```

---

## When to Use

- When `currentTask.status === "retrospective_synthesized"`
- Worker retrospective is complete and committed
- Before PRD refinement phase

---

## State Flow

```
retrospective_synthesized → playtest_phase → playtest_complete
```

---

## Decision Framework

| Status | Action |
|--------|--------|
| `retrospective_synthesized` | Send `Playtest`, set `playtest_phase`, exit |
| `playtest_phase` | Wait for `playtest_session_report` |
| Report received | Review, update PRD, commit, set `playtest_complete`, exit |
| `playtest_complete` | Proceed to PRD refinement |

---

## Process

### Step 1: Send Playtest Request

```powershell
Send-Message -To "gamedesigner" -Type "Playtest" -Payload @{
    taskId = "{taskId}"
    taskTitle = "{title}"
    retrospectiveComplete = $true
    context = "Validate implementation through playtest"
    focus = "all"
    gddReference = "docs/design/gdd.md"
}

# Set currentTask.status = "playtest_phase"
# Exit for context reset
```

### Step 2: Process Report (On Wake-Up)

```powershell
# When Playtest message received:
if ($Message.type -eq "Playtest") {
    # Validate: playwrightUsed=true, visionMcpUsed=true
    # If failed: request re-run
    # If passed:
    #   - Review findings
    #   - Create tasks for issues
    #   - Update PRD
    #   - Commit changes
    #   - Set status = "playtest_complete"
    #   - Exit
}
```

---

## Playtest Message (PM → Game Designer)

```json
{
  "type": "Playtest",
  "from": "pm",
  "to": "gamedesigner",
  "payload": {
    "taskId": "feat-001",
    "taskTitle": "{title}",
    "retrospectiveComplete": true,
    "context": "Validate implementation through playtest",
    "focus": "all",
    "gddReference": "docs/design/gdd.md"
  }
}
```

---

## Playtest Report (Game Designer → PM)

```json
{
  "type": "Playtest",
  "from": "gamedesigner",
  "to": "pm",
  "payload": {
    "taskId": "feat-001",
    "screenshots": ["playtest-start.png", "playtest-during.png"],
    "playwrightUsed": true,
    "visionMcpUsed": true,
    "findings": "Gameplay working, visual polish needs improvement",
    "gddCompliance": "pass",
    "issues": [],
    "recommendations": []
  }
}
```

---

## Anti-Patterns

| ❌ Don't | ✅ Do |
|----------|-------|
| Skip playtest | Always request playtest |
| Accept without Playwright | Verify `playwrightUsed: true` |
| Accept without Vision MCP | Verify `visionMcpUsed: true` |
| Forget to commit PRD changes | Commit if issues found |
| Skip updating PRD | Update with findings |

---

## Checklist

**Before request:**
- [ ] Worker retrospective complete
- [ ] Retrospective synthesis committed
- [ ] Status is `retrospective_synthesized`

**After report:**
- [ ] Playwright MCP used
- [ ] Vision MCP used
- [ ] At least 3 screenshots
- [ ] GDD compliance documented
- [ ] PRD updated if issues found
- [ ] Changes committed
- [ ] Status set to `playtest_complete`
- [ ] Exited for context reset

---

## References

- [pm-retrospective-facilitation](../pm-retrospective-facilitation/SKILL.md) - Worker retro
- [pm-organization-prd-reorganization](../pm-organization-prd-reorganization/SKILL.md) - PRD refinement
