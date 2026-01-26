---
name: pm-planning-test-planning
description: Test planning specialist - collaborates with QA and Game Designer to define success criteria and test cases before task assignment
category: pm
user-invocable: true
model: inherit
agent: pm
degrees-of-freedom: medium
---

# Test Planning

> "Well-planned tests catch more bugs with less effort."

**Definition of Done (Agile Principle):** Collaboratively define acceptance criteria before work begins.

## When to Use

During `test_planning` phase (after task selection, before assignment).

## Process

```
1. Understand task → 2. Coordinate with QA → 3. Coordinate with GD → 4. Create test plan
```

### Step 1: Understand Task

Read from `prd.json`:
- Title, description, category
- Acceptance criteria
- Related tasks/dependencies

### Step 2: Coordinate with QA

Request QA input on test approach:
- Test cases needed?
- Validation approach? (manual/automated/browser/multiplayer)
- Edge cases to cover?

### Step 3: Coordinate with Game Designer

Request GD input on success criteria:
- What defines "success" from player perspective?
- Reference games or examples?
- Edge cases to consider?

### Step 4: Create Test Plan

Generate test plan with:
- Success criteria (measurable)
- Test cases (specific steps)
- Validation approach
- Edge cases

---

## Test Plan Template

```markdown
## Test Plan: {TASK_ID}

### Success Criteria
1. {measurable criteria with specific values}
2. {measurable criteria with specific values}

### Test Cases
| Case | Steps | Expected Result |
|------|-------|-----------------|
| TC1 | {step 1} → {step 2} → {step 3} | {outcome} |
| TC2 | {step 1} → {step 2} | {outcome} |

### Validation Approach
- **Manual testing:** {what needs manual verification}
- **Automated tests:** {what unit/integration tests}
- **Browser testing:** {what Playwright MCP tests}
- **Multiplayer testing:** {server-authoritative checks}

### Edge Cases
- {edge case 1}
- {edge case 2}

### Reference Examples
- {game/app showing similar functionality}
```

---

## Category-Specific Considerations

| Category | Focus Areas |
|----------|-------------|
| **Architectural** | State management, race conditions, state transitions |
| **Functional** | Core functionality, error conditions, acceptance criteria |
| **Visual/Shader** | Visual regression, performance benchmarks, screenshots |
| **Multiplayer** | Server-authoritative, state sync, network simulation |

---

## Important

- Always consult both QA and Game Designer before finalizing
- Success criteria must be measurable and specific
- Test cases should cover happy path and edge cases
- For visual tasks: include screenshot comparison criteria
- For multiplayer tasks: include server-authoritative checks

---

## References

- [pm-organization-task-selection](../pm-organization-task-selection/SKILL.md) - Task selection
- [qa-validation-workflow](../qa-validation-workflow/SKILL.md) - QA pipeline
- [gd-validation-playtest](../gd-validation-playtest/SKILL.md) - Playtesting
