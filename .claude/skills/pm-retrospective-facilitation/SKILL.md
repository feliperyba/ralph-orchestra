---
name: pm-retrospective
description: Facilitate file-based retrospective after task completion with worker agents (Developer, Tech Artist, QA). Playtest session is now a separate phase.
---

# Retrospective Skill

> "Quality over speed – every completed task deserves reflection."

> **IMPORTANT**: Playtest is now a SEPARATE phase. This skill handles worker retrospective contributions ONLY.

**NOTE FOR EVENT-DRIVEN MODE:**
The message queue is PRE-LOADED by the agent runner script. Skip sourcing `message-queue.ps1` in examples below.

## When to Use This Skill

Use when:

- `prd.json.items[{taskId}].status === "passed"` (QA validated)
- Before assigning the next task
- NEVER skip retrospective

## Quick Start

1. Create `.claude/session/retrospective.txt` with template
2. Set `prd.json.items[{taskId}].status = "in_retrospective"`
3. Send `retrospective_initiate` to Developer, Tech Artist, QA (**NOT Game Designer**)
4. **EXIT** - watchdog will restart you when messages arrive
5. On wake-up: If all 3 workers contributed → read separate files → merge → synthesize
6. **Commit changes with git**: `[ralph] [pm] {taskId} retrospective: Worker contributions synthesized`
7. Set status to `retrospective_synthesized`
8. **EXIT** (context reset for next phase)

**P1 FIX: Workers now write to separate contribution files (prevents race conditions):**
- `.claude/session/retrospective-developer.json`
- `.claude/session/retrospective-techartist.json`
- `.claude/session/retrospective-qa.json`
- PM reads all 3 files and merges them into final retrospective.txt

**⚠️ CRITICAL: Playtest is a SEPARATE Phase**

After retrospective completes, use the `pm-retrospective-playtest-session` skill to request playtest from Game Designer.

## State Flow

```
passed → in_retrospective → retrospective_synthesized
```

**Next phases** (handled by other skills):
- `retrospective_synthesized` → `playtest_phase` (via pm-retrospective-playtest-session skill)
- `playtest_complete` → `prd_refinement` (via pm-organization-prd-reorganization skill)
- `task_ready` → `skill_research` (via pm-improvement-skill-research skill)
- `completed` → next task assignment

## Decision Framework

| Status                            | Action                                                          |
| --------------------------------- | --------------------------------------------------------------- |
| Just passed QA                    | Create retrospective.txt, set in_retrospective                  |
| Sent retrospective_initiate        | **EXIT** - watchdog restarts you when messages arrive           |
| On wake-up: incomplete             | Check state, if incomplete → **EXIT again**                     |
| All THREE workers contributed       | Synthesize, **commit**, set retrospective_synthesized, **EXIT**   |

**Event-driven principle: PM checks state on wake-up and either proceeds or exits. NO polling, NO timers.**

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

### Tech Artist Perspective (to be filled by Tech Artist Agent)

<!-- WAITING for Tech Artist to add their points -->

### QA Perspective (to be filled by QA Agent)

<!-- WAITING for QA to add their points -->

### PM Synthesis (to be filled by PM Agent)

<!-- WAITING for all THREE worker agents to contribute -->

---

## Completion Status

- [ ] Developer contributed
- [ ] Tech Artist contributed
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

