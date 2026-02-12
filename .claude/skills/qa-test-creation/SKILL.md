---
name: qa-test-creation
description: Test coverage check and creation workflow. Ensures tests exist for all features. Creates unit tests when missing following acceptance criteria. Use during validation before code review.
category: workflow
---

# Test Coverage Check and Creation Workflow

> "No feature passes QA without tests. If tests don't exist, we create them."

## When to Use This Skill

Use when:
- Validating a new feature (status: "awaiting_qa")
- PRD item has acceptance criteria but no tests exist
- Source files are modified but corresponding test files are missing
  
**CRITICAL:** NEVER CREATE FAKE OR TRIVIAL TESTS. If a test cannot be created with meaningful assertions based on the specs/gdd requirements, DO NOT CREATE A TEST. Instead, report the issue to PM and document the gap in test coverage in the task comments and close the task as completed with observations.

## Test Coverage Guidelines

**⚠️ CRITICAL: Focus on unit tests for code quality verification.**

QA validates implementation through:
- Code review for quality, anti-patterns, and maintainability
- Unit tests for component behavior, services, and utilities
- Specification validation against acceptance criteria

**Avoid browser/E2E testing** - AI agents do not reliably handle browser automation, which delays validation. QA must be smart enough to validate code quality through static analysis and unit testing.

### Unit Test Focus

| Component Type | Unit Test Coverage | Spec Validation |
| --------------- | ------------------- | ----------------- |
| Gameplay mechanic | YES (systems, components) | YES |
| UI Component | YES (rendering, behavior) | YES |
| Visual effect | YES (shader/material params) | YES |
| Service/Utility | YES (pure functions) | MAYBE |
| Asset (model/texture) | N/A | YES (visual inspection) |

**CRITICAL:** NEVER CREATE FAKE OR TRIVIAL TESTS. If a meaningful unit test cannot be created based on implementation specs, report the gap to PM and document as observation in task comments.

## Quick Start

```bash
# 1. Get the task ID from PRD
# 2. Check test coverage for modified files
# 3. If coverage incomplete, invoke test-creator
# 4. Verify tests pass before proceeding
```

## Test File Locations

### Unit Tests (Vitest)
- **Pattern**: Mirror `src/` structure in `src/tests/`
- **Example**: `src/components/game/player/index.ts` → `src/tests/components/game/player/index.test.ts`
- **Check**: For each source file, check if corresponding `src/tests/.../{name}.test.ts` exists

## Coverage Check Procedure

### Step 1: Get Task Information

```bash
# Read PRD for current task
cat prd.json | jq '.items[] | select(.id == "{taskId}")'

# Extract:
# - acceptance criteria
# - modified files (from git diff or PRD)
# - feature type (component, service, gameplay, etc.)
```

### Step 2: Identify Files to Check

```bash
# Get list of modified source files
git diff --name-only HEAD~5 HEAD | grep '^src/'

# Or read from task context
# Common patterns:
# - src/components/**/*.tsx
# - src/services/**/*.ts
# - src/stores/**/*.ts
# - src/utils/**/*.ts
# - src/ecs/**/*.ts
```

### Step 3: Check Unit Test Coverage

For each source file:

```bash
# Convert source path to test path
SOURCE="src/components/game/player/index.ts"
TEST="src/tests/components/game/player/index.test.ts"

# Check if test exists
if [ -f "$TEST" ]; then
  echo "Test exists: $TEST"
else
  echo "MISSING TEST: $TEST"
fi
```

### Step 4: Determine Required Tests

| Source File Pattern | Requires Unit Test? |
| ------------------- | ------------------- |
| `src/components/**/*.tsx` | Yes |
| `src/services/**/*.ts` | Yes |
| `src/stores/**/*.ts` | Yes |
| `src/utils/**/*.ts` | Yes |
| `src/ecs/**/*.ts` | Yes |
| `src/audio/**/*.ts` | Yes |
| `src/materials/**/*.ts` | No (visual asset) |
| `src/shaders/**/*.ts` | No (visual asset) |

### Step 6: Invoke Test Creator

**If tests are missing, invoke the test-creator sub-agent:**

```javascript
Task({
  subagent_type: "test-creator",
  description: "Create tests for {feature-name}",
  prompt: `
Create tests for the following task:

Task ID: {taskId}
Title: {title}
Acceptance Criteria:
{list of acceptance criteria}

Modified Files:
{list of modified files}

GDD Specs:
{relevant GDD sections}

Create:
1. Unit tests in src/tests/ mirroring src structure
2. E2E tests in tests/e2e/ with {feature}-suite.spec.ts naming

Ensure all acceptance criteria have test coverage.
`
})
```

### Step 6: Execute Tests and Verify

After tests are created (or if they already existed):

```bash
# Run unit tests
npm run test

# Verify tests pass
# Check exit codes and output
```

### Step 8: Test Failure Analysis

When tests fail, determine the root cause.

> **See `qa-workflow` skill for the Test Failure Decision Tree and how to distinguish test vs game code issues.**

### Step 8: Fix Test Code (If Applicable)

If issue is in test code, QA may fix:

