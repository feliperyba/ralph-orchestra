---
name: retrospective
description: Facilitate file-based retrospective after task completion with all agents (Developer, QA, Game Designer)
category: coordination
depends-on: []
---

# Retrospective Skill

> "Quality over speed – every completed task deserves reflection."

## When to Use This Skill

Use when:

- `currentTask.status === "passed"` (QA validated)
- Before assigning the next task
- NEVER skip retrospective

## Quick Start

1. Create `.claude/session/retrospective.txt` with template
2. Set `currentTask.status = "in_retrospective"`
3. **CRITICAL**: Send `retrospective_initiate` to **ALL THREE** agents (Developer, QA, AND Game Designer)
4. Send `playtest_request` to Game Designer (separate message for Playwright-based playtesting)
5. Poll for agent contributions every 30 seconds
6. Synthesize when Developer, QA, AND Game Designer all contribute
7. Set `currentTask.status = "prd_analysis"` and reorganize PRD
8. Set `currentTask.status = "skill_research"` and improve skills
9. Set `currentTask.status = "completed"`
10. Delete retrospective.txt and assign next task

## State Flow

```
passed → in_retrospective → prd_analysis → skill_research → completed
```

## Decision Framework

| Status                        | Action                                         |
| ----------------------------- | ---------------------------------------------- |
| Just passed QA                | Create retrospective.txt, set in_retrospective |
| Developer not contributed     | Wait 30s, poll again                           |
| QA not contributed            | Wait 30s, poll again                           |
| Game Designer not contributed | Wait 30s, poll again                           |
| All THREE contributed         | Synthesize and move to prd_analysis            |
| PRD analysis complete         | Move to skill_research                         |
| Skill research complete       | Set status completed, assign next task         |

## Progressive Guide

### Level 1: Create Retrospective File

```markdown
# Retrospective: {{TASK_ID}} - {{TASK_TITLE}}

**Started**: {{ISO_TIMESTAMP}}
**Task**: {{TASK_ID}}

## Status: WAITING_FOR_AGENTS

---

## Task Summary

**Title**: {{TASK_TITLE}}
**Category**: {{CATEGORY}}
**Completed At**: {{ISO_TIMESTAMP}}

## Retrospective Sections

### Developer Perspective (to be filled by Developer Agent)

<!-- WAITING for developer to add their points -->

### QA Perspective (to be filled by QA Agent)

<!-- WAITING for QA to add their points -->

### Game Designer Perspective (to be filled by Game Designer Agent)

<!-- WAITING for Game Designer playtest report -->

### PM Synthesis (to be filled by PM Agent)

<!-- WAITING for all THREE agents to contribute -->

---

## Completion Status

- [ ] Developer contributed
- [ ] QA contributed
- [ ] Game Designer contributed (playtest report)
- [ ] PM synthesized and completed

## Action Items

<!-- To be filled by PM after synthesis -->
```

### Level 2: Track Agent Contributions

```javascript
// Check if Developer contributed
const devSection = retrospective.match(/### Developer Perspective\n([\s\S]*?)###/);
const devContributed = devSection && !devSection[1].includes('WAITING');

// Check if QA contributed
const qaSection = retrospective.match(/### QA Perspective\n([\s\S]*?)###/);
const qaContributed = qaSection && !qaSection[1].includes('WAITING');

// Check if Game Designer contributed
const gdSection = retrospective.match(/### Game Designer Perspective\n([\s\S]*?)###/);
const gdContributed = gdSection && !gdSection[1].includes('WAITING');

// Update checkboxes
if (devContributed) updateCheckbox('Developer contributed', true);
if (qaContributed) updateCheckbox('QA contributed', true);
if (gdContributed) updateCheckbox('Game Designer contributed (playtest report)', true);
```

### Level 2.5: Send Retrospective Messages (CRITICAL)

**You MUST send TWO types of messages:**

```powershell
# 1. Send retrospective_initiate to ALL THREE agents
. .\\.claude\\scripts\\message-queue.ps1

# To Developer
Send-AgentMessage -From "pm" -To "developer" -Type "retrospective_initiate" -Payload @{
    taskId = $currentTask.id
    retrospectiveFile = ".claude/session/retrospective.txt"
} -Priority "normal"

# To QA
Send-AgentMessage -From "pm" -To "qa" -Type "retrospective_initiate" -Payload @{
    taskId = $currentTask.id
    retrospectiveFile = ".claude/session/retrospective.txt"
} -Priority "normal"

# To Game Designer
Send-AgentMessage -From "pm" -To "gamedesigner" -Type "retrospective_initiate" -Payload @{
    taskId = $currentTask.id
    retrospectiveFile = ".claude/session/retrospective.txt"
} -Priority "normal"

# 2. Send playtest_request to Game Designer (separate message for playtesting)
Send-AgentMessage -From "pm" -To "gamedesigner" -Type "playtest_request" -Payload @{
    taskId = $currentTask.id
    focus = "all"
    scope = "current_task"
} -Priority "normal"
```

