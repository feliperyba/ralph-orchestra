---
name: qa-mcp-helpers
description: Shared helper patterns for Playwright MCP validation agents. Reuses Page Object patterns from E2E tests.
category: helper
---

# Playwright MCP Helper Patterns

> "Share code between E2E tests and MCP validation"

This skill provides common patterns for using Playwright MCP tools in validation agents. These patterns align with the Page Object Model used in automated E2E tests.

## Quick Reference

| E2E Test Pattern | MCP Equivalent |
| ----------------- | -------------- |
| `new GamePage(page)` | Use same selectors via `page.getByRole()` |
| `await gamePage.goto()` | `await page.goto('http://localhost:3000')` |
| `await expect(element).toBeVisible()` | Check visibility, take screenshot |

## Common MCP Patterns

### Navigation

```typescript
// Navigate to the application
await page.goto('http://localhost:3000');

// Wait for page to fully load
await page.waitForLoadState('networkidle');

// Wait for canvas to be ready
await page.waitForSelector('canvas');
```

### Console Monitoring

```typescript
// Track console errors during validation
const errors: string[] = [];

page.on('console', (msg) => {
  if (msg.type() === 'error') {
    errors.push(msg.text());
  }
});

// After performing actions:
// Check that no errors occurred
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

### Using Page Object Selectors

When the E2E test uses specific selectors, use the same approach in MCP validation:

```typescript
// Character Selection Screen
// E2E test: page.locator('#characterName')
// MCP: page.locator('#characterName')

// Select Character Button
// E2E test: page.locator('button:has-text("Select Character")')
// MCP: page.locator('button:has-text("Select Character")')

// Lobby State
// E2E test: page.getByText('LOBBY')
// MCP: page.getByText('LOBBY')

// Connection State
// E2E test: page.getByText('Connected')
// MCP: page.getByText('Connected')
```

## Game-Specific Patterns

### Character Selection Flow

```typescript
// Navigate to game
await page.goto('http://localhost:3000');
await page.waitForLoadState('networkidle');

// Check if at Character Selection screen
const atCharacterSelection = await page.evaluate(() => {
  const bodyText = document.body.textContent || '';
  return bodyText.includes('Choose Your Character') ||
         bodyText.includes('Character Selection');
});

if (atCharacterSelection) {
  // Enter character name
  await page.fill('#characterName', 'TestPlayer');

  // Wait for state update
  await page.waitForTimeout(500);

  // Click Select Character button
  const selectButton = page.locator('button:has-text("Select Character")').first();
  await selectButton.click();

  // Wait for Lobby screen
  await page.waitForFunction(
    () => {
      const bodyText = document.body.textContent || '';
      return bodyText.includes('LOBBY') ||
             bodyText.includes('Connecting to server');
    },
    { timeout: 10000 }
  );
}
```

### Connection Verification

```typescript
// Wait for server connection
await page.waitForFunction(
  () => {
    const bodyText = document.body.textContent || '';
    // Must show "Connected" but not "Connecting to server"
    return bodyText.includes('Connected') &&
           !bodyText.includes('Connecting to server');
  },
  { timeout: 25000 }
);

// Verify connection state
const isConnected = await page.evaluate(() => {
  const bodyText = document.body.textContent || '';
  return bodyText.includes('Connected') &&
         bodyText.includes('Players in Lobby') &&
         !bodyText.includes('Connecting to server');
});
```

## Input Testing Patterns

### Keyboard Input (Movement)

```typescript
// Continuous movement for gameplay testing
await page.keyboard.down('KeyW');
await page.waitForTimeout(1000); // Move for 1 second
await page.keyboard.up('KeyW');

// Individual key presses
await page.keyboard.press('KeyA');
await page.waitForTimeout(500);
```

### Mouse Input (Pointer Lock)

```typescript
// Click to activate pointer lock
await page.mouse.click(400, 300);
await page.waitForTimeout(500);

// Simulate mouse movement (movementX/Y only work when locked)
await page.mouse.move(100, 100);
await page.mouse.move(200, 150); // movementX: 100, movementY: 50

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

## Selector Best Practices

When writing MCP validation scripts, follow these selector priorities:

### Priority Order

1. **Role-based selectors** (Preferred - accessible)
   ```typescript
   page.getByRole('button', { name: 'Submit' })
   page.getByRole('textbox', { name: 'Username' })
   ```

2. **Label-based selectors** (Good - accessible)
   ```typescript
   page.getByLabel('Character Name')
   page.getByLabel('Email address')
   ```

3. **Test ID selectors** (When no accessible name)
   ```typescript
   page.getByTestId('submit-button')
   page.getByTestId('character-name-input')
   ```

4. **Text content** (For existing patterns)
   ```typescript
   page.getByText('LOBBY')
   page.locator('button:has-text("Select Character")')
   ```

5. **ID selectors** (For legacy/existing code)
   ```typescript
   page.locator('#characterName')
   ```

### Avoid

❌ **Brittle CSS selectors:**
```typescript
// Bad - breaks with CSS changes
page.locator('.btn-primary:first-child')
page.locator('div.container > div:nth-child(2)')

// Bad - fragile to DOM structure changes
page.locator('body > div > div > button')
```

## Anti-Patterns

### Don't Use Hard-coded Waits

```typescript
// Bad - arbitrary delay
await page.waitForTimeout(5000);

// Good - wait for specific condition
await page.waitForSelector('canvas');
await page.waitForFunction(() => {
  return document.body.textContent?.includes('Connected');
});
```

### Don't Skip Error Checking

```typescript
// Always check for console errors
const errors: string[] = [];
page.on('console', (msg) => {
  if (msg.type() === 'error') errors.push(msg.text());
});

// After validation, verify no errors
if (errors.length > 0) {
  console.error('Console errors found:', errors);
}
```

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

## Page Object Model Reference

**E2E tests and MCP agents share Page Objects from `tests/pages/`:**

| File                                                               | Purpose                                     |
| ------------------------------------------------------------------ | ------------------------------------------- |
| [tests/pages/base.page.ts](tests/pages/base.page.ts)               | Base page class (goto, console, screenshot) |
| [tests/pages/game.page.ts](tests/pages/game.page.ts)               | Character selection, lobby, connection      |
| [tests/pages/multiplayer.page.ts](tests/pages/multiplayer.page.ts) | Multi-client setup, connect, cleanup        |

**Selector priority:**

1. Role-based: `page.getByRole('button', { name: 'Submit' })`
2. Label-based: `page.getByLabel('Character Name')`
3. Test ID: `page.getByTestId('submit-button')`
4. Text content: `page.getByText('LOBBY')`
5. ID selector: `page.locator('#characterName')`

**Avoid:** Brittle CSS selectors like `.btn-primary:first-child`

---

## References

- [tests/pages/base.page.ts](tests/pages/base.page.ts) - Base page class
- [tests/pages/game.page.ts](tests/pages/game.page.ts) - Game-specific interactions
- [tests/pages/multiplayer.page.ts](tests/pages/multiplayer.page.ts) - Multiplayer test helpers
- [tests/e2e/multiplayer-suite.spec.ts](tests/e2e/multiplayer-suite.spec.ts) - Example E2E tests
- [.claude/skills/qa-browser-testing/SKILL.md](.claude/skills/qa-browser-testing/SKILL.md) - Browser testing skill
