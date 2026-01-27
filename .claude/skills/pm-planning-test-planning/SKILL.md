---
name: pm-planning-test-planning
description: Test planning specialist. Collaborates with QA and Game Designer to create comprehensive test plans. Defines success criteria and test cases before task assignment. Use proactively before task assignment.
user-invocable: true
category: planning
---

# Test Planning

> "Well-planned tests catch more bugs with less effort."

Create comprehensive test plans before task assignment. Collaborate with QA and Game Designer to define success criteria, test cases, and validation approaches.

## When to Use

Use during the `test_planning` phase, after task selection but before assignment to worker.

## Process

### Step 1: Understand Task

Read task details from `prd.json`:
- Title, description, category
- Acceptance criteria
- Verification steps
- Related tasks/dependencies

### Step 2: Coordinate with QA

Request QA input on test approach:
- What test cases are needed?
- What validation approaches? (manual/automated/browser/multiplayer)
- What edge cases should be covered?

**Message to QA:**
```json
{
  "id": "msg-qa-{timestamp}-001",
  "from": "pm",
  "to": "qa",
  "type": "test_plan_request",
  "payload": {
    "taskId": "{task-id}",
    "taskTitle": "{title}",
    "category": "{category}",
    "acceptanceCriteria": [{criteria}],
    "question": "What test cases and validation approach do you recommend?"
  }
}
```

### Step 3: Coordinate with Game Designer

Request GD input on success criteria:
- What defines "success" from player perspective?
- Reference games or examples?
- Edge cases to consider?

**Message to Game Designer:**
```json
{
  "id": "msg-gamedesigner-{timestamp}-001",
  "from": "pm",
  "to": "gamedesigner",
  "type": "success_criteria_request",
  "payload": {
    "taskId": "{task-id}",
    "taskTitle": "{title}",
    "question": "What are the success criteria for this feature from a player perspective?"
  }
}
```

### Step 4: Create Test Plan

Generate a comprehensive test plan including:
- Success criteria (measurable)
- Test cases (specific steps)
- Validation approach (manual/automated/browser/multiplayer)
- Edge cases to cover

## Test Plan Template

```markdown
## Test Plan: {TASK_ID}

### Success Criteria
1. {measurable criteria with specific values}
2. {measurable criteria with specific values}

### Test Cases
| Case | Steps | Expected Result |
|------|-------|-----------------|
| TC1 | {step 1} -> {step 2} -> {step 3} | {expected outcome} |
| TC2 | {step 1} -> {step 2} | {expected outcome} |

### Validation Approach
- **Manual testing:** {what needs manual verification}
- **Automated tests:** {what unit/integration tests}
- **Browser testing:** {what Playwright MCP tests}
- **Multiplayer testing:** {if applicable - server-authoritative checks}

### Edge Cases
- {edge case 1: what happens when...}
- {edge case 2: boundary conditions}

### Reference Examples
- {game/app showing similar functionality}
```

## Output Format

Return to PM:

```markdown
## Test Plan Ready: {TASK_ID}

### Success Criteria
- {criteria 1}
- {criteria 2}

### Test Cases Summary
- {count} test cases defined
- Testing approach: {manual/automated/browser/multiplayer}

### QA/GD Consultation
- QA input: {summary of QA recommendations}
- GD input: {summary of GD success criteria}

### Attached Test Plan
{full test plan content}
```

## Category-Specific Considerations

### Architectural Tasks
- Focus on state management correctness
- Test edge cases in state transitions
- Verify no race conditions

### Functional Tasks
- Test core functionality thoroughly
- Verify all acceptance criteria
- Test error conditions

### Visual/Shader Tasks
- Visual regression testing
- Performance benchmarks (FPS, draw calls)
- Screenshot verification

### Multiplayer Tasks
- Server-authoritative verification
- State synchronization testing
- Network condition simulation
- Anti-cheat validation

## Important

- Always consult both QA and Game Designer before finalizing test plan
- Success criteria must be measurable and specific
- Test cases should cover both happy path and edge cases
- Consider the validation approach needed (manual vs automated)
- For visual tasks, include screenshot comparison criteria
- For multiplayer tasks, include server-authoritative checks

## See Also

- [pm-organization-task-selection](../pm-organization-task-selection/SKILL.md) — Task selection before test planning
- [qa-validation-workflow](../qa-validation-workflow/SKILL.md) — QA validation pipeline
- [gd-validation-playtest](../gd-validation-playtest/SKILL.md) — Game Designer playtesting