**Message Flow:**

```
PM                    Developer               QA               GameDesigner
 │                        │                    │                     │
 │──retrospective_initiate──►│                    │                     │
 │──retrospective_initiate──────────────────────►│                     │
 │──retrospective_initiate────────────────────────────────────────────►│
 │ │                                              │                     │
 │ │                                              │  ┌──playtest_request──►│
 │ │                                              │  │                   │
```

**Expected Responses:**

| Agent | Message Type | What They Contribute |
|-------|-------------|---------------------|
| Developer | Writes to retrospective.txt | Implementation challenges, technical insights |
| QA | Writes to retrospective.txt | Validation findings, test coverage, bugs found |
| Game Designer | Writes to retrospective.txt | Design perspective, UX considerations |
| Game Designer | Sends `playtest_report` | Playtest findings via Playwright MCP |

### Level 3: PM Synthesis

When ALL THREE agents contribute, add synthesis covering:

```markdown
### PM Synthesis

**Summary**:

- Task accomplished: {{what was done}}
- Time taken: {{actual vs expected}}
- Challenges: {{unexpected issues}}

**Quality Assessment**:

- Developer insights: {{from dev section}}
- QA validation: {{from qa section}}
- Game Designer playtest findings: {{from GD section}}
- Code quality: {{combined assessment}}
- Design compliance: {{alignment with GDD}}

**Risk Identification**:

- Technical risks: {{dependencies, performance}}
- Project risks: {{timeline, complexity}}
- Quality risks: {{technical debt, shortcuts}}
- Design risks: {{deviations from GDD vision}}

**Iteration Estimation**:

- Remaining tasks: {{count}}
- Estimated iterations: {{calculation}}
- Buffer needed: {{risk adjustment}}

**GDD Compliance**:

- GDD sections affected: {{list}}
- Tasks needed from GDD: {{list}}
- Design gaps identified: {{list}}

**PRD Updates**:

- New risks discovered: {{list}}
- Description clarifications: {{if any}}
- New tasks from retrospective: {{list}}
- New tasks from GDD: {{list}}
```

## Anti-Patterns

❌ **DON'T:**

- Skip retrospective even for "simple" tasks
- Synthesize before ALL THREE agents contribute
- Skip Game Designer playtest report
- Move to skill_research without prd_analysis
- Delete retrospective.txt without documenting summary

✅ **DO:**

- Wait patiently for all agent contributions
- Send `retrospective_initiate` to ALL THREE agents (Developer, QA, Game Designer)
- Send `playtest_request` to Game Designer for Playwright-based playtesting
- Support QA's authority to request refactors
- Document action items from findings
- Update PRD with discovered risks and new tasks
- Reorganize PRD based on retrospective findings
- Improve skills for ALL agents (PM included)

## Checklist

Before completing retrospective:

- [ ] Developer contributed their perspective
- [ ] QA contributed their perspective
- [ ] Game Designer contributed playtest report
- [ ] PM synthesis includes all sections
- [ ] Action items documented
- [ ] GDD compliance analysis completed
- [ ] PRD reorganized (prd_analysis phase complete)
- [ ] Skills improved for ALL agents (skill_research phase complete)
- [ ] Summary appended to coordinator-progress.txt
- [ ] PRD updated with new tasks and risks (if any)

## Post-Synthesis Workflow

After PM synthesis is complete:

### prd_analysis Phase

1. Use [prd-reorganization.md](./prd-reorganization.md) skill
2. Extract tasks from GDD if updated
3. Create tasks from retrospective findings
4. Reorganize PRD priorities and dependencies
5. Commit PRD changes
6. Send `prd_reorganized` message to workers

### skill_research Phase

1. Use [skill-improvement.md](./skill-improvement.md) skill
2. Use [pm-self-improvement.md](./pm-self-improvement.md) skill
3. Improve skills for ALL FOUR agents (PM, Developer, QA, Game Designer)
4. Commit skill improvements
5. Send `skill_improvements` message to watchdog

### Complete

1. Set `currentTask.status = "completed"`
2. Delete retrospective.txt
3. Assign next task

## Reference

- [agents/pm/AGENT.md](../../AGENT.md) — Full retrospective protocol
- [agents/pm/skills/skill-improvement.md](./skill-improvement.md) — MCP-based skill updates
- [agents/pm/skills/prd-reorganization.md](./prd-reorganization.md) — PRD reorganization
- [agents/pm/skills/pm-self-improvement.md](./pm-self-improvement.md) — PM self-improvement
