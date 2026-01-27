---
name: dev-validation-browser-testing
description: E2E test creation for Developer - write tests using Playwright API for feature validation
category: validation
---

# Browser Testing for Developer

> "Write E2E tests that validate your implementation and become regression tests for CI/CD."

## When to Use This Skill

Use when:

- Implementing new features with user-facing behavior
- Modifying existing gameplay mechanics
- Adding or changing UI components
- Before committing code to send to QA

## Quick Start

```bash
# 1. Create E2E test file
# tests/e2e/{feature}-suite.spec.ts

# 2. Write test covering acceptance criteria
# Use patterns from qa-e2e-test-creation/SKILL.md

# 3. Run test to verify implementation
npm run test:e2e -- -g "test-name"

# 4. Commit test with implementation
git add tests/e2e/{feature}-suite.spec.ts
```

## MANDATORY: Port Detection Before Browser Testing

**⚠️ CRITICAL: Vite dev server may run on different ports (3000, 3001, 5173, 8080, etc.)**

**Before ANY browser interaction, ALWAYS detect the correct port:**

```bash
# Method 1: Check listening ports
netstat -an | grep LISTEN | grep -E ":(3000|3001|5173|8080)"

# Method 2: Try curl to detect Vite
curl -s http://localhost:3000 | grep -q "vite" && echo "PORT=3000" || \
curl -s http://localhost:3001 | grep -q "vite" && echo "PORT=3001" || \
curl -s http://localhost:5173 | grep -q "vite" && echo "PORT=5173"
```

**NOTE:** E2E tests configured in `playwright.config.ts` use `baseURL: 'http://localhost:3000'` and the `webServer` configuration automatically starts the dev server on the correct port.

**For manual testing or MCP validation, detect the port first and use `http://localhost:{detectedPort}`.**

## Core Principle: Write Tests, Don't Run MCP

**❌ OLD APPROACH (Do NOT do this):**

```typescript
// Interactive MCP testing - NO!
mcp__playwright__browser_navigate('http://localhost:3000');
mcp__playwright__browser_take_screenshot({ filename: 'test.png' });
```

**✅ NEW APPROACH (Do this):**

```typescript
// Write E2E test file - YES!
test('new feature works', async ({ page }) => {
  await page.goto('http://localhost:3000');
  await expect(page.getByTestId('new-feature')).toBeVisible();
});
```

## E2E Test Creation Workflow

### Step 1: Check for Existing Tests

```bash
# Check if test file exists
ls tests/e2e/{feature}-suite.spec.ts

# If exists, add tests to existing file
# If not, create new test file
```

### Step 2: Create or Update Test File

**File location:** `tests/e2e/{feature}-suite.spec.ts`

**Basic structure:**

```typescript
import { test, expect } from '@playwright/test';

test.describe('Feature Name', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('http://localhost:3000'); // E2E tests use baseURL from playwright.config.ts
  });

  test('should meet acceptance criterion 1', async ({ page }) => {
    // Test implementation
  });

  test('should meet acceptance criterion 2', async ({ page }) => {
    // Test implementation
  });
});
```

### Step 3: Use Accessible Selectors

```typescript
// ✅ Good - Role-based
page.getByRole('button', { name: 'Submit' });

// ✅ Good - By label
page.getByLabel('Email address');

// ✅ Good - Test ID (when no accessible name)
page.getByTestId('submit-button');

// ❌ Bad - Brittle CSS selector
page.locator('.btn-primary:first-child');
```

### Step 4: Run Test to Verify

```bash
# Run specific test
npm run test:e2e -- -g "test-name"

# Run specific file
npm run test:e2e -- tests/e2e/{feature}-suite.spec.ts

# Run in headed mode (see browser)
npm run test:e2e -- --headed
```

### Step 5: Commit Test with Implementation

```bash
# Add test file with your implementation
git add tests/e2e/{feature}-suite.spec.ts
git commit -m "[ralph] [developer] feat-XXX: Add E2E test for {feature}"
```

## Common Test Patterns

### Feature Works Test

```typescript
test('new feature is visible and functional', async ({ page }) => {
  await page.goto('http://localhost:3000');

  // Verify feature exists
  await expect(page.getByTestId('new-feature')).toBeVisible();

  // Verify it works
  await page.getByTestId('new-feature').click();
  await expect(page.getByText('Expected result')).toBeVisible();
});
```

### Console Error Check

```typescript
test('no console errors when using feature', async ({ page }) => {
  const errors: string[] = [];

  page.on('console', (msg) => {
    if (msg.type() === 'error') {
      errors.push(msg.text());
    }
  });

  await page.goto('http://localhost:3000');

  // Use the feature
  await page.getByTestId('new-feature').click();

  // Verify no errors
  expect(errors).toHaveLength(0);
});
```

### Navigation Test

```typescript
test('navigation flows work correctly', async ({ page }) => {
  await page.goto('http://localhost:3000');

  // Navigate through feature
  await page.getByRole('button', { name: 'Start' }).click();
  await expect(page).toHaveURL(/\/game/);

  // Verify expected state
  await expect(page.getByTestId('game-ui')).toBeVisible();
});
```

### Input Test

```typescript
test('keyboard controls work', async ({ page }) => {
  await page.goto('http://localhost:3000');
  await page.click('canvas'); // Focus game

  // Test WASD movement
  await page.keyboard.down('KeyW');
  await page.waitForTimeout(500);
  await page.keyboard.up('KeyW');

  // Verify position changed
  const position = await page.evaluate(() => {
    return (window as any).gameState?.player?.position;
  });
  expect(position).toBeDefined();
});
```

