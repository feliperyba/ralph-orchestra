---
name: qa-accessibility-testing
description: Accessibility testing patterns for WCAG compliance, color modes, ARIA labels, and keyboard navigation. Use when validating accessibility features like P1-005 (Color Blind Modes).
---

# Accessibility Testing

> "Accessibility is not a feature, it's a fundamental aspect of quality software."

## When to Use

Use for **every UI feature** to validate:
- WCAG AA compliance (contrast ratios, readable text)
- Color blind mode support (protanopia, deuteranopia, tritanopia)
- Keyboard navigation (Tab, Enter, Escape)
- ARIA labels and roles
- Screen reader compatibility

## Quick Start

```bash
# Install axe-core for automated WCAG checking
npm install --save-dev @axe-core/playwright
```

```typescript
import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

test('should not have WCAG AA violations', async ({ page }) => {
  await page.goto('http://localhost:3000');

  const accessibilityScanResults = await new AxeBuilder({ page })
    .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa'])
    .analyze();

  expect(accessibilityScanResults.violations).toEqual([]);
});
```

---

## Core Principles

| Principle | What to Check |
|-----------|---------------|
| **Perceivable** | Color contrast, text alternatives, time-based media |
| **Operable** | Keyboard navigation, no traps, enough time |
| **Understandable** | Readable text, predictable input, error help |
| **Robust** | ARIA attributes, compatible with assistive tech |

---

<examples>

## Example 1: Color Mode Testing (P1-005)

```typescript
test.describe('Accessibility - Color Modes', () => {
  const colorModes = ['default', 'protanopia', 'deuteranopia', 'tritanopia', 'high_contrast'];

  colorModes.forEach(mode => {
    test(`renders ${mode} color mode correctly`, async ({ page }) => {
      await page.goto('http://localhost:3000');
      await page.evaluate((m) => {
        localStorage.setItem('project-chroma-accessibility', JSON.stringify({
          hasCompletedFirstLaunch: true,
          colorMode: m
        }));
      }, mode);
      await page.reload();

      // Navigate to lobby
      await page.fill('#characterName', 'TestPlayer');
      await page.locator('button:has-text("Select Character")').first().click();
      await page.waitForURL('**/lobby');

      // Verify WCAG AA compliance badges visible
      await expect(page.getByText('WCAG AA')).toBeVisible();

      // Verify contrast ratios displayed (format: "O: 4.5:1", "B: 4.5:1")
      await expect(page.locator('text=/O:\\s*\\d+:\\d+/')).toBeVisible();
      await expect(page.locator('text=/B:\\s*\\d+:\\d+/')).toBeVisible();
    });
  });
});
```

## Example 2: Keyboard Navigation

```typescript
test('should be fully keyboard navigable', async ({ page }) => {
  await page.goto('http://localhost:3000');

  // Tab through interactive elements
  await page.keyboard.press('Tab');
  let firstFocused = await page.evaluate(() => document.activeElement?.tagName);
  expect(['BUTTON', 'INPUT', 'A'].includes(firstFocused || '')).toBe(true);

  // Activate with Enter
  await page.keyboard.press('Enter');

  // Escape to close
  await page.keyboard.press('Escape');
  const modalClosed = await page.getByRole('dialog').isHidden();
  expect(modalClosed).toBe(true);
});
```

## Example 3: ARIA Validation

```typescript
test('should have proper ARIA labels', async ({ page }) => {
  await page.goto('http://localhost:3000');

  const hasAriaLabels = await page.evaluate(() => {
    const settings = document.querySelector('.color-settings');
    if (!settings) return false;

    // Check for aria-label on buttons
    const buttons = settings.querySelectorAll('button[aria-label]');
    if (buttons.length === 0) return false;

    // Check for aria-pressed on selected mode
    const selected = settings.querySelector('[aria-pressed="true"]');
    if (!selected) return false;

    return true;
  });

  expect(hasAriaLabels).toBe(true);
});
```

</examples>

---

## WCAG Compliance Testing

### Automated WCAG Scans

```typescript
import AxeBuilder from '@axe-core/playwright';

test.describe('WCAG Compliance', () => {
  test('should have no violations', async ({ page }) => {
    await page.goto('http://localhost:3000');

    const results = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa'])
      .analyze();

    expect(results.violations).toEqual([]);
  });

  test('should have no color contrast violations', async ({ page }) => {
    await page.goto('http://localhost:3000');

    const results = await new AxeBuilder({ page })
      .include('.color-settings')
      .analyze();

    const contrastViolations = results.violations.filter(v => v.id === 'color-contrast');
    expect(contrastViolations).toEqual([]);
  });
});
```

### Manual WCAG Checklist

- [ ] All images have alt text
- [ ] Color contrast ratio ≥ 4.5:1 for normal text
- [ ] Color contrast ratio ≥ 3:1 for large text
- [ ] All interactive elements are keyboard accessible
- [ ] Focus indicators are visible
- [ ] Form inputs have associated labels
- [ ] Error messages are descriptive
- [ ] Page title is descriptive

