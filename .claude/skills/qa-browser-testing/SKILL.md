---
name: qa-browser-testing
description: E2E test creation and execution for QA. Validates implementations using Playwright API tests that become persistent artifacts for regression.
category: validation
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

### Load State Decision Tree

**CRITICAL: Choose correct load state to avoid flaky timeouts**

Based on retrospective findings (bugfix-e2e-001, 2026-01-26), `domcontentloaded` is more reliable than `networkidle` for most E2E tests.

```
                    What does your test need?
                            |
        ┌───────────────────┼───────────────────┐
        │                   │                   │
   HTML/DOM only?    All resources?     No network activity?
        │                   │                   │
        ▼                   ▼                   ▼
   domcontentloaded        load          networkidle (rare)
        │                   │
        │             Use when:         Use when:
        │             - Images           - SPA with
        │             - Styles           background
   Use when:             - Scripts          polling
   - Page structure       - Fonts
   - Element visibility   - Media
   - Fast test execution
```

**Default Choice**: `domcontentloaded`

**Why `domcontentloaded` is preferred:**
- Fires when HTML is parsed and DOM is ready
- Much faster than waiting for all network requests
- Sufficient for most UI interactions (after waiting for specific elements)
- `networkidle` can timeout on pages with continuous background activity

**When to use `load`:**
- Testing image loading
- Need fonts fully applied
- Media elements (video/audio)
- Critical styles depend on external resources

**When to use `networkidle`:**
- SPA with continuous background polling
- Analytics/tracking scripts running
- WebSocket connections active
- Rare - only when explicitly justified

**Learned from bugfix-e2e-001 (2026-01-26):**
- Changed `waitForLoadState('networkidle')` to `waitForLoadState('domcontentloaded')`
- 23/23 accessibility tests now passing (was timing out before)
- Tests complete within 60 seconds (was timing out)

### Load State Usage Examples

```typescript
// Default: domcontentloaded (fastest, most reliable)
await page.goto('http://localhost:3000');
await page.waitForLoadState('domcontentloaded');

// For element-specific waits (even better than load state)
await page.waitForSelector('canvas', { state: 'attached' });

// Only use load when you need all resources
await page.waitForLoadState('load'); // For images, fonts, styles

// Rarely use networkidle (only for background activity)
await page.waitForLoadState('networkidle'); // Last resort
```

### E2E Server Lifecycle Management

**CRITICAL: Multiplayer E2E tests require explicit port cleanup**

Based on retrospective findings (bugfix-e2e-002, 2026-01-26), Colyseus server tests need proper lifecycle management to avoid EADDRINUSE errors.

```typescript
// tests/e2e/multiplayer-suite.spec.ts
import { test, expect } from '@playwright/test';

let serverProcess: ReturnType<typeof spawn> | null = null;
const TEST_PORT = 2577; // Different from default 2567

test.beforeAll(async () => {
  // Start server for E2E tests
  serverProcess = spawn('npm', ['run', 'server'], {
    env: { ...process.env, PORT: String(TEST_PORT) },
    stdio: 'pipe'
  });

  // Wait for server to be ready
  await waitForServerReady(TEST_PORT);
});

test.afterAll(async () => {
  // EXPLICIT cleanup required
  if (serverProcess) {
    serverProcess.kill('SIGTERM');
    serverProcess = null;

    // Additional: verify port is released
    await waitForPortRelease(TEST_PORT);
  }
});
```

**Port Management Checklist:**
- [ ] Use unique port for E2E tests (different from development)
- [ ] Set port via environment variable
- [ ] Explicitly kill server process in afterAll
- [ ] Verify port is released before next test
- [ ] Handle cleanup even if test fails (try/finally)

**Learned from bugfix-e2e-002 (2026-01-26):**
- Fixed EADDRINUSE errors with proper port cleanup
- 65/65 E2E tests passing (100% success rate)
- Server availability detection added

### Shader-Specific Error Detection

**CRITICAL for Shader/TSL Tasks**: Add pattern matching for shader errors:

```typescript
test.describe('Shader Error Detection', () => {
  test('should have no shader compilation errors', async ({ page }) => {
    const shaderErrors: string[] = [];

    page.on('console', (msg) => {
      const text = msg.text();

      // Three.js shader error patterns
      const shaderErrorPatterns = [
        /THREE\.WebGLProgram/i,
        /shader error/i,
        /program info log/i,
        /WEBGL_WARNING/i,
        // TSL-specific patterns
        /Cannot read properties.*undefined.*replace/i,
        /VaryingProperty/i,
        /NodeBuilder/i,
        /assign.*null/i,
      ];

      if (shaderErrorPatterns.some(pattern => pattern.test(text))) {
        shaderErrors.push(text);
      }
    });

    await page.goto('http://localhost:3000');
    await page.waitForLoadState('networkidle');

    // Trigger shader-heavy interactions
    await page.mouse.click(400, 300);
    await page.waitForTimeout(2000);

    expect(shaderErrors).toHaveLength(0);
  });
});
```

### Color Mode / Shader Task Validation Pattern

For P1-005 (Color Blind Modes) and similar shader tasks:

```typescript
test.describe('Shader Task Validation Checklist', () => {
  test('should validate all color modes without errors', async ({ page }) => {
    const allErrors: string[] = [];

    page.on('console', (msg) => {
      if (msg.type() === 'error') allErrors.push(msg.text());
    });

    const colorModes = ['default', 'protanopia', 'deuteranopia', 'tritanopia', 'high_contrast'];

    for (const mode of colorModes) {
      // Set mode via localStorage or UI
      await page.evaluate((m) => {
        localStorage.setItem('project-chroma-accessibility', JSON.stringify({
          hasCompletedFirstLaunch: true,
          colorMode: m
        }));
      }, mode);
      await page.reload();
      await page.waitForTimeout(1000);
    }

    // Verify no shader errors across all modes
    const shaderErrors = allErrors.filter(e =>
      /shader|THREE|TSL|WebGL/i.test(e)
    );
    expect(shaderErrors).toHaveLength(0);
  });
});
```

