---
name: qa-browser-testing
description: E2E test creation and execution for QA. Validates implementations using Playwright API tests that become persistent artifacts for regression.
---

# Browser Testing for QA

> "Validate implementations with E2E tests that become regression tests for the project."

## When to Use This Skill

Use for **every validation** after automated checks pass:
- Validating Developer implementation
- Verifying Tech Artist visual assets
- Testing gameplay mechanics
- Checking UI components
- Before marking PRD items as passed

## Quick Start

```bash
# 1. Check if E2E test exists for the feature
ls tests/e2e/{feature}-suite.spec.ts

# 2. If missing, create using qa-e2e-test-creation patterns
# Use Skill("qa-e2e-test-creation")

# 3. Run E2E tests to validate implementation
npm run test:e2e

# 4. Review test output for acceptance criteria verification
```

## Core Principle: Run Tests, Don't Use MCP

**❌ OLD APPROACH (Do NOT do this):**
```typescript
// Interactive MCP validation - NO!
mcp__playwright__browser_navigate('http://localhost:3000');
mcp__playwright__browser_take_screenshot({ filename: 'validation.png' });
```

**✅ NEW APPROACH (Do this):**
```typescript
// Write or run E2E test - YES!
npm run test:e2e -- tests/e2e/{feature}-suite.spec.ts
```

## Validation Workflow

### Level 0: Test Coverage Check (BEFORE Validation)

**⚠️ CRITICAL: Ensure tests exist before validation**

1. **Check if E2E test exists** for the validated feature:
   ```bash
   # Look for test file
   ls tests/e2e/{feature}-suite.spec.ts

   # Or search for task/feature in tests
   grep -r "taskId" tests/e2e/
   ```

2. **If test is missing:**
   - Load `qa-e2e-test-creation` skill
   - Create test covering acceptance criteria
   - Verify test runs successfully

### Level 1: Run E2E Tests

```bash
# Run all E2E tests
npm run test:e2e

# Run specific test file
npm run test:e2e -- tests/e2e/{feature}-suite.spec.ts

# Run specific test by name
npm run test:e2e -- -g "test-name"

# Run in headed mode (see browser)
npm run test:e2e -- --headed

# Run with debug mode
npm run test:e2e -- --debug
```

### Level 2: Verify Acceptance Criteria

For each acceptance criterion in `prd.json.items[{taskId}]`:

```markdown
## Acceptance Criteria Verification

### Criterion 1: "Feature does X"

- **Test**: `npm run test:e2e -- -g "feature does X"`
- **Result**: ✅ PASS / ❌ FAIL
- **Evidence**: Test output shows expected behavior
```

### Level 3: Report Results

**If ALL tests pass:**
```json
{
  "id": "{taskId}",
  "passes": true,
  "status": "passed",
  "validatedAt": "{ISO_TIMESTAMP}",
  "testResults": {
    "e2eTests": "passed",
    "testFile": "tests/e2e/{feature}-suite.spec.ts"
  }
}
```

**If ANY test fails:**
```json
{
  "id": "{taskId}",
  "status": "needs_fixes",
  "bugNotes": "Test failure details...",
  "retryCount": 1,
  "testResults": {
    "e2eTests": "failed",
    "failureReason": "Test output excerpt"
  }
}
```

## Test Categories

| Category | What to Check | Test Pattern |
|----------|---------------|--------------|
| **Load** | Page loads, canvas renders | `test('page loads', ...)` |
| **Console** | No errors or warnings | Console listener test |
| **Functional** | Features work as specified | Acceptance criteria tests |
| **Visual** | UI appears correctly | Screenshot comparison |
| **Performance** | 60 FPS, no stuttering | FPS monitoring test |
| **Input** | Controls respond correctly | WASD/mouse tests |

## Creating Tests for Missing Coverage

When Developer/Tech Artist didn't create tests:

```typescript
// tests/e2e/{feature}-suite.spec.ts
import { test, expect } from '@playwright/test';

test.describe('Feature Name - {taskId}', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('http://localhost:3000');
  });

  test('should meet acceptance criterion 1', async ({ page }) => {
    // Test implementation
  });

  test('should meet acceptance criterion 2', async ({ page }) => {
    // Test implementation
  });
});
```

**Then verify:**
```bash
npm run test:e2e -- tests/e2e/{feature}-suite.spec.ts
```

## Common Test Patterns for Validation

### Basic Load Test

```typescript
test('page loads correctly', async ({ page }) => {
  await page.goto('http://localhost:3000');

  // Wait for canvas
  const canvas = page.locator('canvas');
  await expect(canvas).toBeVisible();

  // Check for console errors
  const errors: string[] = [];
  page.on('console', (msg) => {
    if (msg.type() === 'error') errors.push(msg.text());
  });

  await page.waitForTimeout(5000); // Wait for initial load
  expect(errors).toHaveLength(0);
});
```

### Input Testing

```typescript
test('keyboard controls work', async ({ page }) => {
  await page.goto('http://localhost:3000');
  await page.waitForSelector('canvas');

  // Focus canvas
  await page.click('canvas');

  // Press WASD keys
  await page.keyboard.down('KeyW');
  await page.waitForTimeout(500);
  await page.screenshot({ path: 'test-results/after-w.png' });
  await page.keyboard.up('KeyW');
});
```

### Visual Comparison

