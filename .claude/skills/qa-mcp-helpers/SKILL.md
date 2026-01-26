---
name: qa-mcp-helpers
description: Shared helper patterns for Playwright MCP validation agents. Reuses Page Object patterns from E2E tests.
---

# Playwright MCP Helper Patterns

> "Share code between E2E tests and MCP validation"

This skill provides common patterns for Playwright MCP tools in validation agents. These align with Page Object Model used in automated E2E tests.

## Quick Reference

| E2E Test Pattern | MCP Equivalent |
| ----------------- | -------------- |
| `new GamePage(page)` | Use same selectors via `page.getByRole()` |
| `await gamePage.goto()` | `await page.goto('http://localhost:3000')` |
| `await expect(element).toBeVisible()` | Check visibility, take screenshot |

## Helper Libraries

**See these helper files for complete implementations:**

| Helper File | Purpose |
|-------------|---------|
| `tests/helpers/gameplay-patterns.ts` | Movement, input, FPS monitoring |
| `tests/helpers/visual-analysis.ts` | Screenshot analysis, GDD compliance |
| `tests/pages/base.page.ts` | Base page class with common methods |
| `tests/pages/game.page.ts` | Game-specific interactions |
| `tests/pages/multiplayer.page.ts` | Multi-client testing |

---

## Core Patterns

### Navigation

```typescript
// Navigate to the application
await page.goto('http://localhost:3000');
await page.waitForLoadState('networkidle');
await page.waitForSelector('canvas');
```

### Console Monitoring

```typescript
// Track console errors during validation
const errors: string[] = [];
page.on('console', (msg) => {
  if (msg.type() === 'error') errors.push(msg.text());
});

// After actions: verify no errors
expect(errors).toHaveLength(0);
```

### Screenshot Evidence

```typescript
// Capture screenshot for validation evidence
await page.screenshot({
  path: '.claude/session/qa-validation/screenshot.png',
  fullPage: true
});
```

---

## Game-Specific Patterns

<details>
<summary>Character Selection Flow</summary>

```typescript
// Navigate to game
await page.goto('http://localhost:3000');
await page.waitForLoadState('networkidle');

// Check if at Character Selection screen
const atCharacterSelection = await page.evaluate(() => {
  const bodyText = document.body.textContent || '';
  return bodyText.includes('Choose Your Character');
});

if (atCharacterSelection) {
  // Enter character name
  await page.fill('#characterName', 'TestPlayer');
  await page.waitForTimeout(500);

  // Click Select Character button
  const selectButton = page.locator('button:has-text("Select Character")').first();
  await selectButton.click();

  // Wait for Lobby screen
  await page.waitForFunction(() => {
    const bodyText = document.body.textContent || '';
    return bodyText.includes('LOBBY');
  }, { timeout: 10000 });
}
```

</details>

<details>
<summary>Connection Verification</summary>

```typescript
// Wait for server connection
await page.waitForFunction(
  () => {
    const bodyText = document.body.textContent || '';
    return bodyText.includes('Connected') &&
           !bodyText.includes('Connecting to server');
  },
  { timeout: 25000 }
);

// Verify connection state
const isConnected = await page.evaluate(() => {
  const bodyText = document.body.textContent || '';
  return bodyText.includes('Connected') &&
         bodyText.includes('Players in Lobby');
});
```

</details>

---

## Input Testing Patterns

### Keyboard Input (Movement)

```typescript
// Continuous movement - use gameplay-patterns.ts helpers
import { moveForward, strafeLeft, jump } from '@/helpers/gameplay-patterns';

await moveForward(page, 1000);  // Move forward for 1 second
await strafeLeft(page, 500);    // Strafe left for 500ms
await jump(page);               // Jump once
```

### Mouse Input (Pointer Lock)

```typescript
// Click to activate pointer lock
await page.mouse.click(400, 300);
await page.waitForTimeout(500);

// Simulate mouse movement
await page.mouse.move(100, 100);
await page.mouse.move(200, 150);

// Mouse click (shoot action)
await page.mouse.down();
await page.waitForTimeout(200);
await page.mouse.up();
```

### Escape Key (Pause/Unlock)

```typescript
// Press ESC to unlock pointer and show PAUSED
await page.keyboard.press('Escape');

// Verify pointer is unlocked
const isLocked = await page.evaluate(() => {
  return document.pointerLockElement === document.body;
});
expect(isLocked).toBe(false);
```

---

## Selector Best Practices

### Priority Order

| Priority | Type | Example |
|----------|------|---------|
| 1 (Best) | Role-based | `page.getByRole('button', { name: 'Submit' })` |
| 2 (Good) | Label-based | `page.getByLabel('Character Name')` |
| 3 (When needed) | Test ID | `page.getByTestId('submit-button')` |
| 4 (Existing) | Text content | `page.getByText('LOBBY')` |
| 5 (Legacy) | ID selector | `page.locator('#characterName')` |

### Avoid

❌ **Brittle CSS selectors:**
```typescript
// Breaks with CSS changes
page.locator('.btn-primary:first-child')
page.locator('div.container > div:nth-child(2)')
```

✅ **Stable accessible selectors:**
```typescript
// Uses semantic HTML
page.getByRole('button', { name: 'Submit' })
page.getByLabel('Email address')
```

---

## Common Page Object Selectors

When E2E tests use specific selectors, use the same approach in MCP validation:

```typescript
// Character Selection Screen
await page.fill('#characterName', 'TestPlayer');
await page.locator('button:has-text("Select Character")').first().click();

// Lobby State
await expect(page.getByText('LOBBY')).toBeVisible();

// Connection State
await expect(page.getByText('Connected')).toBeVisible();
```

---

## Alignment with E2E Tests

MCP validation agents should:

1. **Use same selectors** as defined in `tests/pages/*.page.ts`
2. **Focus on NEW features** - don't duplicate regression tests
3. **Use Vision MCP** for visual validation when appropriate
4. **Take screenshots** as evidence for validation reports

### Example Alignment

```typescript
// E2E test (tests/pages/game.page.ts):
export class GamePage {
  readonly characterNameInput: Locator;
  constructor(page: Page) {
    this.characterNameInput = page.locator('#characterName');
  }
}

// MCP validation uses same selector:
await page.fill('#characterName', 'TestPlayer');
```

---

## Anti-Patterns

| ❌ DON'T | ✅ DO |
|----------|-------|
| Hardcoded waits (`waitForTimeout(5000)`) | Wait for specific condition (`waitForSelector`) |
| Skip error checking | Always monitor console for errors |
| Use brittle CSS selectors | Use role-based selectors |
| Duplicate E2E test logic | Focus on NEW feature validation |
| Ignore page object patterns | Reuse selectors from `tests/pages/` |

---

## References

- [tests/pages/base.page.ts](tests/pages/base.page.ts) - Base page class
- [tests/pages/game.page.ts](tests/pages/game.page.ts) - Game page object
- [tests/pages/multiplayer.page.ts](tests/pages/multiplayer.page.ts) - Multiplayer helpers
- **[qa-browser-testing/SKILL.md](../qa-browser-testing/SKILL.md)** - Browser testing skill
