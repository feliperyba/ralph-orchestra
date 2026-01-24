---
name: qa-browser-testing
description: Browser testing with Playwright MCP for visual and functional validation
category: validation
---

# Browser Testing Skill

> "Automated tests verify logic – browser tests verify reality."

## When to Use This Skill

Use for **every validation** after automated checks pass.

## Quick Start

```typescript
// Using Playwright MCP
// 1. Navigate
await page.goto('http://localhost:3000');

// 2. Wait for canvas
await page.waitForSelector('canvas');

// 3. Take screenshot
await page.screenshot({ path: 'validation.png' });

// 4. Check console
const errors = [];
page.on('console', (msg) => {
  if (msg.type() === 'error') errors.push(msg.text());
});
```

## Test Categories

| Category    | What to Check              |
| ----------- | -------------------------- |
| Load        | Page loads, canvas renders |
| Console     | No errors or warnings      |
| Functional  | Features work as specified |
| Visual      | UI appears correctly       |
| Performance | 60 FPS, no stuttering      |
| Input       | Controls respond correctly |

## Progressive Guide

### Level 1: Basic Load Test

```typescript
test('page loads correctly', async ({ page }) => {
  // Navigate
  await page.goto('http://localhost:3000');

  // Wait for canvas
  const canvas = page.locator('canvas');
  await expect(canvas).toBeVisible();

  // Take screenshot
  await page.screenshot({ path: 'playwright-test/load.png' });
});
```

### Level 2: Console Error Check

```typescript
test('no console errors', async ({ page }) => {
  const errors: string[] = [];

  page.on('console', (msg) => {
    if (msg.type() === 'error') {
      errors.push(msg.text());
    }
  });

  await page.goto('http://localhost:3000');
  await page.waitForTimeout(5000); // Wait for initial load

  expect(errors).toHaveLength(0);
});
```

### Level 3: Input Testing

```typescript
test('keyboard controls work', async ({ page }) => {
  await page.goto('http://localhost:3000');
  await page.waitForSelector('canvas');

  // Focus canvas
  await page.click('canvas');

  // Press WASD keys
  await page.keyboard.press('KeyW');
  await page.waitForTimeout(500);
  await page.screenshot({ path: 'playwright-test/after-w.png' });

  await page.keyboard.press('KeyA');
  await page.waitForTimeout(500);
  await page.screenshot({ path: 'playwright-test/after-a.png' });
});
```

**For game-specific input patterns**, see [`game-testing.md`](game-testing.md) for:

- Continuous movement (key down/up patterns)
- Mouse aiming and clicking
- Combo sequences
- Special key combinations

### Level 4: Visual Comparison

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

**For advanced visual testing**, see [`visual-testing.md`](visual-testing.md) for:

- Game state detection (menu, playing, game over, win)
- Semantic visual comparison with Vision MCP
- UI element validation (HUD, health bars, minimap)
- GDD compliance validation

### Level 5: Performance Metrics

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

### Level 6: Pointer Lock Testing (FPS/TPS Controls)

For games with FPS/TPS mouse controls, test the Pointer Lock API:

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

test('mouse movement controls camera when locked', async ({ page }) => {
  await page.goto('http://localhost:3000');
  await page.waitForSelector('canvas');

  // Request pointer lock explicitly
  await page.click('canvas');

  // Wait for lock to engage
  await page.waitForTimeout(200);

  // Simulate mouse movement (movementX/Y only work when locked)
  await page.mouse.move(100, 100);
  await page.mouse.move(200, 150); // movementX: 100, movementY: 50

  await page.waitForTimeout(100);
  await page.screenshot({ path: 'playwright-test/after-mouse-move.png' });
});

