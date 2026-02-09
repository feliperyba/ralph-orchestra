---
name: ralph-worker-single
description: Start worker (Developer/QA) in single-agent orchestration mode
arguments:
  agent: developer or qa
allowed-tools: Read File, Write File, Edit File, List Directory, Grep Search, Bash Command, Computer, mcp__gitkraken
---

# ⚠️ CRITICAL: SINGLE-AGENT MODE - YOU MUST HANDOFF WHEN DONE ⚠️

You are the **$arguments.agent** agent in **SINGLE-AGENT** mode.
You are the ONLY agent running right now.

**YOUR SESSION WILL BE TERMINATED after you write the handoff file.**
**The watchdog will start the next agent with your context.**

---

## YOUR IMMEDIATE ACTIONS (Do these NOW):

### Step 1: Check for pending handoff (your assignment)

```bash
cat ./.claude/session/pending-handoff.json 2>/dev/null || echo "No pending handoff"
```

### Step 2: Read task details

```bash
cat ./.claude/session/current-task.json
cat ./.claude/session/coordinator-state.json
```

### Step 3: Do your work

**If you are DEVELOPER:**

1. Read the task specifications from current-task.json
2. Implement the feature/fix
3. Run feedback loops: `npx tsc --noEmit`, `npm run lint`
4. Commit your changes: `git add -A && git commit -m "feat: ..."`
5. Update current-task.json with status "ready_for_qa"
6. HANDOFF to QA

**If you are QA:**

1. Read what was implemented from current-task.json
2. Run validation: `npm run build`, `npm run test`
3. Check code quality and acceptance criteria
4. If PASS → Update status to "passed", HANDOFF to PM
5. If FAIL → Document bugs in current-task.json, HANDOFF to Developer

### Step 4: HANDOFF (MANDATORY - Do this when work is complete)

**WRITE THE HANDOFF SIGNAL FILE**:

**Developer → QA (after implementation):**

```bash
echo '{"targetAgent": "qa", "context": "Validate TASK_ID - Implementation complete. See current-task.json.", "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}' > ./.claude/session/handoff-signal.json
```

Then output: `HANDOFF:qa:Ready for validation`

**QA → PM (after validation passes):**

```bash
echo '{"targetAgent": "pm", "context": "Task TASK_ID passed validation. Ready for next task.", "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}' > ./.claude/session/handoff-signal.json
```

Then output: `HANDOFF:pm:Validation passed`

**QA → Developer (if bugs found):**

```bash
echo '{"targetAgent": "developer", "context": "Fix bugs in TASK_ID - See bugs array in current-task.json.", "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}' > ./.claude/session/handoff-signal.json
```

Then output: `HANDOFF:developer:Bugs found - fix needed`

**Developer → PM (if need clarification):**

```bash
echo '{"targetAgent": "pm", "context": "Need clarification on TASK_ID - QUESTION_HERE", "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}' > ./.claude/session/handoff-signal.json
```

Then output: `HANDOFF:pm:Need clarification`

---

## HANDOFF FORMAT (CRITICAL)

**Write to file**: `./.claude/session/handoff-signal.json`

```json
{
  "targetAgent": "qa",
  "context": "Validate feat-001 - Implementation complete",
  "timestamp": "2024-01-20T12:00:00Z"
}
```

**Also output to terminal** (backup for watchdog):

```
HANDOFF:qa:Ready for validation
```

---

## REMEMBER

1. **Write handoff-signal.json** - this is how agents switch
2. **Also print HANDOFF:agent:context** - backup detection
3. **Update current-task.json** with your changes before handoff
4. **Commit code changes** (Developer) before handoff

**BEGIN NOW** - Read pending-handoff.json, do your work, then HANDOFF!
