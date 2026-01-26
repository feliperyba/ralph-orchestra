---
name: qa-visual-testing
description: E2E visual testing using Playwright screenshot API with Vision MCP helpers for qualitative GDD compliance analysis. Use when validating shaders, materials, UI elements, and visual appearance against design specifications.
---

# Visual Testing with E2E Tests

> "Visual validation catches bugs that functional tests miss."

## When to Use

Use for **every game feature validation** to create E2E tests that:
- Compare screenshots against baseline images (quantitative regression)
- Validate UI elements programmatically (HUD, buttons, menus)
- Verify visual appearance matches GDD specifications (qualitative analysis)

## Core Principle: Write E2E Tests, Reference Helpers

**✅ CORRECT APPROACH:**
```typescript
// Write E2E test with screenshot comparison - YES!
test('visual regression check', async ({ page }) => {
  await page.goto('http://localhost:3000');
  await expect(page).toHaveScreenshot('baseline.png', {
    maxDiffPixelRatio: 0.01,
  });
});
```

**✅ FOR QUALITATIVE ANALYSIS:**
```typescript
// Use helper function for Vision MCP analysis - YES!
test('shader quality meets GDD standards', async ({ page }) => {
  await page.goto('http://localhost:3000');
  const screenshot = await page.screenshot();

  const analysis = await analyzeVisualQuality(screenshot, 'Shader material quality');
  expect(analysis.passes).toBe(true);
});
```

**❌ DO NOT USE:**
```typescript
// Interactive MCP - NO!
mcp__playwright__browser_navigate('http://localhost:3000');
mcp__4_5v_mcp__analyze_image({ imageSource: 'screenshot.png' });
```

---

## Helper Library

**See [tests/helpers/visual-analysis.ts](tests/helpers/visual-analysis.ts) for complete implementation.**

| Helper | Purpose |
|--------|---------|
| `analyzeVisualQuality()` | Qualitative visual analysis |
| `checkGDDCompliance()` | GDD specification validation |
| `detectGameState()` | Game state detection |
| `captureStableScreenshot()` | Stabilized screenshot capture |
| `positionCamera()` | Consistent camera positioning |
| `SCREENSHOT_TOLERANCE` | Tolerance guidelines |

---

<examples>

## Example 1: Basic Screenshot Comparison

```typescript
test('ui matches baseline', async ({ page }) => {
  await page.goto('http://localhost:3000');
  await page.waitForSelector('canvas');
  await page.waitForTimeout(2000);

  await expect(page).toHaveScreenshot('baseline.png', {
    maxDiffPixelRatio: 0.01,
  });
});
```

## Example 2: Game State Detection

```typescript
test('detect game playing state', async ({ page }) => {
  await page.goto('http://localhost:3000');
  await page.click('canvas');
  await page.waitForTimeout(1000);

  const screenshot = await page.screenshot();
  const state = await detectGameState(screenshot);

  expect(state.state).toBe('playing');
  expect(state.playerVisible).toBe(true);
  expect(state.uiElements).toContain('hud');
});
```

## Example 3: GDD Compliance Validation

```typescript
test('shader meets GDD specifications', async ({ page }) => {
  await page.goto('http://localhost:3000');
  await page.click('canvas');
  await page.waitForTimeout(2000);

  const screenshot = await page.screenshot();
  const gddSpec = `
    - Terrain should use raymarching SDF shader
    - Paint should appear as wet/glossy surface
    - Team colors: orange (team 1) and blue (team 2)
  `;

  const result = await checkGDDCompliance(screenshot, gddSpec);
  expect(result.compliant).toBe(true);
  expect(result.deviations).toHaveLength(0);
});
```

</examples>

---

## Tolerance Guidelines

| Scenario | Max Diff Ratio | Max Pixels |
|----------|---------------|------------|
| Static UI (menus) | 0.001 | 100 |
| Gameplay (animations) | 0.05 | 5000 |
| Particle effects | 0.10 | 10000 |
| Text content | 0.0001 | 10 |

---

<details>
<summary>Additional Test Patterns</summary>

### Multi-State Screenshot Tests

```typescript
test.describe('Game State Visual Regression', () => {
  test('menu state matches baseline', async ({ page }) => {
    await page.goto('http://localhost:3000');
    await expect(page).toHaveScreenshot('menu-baseline.png');
  });

  test('playing state matches baseline', async ({ page }) => {
    await page.goto('http://localhost:3000');
    await page.click('canvas');
    await page.waitForTimeout(1000);

    await expect(page).toHaveScreenshot('playing-baseline.png', {
      maxDiffPixels: 5000, // Allow for animation variation
    });
  });
});
```

### Multi-Angle Shader Validation