test('ESC key unlocks pointer and shows PAUSED', async ({ page }) => {
  await page.goto('http://localhost:3000');
  await page.waitForSelector('canvas');

  // Ensure pointer is locked first
  await page.click('canvas');
  await page.waitForTimeout(200);

  // Press ESC to unlock
  await page.keyboard.press('Escape');

  // Check pointer is unlocked
  const isLocked = await page.evaluate(() => {
    return document.pointerLockElement === document.body;
  });
  expect(isLocked).toBe(false);

  // Check for PAUSED overlay
  const pausedVisible = await page
    .locator('text=PAUSED')
    .isVisible()
    .catch(() => false);
  expect(pausedVisible).toBe(true);

  await page.screenshot({ path: 'playwright-test/paused-overlay.png' });
});

test('click re-engages pointer lock', async ({ page }) => {
  await page.goto('http://localhost:3000');
  await page.waitForSelector('canvas');

  // Lock initially
  await page.click('canvas');
  await page.waitForTimeout(200);

  // Unlock with ESC
  await page.keyboard.press('Escape');
  await page.waitForTimeout(100);

  // Verify unlocked
  let isLocked = await page.evaluate(() => {
    return document.pointerLockElement === document.body;
  });
  expect(isLocked).toBe(false);

  // Click to re-lock
  await page.click('body');
  await page.waitForTimeout(200);

  // Verify re-locked
  isLocked = await page.evaluate(() => {
    return document.pointerLockElement === document.body;
  });
  expect(isLocked).toBe(true);
});
```

**Key Pointer Lock Validation Points:**

- Pointer locks automatically on mount (100ms timeout)
- `movementX/Y` values are processed for camera rotation
- ESC key unlocks and shows PAUSED overlay
- Click-to-resume functionality works
- Cursor is hidden when locked (visible when unlocked)

## ⚠️ CRITICAL: Playwright MCP is REQUIRED

**There is NO manual testing fallback.**

If Playwright MCP is not available:

1. **FAIL the validation immediately**
2. Report as critical blocker: `"Playwright MCP not configured - cannot validate"`
3. **DO NOT** attempt manual browser testing

Browser testing via Playwright MCP is **NON-NEGOTIABLE**.

**This is a mandatory gating condition** - validation cannot proceed without Playwright MCP.

### Why No Manual Fallback?

- Manual testing is subjective and error-prone
- Automations ensure consistent validation across all tasks
- Screenshots via Playwright provide objective evidence
- Console monitoring catches issues humans miss
- No manual testing = higher quality bar

## Cross-Browser Testing

| Browser         | Priority         | Notes                   |
| --------------- | ---------------- | ----------------------- |
| Chrome/Chromium | Required         | Primary target          |
| Firefox         | Recommended      | WebGL differences       |
| Safari/WebKit   | If targeting iOS | Significant differences |
| Edge            | Optional         | Uses Chromium           |

## Anti-Patterns

❌ **DON'T:**

- Skip browser testing because automated tests passed
- Test only in one browser
- Ignore console warnings
- Skip performance check
- Assume "it works on my machine"

✅ **DO:**

- Test in browser for every validation
- Check console for errors
- Verify all acceptance criteria
- Take screenshots as evidence
- Test keyboard and mouse input

## Checklist

For each validation:

- [ ] Dev server running (`npm run dev:all:sh`)
- [ ] Navigate to app URL
- [ ] Canvas loads and renders
- [ ] No console errors
- [ ] All acceptance criteria verified
- [ ] Input controls work
- [ ] Performance acceptable
- [ ] Screenshots captured

## Reference

- [Playwright Documentation](https://playwright.dev/docs/intro)
- [agents/qa/skills/validation-workflow.md](validation-workflow.md) — Full workflow
- [agents/qa/skills/game-testing.md](game-testing.md) — Game control patterns
- [agents/qa/skills/visual-testing.md](visual-testing.md) — Visual validation
- [agents/qa/AGENT.md](../AGENT.md) — Full QA instructions
- [bugfix-003](../../prd.json) — Pointer Lock implementation reference

**Learned from bugfix-003 retrospective (2026-01-22):**
Pointer Lock API E2E testing patterns using Playwright. Tests should verify auto-lock on mount, mouse movement processing, ESC unlock handling, PAUSED overlay visibility, and click-to-resume functionality.
