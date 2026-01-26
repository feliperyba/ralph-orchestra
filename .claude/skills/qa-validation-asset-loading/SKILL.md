---
name: qa-validation-asset-loading
description: Asset loading performance validation using Playwright. Use when validating FBX model loading performance, testing asset loading across environments, ensuring error handling for failed loads, or verifying browser compatibility.
---

# Asset Loading Performance Validation

## When to Use

- Validating FBX model loading performance and memory usage
- Testing asset loading across different environments
- Ensuring proper error handling for failed asset loads
- Verifying browser compatibility for asset formats

## Quick Start

```typescript
import { test, expect } from '../fixtures';

test.describe('Asset Loading Validation', () => {
  test('Sequential FBX model loading', async ({ page }) => {
    await page.goto('/');

    // Monitor memory usage
    const memoryUsage = await page.evaluate(() => performance.memory?.usedJSHeapSize || 0);

    // Check for loading indicators
    await expect(page.locator('.loading-indicator')).toBeVisible();
    await expect(page.locator('.loading-indicator')).toBeHidden();

    // Verify models loaded
    await expect(page.locator('canvas')).toBeVisible();
    await expect(page.locator('[data-testid="character-model"]')).toHaveCount(6);

    // Performance assertions
    const afterLoadMemory = await page.evaluate(() => performance.memory?.usedJSHeapSize || 0);
    expect(afterLoadMemory - memoryUsage).toBeLessThan(100 * 1024 * 1024); // < 100MB
  });
});
```

---

<examples>

## Example 1: Memory-Safe Asset Loading

```typescript
test('Memory-safe asset loading', async ({ page }) => {
  const initialMemory = await page.evaluate(() => performance.memory?.usedJSHeapSize || 0);

  await page.goto('/characters');
  await page.waitForSelector('[data-testid="all-models-loaded"]');

  const finalMemory = await page.evaluate(() => performance.memory?.usedJSHeapSize || 0);
  const memoryIncrease = finalMemory - initialMemory;

  expect(memoryIncrease).toBeLessThan(50 * 1024 * 1024); // 50MB limit

  // Check for memory leaks
  await page.waitForTimeout(5000);
  const afterWaitMemory = await page.evaluate(() => performance.memory?.usedJSHeapSize || 0);

  expect(afterWaitMemory - finalMemory).toBeLessThan(5 * 1024 * 1024); // < 5MB after 5s
});
```

## Example 2: Error Handling for Missing Assets

```typescript
test('Graceful handling of missing assets', async ({ page }) => {
  // Mock a failed asset load
  await page.route('**/assets/missing.fbx', route => route.abort('failed'));

  await page.goto('/test-missing-assets');

  // Check error display
  await expect(page.locator('.error-message')).toBeVisible();
  await expect(page.locator('.error-message')).not.toContain('crashed');

  // Check fallback content
  await expect(page.locator('.fallback-model')).toBeVisible();

  // Console error check
  const consoleErrors = await page.evaluate(() => (window as any).__consoleErrors || []);
  expect(consoleErrors.length).toBe(0); // No unhandled errors
});
```

## Example 3: Retry Mechanism

```typescript
test('Retry mechanism for transient failures', async ({ page }) => {
  let attemptCount = 0;

  // Mock 2 failures then success
  await page.route('**/assets/retry-test.fbx', route => {
    attemptCount++;
    if (attemptCount < 3) {
      route.abort('failed');
    } else {
      route.fulfill({
        status: 200,
        contentType: 'application/octet-stream',
        body: new ArrayBuffer(1024) // Mock FBX data
      });
    }
  });

  await page.goto('/test-retry-mechanism');

  // Should eventually succeed
  await expect(page.locator('.model-loaded')).toBeVisible();
  expect(attemptCount).toBe(3); // 2 failures + 1 success
});
```

</examples>

---

## Performance Validation Patterns

### Load Time Measurement

```typescript
test.describe('Asset Loading Performance', () => {
  test('Sequential loading load time', async ({ page }) => {
    const startTime = Date.now();

    await page.goto('/characters');
    await page.waitForSelector('[data-testid="all-characters-loaded"]');

    const loadTime = Date.now() - startTime;

    // Assert load time is reasonable
    expect(loadTime).toBeLessThan(10000); // 10 seconds max

    // Check loading progress
    const progressHistory = await page.evaluate(() => (window as any).__progressLog || []);
    expect(progressHistory.length).toBeGreaterThan(0);
    expect(progressHistory[progressHistory.length - 1]).toBe(100);
  });
});
```

### Performance Budget Checker

```typescript
function createPerformanceBudget() {
  return {
    maxLoadTime: 10000, // 10 seconds
    maxMemoryIncrease: 50 * 1024 * 1024, // 50MB
    maxConcurrentLoads: 3,
    allowedErrors: 0,

    async checkBudget(page: Page, testId: string) {
      const metrics = await page.evaluate(() => ({
        loadTime: window.performance.timing.loadEventEnd - window.performance.timing.navigationStart,
        memory: {
          used: performance.memory?.usedJSHeapSize || 0,
          total: performance.memory?.jsHeapSizeLimit || 0
        },
        errors: (window as any).__consoleErrors?.length || 0
      }));

      const violations = [];

      if (metrics.loadTime > this.maxLoadTime) {
        violations.push(`Load time exceeded: ${metrics.loadTime}ms`);
      }

      if (metrics.memory.used > this.maxMemoryIncrease) {
        violations.push(`Memory increase exceeded: ${metrics.memory.used} bytes`);
      }

      if (metrics.errors > this.allowedErrors) {
        violations.push(`Error count exceeded: ${metrics.errors} errors`);
      }

      if (violations.length > 0) {
        throw new Error(`Performance budget violated:\n${violations.join('\n')}`);
      }

      return metrics;
    }
  };
}

// Usage
const budget = createPerformanceBudget();
test('Performance budget compliance', async ({ page }) => {
  await page.goto('/characters');
  await page.waitForSelector('[data-testid="all-loaded"]');
  await budget.checkBudget(page, 'sequential-loading-test');
});
```

