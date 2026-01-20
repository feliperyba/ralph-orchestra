---
name: retrospective
description: Facilitate file-based retrospective after task completion with all agents
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
3. Poll for agent contributions every 30 seconds
4. Synthesize when both Developer and QA contribute
5. Document summary in coordinator-progress.txt
6. Delete retrospective.txt and assign next task

## Decision Framework

| Status                    | Action                               |
| ------------------------- | ------------------------------------ |
| Just passed QA            | Create retrospective.txt, set status |
| Developer not contributed | Wait 30s, poll again                 |
| QA not contributed        | Wait 30s, poll again                 |
| Both contributed          | Synthesize and complete              |
| Retrospective complete    | Delete file, assign next task        |

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

### PM Synthesis (to be filled by PM Agent)

<!-- WAITING for all agents to contribute -->

---

## Completion Status

- [ ] Developer contributed
- [ ] QA contributed
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

// Update checkboxes
if (devContributed) updateCheckbox('Developer contributed', true);
if (qaContributed) updateCheckbox('QA contributed', true);
```

### Level 3: PM Synthesis

When both agents contribute, add synthesis covering:

```markdown
### PM Synthesis

**Summary**:

- Task accomplished: {{what was done}}
- Time taken: {{actual vs expected}}
- Challenges: {{unexpected issues}}

**Quality Assessment**:

- Developer insights: {{from dev section}}
- QA validation: {{from qa section}}
- Code quality: {{combined assessment}}

**Risk Identification**:

- Technical risks: {{dependencies, performance}}
- Project risks: {{timeline, complexity}}
- Quality risks: {{technical debt, shortcuts}}

**Iteration Estimation**:

- Remaining tasks: {{count}}
- Estimated iterations: {{calculation}}
- Buffer needed: {{risk adjustment}}

**PRD Updates**:

- New risks discovered: {{list}}
- Description clarifications: {{if any}}
```

## Anti-Patterns

❌ **DON'T:**

- Skip retrospective even for "simple" tasks
- Synthesize before both agents contribute
- Assign next task before retrospective complete
- Delete retrospective.txt without documenting summary

✅ **DO:**

- Wait patiently for agent contributions
- Support QA's authority to request refactors
- Document action items from findings
- Update PRD with discovered risks

## Checklist

Before completing retrospective:

- [ ] Developer contributed their perspective
- [ ] QA contributed their perspective
- [ ] PM synthesis includes all sections
- [ ] Action items documented
- [ ] Summary appended to coordinator-progress.txt
- [ ] PRD updated with new risks (if any)

## Reference

- [agents/pm/AGENT.md](../../AGENT.md) — Full retrospective protocol
- [agents/pm/skills/skill-improvement.md](skill-improvement.md) — MCP-based skill updates
