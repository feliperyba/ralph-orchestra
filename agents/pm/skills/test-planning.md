---
title: Test Planning
category: coordination
description: Collaborative test planning with QA and Game Designer before assigning tasks
version: 1.0.0
---

# Test Planning

Before assigning any task to the Developer, the PM must collaborate with QA and Game Designer to create a comprehensive test plan. This ensures testing is well-planned and all edge cases are considered BEFORE implementation begins.

## When to Use

Use this skill after retrospective completes (`currentTask.status = "completed"`) and BEFORE selecting the next task.

## State Flow

```
completed → test_planning → assigned
```

## Quick Start

1. Select next task from PRD
2. Set `currentTask.status = "test_planning"`
3. Send `test_plan_request` to QA and Game Designer
4. Poll for contributions
5. Synthesize into comprehensive test plan
6. Use MCP tools to enhance plan (optional)
7. Attach test plan to task
8. Set `currentTask.status = "assigned"`
9. Send task to Developer

## Decision Framework

| Situation | Action |
|-----------|--------|
| Just completed retrospective | Enter `test_planning` phase for next task |
| First task of session | Still do test planning (no retrospective yet) |
| No tasks remaining | Exit, don't do test planning |
| Simple bug fix | Streamlined test planning (focus on regression) |

## Collaborative Test Planning Workflow

### Step 1: Select Next Task

```powershell
# Use task-selection skill to identify next task
$nextTask = Select-NextTask -PRD prd.json
```

### Step 2: Request Test Plan Input

Send `test_plan_request` to both QA and Game Designer:

```json
{
  "type": "test_plan_request",
  "from": "pm",
  "to": "qa",
  "payload": {
    "taskId": "feat-001",
    "title": "User Authentication",
    "description": "Implement login form with email/password",
    "acceptanceCriteria": [
      "User can login with valid credentials",
      "Error shown for invalid credentials",
      "Form validates email format"
    ]
  }
}
```

### Step 3: Poll for Contributions

Wait for both QA and Game Designer to contribute:

**QA Contribution Should Include**:
- Test cases for each acceptance criterion
- Edge cases and boundary conditions
- Performance validation approach
- Browser/device compatibility checks
- Security considerations

**Game Designer Contribution Should Include**:
- Design validation criteria
- User experience considerations
- Playtest scenarios
- Visual regression checks
- Interaction design validation

### Step 4: Synthesize Test Plan

Combine inputs into comprehensive test plan:

```json
{
  "taskId": "feat-001",
  "title": "User Authentication",
  "testPlan": {
    "acceptanceCriteriaTests": [
      {
        "criteria": "User can login with valid credentials",
        "testSteps": [
          "Navigate to /login",
          "Enter valid email in email field",
          "Enter valid password in password field",
          "Click submit button"
        ],
        "expectedResult": "User redirected to dashboard",
        "edgeCases": [
          "Empty email field",
          "Empty password field",
          "Invalid email format",
          "SQL injection attempts",
          "Special characters in input"
        ]
      }
    ],
    "validationApproach": {
      "unit": [
        "Jest tests for auth functions",
        "Test form validation logic",
        "Test API call handling"
      ],
      "integration": [
        "Test auth API endpoints",
        "Test session management"
      ],
      "e2e": [
        "Playwright: Successful login flow",
        "Playwright: Failed login flow",
        "Playwright: Form validation"
      ],
      "manual": [
        "Exploratory testing of form interactions",
        "Visual regression check"
      ]
    },
    "designValidation": {
      "criteria": [
        "Matches Figma design specifications",
        "Responsive on mobile (375px+)",
        "Responsive on tablet (768px+)",
        "Loading states shown appropriately"
      ],
      "playtestScenarios": [
        "New user first-time login",
        "Returning user with saved credentials",
        "Password recovery flow initiation"
      ]
    },
    "performanceTargets": {
      "loginTime": "< 2s",
      "formRenderTime": "< 100ms",
      "apiResponseTime": "< 500ms"
    },
    "securityChecks": [
      "Password field uses type='password'",
      "Inputs sanitized",
      "No sensitive data in URLs",
      "CSRF protection on submit"
    ],
    "browserCompatibility": [
      "Chrome (latest)",
      "Firefox (latest)",
      "Safari (latest)",
      "Edge (latest)"
    ]
  }
}
```

### Step 5: Enhance Plan with MCP Tools (Optional)

The PM may use MCP tools to enhance the test plan:

**Image Generation**:
- Generate visual test flow diagrams
- Create wireframes for test scenarios

