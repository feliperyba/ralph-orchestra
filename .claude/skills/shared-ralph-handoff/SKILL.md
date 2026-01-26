---
name: shared-ralph-handoff
description: Handoff protocol for single-agent orchestration mode. Use when transferring control between agents in sequential mode.
category: orchestration
tags: [handoff, sequential, single-agent, coordination]
dependencies: [shared-ralph-core, shared-ralph-event-protocol]
---

# Ralph Handoff Protocol

> "One agent active at a time – handoff phrase triggers next agent."

## When to Use This Skill

Use **proactively**:
- When your work is complete and another agent should continue
- When you need another agent's expertise
- Before exiting in sequential mode

---

## Quick Start

<examples>
Example 1: PM hands off to Developer
```
HANDOFF:developer:eyJmcm9tIjoicG0iLCJyZWFzb24iOiJ0YXNrX2Fzc2lnbm1lbnQiLCJ0YXNrIjp7ImlkIjoiZmVhdC0wMDEifX0=
```

Example 2: Developer hands off to QA
```
HANDOFF:qa:eyJmcm9tIjoiZGV2ZWxvcGVyIiwicmVhc29uIjoicmVhZHlfZm9yX3FhIiwidGFzayI6eyJpZCI6ImZlYXQtMDAxIn19
```

Example 3: All complete (session end)
```
<promise>RALPH_COMPLETE</promise>
```
</examples>

---

## Handoff Phrase Format

```
HANDOFF:agent_name:base64_context
```

| Component | Values |
|-----------|--------|
| `agent_name` | `pm`, `developer`, `qa`, `techartist`, `gamedesigner` |
| `base64_context` | Base64-encoded JSON with handoff details |

---

## Context JSON Structure

```json
{
  "from": "pm",
  "reason": "task_assignment",
  "timestamp": "2026-01-23T...",
  "task": {
    "id": "feat-001",
    "title": "Add user authentication",
    "action": "implement",
    "notes": "Focus on JWT tokens"
  }
}
```

---

## Handoff Reasons

| Reason | From | To | Description |
|--------|------|-----|-------------|
| `task_assignment` | PM | Developer | New implementation task |
| `ready_for_qa` | Developer | QA | Implementation complete |
| `validation_passed` | QA | PM | Tests passed, task complete |
| `validation_failed` | QA | Developer | Bugs found, needs fixes |
| `need_clarification` | Worker | PM | Questions about specs |
| `all_complete` | PM | - | Use `RALPH_COMPLETE` instead |

---

## Before Handoff: Save State

**CRITICAL**: Before handoff, you MUST:

1. **Save all state to files**:
   - Update `prd.json.session`
   - Update `prd.json.items[{taskId}]`
   - Update `prd.json.agents.{agent}`
   - Commit any code changes

2. **Signal readiness**: `AGENT_READY_FOR_HANDOFF`

3. **Output handoff phrase**: `HANDOFF:next_agent:context`

---

## Encoding Context

**PowerShell:**
```powershell
$context = @{ from = "pm"; reason = "task_assignment"; task = @{ id = "feat-001" } }
$json = $context | ConvertTo-Json -Compress
$bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
$base64 = [System.Convert]::ToBase64String($bytes)
Write-Host "HANDOFF:developer:$base64"
```

**Bash:**
```bash
context='{"from":"pm","reason":"task_assignment","task":{"id":"feat-001"}}'
encoded=$(echo -n "$context" | base64 -w0)
echo "HANDOFF:developer:$encoded"
```

---

## Receiving Handoff

When starting with handoff context:

1. Acknowledge: "Received handoff from PM for task feat-001"
2. Read `prd.json.session`, `prd.json.agents`, `prd.json.items`
3. Begin assigned work

---

## Completion Protocol

When ALL PRD items have `passes: true`:

```
<promise>RALPH_COMPLETE</promise>
```

This signals graceful session end.

---

## Sequential vs Event-Driven

| Aspect | Sequential (Handoff) | Event-Driven |
|--------|---------------------|--------------|
| Active agents | 1 at a time | Multiple simultaneously |
| Token usage | Only active agent | All active agents |
| Communication | Handoff phrases | Named pipes |
| Switching | Explicit handoff | Message-driven |

---

## Error Handling

If error prevents work:

1. Save partial state
2. Output error context in handoff
3. Handoff to PM for resolution

```json
{
  "from": "developer",
  "reason": "error",
  "task": { "id": "feat-001" },
  "error": "Build failed: missing dependency"
}
```

---

## Related Skills

| Skill | Purpose |
|-------|---------|
| `shared-ralph-core` | Session structure |
| `shared-ralph-event-protocol` | Event-driven mode messaging |
| `shared-message-handling` | Named pipe communication |
