---
name: qa-browser-testing
description: E2E test creation and execution for QA. Validates implementations using Playwright API tests that become persistent artifacts for regression.
---

# Browser Testing for QA

> "Validate implementations with E2E tests that become regression tests for the project."

## When to Use

Use for **every validation** after automated checks pass.

---

## Quick Start

```bash
# 1. Check if E2E test exists
ls tests/e2e/{feature}-suite.spec.ts

# 2. If missing, create using qa-e2e-test-creation
# Skill("qa-e2e-test-creation")

# 3. Run E2E tests
npm run test:e2e
```

---

## Core Principle: Run Tests, Don't Use MCP

**❌ OLD (Do NOT do this):**
```typescript
mcp__playwright__browser_navigate('http://localhost:3000');
mcp__playwright__browser_take_screenshot({ filename: 'validation.png' });
```

**✅ NEW (Do this):**
```typescript
npm run test:e2e -- tests/e2e/{feature}-suite.spec.ts
```

---

## Test Categories

| Category | What to Check | Test Pattern |
|----------|---------------|--------------|
| **Load** | Page loads, canvas renders | `test('page loads', ...)` |
| **Console** | No errors or warnings | Console listener test |
| **Functional** | Features work as specified | Acceptance criteria tests |
| **Visual** | UI appears correctly | Screenshot comparison |
| **Performance** | 60 FPS, no stuttering | FPS monitoring test |
| **Input** | Controls respond correctly | WASD/mouse tests |

---

<details>
<summary>Test Execution Commands</summary>

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

# Run on different browsers
npm run test:e2e -- --project=chromium
npm run test:e2e -- --project=firefox
npm run test:e2e -- --project=webkit
```

</details>

---

## Common Test Patterns

See [tests/pages/](tests/pages/) for Page Object Model classes.

### Basic Load Test

```typescript
test('page loads correctly', async ({ page }) => {
  await page.goto('http://localhost:3000');

  const canvas = page.locator('canvas');
  await expect(canvas).toBeVisible();

  const errors: string[] = [];
  page.on('console', (msg) => {
    if (msg.type() === 'error') errors.push(msg.text());
  });

  await page.waitForTimeout(5000);
  expect(errors).toHaveLength(0);
});
```

### Input Testing

```typescript
test('keyboard controls work', async ({ page }) => {
  await page.goto('http://localhost:3000');
  await page.click('canvas');

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
  await page.waitForTimeout(2000);

  await expect(page).toHaveScreenshot('baseline.png', {
    maxDiffPixelRatio: 0.01,
  });
});
```

### Pointer Lock Testing

```typescript
test('pointer lock activates', async ({ page }) => {
  await page.goto('http://localhost:3000');
  await page.waitForTimeout(200);

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

  const metrics = await page.evaluate(() => {
    const nav = performance.getEntriesByType('navigation')[0] as PerformanceNavigationTiming;
    return {
      loadTime: nav.loadEventEnd - nav.startTime,
      domContentLoaded: nav.domContentLoadedEventEnd - nav.startTime,
    };
  });

  expect(metrics.loadTime).toBeLessThan(3000);
  expect(metrics.domContentLoaded).toBeLessThan(2000);
});
```

---

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

---

## Verification Output Format

```markdown
## Browser Validation Results

### E2E Tests
- Test file: tests/e2e/{feature}-suite.spec.ts
- Tests passed: X/Y
- Failed: [list]

### Console Status
- Errors: X
- Warnings: X

### Acceptance Criteria
- Criterion 1: ✅ Pass / ❌ Fail - {details}
- Criterion 2: ✅ Pass / ❌ Fail - {details}

### Screenshots
- {screenshot-path}

### Overall Result
- Status: ✅ PASS / ❌ FAIL
```

---

## Decision Framework

| Test Result | Action |
|-------------|--------|
| All E2E tests pass | Mark as PASSED |
| Some tests fail | Mark as NEEDS_FIXES with bug notes |
| Console errors | Mark as NEEDS_FIXES |
| No test exists | Create test first, then validate |

---

## Cross-Browser Testing

| Browser | Priority | Notes |
|---------|----------|-------|
| Chrome/Chromium | Required | Primary target |
| Firefox | Recommended | WebGL differences |
| Safari/WebKit | If targeting iOS | Significant differences |
| Edge | Optional | Uses Chromium |

---

## Hybrid Model: Tests Serve Dual Purpose

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

---

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

---

## Validation Checklist

- [ ] E2E test file exists in `tests/e2e/`
- [ ] `npm run test:e2e` runs without errors
- [ ] All acceptance criteria covered by tests
- [ ] No console errors during tests
- [ ] Performance acceptable (60 FPS target)
- [ ] Screenshot comparison passes (for visual features)
- [ ] Tests committed to repository

---

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

---

## References

- **[qa-e2e-test-creation/SKILL.md](../qa-e2e-test-creation/SKILL.md)** - Full E2E test patterns
- **[tests/pages/](tests/pages/)** - Page Object Model classes
- [Playwright Documentation](https://playwright.dev/docs/intro)
