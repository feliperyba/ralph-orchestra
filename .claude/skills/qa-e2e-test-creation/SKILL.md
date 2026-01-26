---
name: qa-e2e-test-creation
description: Playwright E2E test creation patterns. Provides patterns for page objects, multi-client testing, and user flow validation. Use when creating end-to-end tests for authentication, gameplay, and UI interactions.
---

## Separation of Concerns

| Type | Purpose | When |
|------|---------|------|
| **E2E Tests** (`npm test:e2e`) | REGRESSION testing for CI/CD | Run on every commit/PR |
| **MCP Agents** | EXPLORATORY validation for NEW features | One-time validation per task |

# Playwright E2E Test Creation Patterns

> "E2E tests verify your application works from the user's perspective."

## When to Use

Use when creating E2E tests for:
- User authentication flows (character selection, lobby)
- Gameplay mechanics (movement, shooting, painting)
- Multiplayer features (state sync, multiple clients)
- UI interactions (buttons, forms, navigation)

## Test File Locations

**Pattern:** Flat structure in `tests/e2e/`

| Feature | Test File |
| ------- | --------- |
| Authentication | `tests/e2e/auth-suite.spec.ts` |
| Gameplay | `tests/e2e/gameplay-suite.spec.ts` |
| Multiplayer | `tests/e2e/multiplayer-suite.spec.ts` |
| Accessibility | `tests/e2e/accessibility-suite.spec.ts` |
| UI Components | `tests/e2e/ui-suite.spec.ts` |

**Naming convention:** `{feature}-suite.spec.ts`

---

## Core Principles

### 1. Use Accessible Selectors

```typescript
// ✅ Good - Use role and name
const button = page.getByRole('button', { name: 'Submit' });
const input = page.getByLabel('Email');
const heading = page.getByRole('heading', { name: 'Welcome' });

// ✅ Good - Use test id when needed
const component = page.getByTestId('user-card');

// ❌ Bad - Avoid CSS selectors
const button = page.locator('.btn-primary');
```

### 2. Let Playwright Wait

```typescript
// ✅ Good - Auto-waiting with assertions
await expect(page.getByRole('button')).toBeVisible();

// ✅ Good - Explicit wait for specific condition
await page.waitForURL('**/lobby');
await page.waitForLoadState('networkidle');

// ❌ Bad - Hardcoded waits
await page.waitForTimeout(5000);
```

### 3. Use Page Object Model

All E2E tests MUST use Page Objects from `tests/pages/`:

```typescript
import { GamePage } from '@/pages/game.page';
import { MultiplayerPage } from '@/pages/multiplayer.page';

test('should select character and reach lobby', async ({ page }) => {
  const gamePage = new GamePage(page);
  await gamePage.goto();
  await gamePage.selectCharacter('TestPlayer');
  await gamePage.waitForLobby();
  expect(await gamePage.isConnected()).toBe(true);
});
```

---

<examples>

## Example 1: Navigation and Page Load

```typescript
test.describe('Navigation', () => {
  test('should load home page', async ({ page }) => {
    await page.goto('http://localhost:3000');
    await expect(page).toHaveTitle(/Game/);
    await expect(page.getByRole('heading')).toBeVisible();
  });

  test('should navigate to character selection', async ({ page }) => {
    await page.goto('http://localhost:3000');
    await page.getByRole('button', { name: 'Play' }).click();
    await expect(page).toHaveURL(/\/character-selection/);
    await expect(page.getByRole('heading', { name: 'Choose Your Character' })).toBeVisible();
  });
});
```

## Example 2: Form Input and Submission

```typescript
test.describe('Character Selection', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('http://localhost:3000');
  });

  test('should enter character name', async ({ page }) => {
    const nameInput = page.getByLabel('Character Name');
    await nameInput.fill('TestPlayer');
    await expect(nameInput).toHaveValue('TestPlayer');
  });

  test('should submit character selection', async ({ page }) => {
    await page.getByLabel('Character Name').fill('TestPlayer');
    await page.getByRole('button', { name: 'Select Character' }).click();
    await expect(page).toHaveURL(/\/lobby/);
  });

  test('should show validation for empty name', async ({ page }) => {
    await page.getByRole('button', { name: 'Select Character' }).click();
    await expect(page.getByRole('alert')).toContainText('name is required');
  });
});
```

## Example 3: Multi-Client Testing

```typescript
test.describe('Multiplayer - State Sync', () => {
  test('should sync player position between clients', async ({ browser }) => {
    const multiplayerPage = new MultiplayerPage(page);
    const players = await multiplayerPage.setupMultiPlayerTest(browser, 2);

    try {
      await multiplayerPage.connectPlayersToGame(players);

      // Player 1 moves
      await players[0].page.click('canvas');
      await players[0].page.keyboard.down('KeyW');
      await players[0].page.waitForTimeout(500);
      await players[0].page.keyboard.up('KeyW');

      // Player 2 sees movement
      const synced = await multiplayerPage.verifyStateSync(players);
      expect(synced).toBe(true);
    } finally {
      await multiplayerPage.cleanupPlayers(players);
    }
  });
});
```

</examples>

---

## Page Object Model

### Available Page Objects

```typescript
// tests/pages/base.page.ts - Base class with common methods
import { BasePage } from '@/pages/base.page';

// tests/pages/game.page.ts - Game-specific interactions
import { GamePage } from '@/pages/game.page';

// tests/pages/multiplayer.page.ts - Multi-client testing
import { MultiplayerPage } from '@/pages/multiplayer.page';
```

