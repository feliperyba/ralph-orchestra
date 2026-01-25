---
name: qa-test-creation
description: Test coverage check and creation workflow. Ensures tests exist for all features. Creates unit and E2E tests when missing following acceptance criteria. Use during validation before code review.
---

# Test Coverage Check and Creation Workflow

> "No feature passes QA without tests. If tests don't exist, we create them."

## When to Use This Skill

Use when:
- Validating a new feature (status: "awaiting_qa")
- PRD item has acceptance criteria but no tests exist
- Source files are modified but corresponding test files are missing

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

### E2E Tests (Playwright)
- **Pattern**: Flat structure in `tests/e2e/`
- **Example**: `tests/e2e/gameplay-suite.spec.ts`, `tests/e2e/auth-suite.spec.ts`
- **Check**: For each feature, check if corresponding `tests/e2e/{feature}-suite.spec.ts` exists

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

### Step 4: Check E2E Test Coverage

```bash
# List existing E2E tests
ls tests/e2e/*.spec.ts

# Expected tests for features:
# - auth-suite.spec.ts       (character selection, lobby)
# - gameplay-suite.spec.ts   (movement, shooting, paint)
# - multiplayer-suite.spec.ts (state sync, multi-client)
# - ui-suite.spec.ts         (UI components)
```

### Step 5: Determine Required Tests

| Source File Pattern | Requires Unit Test? | Requires E2E Test? |
| ------------------- | ------------------- | ------------------ |
| `src/components/**/*.tsx` | Yes | Maybe* |
| `src/services/**/*.ts` | Yes | If network-related |
| `src/stores/**/*.ts` | Yes | Maybe* |
| `src/utils/**/*.ts` | Yes | No |
| `src/ecs/**/*.ts` | Yes | If gameplay-related |
| `src/audio/**/*.ts` | Yes | No |
| `src/materials/**/*.ts` | No | Yes (visual) |
| `src/shaders/**/*.ts` | No | Yes (visual) |

*_E2E test needed if component has user interaction or visual output_

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

## Coverage Report Template

After checking coverage, create a report:

```markdown
## Test Coverage Report for {taskId}

### Unit Tests
| Source File | Test File | Status |
| ------------ | --------- | ------ |
| src/components/game/player/index.ts | src/tests/components/game/player/index.test.ts | ✅ EXISTS / ❌ MISSING |
| src/services/ShootingService.ts | src/tests/services/ShootingService.test.ts | ✅ EXISTS / ❌ MISSING |

### E2E Tests
| Feature | Test File | Status |
| ------- | --------- | ------ |
| Authentication | tests/e2e/auth-suite.spec.ts | ✅ EXISTS / ❌ MISSING |
| Gameplay | tests/e2e/gameplay-suite.spec.ts | ✅ EXISTS / ❌ MISSING |

### Coverage Summary
- Unit test coverage: X%
- E2E test coverage: X/Y features
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
         │ (E2E     │          │ file for test     │
         │  only)   │          └─────────┬────────┘
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
   - Check E2E test coverage
   - Create missing tests via test-creator
   ↓
8. Run validation: code review → type-check → lint → test → build → E2E
```

## Test Creation Triggers

**Invoke test-creator when:**

1. **New feature implementation** - No tests exist for new code
2. **Missing unit tests** - Source file exists but no `.test.ts` in `src/tests/`
3. **Missing E2E tests** - Feature has user-facing behavior but no `.spec.ts`
4. **Acceptance criteria untested** - Criterion has no corresponding test case

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

# 3. Run E2E tests
npm run test:e2e

# 4. Verify coverage
npm run test -- --coverage

# 5. Proceed with validation workflow
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

# E2E tests
tests/e2e/gameplay-suite.spec.ts                   ✅ EXISTS (add tests)
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

# E2E tests
tests/e2e/ui-suite.spec.ts                         ❌ MISSING
```

**Action:** Invoke test-creator for both unit and E2E tests

## Best Practices

1. **Be thorough** - Every acceptance criterion needs test coverage
2. **Test behavior, not implementation** - Focus on what the feature does
3. **Use proper test structure** - AAA for unit, user flows for E2E
4. **Ensure tests are independent** - No test dependencies
5. **Make tests fast** - Unit tests should run in milliseconds
6. **Use descriptive names** - Test names should explain what is being tested

## References

- [qa-unit-test-creation](.claude/skills/qa-unit-test-creation/SKILL.md) - Unit test patterns
- [qa-e2e-test-creation](.claude/skills/qa-e2e-test-creation/SKILL.md) - E2E test patterns
- [test-creator agent](.claude/agents/test-creator.md) - Test creation sub-agent
- [playwright.config.ts](playwright.config.ts) - Playwright configuration
- [tests/e2e/multiplayer-suite.spec.ts](tests/e2e/multiplayer-suite.spec.ts) - Example E2E tests