## Runtime Error Detection

### Problem: Pre-existing Runtime Errors Block Validation

Runtime TypeErrors like "Cannot read properties of undefined" can exist in the codebase before a task starts, blocking browser validation for unrelated features. QA needs to detect and report these blockers early.

### Runtime Error Monitoring Pattern

```typescript
// tests/e2e/runtime-error-check.spec.ts
import { test, expect } from '@playwright/test';

test.describe('Runtime Error Detection', () => {
  test('should have no runtime TypeErrors', async ({ page }) => {
    const runtimeErrors: Array<{
      message: string;
      stack?: string;
      timestamp: number;
    }> = [];

    // Capture all unhandled errors
    page.on('pageerror', (error) => {
      runtimeErrors.push({
        message: error.message,
        stack: error.stack,
        timestamp: Date.now(),
      });
    });

    // Also capture console errors
    page.on('console', (msg) => {
      if (msg.type() === 'error') {
        runtimeErrors.push({
          message: msg.text(),
          timestamp: Date.now(),
        });
      }
    });

    await page.goto('http://localhost:3000');
    await page.waitForSelector('canvas');
    await page.waitForTimeout(5000); // Wait for initial load

    // Check for specific runtime error patterns
    const blockingErrors = runtimeErrors.filter(error => {
      const blockingPatterns = [
        /Cannot read properties.*undefined/,
        /Cannot read.*property.*undefined/,
        /undefined is not.*object/,
        /null is not.*object/,
        /is not a function/,
        /Unexpected token/,
      ];
      return blockingPatterns.some(pattern => pattern.test(error.message));
    });

    if (blockingErrors.length > 0) {
      console.error('BLOCKING RUNTIME ERRORS FOUND:', blockingErrors);
      throw new Error(
        `Found ${blockingErrors.length} blocking runtime error(s):\n` +
        blockingErrors.map(e => `  - ${e.message}`).join('\n') +
        `\n\nThese errors must be fixed before validation can proceed.`
      );
    }

    // Also check for any runtime errors (not just blocking)
    if (runtimeErrors.length > 0) {
      console.warn('Non-blocking runtime errors:', runtimeErrors);
    }
  });

  test('should report all runtime errors for debugging', async ({ page }) => {
    const allErrors: string[] = [];

    page.on('pageerror', (error) => {
      allErrors.push(`[${error.name}] ${error.message}`);
    });

    await page.goto('http://localhost:3000');
    await page.waitForSelector('canvas');
    await page.waitForTimeout(3000);

    if (allErrors.length > 0) {
      // Log all errors for debugging, even if non-blocking
      console.log('All Runtime Errors:', allErrors);
    }
  });
});
```

### Error Blocking Decision Tree

```
                    Runtime Error Found?
                            |
            ┌───────────────┴───────────────┐
            │                               │
      Error in CHANGED files?         Error in UNCHANGED files?
            │                               │
            ▼                               ▼
       RETURN to Developer          CREATE BLOCKER TASK
       (Task's code has bug)        (Pre-existing issue)
```

### Runtime Error Report Format

When blocking runtime errors are found:

```json
{
  "status": "blocked",
  "blocker": "Pre-existing runtime TypeError",
  "errors": [
    {
      "message": "Cannot read properties of undefined (reading 'position')",
      "location": "src/components/game/player/index.ts:42",
      "isNew": false,
      "relatedToTask": false
    }
  ],
  "action": "Create separate bugfix task for pre-existing error",
  "recommendation": "Developer should fix pre-existing error before validating new features"
}
```

### Pre-Existing Error Detection

```typescript
// Check if error exists before task changes
test.beforeEach(async ({ page }) => {
  // Record baseline errors before any task interactions
  const baselineErrors: string[] = [];

  page.on('pageerror', (error) => {
    baselineErrors.push(error.message);
  });

  await page.goto('http://localhost:3000');
  await page.waitForTimeout(2000);

  // Store baseline for comparison
  (page as any).__baselineErrors = baselineErrors;
});
```

### Validation Blocking Rules

| Error Type | Is Blocking? | Action |
|------------|--------------|--------|
| TypeError in changed files | YES | Return to Developer |
| TypeError in unchanged files | YES | Create blocker task |
| ReferenceError | YES | Return to Developer |
| Console warnings | NO | Note in report |
| Asset load errors (404) | MAYBE | Check if task-related |

**Learned from bugfix-tps-001 retrospective (2026-01-25)**:
- "Cannot read properties of undefined" runtime error blocked browser validation for feat-tps-005
- Pre-existing errors need separate bugfix tasks, not to block current task indefinitely
- QA must distinguish between task-caused errors and pre-existing issues

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

## Server Management

**⚠️ CRITICAL: Use `shared-lifecycle` skill for server management.**

Before running E2E tests, always check/start the dev server using the patterns from `shared-lifecycle` skill.

**MANDATORY CLEANUP after all tests complete (pass OR fail):**

Use the cleanup patterns from `shared-lifecycle` skill to ensure:
- Dev server is stopped
- Ports are released
- No orphaned processes remain

**See also:** `shared-lifecycle` skill for complete process management patterns.

## References

- **[qa-e2e-test-creation/SKILL.md](../qa-e2e-test-creation/SKILL.md)** - Full E2E test patterns
- [Playwright Documentation](https://playwright.dev/docs/intro)
- [tests/pages/](tests/pages/) - Page Object Model classes