// Check if Tech Artist contributed
const taSection = retrospective.match(/### Tech Artist Perspective\n([\s\S]*?)###/);
const taContributed = taSection && !taSection[1].includes('WAITING');

// Check if QA contributed
const qaSection = retrospective.match(/### QA Perspective\n([\s\S]*?)###/);
const qaContributed = qaSection && !qaSection[1].includes('WAITING');

// Update checkboxes
if (devContributed) updateCheckbox('Developer contributed', true);
if (taContributed) updateCheckbox('Tech Artist contributed', true);
if (qaContributed) updateCheckbox('QA contributed', true);
```

### Level 2.5: Send Retrospective Messages (Workers Only)

**⚠️ CRITICAL: This phase is for worker contributions ONLY. Game Designer playtest is separate.**

**Use Write tool to create message files directly (bash-safe):**

```bash
# === STEP 1: Update prd.json with Edit tool ===
# Add/update prd.json.session.retro section for batching

# === STEP 2: Send messages to workers ===
# Write message files to .claude/session/messages/{agent}/

# To Developer (retrospective_initiate)
File: .claude/session/messages/developer/msg-developer-{timestamp}-001.json
{
  "id": "msg-developer-{timestamp}-001",
  "from": "pm",
  "to": "developer",
  "type": "retrospective_initiate",
  "priority": "normal",
  "payload": {
    "taskId": "{taskId}",
    "taskTitle": "{taskTitle}",
    "retrospectiveFile": ".claude/session/retrospective.txt"
  },
  "timestamp": "{UTC-timestamp}",
  "status": "pending"
}

# To Tech Artist (retrospective_initiate)
File: .claude/session/messages/techartist/msg-techartist-{timestamp}-001.json
{
  "id": "msg-techartist-{timestamp}-001",
  "from": "pm",
  "to": "techartist",
  "type": "retrospective_initiate",
  "priority": "normal",
  "payload": {
    "taskId": "{taskId}",
    "taskTitle": "{taskTitle}",
    "retrospectiveFile": ".claude/session/retrospective.txt"
  },
  "timestamp": "{UTC-timestamp}",
  "status": "pending"
}

# To QA (retrospective_initiate)
File: .claude/session/messages/qa/msg-qa-{timestamp}-001.json
{
  "id": "msg-qa-{timestamp}-001",
  "from": "pm",
  "to": "qa",
  "type": "retrospective_initiate",
  "priority": "normal",
  "payload": {
    "taskId": "{taskId}",
    "taskTitle": "{taskTitle}",
    "retrospectiveFile": ".claude/session/retrospective.txt"
  },
  "timestamp": "{UTC-timestamp}",
  "status": "pending"
}

# === NOTE: Do NOT send any message to Game Designer in this phase ===
# Game Designer will be invoked in the separate playtest phase

# === EXIT and wait for workers to respond ===
# Watchdog will wake you when messages arrive
```

**Alternative: Use Glob/Read to check for messages (simplest):**
- Glob: `.claude/session/messages/pm/msg-*.json` (find your messages)
- Read each message file to understand content
- Delete: `rm .claude/session/messages/pm/msg-{id}.json` (after processing)

**Message Flow:**

```
Retrospective Phase:
PM             Developer      TechArtist       QA
 │                 │               │            │
 │──retrospective_initiate──►│               │            │
 │──retrospective_initiate───────────────────►│            │
 │──retrospective_initiate──────────────────────────────►│
 │                                                      │
 │◄─────────────────────────────────────────────────────┤
 │     (All workers contribute via messages)             │
```

**Expected Responses:**

| Agent    | Message Type              | What They Contribute                         |
| -------- | ------------------------- | -------------------------------------------- |
| Developer | `retrospective_contribution` | Implementation challenges, technical insights |
| Tech Artist | `retrospective_contribution` | Visual quality, asset challenges, performance |
| QA        | `retrospective_contribution` | Validation findings, test coverage, bugs found |

### Level 2.6: Watchdog File Watcher Coordination (CRITICAL - NO LOOPS, NO TIMERS)

**Watchdog monitors `retrospective.txt` and wakes PM when all 3 workers contributed.**

**Event-driven flow (NO loops, NO timers, NO blocking):**

```bash
# After sending retrospective_initiate:
# 1. EXIT immediately - watchdog monitors file and wakes you when complete
# 2. On wake-up, all workers should have contributed

# When PM wakes up (watchdog signals all complete):
# Use Read tool to verify all contributions received

# Read contribution files directly:
Read(".claude/session/retrospective-developer.json")
Read(".claude/session/retrospective-techartist.json")
Read(".claude/session/retrospective-qa.json")

# If any file missing → EXIT and wait for next wake-up
# All files present → proceed to synthesis
```

**Key principles:**
- **NO loops** - no `while`, no `foreach`, no `for`
- **NO timers** - no `Start-Sleep`, no timeouts
- **File watcher coordination** - watchdog monitors retrospective.txt changes
- **Watchdog wakes PM** - only when all 3 workers contributed
- **Timeout escalation** - watchdog sends reminders to idle agents after 5 minutes

### Level 3: PM Synthesis

**P1 FIX: Workers now contribute to separate JSON files - read and merge them.**

**BEFORE synthesizing - verify ALL conditions met:**

1. ✅ `.claude/session/retrospective-developer.json` exists
2. ✅ `.claude/session/retrospective-techartist.json` exists
3. ✅ `.claude/session/retrospective-qa.json` exists

**If any condition NOT met → EXIT and wait for next wake-up**

**Step 1: Read all contribution files**

```bash
# Use Read tool to read contribution files
Read(".claude/session/retrospective-developer.json")
Read(".claude/session/retrospective-techartist.json")
Read(".claude/session/retrospective-qa.json")
```

**Step 2: Merge into retrospective.txt**

```markdown
# Build markdown from JSON contributions and write using Write tool
# Format each agent's contribution into markdown sections

# Write merged retrospective.txt using Write tool:
File: .claude/session/retrospective.txt
# Retrospective: {taskId} - {taskTitle}

**Started**: {timestamp}
**Task**: {taskId}

---

### Developer Perspective

**Implementation Decisions**:
- (from developer contribution)

**Technical Challenges Faced**:
- (from developer contribution)

**What Worked Well**:
- (from developer contribution)

**Areas for Improvement**:
- (from developer contribution)

**Lessons Learned**:
- (from developer contribution)

_**Contributed by**: Developer Agent | {timestamp}_

### Tech Artist Perspective

(Similar sections from tech artist contribution)

### QA Perspective

(Similar sections from QA contribution)

### PM Synthesis

**Summary**:
- Task accomplished: {taskTitle}
- Contributors: Developer, Tech Artist, QA
- All contributions received via separate files (P1 FIX - no race conditions)
```

**Step 3: Clean up contribution files**

```bash
# Remove contribution files using Bash
rm .claude/session/retrospective-developer.json 2>/dev/null || true
rm .claude/session/retrospective-techartist.json 2>/dev/null || true
rm .claude/session/retrospective-qa.json 2>/dev/null || true
```

**Step 3: Add PM synthesis**

When ALL conditions met, add synthesis covering:

```markdown
### PM Synthesis

**Summary**:

- Task accomplished: {{what was done}}
- Time taken: {{actual vs expected}}
- Challenges: {{unexpected issues}}

**Quality Assessment**:

- Developer insights: {{from dev section}}
- Tech Artist insights: {{from TA section}}
- QA validation: {{from qa section}}
- Code quality: {{combined assessment}}
- Visual quality: {{from TA section}}

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
- New tasks from retrospective: {{list}}
```

**⚠️ CRITICAL: After synthesis, MUST commit before exiting:**

```bash
# Commit retrospective synthesis
git add .claude/session/retrospective.txt prd.json
git commit -m "[ralph] [pm] {taskId} retrospective: Worker contributions synthesized

- Synthesized contributions from Developer, Tech Artist, QA
- Identified {count} new tasks from findings
- Updated risk assessment

PRD: {taskId} | Agent: pm | Iteration: {iteration}"
```

Then set status and exit:

```bash
# Use Edit tool to update prd.json:
# 1. Set currentTask.status = "retrospective_synthesized"
# 2. Clear prd.json.session.retro section

# Exit for context reset
```

## Anti-Patterns

❌ **DON'T:**

- Skip retrospective even for "simple" tasks
- Synthesize before ALL THREE worker agents contribute
- Send playtest_request to Game Designer (use pm-playtest-session skill instead)
- Use `Start-Sleep` or timers - **NO polling, NO waiting**
- Use `while` loops - **blocks the process**
- Use `foreach` or `for` loops - **blocks the process**
- Forget to commit after synthesis
- Move to next phase without setting correct status

✅ **DO:**

- Send messages, then **EXIT** - let watchdog wake you when agents respond
- Check state on wake-up, proceed or **EXIT again** based on conditions
- Process ONE message per wake-up max (use `Select-Object -First 1`)
- Send `retrospective_initiate` to Developer, Tech Artist, QA **ONLY**
- **Commit changes** after synthesis before setting status and exiting
- Set status to `retrospective_synthesized` before exiting
- Use pm-playtest-session skill for the next phase

## Checklist

**Initial setup:**
- [ ] Created retrospective.txt with template
- [ ] Set `prd.json.items[{taskId}].status = "in_retrospective"`
- [ ] Initialized retrospective state in prd.json.session

**Messages sent:**
- [ ] Sent `retrospective_initiate` to Developer
- [ ] Sent `retrospective_initiate` to Tech Artist
- [ ] Sent `retrospective_initiate` to QA
- [ ] Did NOT send any message to Game Designer (handled in next phase)
- [ ] Exited to wait for worker responses

**Final verification before synthesis:**
- [ ] Developer contributed their perspective
- [ ] Tech Artist contributed their perspective
- [ ] QA contributed their perspective
- [ ] PM synthesis includes all sections
- [ ] Action items documented

**After synthesis:**
- [ ] **Committed changes** with git commit message
- [ ] Status set to `retrospective_synthesized`
- [ ] Cleared retrospective batching state from prd.json.session
- [ ] Exited for context reset (next phase will invoke playtest)

## Post-Retrospective Phases

After retrospective completes with status `retrospective_synthesized`:

1. **Playtest Phase** (use `pm-retrospective-playtest-session` skill):
   - Send `playtest_session_request` to Game Designer
   - Receive `playtest_session_report` with screenshots
   - Review findings, update PRD if needed
   - Set status to `playtest_complete`

2. **PRD Refinement Phase** (use `pm-organization-prd-reorganization` skill):
   - Extract tasks from GDD if updated
   - Create tasks from retrospective findings
   - Reorganize PRD priorities and dependencies
   - Send `prd_analysis_request` to Game Designer

3. **Acceptance Criteria Phase** (MANDATORY before task assignment):
   - Select next task with Game Designer input
   - Send `acceptance_criteria_request` to Game Designer
   - Receive `acceptance_criteria` with success criteria and test plan
   - Incorporate into task definition
   - Set status to `task_ready`

4. **Skill Research Phase** (use `pm-improvement-skill-research` skill):
   - Improve skills for ALL FIVE agents based on retrospective
   - Commit skill improvements
   - Set status to `completed`

5. **Complete**:
   - Delete retrospective.txt
   - Assign next task (now with proper acceptance criteria)

## Reference

- [`.claude/skills/pm-retrospective-playtest-session/SKILL.md`](../pm-retrospective-playtest-session/SKILL.md) — Playtest phase (next after retrospective)
- [`.claude/skills/pm-organization-prd-reorganization/SKILL.md`](../pm-organization-prd-reorganization/SKILL.md) — PRD refinement phase
- [`.claude/skills/pm-improvement-skill-research/SKILL.md`](../pm-improvement-skill-research/SKILL.md) — Skill research phase
- [`.claude/skills/shared-ralph-event-protocol/SKILL.md`](../shared-ralph-event-protocol/SKILL.md) — Message protocol
- [`agents/pm/AGENT.md`](../../../agents/pm/AGENT.md) — Full PM instructions