---

## Cross-Browser Testing

```typescript
test.describe('Cross-Browser Asset Loading', () => {
  ['chromium', 'firefox', 'webkit'].forEach(browserName => {
    test(`Asset loading in ${browserName}`, async ({ page }) => {
      await page.goto('/');
      await page.waitForLoadState('networkidle');

      // Test asset loading
      const assetResponses = await page.waitForResponse(response =>
        response.url().includes('/assets/')
      );

      expect(assetResponses.status()).toBe(200);

      // Visual regression check
      await expect(page).toHaveScreenshot(`asset-loading-${browserName}.png`, {
        maxDiffPixels: 100,
      });
    });
  });
});
```

---

## Network Conditions Testing

```typescript
test.describe('Network Condition Testing', () => {
  ['slow-3g', 'offline'].forEach(condition => {
    test(`Asset loading under ${condition}`, async ({ page }) => {
      // Set network condition
      await page.emulateNetworkConditions({
        offline: condition === 'offline',
        downloadThroughput: condition === 'slow-3g' ? 500 * 1024 : 0,
        uploadThroughput: condition === 'slow-3g' ? 500 * 1024 : 0
      });

      await page.goto('/characters');

      if (condition === 'offline') {
        await expect(page.locator('.offline-message')).toBeVisible();
      } else {
        await expect(page.locator('.loading-message')).toBeVisible();
      }
    });
  });
});
```

---

## Visual Regression Testing

<details>
<summary>Loading and Error States</summary>

```typescript
test.describe('Visual Regression for Loading States', () => {
  test('Loading state appearance', async ({ page }) => {
    await page.goto('/characters');

    // Capture loading state
    await expect(page).toHaveScreenshot('loading-state.png', {
      mask: [page.locator('.loading-spinner')], // Animate elements
    });

    await page.waitForSelector('[data-testid="characters-loaded"]');

    // Capture loaded state
    await expect(page).toHaveScreenshot('loaded-state.png');
  });
});

test('Error state visual consistency', async ({ page }) => {
  // Mock asset loading failure
  await page.route('**/assets/error-test.fbx', route => route.abort('failed'));

  await page.goto('/error-test');

  await expect(page).toHaveScreenshot('error-state.png');
  await expect(page.locator('.error-icon')).toBeVisible();
  await expect(page.locator('.retry-button')).toBeVisible();
});
```

</details>

---

## Anti-Patterns

| ❌ DON'T | ✅ DO |
|----------|-------|
| Only test in development environment | Test in multiple environments |
| Ignore memory usage during loading | Monitor memory and performance metrics |
| No error handling for failed loads | Test graceful degradation and retry |

<details>
<summary>Correct Patterns</summary>

### Multi-Environment Testing

```typescript
// ✅ DO: Test multiple environments
[process.env.TEST_ENV].forEach(env => {
  test(`Asset loading in ${env}`, async ({ page }) => {
    const baseUrl = env === 'production'
      ? 'https://your-game.com'
      : 'http://localhost:3000';

    await page.goto(`${baseUrl}/characters`);
    // ... environment-specific tests
  });
});
```

### Memory Monitoring

```typescript
// ✅ DO: Monitor memory usage
test('Memory-safe asset loading', async ({ page }) => {
  const initialMemory = await page.evaluate(() => performance.memory?.usedJSHeapSize || 0);

  await page.goto('/characters');
  await page.waitForSelector('[data-testid="all-models-loaded"]');

  const finalMemory = await page.evaluate(() => performance.memory?.usedJSHeapSize || 0);
  const memoryIncrease = finalMemory - initialMemory;

  expect(memoryIncrease).toBeLessThan(50 * 1024 * 1024); // 50MB limit

  // Check for memory leaks
  await page.waitForTimeout(5000);
  const afterWaitMemory = await page.evaluate(() => performance.memory?.usedJSHeapSize || 0);

  expect(afterWaitMemory - finalMemory).toBeLessThan(5 * 1024 * 1024); // < 5MB after 5s
});
```

</details>

---

## Running Asset Loading Tests

```bash
# Run asset loading tests
npm run test:e2e -- tests/e2e/asset-loading-suite.spec.ts

# Run in headed mode to see loading
npm run test:e2e -- --headed

# Run specific test
npm run test:e2e -- -g "Memory-safe asset loading"
```

---

## References

- [Playwright Testing](https://playwright.dev/) — Browser automation testing
- [Web Performance APIs](https://developer.mozilla.org/en-US/docs/Web/API/Performance) — Performance monitoring
- [Lighthouse CI](https://github.com/GoogleChrome/lighthouse-ci) — Automated performance testing
- [Three.js Memory Management](https://threejs.org/docs/#manual/en/introduction/Performance) — Three.js optimization
- **[qa-validation-asset/SKILL.md](../qa-validation-asset/SKILL.md)** - General asset validation