### MultiplayerPage Helpers

| Method | Purpose |
|--------|---------|
| `setupMultiPlayerTest(browser, count)` | Create browser contexts |
| `connectPlayersToGame(players)` | Connect players to lobby |
| `verifyAllConnected(players)` | Check all players connected |
| `verifyStateSync(players)` | Check state synchronization |
| `cleanupPlayers(players)` | Close contexts (use in finally block) |

---

<details>
<summary>Additional E2E Test Patterns</summary>

### Keyboard Interaction

```typescript
test.describe('Movement Controls', () => {
  test('should move character with WASD', async ({ page }) => {
    await page.goto('http://localhost:3000');
    // Navigate to game...

    await page.keyboard.down('KeyW');
    await page.waitForTimeout(500);
    await page.keyboard.up('KeyW');

    const position = await page.evaluate(() => (window as any).gameState?.player?.position);
    expect(position.z).toBeLessThan(0); // Moved forward
  });
});
```

### Mouse Interaction

```typescript
test.describe('Shooting Controls', () => {
  test('should activate pointer lock on click', async ({ page }) => {
    await page.goto('http://localhost:3000');
    await page.mouse.click(400, 300);

    const isPointerLocked = await page.evaluate(() => document.pointerLockElement !== null);
    expect(isPointerLocked).toBe(true);
  });
});
```

### Console Error Checking

```typescript
test('should not have console errors', async ({ page }) => {
  const errors: string[] = [];
  page.on('console', (msg) => {
    if (msg.type() === 'error') errors.push(msg.text());
  });

  await page.goto('http://localhost:3000');
  await page.getByRole('button', { name: 'Play' }).click();

  expect(errors).toHaveLength(0);
});
```

### Network Request Testing

```typescript
test('should connect to websocket server', async ({ page }) => {
  const wsConnections: string[] = [];
  page.on('websocket', (ws) => wsConnections.push(ws.url()));

  await page.goto('http://localhost:3000');
  await page.getByRole('button', { name: 'Select Character' }).click();

  expect(wsConnections.some((url) => url.includes('2567'))).toBe(true);
});
```

### Visual Regression Testing

```typescript
test('should match screenshot', async ({ page }) => {
  await page.goto('http://localhost:3000');
  await page.waitForLoadState('networkidle');

  await expect(page).toHaveScreenshot('home-page.png', {
    maxDiffPixels: 100,
  });
});
```

### Test Organization

```typescript
test.describe('Authentication Flow', () => {
  test.describe('Character Selection', () => {
    test.beforeEach(async ({ page }) => {
      await page.goto('http://localhost:3000');
    });

    test('should show character selection screen', async ({ page }) => {});
    test('should validate character name', async ({ page }) => {});
    test('should proceed to lobby on submit', async ({ page }) => {});
  });
});
```

</details>

---

## Best Practices Summary

### Focus on Critical User Journeys

- Test complete flows, not individual components
- Cover happy path + common error cases
- Avoid over-testing

```typescript
// ✅ Good - Tests complete user flow
test('should select character and join lobby', async ({ page }) => {
  const gamePage = new GamePage(page);
  await gamePage.goto();
  await gamePage.selectCharacter('TestPlayer');
  await gamePage.waitForLobby();
  expect(await gamePage.isConnected()).toBe(true);
});

// ❌ Bad - Tests implementation detail
test('should set characterName state variable', async ({ page }) => {
  // Don't test internal state
});
```

### Test Isolation

- Each test should be independent
- Use `test.beforeEach` for setup
- Use unique data per test

```typescript
// ✅ Good - Unique data per test
test('should handle player join', async ({ page }) => {
  const playerName = `Player_${Date.now()}_${Math.random()}`;
  await gamePage.selectCharacter(playerName);
});

// ❌ Bad - Shared data causes race conditions
test('should handle player join', async ({ page }) => {
  await gamePage.selectCharacter('TestPlayer'); // Fails in parallel
});
```

### Clean Up Resources

```typescript
test('multiplayer test', async ({ browser }) => {
  const players = await setupMultiPlayerTest(browser, 2);
  try {
    // Test implementation
  } finally {
    await cleanupPlayers(players); // Always runs
  }
});
```

---

## Running E2E Tests

```bash
# Run all E2E tests
npm run test:e2e

# Run specific file
npm run test:e2e -- tests/e2e/auth-suite.spec.ts

# Run in headed mode (see browser)
npm run test:e2e -- --headed

# Run specific test
npm run test:e2e -- -g "should connect 2 clients"

# Run on different browsers
npm run test:e2e -- --project=chromium
npm run test:e2e -- --project=firefox
npm run test:e2e -- --project=webkit
```

---

## Accessibility Testing

For WCAG compliance, color modes, and keyboard navigation testing, see:
**[qa-accessibility-testing/SKILL.md](../qa-accessibility-testing/SKILL.md)**

---

## References

- [Playwright Documentation](https://playwright.dev/)
- [tests/pages/base.page.ts](tests/pages/base.page.ts) - Base page class
- [tests/pages/game.page.ts](tests/pages/game.page.ts) - Game page object
- [tests/pages/multiplayer.page.ts](tests/pages/multiplayer.page.ts) - Multiplayer page object
- **[qa-unit-test-creation/SKILL.md](../qa-unit-test-creation/SKILL.md)** - Unit test patterns