```bash
# Edit test file directly (QA has permission for test files)
Edit src/tests/{path}/{feature}.test.ts

# Re-run specific test
npm run test -- src/tests/{path}/{feature}.test.ts

# Verify fix
git diff src/tests/{path}/{feature}.test.ts
```

### Step 9: Create Bug Report (If Game Code Issue)

If issue is in game code, use `qa-bug-reporting` skill:

```markdown
## Bug Report: {TASK_ID} - Test Failure

**Severity**: High
**Category**: Test / Runtime

### Summary
Unit test "{test_name}" failed due to game code not meeting acceptance criteria.

### Test That Failed
- File: src/tests/{path}/{feature}.test.ts
- Test: "{test_name}"
- Error: {error_message}

### Acceptance Criteria Not Met
- {criterion from test plan}

### Expected vs Actual
- Expected: {what test expects}
- Actual: {what actually happened}

### Test Output
\`\`\`
{npm run test output}
\`\`\`
```

## Coverage Report Template

After checking coverage, create a report:

```markdown
## Test Coverage Report for {taskId}

### Unit Tests
| Source File | Test File | Status |
| ------------ | --------- | ------ |
| src/components/game/player/index.ts | src/tests/components/game/player/index.test.ts | ✅ EXISTS / ❌ MISSING |
| src/services/ShootingService.ts | src/tests/services/ShootingService.test.ts | ✅ EXISTS / ❌ MISSING |

### Coverage Summary
- Unit test coverage: X%
- Action required: CREATE TESTS / NO ACTION
```

## Decision Tree

```
                    ┌─────────────────┐
                    │  Start Check    │
                    └────────┬────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │ Any source      │
                    │ files modified? │
                    └────────┬────────┘
                             │
                ┌────────────┴────────────┐
                │ NO                      │ YES
                ▼                         ▼
         ┌──────────┐          ┌──────────────────┐
         │ SKIP     │          │ Check each source │
         │ (assets   │          │ file for test     │
         │  only)    │          └─────────┬────────┘
         └──────────┘                    │
                             ┌────────────┴────────────┐
                             │                         │
                        Test exists              Test missing
                             │                         │
                             ▼                         ▼
                      ┌──────────┐            ┌──────────────┐
                      │ Mark OK  │            │ Invoke test- │
                      └──────────┘            │ creator      │
                                               └──────────────┘
```

## Integration with QA Workflow

**Add this step between "Task Research" and "Code Review":**

```
6. TASK RESEARCH (MANDATORY)
   ↓
7. TEST COVERAGE CHECK (NEW)
   - Check unit test coverage
   - Create missing tests via test-creator
   ↓
8. Run validation: code review → type-check → lint → test → build
```

## Test Creation Triggers

**Invoke test-creator when:**

1. **New feature implementation** - No tests exist for new code
2. **Missing unit tests** - Source file exists but no `.test.ts` in `src/tests/`
3. **Acceptance criteria untested** - Criterion has no corresponding test case

**Do NOT invoke test-creator when:**

1. Tests already exist and pass
2. Only configuration/doc changes
3. Asset file changes (models, textures)
4. Test refactoring (updating existing tests)

## Verification After Test Creation

After test-creator completes:

```bash
# 1. Verify tests were created
git status
git diff --cached

# 2. Run unit tests
npm run test

# 3. Verify coverage
npm run test -- --coverage

# 4. Proceed with validation workflow
```

## Examples

### Example 1: Player Movement Feature

**PRD Item:**
```json
{
  "id": "feat-movement-001",
  "title": "WASD Movement System",
  "acceptanceCriteria": [
    "Player moves forward when W is pressed",
    "Player moves left when A is pressed",
    "Player moves backward when S is pressed",
    "Player moves right when D is pressed"
  ],
  "files": [
    "src/components/game/player/index.tsx",
    "src/ecs/systems/MovementSystem.ts"
  ]
}
```

**Coverage Check:**
```bash
# Unit tests
src/tests/components/game/player/index.test.ts     ❌ MISSING
src/tests/ecs/systems/MovementSystem.test.ts       ❌ MISSING
```

**Action:** Invoke test-creator to create missing tests

### Example 2: UI Component Only

**PRD Item:**
```json
{
  "id": "feat-ui-001",
  "title": "Health Bar Component",
  "acceptanceCriteria": [
    "Displays current health",
    "Updates when health changes",
    "Shows correct color based on health percentage"
  ],
  "files": [
    "src/components/ui/HealthBar.tsx"
  ]
}
```

**Coverage Check:**
```bash
# Unit tests
src/tests/components/ui/HealthBar.test.ts          ❌ MISSING
```

**Action:** Invoke test-creator to create missing unit tests

## Best Practices

1. **Be thorough** - Every acceptance criterion needs test coverage
2. **Test behavior, not implementation** - Focus on what the feature does
3. **Use proper test structure** - AAA pattern for unit tests
4. **Ensure tests are independent** - No test dependencies
5. **Make tests fast** - Unit tests should run in milliseconds
6. **Use descriptive names** - Test names should explain what is being tested

## References

- [qa-unit-test-creation](./.claude/skills/qa-unit-test-creation/SKILL.md) - Unit test patterns
- [test-creator agent](./.claude/agents/test-creator.md) - Test creation sub-agent
