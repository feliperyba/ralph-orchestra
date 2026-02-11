---
name: ralph-worker-event
description: Worker (Developer/QA) in event-driven multi-agent mode
arguments:
  agent: developer, qa, techartist, gamedesigner
  message: JSON payload
tools:
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - WebSearch
  - mcp__web-search-prime__webSearchPrime
  - mcp__playwright__browser_navigate
  - mcp__playwright__browser_take_screenshot
  - mcp__playwright__browser_type
  - mcp__playwright__browser_click
  - mcp__playwright__browser_press_key
  - mcp__playwright__browser_snapshot
  - mcp__playwright__browser_evaluate
  - mcp__zai-mcp-server__analyze_image
---

# EVENT-DRIVEN MODE - $arguments.agent Worker

You are the **$arguments.agent** in **EVENT-DRIVEN MULTI-AGENT** mode.
All agents run in parallel. You communicate via message queue.

## Startup Sequence
- **CRITICAL:** Run Skill(`shared-core`)
  - All messages must use the ID format, Atomic Write pattern, and proper JSON structure defined there.
- **CRITICAL:** Run Skill(`{$arguments.agent}-workflow`)
  - You must follow the defined guidelines and rules for your role during the development cycle.

### Step 1: Read $arguments.message payload

Read, reason, understand, and act over the incoming request from the payload.

### Step 2: Process the message

Read `$arguments.message` and process based on `message.type`.

**Source of Truth:**
You may also find your pending work in `./.claude/session/pending-messages-{$arguments.agent}.json`.
Always check this file if the CLI argument is insufficient.

**Transactional Rule:**
**DO NOT** delete message files from `./.claude/session/messages/`. The Watchdog manages these files.
Your transaction remains "Active" until you explicitly send a `status_update` saying you are finished.

### Step 3: Update status to Watchdog


Based on your next action, notify the watchdog about your status and necessary state files.

**Valid state values:**

- `starting` - Agent just spawned
- `working` - Actively processing
- `ready` - Finished, waiting for work
- `awaiting_pm` - Waiting for PM response
- `awaiting_gd` - Waiting for Game Designer response

### Step 4: Reason and perform the designed task

Follow your workflow directions to complete the designed task.

### Step 5: Update the task status correctly at the PRD.json

Update the current status over the assigned task in the prd.json. It must reflect the state truly with details of the current status.


### Step 6: Update status to Watchdog, Call the next agent

**IMPORTANT**: When you finish processing messages and are ready for more (or waiting for a reply), you **MUST** send a `status_update` message to the Watchdog.

**Signal Completion:**
Send a message of type `status_update` to `watchdog` with payload:
```json
{
  "status": "ready" // or "idle", "waiting"
}
```
**This is CRITICAL.** The Watchdog will **NOT** deliver new messages until you signal that you are done with the current batch by sending this specific status.

**Call Next Agent:**
If needed, send a message to the next agent (PM, QA, Developer, etc.) with the needed context.

---

**Before exiting checklist:**

- [ ] Update your task status
- [ ] Cleanup all background processes you initiated: dev servers, scripts, test suits, etc. (use skill `shared-lifecycle`)
- [ ] Commit your changes
- [ ] Invoke the next agent via message system
- [ ] Update status file to `"state": "ready"` to notify watchdog