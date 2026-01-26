---
name: qa-test-creation
description: Test coverage check and creation workflow. Ensures tests exist for all features. Creates unit and E2E tests when missing following acceptance criteria.
---

# Test Coverage Check and Creation

> "No feature passes QA without tests. If tests don't exist, we create them."

## When to Use

Use when:
- Validating a new feature (status: "awaiting_qa")
- PRD item has acceptance criteria but no tests exist
- Source files are modified but corresponding test files are missing

## Test File Locations

| Type | Pattern | Example |
|------|---------|---------|
| **Unit Tests** | Mirror `src/` in `src/tests/` | `src/components/game/player/index.ts` → `src/tests/components/game/player/index.test.ts` |
| **E2E Tests** | Flat structure in `tests/e2e/` | Feature → `tests/e2e/{feature}-suite.spec.ts` |

## Coverage Requirements

| Source File Pattern | Unit Test | E2E Test |
|-------------------|-----------|----------|
| `src/components/**/*.tsx` | Yes | If user interaction |
| `src/services/**/*.ts` | Yes | If network-related |
| `src/stores/**/*.ts` | Yes | If user-facing |
| `src/utils/**/*.ts` | Yes | No |
| `src/ecs/**/*.ts` | Yes | If gameplay-related |
| `src/audio/**/*.ts` | Yes | No |
| `src/materials/**/*.ts` | No | Yes (visual) |
| `src/shaders/**/*.ts` | No | Yes (visual) |

---

<examples>

## Example 1: Complete Coverage (New Feature)

**PRD Item:**
```json
{
  "id": "feat-movement-001",
  "title": "WASD Movement System",
  "acceptanceCriteria": [
    "Player moves forward when W is pressed",
    "Player moves left when A is pressed"
  ],
  "files": [
    "src/components/game/player/index.tsx",
    "src/ecs/systems/MovementSystem.ts"
  ]
}
```

**Coverage Decision:** ❌ Tests missing → Create tests

---

## Example 2: Partial Coverage (UI Component)

**PRD Item:**
```json
{
  "id": "feat-ui-001",
  "title": "Health Bar Component",
  "files": ["src/components/ui/HealthBar.tsx"]
}
```

**Coverage Check:**
- Unit test: `src/tests/components/ui/HealthBar.test.ts` ❌ MISSING
- E2E test: `tests/e2e/ui-suite.spec.ts` ✅ EXISTS (add tests)

**Coverage Decision:** Create unit test, add E2E tests to existing suite

---

## Example 3: Tests Already Exist

**PRD Item:**
```json
{
  "id": "feat-audio-001",
  "files": ["src/audio/effects.ts"]
}
```

**Coverage Check:**
- Unit test: `src/tests/audio/effects.test.ts` ✅ EXISTS
- All acceptance criteria covered ✅

**Coverage Decision:** Skip test creation, proceed to validation
</examples>

---

## Coverage Check Procedure

### Step 1: Identify Files to Check

```bash
# Get list of modified source files
git diff --name-only HEAD~5 HEAD | grep '^src/'

# Or read from PRD task context
```

### Step 2: Check Unit Test Coverage

For each source file, check if corresponding test exists:

```bash
# Convert source path to test path
SOURCE="src/components/game/player/index.ts"
TEST="src/tests/components/game/player/index.test.ts"

# Check if test exists
[ -f "$TEST" ] && echo "✅ EXISTS" || echo "❌ MISSING"
```

### Step 3: Check E2E Test Coverage

```bash
# List existing E2E tests
ls tests/e2e/*.spec.ts

# Expected: auth-suite, gameplay-suite, multiplayer-suite, ui-suite, etc.
```

### Step 4: Invoke Test Creator If Needed

When tests are missing, invoke test-creation sub-agent:

```javascript
Task({
  subagent_type: "developer-implementation", // Use for test creation
  description: "Create tests for {feature-name}",
  prompt: `
Create tests for task {taskId}:
Title: {title}
Acceptance Criteria: {list}
Modified Files: {list}

Create:
1. Unit tests in src/tests/ mirroring src structure
2. E2E tests in tests/e2e/ with {feature}-suite.spec.ts naming
`
})
```

---

## Coverage Report Template

```markdown
## Test Coverage Report for {taskId}

### Unit Tests
| Source File | Test File | Status |
| ------------ | --------- | ------ |
| src/components/game/player/index.ts | src/tests/components/game/player/index.test.ts | ✅ / ❌ |

### E2E Tests
| Feature | Test File | Status |
| ------- | --------- | ------ |
| Gameplay | tests/e2e/gameplay-suite.spec.ts | ✅ / ❌ |

### Summary
- Unit test coverage: X%
- E2E test coverage: X/Y features
- Action: CREATE TESTS / NO ACTION
```

---

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
                      │ Mark OK  │            │ Create tests │
                      └──────────┘            └──────────────┘
```

---

## Test Creation Triggers

**Create tests when:**
- New feature implementation (no tests exist)
- Missing unit tests (source file without `.test.ts`)
- Missing E2E tests (user-facing behavior without `.spec.ts`)
- Acceptance criteria untested (no corresponding test case)

**Skip test creation when:**
- Tests already exist and pass
- Only configuration/doc changes
- Asset file changes (models, textures)
- Test refactoring (updating existing tests)

---

## Verification After Test Creation

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

---

## References

- **[qa-unit-test-creation/SKILL.md](../qa-unit-test-creation/SKILL.md)** - Unit test patterns
- **[qa-e2e-test-creation/SKILL.md](../qa-e2e-test-creation/SKILL.md)** - E2E test patterns
- [tests/pages/multiplayer.page.ts](tests/pages/multiplayer.page.ts) - Page Object examples