```typescript
test('terrain shader from multiple angles', async ({ page }) => {
  await page.goto('http://localhost:3000');
  await page.click('canvas');

  const angles = [
    { name: 'front', pos: [0, 10, 20], target: [0, 0, 0] },
    { name: 'side', pos: [20, 10, 0], target: [0, 0, 0] },
    { name: 'top-down', pos: [0, 30, 5], target: [0, 0, 0] },
  ];

  for (const angle of angles) {
    await positionCamera(page, angle.pos, angle.target);
    await expect(page).toHaveScreenshot(`terrain-${angle.name}.png`, {
      maxDiffPixels: 500,
      threshold: 0.02,
    });
  }
});
```

### Paint Projectile Visual Test

```typescript
test('paint projectile visual validation', async ({ page }) => {
  await page.goto('http://localhost:3000');
  await page.click('canvas');

  // Shoot to create projectile
  await page.mouse.click(400, 300);
  await page.waitForTimeout(100);

  await expect(page).toHaveScreenshot('projectile-flight.png', {
    maxDiffPixels: 2000, // Allow for projectile animation
  });

  // Vision MCP for qualitative check
  const screenshot = await page.screenshot();
  const analysis = await analyzeVisualQuality(
    screenshot,
    'Paint projectile has team color, glow, and trail effect'
  );
  expect(analysis.passes).toBe(true);
});
```

### Color Mode Testing

```typescript
test.describe('Color Mode Visual Regression', () => {
  for (const mode of COLOR_MODES) {
    test(`renders ${mode} color mode correctly`, async ({ page }) => {
      await setColorMode(page, mode);

      // Navigate to lobby
      await page.fill('#characterName', 'TestPlayer');
      await page.locator('button:has-text("Select Character")').first().click();
      await page.waitForURL('**/lobby');

      await page.waitForLoadState('networkidle');

      await expect(page).toHaveScreenshot(`lobby-${mode}.png`, {
        maxDiffPixels: 100,
      });
    });
  }
});
```

### HUD Detection (Programmatic + Vision)

```typescript
test('HUD elements are visible', async ({ page }) => {
  await page.goto('http://localhost:3000');
  await page.click('canvas');

  // Programmatic checks
  const hudVisible = await verifyHudElements(page);
  expect(hudVisible).toBe(true);

  // Vision MCP for qualitative assessment
  const screenshot = await page.screenshot();
  const analysis = await analyzeVisualQuality(
    screenshot,
    'HUD elements properly styled and positioned'
  );
  expect(analysis.passes).toBe(true);
});
```

</details>

---

## Complete Visual Test Suite

```typescript
import { test, expect } from '@playwright/test';
import { analyzeVisualQuality, checkGDDCompliance, detectGameState } from '@/helpers/visual-analysis';

test.describe('Visual Validation - feat-001', () => {
  test('ui matches baseline', async ({ page }) => {
    await page.goto('http://localhost:3000');
    await expect(page).toHaveScreenshot('menu-baseline.png');
  });

  test('gameplay state detected correctly', async ({ page }) => {
    await page.goto('http://localhost:3000');
    await page.click('canvas');

    const screenshot = await page.screenshot();
    const state = await detectGameState(screenshot);

    expect(state.state).toBe('playing');
    expect(state.playerVisible).toBe(true);
  });

  test('shader meets GDD standards', async ({ page }) => {
    await page.goto('http://localhost:3000');
    await page.click('canvas');

    const screenshot = await page.screenshot();
    const gddSpec = 'Raymarching terrain with wet paint appearance';

    const result = await checkGDDCompliance(screenshot, gddSpec);
    expect(result.compliant).toBe(true);
  });
});
```

---

## Running Visual Tests

```bash
# Run all visual tests
npm run test:e2e -- tests/e2e/visual-suite.spec.ts

# Update baselines
npx playwright test --update-snapshots

# Run in headed mode
npm run test:e2e -- --headed

# Run specific test
npm run test:e2e -- -g "shader meets GDD"
```

---

## Testing Checklist

For each visual validation:

- [ ] E2E test file created in `tests/e2e/`
- [ ] Screenshot comparison tests written (quantitative)
- [ ] Vision MCP helper tests for GDD compliance (qualitative)
- [ ] Baselines committed to repository
- [ ] Tests run locally: `npm run test:e2e`
- [ ] No visual glitches detected
- [ ] Deviations documented with severity

---

## Anti-Patterns

| ❌ DON'T | ✅ DO |
|----------|-------|
| Use Playwright MCP directly during test execution | Write E2E tests with screenshot comparison |
| Skip baseline creation | Create baselines for all visual states |
| Use hardcoded waits when assertions work | Use appropriate tolerance for GPU variation |
| Commit without visual tests | Commit visual tests with implementation |

---

## References

- **[qa-e2e-test-creation/SKILL.md](../qa-e2e-test-creation/SKILL.md)** - Full E2E patterns
- **[tests/helpers/visual-analysis.ts](tests/helpers/visual-analysis.ts)** - Vision MCP helpers
- [Playwright Screenshot API](https://playwright.dev/docs/api/class-page#page-screenshot)
- [Playwright Visual Testing](https://playwright.dev/docs/test-snapshots)
