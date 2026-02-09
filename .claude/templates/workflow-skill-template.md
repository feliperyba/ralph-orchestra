---
name: {{ agent.name }}-workflow
description: {{ agent.display_name }} workflow - states, transitions, message handling for V2 event-driven coordination
category: {{ agent.agent_type }}
agent: {{ agent.name }}
model: inherit
---

# {{ agent.display_name }} Workflow

> Load this skill BEFORE starting {{ agent.display_name }} work.

## Core Flow

{% if agent.workflow and agent.workflow.states %}
{% for state in agent.workflow.states %}
- **{{ state.name }}** - {{ state.description if state.description else '' }}
{% endfor %}
{% else %}
- **idle** - Available for work
- **working** - Actively processing tasks
- **awaiting_response** - Waiting for other agents
{% endif %}

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│    idle     │────▶│   working   │────▶│    idle     │
│  (available)│     │ (processing)│     │  (complete) │
└─────────────┘     └─────────────┘     └─────────────┘
       ▲                                      │
       │                                      ▼
┌─────────────┐                         ┌─────────────┐
│awaiting_{{ agent.name }}│◀────────────────│   blocked   │
│  (waiting)  │                         │  (stuck)    │
└─────────────┘                         └─────────────┘
```

## Decision Framework

| Current State | Trigger | Action | Skill/Sub-Agent | Next State |
|--------------|---------|--------|-----------------|------------|
{% if agent.workflow and agent.workflow.transitions %}
{% for transition in agent.workflow.transitions %}
| `{{ transition.from }}` | {{ transition.trigger }} | {{ transition.action if transition.action else '-' }} | {{ transition.skill_to_use if transition.skill_to_use else '-' }} | `{{ transition.to }}` |
{% endfor %}
{% else %}
| `idle` | WorkAssign received | Load task | - | `working` |
| `working` | WorkComplete | Send message | - | `idle` |
| `working` | Need information | Send Query | - | `awaiting_response` |
| `awaiting_response` | Response received | Resume work | - | `working` |
| `working` | Blocked after 3 attempts | Send WorkBlocked | - | `blocked` |
| `blocked` | Guidance received | Resume work | - | `working` |
{% endif %}

## Messages You Send

| Event | Type | To | Priority |
|-------|------|-------|----------|
{% if agent.workflow and agent.workflow.messages_sent %}
{% for msg in agent.workflow.messages_sent %}
| {{ msg.event_type | title }} | `{{ msg.event_type }}` | {{ msg.to }} | {{ msg.priority }} |
{% endfor %}
{% else %}
| Work complete | `WorkComplete` | pm | high |
| Have question | `Query` | pm | high |
| Need clarification | `Query` | pm | normal |
| Blocked | `WorkBlocked` | pm | urgent |
{% endif %}

## Messages You Receive

| Type | From | Action |
|------|------|--------|
{% if agent.workflow and agent.workflow.messages_received %}
{% for msg in agent.workflow.messages_received %}
| `{{ msg.event_type }}` | {{ msg.from }} | {{ msg.action }} |
{% endfor %}
{% else %}
| `WorkAssign` | pm | Load and execute task |
| `WorkAssign` (retry) | pm | Handle fix request |
| `Response` | any | Process answer |
| `Query` | any | Research and respond |
{% endif %}

## Exit Conditions

**⚠️ BEFORE exiting, you MUST:**

1. Complete assigned work
2. Commit with `[ralph] [{{ agent.name }}]` prefix:
   ```
   [ralph] [{{ agent.name }}] feat-XXX: Description

   - Change 1
   - Change 2

   PRD: feat-XXX | Agent: {{ agent.name }} | Iteration: N
   ```
3. Update your status in `prd.json`:
   - Set `agents.{{ agent.name }}.status = "idle"`
   - Set `agents.{{ agent.name }}.currentTaskId = null`
4. Send completion message to next agent or PM
5. ONLY THEN exit

**Worker pool model:** Complete work → commit → update status → send message → exit.