---

## Color Blind Mode Testing

### Test Structure

```typescript
test.describe('Color Blind Accessibility', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('http://localhost:3000');
    await page.evaluate(() => localStorage.clear());
    await page.reload();
  });

  test('should show AccessibilityDetector on first launch', async ({ page }) => {
    await expect(page.locator('.accessibility-detector-overlay')).toBeVisible();
    await expect(page.getByText('Color Accessibility Setup')).toBeVisible();
  });

  test('should allow selecting different color modes', async ({ page }) => {
    await page.evaluate(() => {
      localStorage.setItem('project-chroma-accessibility', JSON.stringify({
        hasCompletedFirstLaunch: true
      }));
    });
    await page.reload();

    // Open Color Settings
    await page.getByRole('button', { name: /color settings/i }).click();

    // Select Protanopia mode
    await page.getByRole('button', { name: /Protanopia/i }).click();

    // Verify mode saved
    const currentMode = await page.evaluate(() => {
      const data = localStorage.getItem('project-chroma-accessibility');
      return data ? JSON.parse(data).colorMode : null;
    });
    expect(currentMode).toBe('protanopia');
  });

  test('should show pattern controls for accessibility', async ({ page }) => {
    await page.goto('http://localhost:3000');
    await page.getByRole('button', { name: /color settings/i }).click();

    await expect(page.getByText('Pattern Overlays')).toBeVisible();
    await expect(page.getByLabel('Pattern Opacity')).toBeVisible();
  });
});
```

### Color Mode Reference

| Mode | Description | Primary Differentiator |
|------|-------------|------------------------|
| **Default** | Standard colors | Color only |
| **Protanopia** | Red-blind | Pattern + Orange tint |
| **Deuteranopia** | Green-blind | Pattern + Yellow tint |
| **Tritanopia** | Blue-blind | Pattern + Green tint |
| **High Contrast** | Maximum contrast | Black/white + Bold patterns |

---

## Keyboard Navigation Testing

### Tab Order Validation

```typescript
test('should have logical tab order', async ({ page }) => {
  await page.goto('http://localhost:3000');

  const tabOrder: string[] = [];

  for (let i = 0; i < 5; i++) {
    const focused = await page.evaluate(() => {
      const el = document.activeElement;
      return el ? el.tagName + (el.getAttribute('aria-label') || '') : 'none';
    });
    tabOrder.push(focused);
    await page.keyboard.press('Tab');
  }

  // Verify logical order: typically top-to-bottom, left-to-right
  expect(tabOrder).toContain('BUTTON');
});
```

### Keyboard Shortcuts

| Shortcut | Expected Behavior |
|----------|-------------------|
| `Tab` | Move focus to next interactive element |
| `Shift+Tab` | Move focus to previous element |
| `Enter` | Activate focused button/link |
| `Escape` | Close modal/dropdown |
| `Space` | Toggle checkbox/radio |
| `Arrow Keys` | Navigate within list/grid |

---

## Screen Reader Testing

### ARIA Attributes to Verify

```typescript
test('should have proper ARIA structure', async ({ page }) => {
  await page.goto('http://localhost:3000');

  const ariaAudit = await page.evaluate(() => {
    const results = {
      hasLandmarks: false,
      hasLabels: false,
      hasDescriptions: false
    };

    // Check for landmarks (header, nav, main, footer)
    results.hasLandmarks = document.querySelectorAll('[role="banner"], [role="navigation"], [role="main"]').length > 0;

    // Check for labels on inputs
    results.hasLabels = document.querySelectorAll('input[aria-label], input[id]').length > 0;

    // Check for descriptions on complex widgets
    results.hasDescriptions = document.querySelectorAll('[aria-describedby]').length > 0;

    return results;
  });

  expect(ariaAudit.hasLandmarks).toBe(true);
  expect(ariaAudit.hasLabels).toBe(true);
});
```

---

## Testing Checklist

For each accessibility validation:

- [ ] WCAG AA automated scan passes (axe-core)
- [ ] All color modes render correctly
- [ ] Contrast ratios meet 4.5:1 minimum
- [ ] All features work via keyboard only
- [ ] Focus indicators are visible
- [ ] ARIA labels present on interactive elements
- [ ] Form inputs have associated labels
- [ ] Error messages are descriptive
- [ ] Page has descriptive title
- [ ] Images have alt text (or decorative)

---

## Running Accessibility Tests

```bash
# Run accessibility suite
npm run test:e2e -- tests/e2e/accessibility-suite.spec.ts

# Run with axe-core reporting
npm run test:e2e -- --reporter=json > accessibility-report.json

# Run specific color mode test
npm run test:e2e -- -g "protanopia"
```

---

## References

- **[qa-e2e-test-creation/SKILL.md](../qa-e2e-test-creation/SKILL.md)** - E2E test patterns
- [WCAG 2.1 Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)
- [Playwright Accessibility Testing](https://playwright.dev/docs/accessibility-testing)
- [@axe-core/playwright](https://www.npmjs.com/package/@axe-core/playwright)