## Page Object Model

For complex tests, use Page Objects from `tests/pages/`:

```typescript
import { test, expect } from '@playwright/test';
import { GamePage } from '@/pages/game.page';

test('complete user flow', async ({ page }) => {
  const gamePage = new GamePage(page);

  await gamePage.goto();
  await gamePage.selectCharacter('TestPlayer');
  await gamePage.waitForLobby();

  expect(await gamePage.isConnected()).toBe(true);
});
```

## When Tests Are Required

Create E2E tests for:

| Scenario                   | Test Required? |
| -------------------------- | -------------- |
| New user-facing feature    | ✅ Yes         |
| Gameplay mechanic changes  | ✅ Yes         |
| UI component changes       | ✅ Yes         |
| Bug fixes with user impact | ✅ Yes         |
| Internal refactor only     | ❌ No          |
| Type definition changes    | ❌ No          |
| Build/config changes       | ❌ No          |

## Running Tests Before Commit

```bash
# Full validation sequence
npm run type-check  # 0 errors
npm run lint        # 0 warnings
npm run test        # Unit tests pass
npm run test:e2e    # E2E tests pass
npm run build       # Build succeeds
```

## Test Location Reference

| Test Type    | Location                            |
| ------------ | ----------------------------------- |
| E2E Tests    | `tests/e2e/{feature}-suite.spec.ts` |
| Page Objects | `tests/pages/{name}.page.ts`        |
| Unit Tests   | `src/**/{name}.test.ts`             |

## Reference Patterns

For comprehensive E2E test patterns, see:

- **[qa-e2e-test-creation/SKILL.md](../qa-e2e-test-creation/SKILL.md)** - Full E2E test reference
- [Playwright Documentation](https://playwright.dev/docs/intro)

## Examples by Feature Type

### UI Component Test

```typescript
test('button renders and is clickable', async ({ page }) => {
  await page.goto('http://localhost:3000');

  const button = page.getByRole('button', { name: 'Submit' });
  await expect(button).toBeVisible();
  await button.click();

  // Verify result
  await expect(page.getByText('Success')).toBeVisible();
});
```

### Gameplay Mechanic Test

```typescript
test('player can move with WASD', async ({ page }) => {
  await page.goto('http://localhost:3000');

  // Get initial position
  const initialPos = await page.evaluate(() => (window as any).gameState?.player?.position);

  // Press W to move forward
  await page.click('canvas');
  await page.keyboard.down('KeyW');
  await page.waitForTimeout(500);
  await page.keyboard.up('KeyW');

  // Check position changed
  const finalPos = await page.evaluate(() => (window as any).gameState?.player?.position);

  expect(finalPos?.z).not.toBe(initialPos?.z);
});
```

### Form Input Test

```typescript
test('form validation works', async ({ page }) => {
  await page.goto('http://localhost:3000');

  // Try to submit empty form
  await page.getByRole('button', { name: 'Submit' }).click();

  // Should show error
  await expect(page.getByText('Name is required')).toBeVisible();

  // Fill and submit
  await page.getByLabel('Name').fill('TestName');
  await page.getByRole('button', { name: 'Submit' }).click();

  // Should succeed
  await expect(page).toHaveURL(/\/success/);
});
```

## Server Management

**⚠️ CRITICAL: Use `shared-lifecycle` skill for server management.**

### Server Detection (Before Running E2E Tests)

**⚠️ IMPORTANT: Playwright's `webServer` config manages servers for E2E tests automatically.**

When running `npm run test:e2e`, Playwright automatically starts:
- `npm run dev` (port 3000) with `reuseExistingServer: !process.env.CI`

**DO NOT manually start servers for E2E tests.**

### Server Check Pattern

```bash
# Check if dev server is running (port 3000)
netstat -an | grep :3000 || lsof -i :3000

# Alternative: Try curl to detect Vite
curl -s http://localhost:3000 | grep -q "vite" && echo "RUNNING" || echo "NOT_RUNNING"
```

### E2E Test Path (Standard)

```bash
# Playwright handles server lifecycle via webServer config
npm run test:e2e -- tests/e2e/{feature}-suite.spec.ts

# NO manual server start needed
# NO manual cleanup needed - Playwright handles it
```

### Manual Testing Path (Only when explicitly needed)

```bash
# Only for manual browser testing (NOT E2E tests)
# Check port 3000 first
if ! netstat -an | grep :3000; then
  # Start server in background
  Bash(command="npm run dev", run_in_background=true)
  # Capture shell_id for cleanup: { shell_id: "abc123" }
fi

# After testing completes:
TaskStop(task_id="abc123")  # MANDATORY cleanup
```

**See also:** `shared-lifecycle` skill for complete process management patterns.

## Anti-Patterns

❌ **DON'T:**

- Use Playwright MCP directly during development
- Skip writing tests for user-facing features
- Write brittle CSS selectors
- Use hardcoded `waitForTimeout()` when assertions would work
- Commit implementation without tests

✅ **DO:**

- Write E2E tests as code artifacts
- Use accessible selectors (getByRole, getByLabel, getByTestId)
- Let Playwright auto-wait with assertions
- Commit tests with implementation
- Run tests before sending to QA

## Checklist

Before committing implementation:

- [ ] E2E test file created in `tests/e2e/`
- [ ] Test covers all acceptance criteria
- [ ] Test uses accessible selectors
- [ ] Test passes locally: `npm run test:e2e -- -g "test-name"`
- [ ] Test file committed with implementation
- [ ] No console errors in test output
- [ ] Screenshot captured for visual features (if needed)