**Web Search**:
- Research testing best practices for specific features
- Find security testing checklists
- Look up performance benchmarks

**Documentation Fetching**:
- Fetch relevant testing framework docs
- Get accessibility testing guidelines

### Step 6: Attach and Assign

1. Attach test plan to task in `current-task.json`
2. Set `currentTask.status = "assigned"`
3. Send `task_assign` message to Developer with test plan included

## Test Plan Templates

### Feature Development Template

```json
{
  "testPlan": {
    "acceptanceCriteriaTests": [],
    "validationApproach": {
      "unit": [],
      "integration": [],
      "e2e": [],
      "manual": []
    },
    "designValidation": {
      "criteria": [],
      "playtestScenarios": []
    },
    "performanceTargets": {},
    "securityChecks": [],
    "browserCompatibility": []
  }
}
```

### Bug Fix Template (Simplified)

```json
{
  "testPlan": {
    "regressionTests": [
      "Verify fix resolves reported issue",
      "Verify related functionality unaffected"
    ],
    "edgeCases": [
      "Test conditions that caused original bug"
    ],
    "validationApproach": {
      "unit": ["Test specific fix"],
      "e2e": ["Regression test for bug scenario"]
    }
  }
}
```

### Technical Debt Template

```json
{
  "testPlan": {
    "refactoringValidation": [
      "Behavior unchanged",
      "Performance improved or maintained",
      "No new issues introduced"
    ],
    "validationApproach": {
      "e2e": ["Full regression suite"],
      "performance": ["Before/after benchmarks"]
    }
  }
}
```

## Message Types

### test_plan_request

PM → QA/GameDesigner requesting test plan input:

```json
{
  "type": "test_plan_request",
  "from": "pm",
  "to": "qa",
  "payload": {
    "taskId": "feat-001",
    "title": "Task title",
    "description": "Task description",
    "acceptanceCriteria": ["Criteria 1", "Criteria 2"]
  }
}
```

### test_plan_contribution

QA/GameDesigner → PM providing test plan input:

```json
{
  "type": "test_plan_contribution",
  "from": "qa",
  "to": "pm",
  "payload": {
    "taskId": "feat-001",
    "testCases": [
      {
        "criteria": "User can login",
        "testSteps": [],
        "edgeCases": []
      }
    ],
    "validationApproach": {},
    "additionalConsiderations": []
  }
}
```

## Minimum Test Plan Requirements

Every test plan MUST include:

- [ ] Test case for EACH acceptance criterion
- [ ] At least 3 edge cases per criterion (or N/A if not applicable)
- [ ] Validation approach (unit, integration, E2E, manual)
- [ ] Design validation criteria (from Game Designer)
- [ ] Performance targets (if applicable)
- [ ] Browser compatibility matrix

## Anti-Patterns

❌ **DON'T:**

- Skip test planning for "simple" tasks
- Only plan unit tests (ignore E2E, manual)
- Forget Game Designer input on UI features
- Create generic plans without specific test steps
- Skip edge case consideration

✅ **DO:**

- Always plan before implementation
- Include all stakeholders (QA, Game Designer)
- Be specific with test steps and expected results
- Consider edge cases and error conditions
- Use MCP tools to enhance plan quality

## Streamlined Planning for Simple Tasks

For very simple tasks (e.g., typo fix, config change):

```powershell
# Skip full collaboration, create minimal plan:
{
  "testPlan": {
    "verification": "Verify the specific change works",
    "regression": "Ensure no side effects"
  }
}
```

## Checklist

Before moving from `test_planning` to `assigned`:

- [ ] Next task selected from PRD
- [ ] `test_plan_request` sent to QA
- [ ] `test_plan_request` sent to Game Designer
- [ ] QA contribution received
- [ ] Game Designer contribution received
- [ ] Test plan synthesized with all required sections
- [ ] MCP tools used for enhancement if applicable
- [ ] Test plan attached to task
- [ ] `currentTask.status = "assigned"`

## Related Skills

- [task-selection.md](./task-selection.md) - Selecting the next task
- [retrospective.md](./retrospective.md) - Preceding phase
- [prd-reorganization.md](./prd-reorganization.md) - May have created new tasks

## State Flow Integration

```
completed (retrospective done)
    ↓
test_planning ← THIS SKILL
    ↓
assigned (task sent to Developer)
```

During `test_planning`:
1. PM coordinates with QA and Game Designer
2. Creates comprehensive test plan
3. Attaches plan to task
4. Transitions to `assigned` when ready