```typescript
test('visual appearance matches', async ({ page }) => {
  await page.goto('http://localhost:3000');
  await page.waitForSelector('canvas');
  await page.waitForTimeout(2000); // Wait for scene to stabilize

  // Compare with baseline
  await expect(page).toHaveScreenshot('baseline.png', {
    maxDiffPixelRatio: 0.01,
  });
});
```

### Pointer Lock Testing (FPS/TPS)

```typescript
test('pointer lock activates on game start', async ({ page }) => {
  await page.goto('http://localhost:3000');
  await page.waitForSelector('canvas');

  // Wait for auto-lock timeout (typically 100ms)
  await page.waitForTimeout(200);

  // Check if pointer lock is active
  const isLocked = await page.evaluate(() => {
    return document.pointerLockElement === document.body;
  });

  expect(isLocked).toBe(true);
});
```

### Performance Metrics

```typescript
test('performance is acceptable', async ({ page }) => {
  await page.goto('http://localhost:3000');

  // Get performance metrics
  const metrics = await page.evaluate(() => {
    const entries = performance.getEntriesByType('navigation');
    const nav = entries[0] as PerformanceNavigationTiming;
    return {
      loadTime: nav.loadEventEnd - nav.startTime,
      domContentLoaded: nav.domContentLoadedEventEnd - nav.startTime,
    };
  });

  expect(metrics.loadTime).toBeLessThan(3000);
  expect(metrics.domContentLoaded).toBeLessThan(2000);
});
```

## Console Error Monitoring

Every validation should include console error checking:

```typescript
test.describe('Console Error Check', () => {
  test('should have no console errors', async ({ page }) => {
    const errors: string[] = [];
    const warnings: string[] = [];

    page.on('console', (msg) => {
      if (msg.type() === 'error') errors.push(msg.text());
      if (msg.type() === 'warning') warnings.push(msg.text());
    });

    await page.goto('http://localhost:3000');
    await page.waitForTimeout(5000);

    expect(errors).toHaveLength(0);
    expect(warnings).toHaveLength(0);
  });
});
```

## Page Object Model Usage

For complex validations, use Page Objects from `tests/pages/`:

```typescript
import { test, expect } from '@playwright/test';
import { GamePage } from '@/pages/game.page';
import { MultiplayerPage } from '@/pages/multiplayer.page';

test('complete gameplay loop', async ({ page }) => {
  const gamePage = new GamePage(page);

  await gamePage.goto();
  await gamePage.selectCharacter('TestPlayer');
  await gamePage.waitForLobby();

  expect(await gamePage.isConnected()).toBe(true);
});

test('multiplayer state sync', async ({ browser }) => {
  const multiplayerPage = new MultiplayerPage(page);
  const players = await multiplayerPage.setupMultiPlayerTest(browser, 2);

  try {
    await multiplayerPage.connectPlayersToGame(players);
    expect(await multiplayerPage.verifyAllConnected(players)).toBe(true);
  } finally {
    await multiplayerPage.cleanupPlayers(players);
  }
});
```

## Cross-Browser Testing

| Browser | Priority | Notes |
|---------|----------|-------|
| Chrome/Chromium | Required | Primary target |
| Firefox | Recommended | WebGL differences |
| Safari/WebKit | If targeting iOS | Significant differences |
| Edge | Optional | Uses Chromium |

```bash
# Run on different browsers
npm run test:e2e -- --project=chromium
npm run test:e2e -- --project=firefox
npm run test:e2e -- --project=webkit
```

## Hybrid Model: Tests Serve Dual Purpose

**New Feature Validation → Regression Tests**

```
Developer/Tech Artist writes E2E test
                ↓
           QA validates feature
                ↓
          Test passes
                ↓
    Feature merged to main
                ↓
    Test becomes regression check in CI/CD
```

## Decision Framework

| Test Result | Action |
|-------------|--------|
| All E2E tests pass | Mark as PASSED |
| Some tests fail | Mark as NEEDS_FIXES with bug notes |
| Console errors | Mark as NEEDS_FIXES |
| No test exists | Create test first, then validate |

## Anti-Patterns

❌ **DON'T:**

- Use Playwright MCP directly for validation
- Skip E2E tests because automated checks passed
- Mark as passed without running tests
- Assume "it works on my machine"

✅ **DO:**

- Always run E2E tests for validation
- Create tests if missing
- Verify all acceptance criteria with tests
- Document failures with test output

## Validation Checklist

For each validation:

- [ ] E2E test file exists in `tests/e2e/`
- [ ] `npm run test:e2e` runs without errors
- [ ] All acceptance criteria covered by tests
- [ ] No console errors during tests
- [ ] Performance acceptable (60 FPS target)
- [ ] Screenshot comparison passes (for visual features)
- [ ] Tests committed to repository

## Bug Report Format

When tests fail, include in bug notes:

```markdown
## Test Failure

**Test File**: tests/e2e/{feature}-suite.spec.ts
**Test Name**: "{test-name}"
**Error Message**: {error from test output}

**Steps to Reproduce**:
1. npm run test:e2e -- -g "{test-name}"
2. Observe failure

**Expected**: {expected behavior}
**Actual**: {actual behavior from test output}
```

## References

- **[qa-e2e-test-creation/SKILL.md](../qa-e2e-test-creation/SKILL.md)** - Full E2E test patterns
- [Playwright Documentation](https://playwright.dev/docs/intro)
- [tests/pages/](tests/pages/) - Page Object Model classes
