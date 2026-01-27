# Tech Artist Message Templates

> Message templates for Tech Artist agent communication

## Commit Format

```
[ralph] [techartist] {taskId}: {Brief description}

Example:
[ralph] [techartist] feat-001: Add water shader with Gerstner waves
```

## Message Types

### task_complete -> PM

Send when asset/work is complete and ready for QA.

```json
// Write to: .claude/session/messages/pm/cmd/{timestamp}.json
{
  "id": "msg-complete-{timestamp}",
  "from": "techartist",
  "to": "pm",
  "type": "task_complete",
  "payload": {
    "taskId": "{taskId}",
    "summary": "{Brief summary of work completed}",
    "files": ["src/path/to/file1.ts", "src/path/to/file2.ts"],
    "screenshot": ".claude/session/playwright-test/{taskId}-asset.png"
  },
  "timestamp": "{ISO-8601-UTC}"
}
```

### validation_request -> QA

Send when ready for QA validation.

```json
// Write to: .claude/session/messages/qa/cmd/{timestamp}.json
{
  "id": "msg-qa-{timestamp}-001",
  "from": "techartist",
  "to": "qa",
  "type": "validation_request",
  "priority": "normal",
  "payload": {
    "taskId": "{taskId}",
    "title": "{Task Title}",
    "category": "shader|visual|asset",
    "files": ["src/path/to/file1.ts"],
    "acceptanceCriteria": ["Criterion 1", "Criterion 2"],
    "screenshot": ".claude/session/playwright-test/{taskId}-asset.png"
  },
  "timestamp": "{ISO-8601-timestamp}",
  "status": "pending"
}
```

### question -> PM

Send when need clarification or guidance.

```json
// Write to: .claude/session/messages/pm/cmd/{timestamp}.json
{
  "id": "msg-question-{timestamp}",
  "from": "techartist",
  "to": "pm",
  "type": "question",
  "payload": {
    "taskId": "{taskId}",
    "question": "{What do you need clarified?}",
    "context": "{Relevant context about the task}"
  },
  "timestamp": "{ISO-8601-UTC}"
}
```

### design_question -> GameDesigner

Send when need artistic direction or design input.

```json
// Write to: .claude/session/messages/gamedesigner/cmd/{timestamp}.json
{
  "id": "msg-design-{timestamp}",
  "from": "techartist",
  "to": "gamedesigner",
  "type": "question",
  "payload": {
    "taskId": "{taskId}",
    "question": "{What artistic direction do you need?}",
    "options": ["Option A", "Option B", "Option C"],
    "context": "{Relevant context about the asset}"
  },
  "timestamp": "{ISO-8601-UTC}"
}
```

### status_update -> PM

Send status update before exiting.

```json
// Write to: .claude/session/messages/pm/cmd/{timestamp}.json
{
  "id": "msg-status-{timestamp}",
  "from": "techartist",
  "to": "pm",
  "type": "status_update",
  "payload": {
    "status": "idle|awaiting_pm|awaiting_gd",
    "currentTask": "{taskId}|null"
  },
  "timestamp": "{ISO-8601-UTC}"
}
```

### asset_question -> PM

Send when asset specs are unclear.

```json
// Write to: .claude/session/messages/pm/cmd/{timestamp}.json
{
  "id": "msg-asset-q-{timestamp}",
  "from": "techartist",
  "to": "pm",
  "type": "asset_question",
  "payload": {
    "taskId": "{taskId}",
    "assetType": "shader|model|texture|vfx",
    "question": "{What specs do you need?}",
    "currentUnderstanding": "{What you think is needed}"
  },
  "timestamp": "{ISO-8601-UTC}"
}
```

## Status Values

| Value | Meaning |
|-------|---------|
| `idle` | Available for work |
| `working` | Actively creating assets |
| `awaiting_references` | Need visual direction |
| `awaiting_pm` | Waiting for PM response |
| `awaiting_gd` | Waiting for Game Designer response |
