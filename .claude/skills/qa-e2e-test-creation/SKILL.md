---
name: qa-e2e-test-creation
description: Playwright E2E test creation patterns. Provides patterns for page objects, multi-client testing, and accessibility selectors. Use when creating end-to-end tests for user flows and gameplay features.
category: workflow
---

## Separation of Concerns

**IMPORTANT:** E2E tests and MCP validation agents have different purposes:

| Type                           | Purpose                                 | When                         |
| ------------------------------ | --------------------------------------- | ---------------------------- |
| **E2E Tests** (`npm test:e2e`) | REGRESSION testing for CI/CD            | Run on every commit/PR       |
| **MCP Agents**                 | EXPLORATORY validation for NEW features | One-time validation per task |

E2E tests ensure existing features don't break. MCP agents verify new feature implementation.

NEVER CREATE FAKE OR TRIVIAL TESTS. If a test cannot be created with meaningful assertions, DO NOT CREATE A TEST. Instead, report the issue to PM and document the gap in test coverage in the task comments and close the task as completed with observations.

## MANDATORY: Port Detection Before Browser Testing

**⚠️ CRITICAL: Vite dev server may run on different ports (3000, 3001, 5174, 8080, etc.)**

**Before ANY browser interaction, ALWAYS detect the correct port:**

```bash
# Method 1: Check listening ports
netstat -an | grep LISTEN | grep -E ":(3000|3001|5174|8080)"

# Method 2: Try curl to detect Vite
curl -s http://localhost:3000 | grep -q "vite" && echo "PORT=3000" || \
curl -s http://localhost:3001 | grep -q "vite" && echo "PORT=3001" || \
curl -s http://localhost:5174 | grep -q "vite" && echo "PORT=5174"
```

**NOTE:** E2E tests configured in `playwright.config.ts` use `baseURL: 'http://localhost:3000'` which works for most cases. The `webServer` configuration in Playwright automatically starts the dev server on the correct port before running tests.

**For manual testing or MCP validation, detect the port first and use `http://localhost:{detectedPort}`.**

# Playwright E2E Test Creation Patterns

> "E2E tests verify your application works from the user's perspective."

  - **CRITICAL:** NEVER CREATE FAKE OR TRIVIAL TESTS. If a test cannot be created with meaningful assertions based on the specs/gdd requirements, DO NOT CREATE A TEST. Instead, report the issue to PM and document the gap in test coverage in the task comments and close the task as completed with observations.

## When to Use This Skill

Use when creating E2E tests for:

- User authentication flows (character selection, lobby)
- Gameplay mechanics (movement, shooting, painting)
- Multiplayer features (state sync, multiple clients)
- UI interactions (buttons, forms, navigation)
- Visual features (shaders, materials, effects)

## Test File Locations

**Pattern:** Flat structure in `tests/e2e/`

| Feature        | Test File                                        |
| -------------- | ------------------------------------------------ |
| Authentication | `tests/e2e/auth-suite.spec.ts`                   |
| Gameplay       | `tests/e2e/gameplay-suite.spec.ts`               |
| Multiplayer    | `tests/e2e/multiplayer-suite.spec.ts` (exists)   |
| Accessibility  | `tests/e2e/accessibility-suite.spec.ts` (P1-005) |
| UI Components  | `tests/e2e/ui-suite.spec.ts`                     |

**Naming convention:** `{feature}-suite.spec.ts`

## Three.js / WebGL Testing Patterns

**⚠️ CRITICAL:** Testing Three.js applications requires specific patterns for WebGL context support.

## Running E2E Tests

```bash
# Run all E2E tests
npm run test:e2e

# Run specific file
npm run test:e2e -- tests/e2e/auth-suite.spec.ts

# Run in headed mode (see browser)
npm run test:e2e -- --headed

# Run with debug mode
npm run test:e2e -- --debug

# Run specific test
npm run test:e2e -- -g "should connect 2 clients"

# Run on different browsers
npm run test:e2e -- --project=chromium
npm run test:e2e -- --project=firefox
npm run test:e2e -- --project=webkit
```

## Best Practices Summary

Based on Playwright official documentation and testing community best practices:

### 1. Focus on Critical User Journeys

- Test complete flows, not individual components
- Cover happy path + common error cases
- Avoid over-testing (don't test every possible input)

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
  // Don't test internal state, test user-observable behavior
});
```

### 2. Use Page Object Model

- All page objects in `tests/pages/` directory
- Reusable across tests
- Single source of truth for selectors

### 3. Accessible Selectors First

```typescript
// ✅ Good - Role-based
page.getByRole('button', { name: 'Submit' });

// ✅ Good - By label
page.getByLabel('Email address');

// ✅ Good - Test ID (when no accessible name)
page.getByTestId('submit-button');

// ⚠️ Acceptable - ID selector (existing code)
page.locator('#characterName');

// ❌ Bad - Brittle CSS selector
page.locator('.btn-primary:first-child');
```

### 4. Let Playwright Wait

```typescript
// ✅ Good - Auto-waiting
await expect(button).toBeVisible();
await page.waitForLoadState('networkidle');

// ❌ Bad - Hard-coded wait
await page.waitForTimeout(5000);
```

### 5. Test Isolation

- Each test should be independent
- Use `test.beforeEach` for setup
- Clean up in `test.afterEach` if needed

```typescript
test.describe('Character Selection', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('http://localhost:3000');
  });

  test('should accept valid name', async ({ page }) => {
    // Test assumes starting at character selection
  });
});
```

### 6. Parallel Execution

- Tests run in parallel by default
- Don't share state between tests
- Use unique data per test

```typescript
// ✅ Good - Unique data per test
test('should handle player join', async ({ page }) => {
  const playerName = `Player_${Date.now()}_${Math.random()}`;
  await gamePage.selectCharacter(playerName);
});

// ❌ Bad - Shared data causes race conditions
test('should handle player join', async ({ page }) => {
  await gamePage.selectCharacter('TestPlayer'); // Fails when tests run in parallel
});
```

### 7. Clean Up Resources

Always clean up in `finally` blocks:

```typescript
test('multiplayer test', async ({ browser }) => {
  const players = await setupMultiPlayerTest(browser, 2);
  try {
    // Test implementation
  } finally {
    await cleanupPlayers(players); // Always runs, even on failure
  }
});
```

### Scene Readiness Pattern

Always wait for Three.js scene initialization using a data attribute:

```typescript
// In your Scene.tsx or App.tsx component
useEffect(() => {
  // Mark scene as ready when Three.js has initialized
  const canvas = canvasRef.current;
  if (canvas) {
    canvas.dataset.ready = '1';
  }
}, []);

// In your E2E test
test('scene renders correctly', async ({ page }) => {
  await page.goto('http://localhost:3000');

  // Wait for scene to be ready
  await page.locator('canvas[data-ready="1"]').waitFor({ timeout: 15000 });

  // Now safe to interact with the scene
  await page.mouse.click(400, 300);
});
```

### WebGL Context Verification

Verify WebGL context is properly initialized:

```typescript
test('WebGL context is available', async ({ page }) => {
  await page.goto('http://localhost:3000');
  await page.locator('canvas[data-ready="1"]').waitFor();

  const webglInfo = await page.evaluate(() => {
    const canvas = document.querySelector('canvas');
    if (!canvas) return { hasContext: false };

    const gl = canvas.getContext('webgl2') || canvas.getContext('webgl');
    if (!gl) return { hasContext: false };

    const debugInfo = gl.getExtension('WEBGL_debug_renderer_info');

    return {
      hasContext: true,
      version: gl.getParameter(gl.VERSION),
      vendor: debugInfo ? gl.getParameter(debugInfo.UNMASKED_VENDOR_WEBGL) : 'unknown',
      renderer: debugInfo ? gl.getParameter(debugInfo.UNMASKED_RENDERER_WEBGL) : 'unknown',
    };
  });

  expect(webglInfo.hasContext).toBe(true);
  console.log('WebGL Info:', webglInfo);
});
```

### Canvas-Only Screenshots for WebGL

For visual regression of WebGL scenes, screenshot only the canvas element:

```typescript
test('canvas visual regression', async ({ page }) => {
  await page.goto('http://localhost:3000');
  await page.locator('canvas[data-ready="1"]').waitFor();

  const canvas = page.locator('canvas');

  // Screenshot just the canvas element
  await expect(canvas).toHaveScreenshot('canvas-render.png', {
    animations: 'allow',
    // Thresholds configured in playwright.config.ts:
    // threshold: 0.2, maxDiffPixelRatio: 0.02, maxDiffPixels: 500
  });
});
```

### Headless vs Headed Mode for WebGL

| Browser  | Headless WebGL   | Configuration                              |
| -------- | ---------------- | ------------------------------------------ |
| Chromium | Yes (with flags) | `--use-gl=desktop` in playwright.config.ts |
| Chrome   | Yes (with flags) | Best WebGL support                         |
| Firefox  | **No**           | `headless: false` required                 |
| WebKit   | **No**           | `headless: false` required                 |

**Firefox Testing:**

```bash
# Local - headed mode
npm run test:e2e -- --project=firefox-webgl --headed

# CI - use Xvfb for virtual display
xvfb-run --auto-servernum npm run test:e2e -- --project=firefox-webgl
```

### Exposing Three.js State for Testing (Development Only)

```typescript
// In Scene.tsx (development builds only)
if (import.meta.env.DEV) {
  (window as any).__THREE__ = {
    scene: sceneRef.current,
    camera: cameraRef.current,
    renderer: gl,
  };
}

// In E2E test
test('scene has expected lights', async ({ page }) => {
  await page.goto('http://localhost:3000');
  await page.locator('canvas[data-ready="1"]').waitFor();

  const lights = await page.evaluate(() => {
    const scene = (window as any).__THREE__?.scene;
    if (!scene) return { ambient: 0, directional: 0 };

    let ambient = 0;
    let directional = 0;

    scene.traverse((obj: any) => {
      if (obj.isAmbientLight) ambient++;
      if (obj.isDirectionalLight) directional++;
    });

    return { ambient, directional };
  });

  expect(lights.ambient).toBeGreaterThan(0);
  expect(lights.directional).toBeGreaterThan(0);
});
```

### Shader Error Detection

```typescript
test('should have no shader compilation errors', async ({ page }) => {
  const shaderErrors: string[] = [];

  page.on('console', (msg) => {
    const text = msg.text();
    const shaderErrorPatterns = [
      /THREE\.WebGLProgram/i,
      /shader error/i,
      /program info log/i,
      /WEBGL_WARNING/i, // But filter out WEBGL_debug_renderer_info
    ];

    if (shaderErrorPatterns.some((p) => p.test(text))) {
      shaderErrors.push(text);
    }
  });

  await page.goto('http://localhost:3000');
  await page.locator('canvas[data-ready="1"]').waitFor();

  // Trigger shader-heavy interactions
  await page.mouse.click(400, 300);
  await page.waitForTimeout(1000);

  expect(shaderErrors).toHaveLength(0);
});
```

## Basic Test Structure

```typescript
import { test, expect } from '@playwright/test';

test.describe('Feature Name', () => {
  // Setup before each test
  test.beforeEach(async ({ page }) => {
    await page.goto('http://localhost:3000');
  });

  test('should do something', async ({ page }) => {
    // Test implementation
  });

  test('should meet acceptance criterion', async ({ page }) => {
    // Test implementation
  });
});
```

## Playwright Best Practices

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
const input = page.locator('#email-input');
```

### 2. Wait for Elements Properly

```typescript
// ✅ Good - Auto-waiting with assertions
await expect(page.getByRole('button', { name: 'Submit' })).toBeVisible();

// ✅ Good - Explicit wait for specific condition
await page.waitForURL('**/lobby');
await page.waitForLoadState('networkidle');

// ❌ Bad - Hardcoded waits
await page.waitForTimeout(5000); // Brittle and slow
```

### 3. Take Screenshots for Debugging

```typescript
test('should show error message', async ({ page }) => {
  await page.goto('http://localhost:3000');

  // Take screenshot on failure
  await page.screenshot({
    path: 'tests/screenshots/error-case.png',
    fullPage: true,
  });
});
```

## Common E2E Test Patterns

### 1. Navigation and Page Load

```typescript
test.describe('Navigation', () => {
  test('should load home page', async ({ page }) => {
    await page.goto('http://localhost:3000');

    // Verify page loaded
    await expect(page).toHaveTitle(/Game/);
    await expect(page.getByRole('heading')).toBeVisible();
  });

  test('should navigate to character selection', async ({ page }) => {
    await page.goto('http://localhost:3000');

    // Click navigation
    await page.getByRole('button', { name: 'Play' }).click();

    // Verify navigation
    await expect(page).toHaveURL(/\/character-selection/);
    await expect(page.getByRole('heading', { name: 'Choose Your Character' })).toBeVisible();
  });
});
```

### 2. Form Input and Submission

```typescript
test.describe('Character Selection', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('http://localhost:3000');
  });

  test('should enter character name', async ({ page }) => {
    const nameInput = page.getByLabel('Character Name');
    await nameInput.fill('TestPlayer');

    // Verify input
    await expect(nameInput).toHaveValue('TestPlayer');
  });

  test('should submit character selection', async ({ page }) => {
    // Fill form
    await page.getByLabel('Character Name').fill('TestPlayer');

    // Submit
    await page.getByRole('button', { name: 'Select Character' }).click();

    // Verify navigation to lobby
    await expect(page).toHaveURL(/\/lobby/);
  });

  test('should show validation for empty name', async ({ page }) => {
    // Try to submit without name
    await page.getByRole('button', { name: 'Select Character' }).click();

    // Verify error message
    await expect(page.getByRole('alert')).toContainText('name is required');
  });
});
```

### 3. Multi-Client Testing

```typescript
test.describe('Multiplayer - State Sync', () => {
  test('should sync player position between clients', async ({ browser }) => {
    // Create two browser contexts (simulating two players)
    const context1 = await browser.newContext();
    const context2 = await browser.newContext();
    const page1 = await context1.newPage();
    const page2 = await context2.newPage();

    try {
      // Both players navigate to game
      await page1.goto('http://localhost:3000');
      await page2.goto('http://localhost:3000');

      // Player 1 enters game
      await page1.getByLabel('Character Name').fill('Player1');
      await page1.getByRole('button', { name: 'Select Character' }).click();
      await page1.waitForURL(/\/lobby/);

      // Player 2 enters game
      await page2.getByLabel('Character Name').fill('Player2');
      await page2.getByRole('button', { name: 'Select Character' }).click();
      await page2.waitForURL(/\/lobby/);

      // Verify both players see each other
      const player1Count = await page1.getByText('Players in Lobby: 2').isVisible();
      const player2Count = await page2.getByText('Players in Lobby: 2').isVisible();

      expect(player1Count).toBe(true);
      expect(player2Count).toBe(true);
    } finally {
      await context1.close();
      await context2.close();
    }
  });
});
```

### 4. Keyboard Interaction

```typescript
test.describe('Movement Controls', () => {
  test('should move character with WASD', async ({ page }) => {
    await page.goto('http://localhost:3000');

    // Navigate to game
    // ... login flow ...

    // Press W to move forward
    await page.keyboard.down('KeyW');
    await page.waitForTimeout(500); // Move for 500ms
    await page.keyboard.up('KeyW');

    // Verify position changed (check canvas or debug panel)
    const position = await page.evaluate(() => {
      return (window as any).gameState.player.position;
    });

    expect(position.z).toBeLessThan(0); // Moved forward (negative Z)
  });

  test('should handle multiple keys', async ({ page }) => {
    await page.goto('http://localhost:3000');

    // Press W and D simultaneously (diagonal movement)
    await page.keyboard.down('KeyW');
    await page.keyboard.down('KeyD');
    await page.waitForTimeout(500);
    await page.keyboard.up('KeyW');
    await page.keyboard.up('KeyD');

    // Verify diagonal movement
  });
});
```

### 5. Mouse Interaction

```typescript
test.describe('Shooting Controls', () => {
  test('should activate pointer lock on click', async ({ page }) => {
    await page.goto('http://localhost:3000');

    // Click to activate pointer lock
    await page.mouse.click(400, 300);

    // Verify pointer lock
    const isPointerLocked = await page.evaluate(() => {
      return document.pointerLockElement !== null;
    });

    expect(isPointerLocked).toBe(true);
  });

  test('should shoot on mouse click', async ({ page }) => {
    await page.goto('http://localhost:3000');

    // Activate pointer lock
    await page.mouse.click(400, 300);

    // Shoot
    await page.mouse.down();
    await page.waitForTimeout(100);
    await page.mouse.up();

    // Verify shot fired (check game state or debug panel)
  });
});
```

### 6. Console Error Checking

**⚠️ IMPORTANT: For Three.js/WebGL applications, filter out expected headless browser warnings.**

```typescript
test.describe('Error Handling', () => {
  test('should not have application console errors', async ({ page }) => {
    // Collect console messages
    const errors: string[] = [];
    const warnings: string[] = [];

    page.on('console', (msg) => {
      if (msg.type() === 'error') {
        errors.push(msg.text());
      }
      if (msg.type() === 'warning') {
        warnings.push(msg.text());
      }
    });

    await page.goto('http://localhost:3000');

    // Navigate through app
    await page.getByRole('button', { name: 'Play' }).click();

    // Filter out known headless WebGL errors (expected, not application bugs)
    const filteredErrors = errors.filter((error) => {
      const webglHeadlessPatterns = [
        /WebGL2RenderingContext/i,
        /Error creating WebGL context/i,
        /WebGL context could not be created/i,
        /Failed to create WebGL2RenderingContext/i,
        /WEBGL_debug_renderer_info/i,
        /ANGLE flag/i,
        /swiftshader/i,
      ];
      return !webglHeadlessPatterns.some((p) => p.test(error));
    });

    // Verify no actual application errors
    expect(filteredErrors).toHaveLength(0);

    // Log warnings (non-failing)
    if (warnings.length > 0) {
      console.warn('Warnings:', warnings);
    }
  });
});
```

**Shader errors should NOT be filtered** - they indicate actual bugs:

```typescript
// These patterns indicate REAL shader compilation errors
const shaderErrorPatterns = [
  /THREE\.WebGLProgram/i,
  /shader error/i,
  /program info log/i,
  /WEBGL_WARNING/i, // But not WEBGL_debug_renderer_info
];

// Do NOT filter these - they indicate bugs in shader code
```

## Page Object Model

**All E2E tests MUST use Page Objects from `tests/pages/`**

The Page Object Model provides:

- Single source of truth for selectors
- Reusable code across E2E tests and MCP agents
- Easier maintenance when UI changes

### Available Page Objects

```typescript
// tests/pages/base.page.ts - Base class with common methods
import { BasePage } from '@/pages/base.page';

// tests/pages/game.page.ts - Game-specific interactions
import { GamePage } from '@/pages/game.page';

// tests/pages/multiplayer.page.ts - Multi-client testing
import { MultiplayerPage } from '@/pages/multiplayer.page';
```

### Usage Examples

```typescript
import { test, expect } from '@playwright/test';
import { GamePage } from '@/pages/game.page';
import { MultiplayerPage } from '@/pages/multiplayer.page';

test('should select character and reach lobby', async ({ page }) => {
  const gamePage = new GamePage(page);

  await gamePage.goto();
  await gamePage.selectCharacter('TestPlayer');
  await gamePage.waitForLobby();

  // Verify connection
  expect(await gamePage.isConnected()).toBe(true);
});

test('should connect 2 players simultaneously', async ({ browser }) => {
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

### Benefits

1. **Single source of truth** - Selectors defined in one place
2. **Reusable across E2E tests and MCP agents** - MCP agents use same selectors
3. **Easier maintenance** - UI changes only need updates in page objects
4. **Test isolation** - Each test gets fresh page object instance

## Multi-Client Test Helpers

Use `MultiplayerPage` from `tests/pages/multiplayer.page.ts` for multi-client testing:

```typescript
import { MultiplayerPage } from '@/pages/multiplayer.page';
import type { TestPlayer } from '@/pages/multiplayer.page';

test('should connect 2 clients', async ({ browser }) => {
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

The `MultiplayerPage` class provides:

- `setupMultiPlayerTest(browser, count)` - Create browser contexts
- `connectPlayersToGame(players)` - Connect players to lobby
- `verifyAllConnected(players)` - Check all players connected
- `cleanupPlayers(players)` - Close contexts (always in finally block)

## Visual Regression Testing

```typescript
test.describe('Visual Tests', () => {
  test('should match screenshot', async ({ page }) => {
    await page.goto('http://localhost:3000');

    // Wait for rendering to complete
    await page.waitForLoadState('networkidle');

    // Take screenshot and compare
    await expect(page).toHaveScreenshot('home-page.png', {
      maxDiffPixels: 100,
    });
  });

  test('should match component screenshot', async ({ page }) => {
    await page.goto('http://localhost:3000');

    const button = page.getByRole('button', { name: 'Play' });

    await expect(button).toHaveScreenshot('play-button.png');
  });
});
```

## Accessibility Testing

Based on [Playwright Accessibility Testing](https://playwright.dev/docs/accessibility-testing) documentation.

### Color Mode / Color Blind Accessibility Testing

For features like P1-005 (Color Blind Modes), test that:

- All color modes are selectable
- Pattern overlays work as primary differentiator
- WCAG contrast ratios are displayed
- UI is navigable with keyboard
- Proper ARIA labels exist

```typescript
test.describe('Accessibility - Color Modes (P1-005)', () => {
  test.beforeEach(async ({ page }) => {
    // Clear localStorage to reset first launch state
    await page.goto('http://localhost:3000');
    await page.evaluate(() => {
      localStorage.clear();
    });
    await page.reload();
  });

  test('should show AccessibilityDetector on first launch', async ({ page }) => {
    await page.goto('http://localhost:3000');

    // AccessibilityDetector overlay should appear
    await expect(page.locator('.accessibility-detector-overlay')).toBeVisible();
    await expect(page.getByText('Color Accessibility Setup')).toBeVisible();
  });

  test('should show all 5 color modes in settings', async ({ page }) => {
    await page.goto('http://localhost:3000');

    // Skip accessibility detector for this test
    await page.evaluate(() => {
      localStorage.setItem(
        'project-chroma-accessibility',
        JSON.stringify({
          hasCompletedFirstLaunch: true,
        })
      );
    });
    await page.reload();

    // Navigate to lobby (should be at character selection)
    const atCharSelection = await page.getByText('Choose Your Character').isVisible();
    if (atCharSelection) {
      await page.fill('#characterName', 'TestPlayer');
      await page.locator('button:has-text("Select Character")').first().click();
      await page.waitForURL('**/lobby', { timeout: 10000 });
    }

    // Open Color Settings from Lobby
    const colorSettingsButton = page.getByRole('button', { name: /color settings/i });
    await colorSettingsButton.click();

    // Verify all 5 color modes are visible
    await expect(page.getByText('Default')).toBeVisible();
    await expect(page.getByText('Protanopia')).toBeVisible();
    await expect(page.getByText('Deuteranopia')).toBeVisible();
    await expect(page.getByText('Tritanopia')).toBeVisible();
    await expect(page.getByText('High Contrast')).toBeVisible();
  });

  test('should display WCAG contrast ratios for each mode', async ({ page }) => {
    await page.goto('http://localhost:3000');

    // Skip to lobby
    await page.evaluate(() => {
      localStorage.setItem(
        'project-chroma-accessibility',
        JSON.stringify({
          hasCompletedFirstLaunch: true,
        })
      );
    });
    await page.reload();

    // Open Color Settings
    const colorSettingsButton = page.getByRole('button', { name: /color settings/i });
    await colorSettingsButton.click();

    // Check for WCAG compliance badges
    await expect(page.getByText('WCAG AA')).toBeVisible();

    // Check for contrast ratio displays (format: "O: 4.5:1", "B: 4.5:1")
    await expect(page.locator('text=/O:\\s*\\d+:\\d+/')).toBeVisible();
    await expect(page.locator('text=/B:\\s*\\d+:\\d+/')).toBeVisible();
  });

  test('should allow selecting different color modes', async ({ page }) => {
    await page.goto('http://localhost:3000');

    // Skip to lobby
    await page.evaluate(() => {
      localStorage.setItem(
        'project-chroma-accessibility',
        JSON.stringify({
          hasCompletedFirstLaunch: true,
        })
      );
    });
    await page.reload();

    // Open Color Settings
    const colorSettingsButton = page.getByRole('button', { name: /color settings/i });
    await colorSettingsButton.click();

    // Select Protanopia mode
    await page.getByRole('button', { name: /Protanopia.*Red-Blind/i }).click();

    // Verify mode is selected (check localStorage or UI state)
    const currentMode = await page.evaluate(() => {
      const data = localStorage.getItem('project-chroma-accessibility');
      if (!data) return null;
      const parsed = JSON.parse(data);
      return parsed.colorMode;
    });
    expect(currentMode).toBe('protanopia');
  });

  test('should show pattern controls for accessibility', async ({ page }) => {
    await page.goto('http://localhost:3000');

    // Skip to lobby
    await page.evaluate(() => {
      localStorage.setItem(
        'project-chroma-accessibility',
        JSON.stringify({
          hasCompletedFirstLaunch: true,
        })
      );
    });
    await page.reload();

    // Open Color Settings
    const colorSettingsButton = page.getByRole('button', { name: /color settings/i });
    await colorSettingsButton.click();

    // Verify Pattern Overlays section exists
    await expect(page.getByText('Pattern Overlays')).toBeVisible();
    await expect(page.getByText('Always Show Patterns')).toBeVisible();

    // Verify pattern opacity slider
    await expect(page.getByLabel('Pattern Opacity')).toBeVisible();
  });

  test('should be keyboard navigable', async ({ page }) => {
    await page.goto('http://localhost:3000');

    // Skip to lobby
    await page.evaluate(() => {
      localStorage.setItem(
        'project-chroma-accessibility',
        JSON.stringify({
          hasCompletedFirstLaunch: true,
        })
      );
    });
    await page.reload();

    // Open Color Settings with keyboard
    const colorSettingsButton = page.getByRole('button', { name: /color settings/i });
    await colorSettingsButton.focus();
    await page.keyboard.press('Enter');

    // Tab through color mode options
    await page.keyboard.press('Tab');
    await page.keyboard.press('Tab');

    // Verify focus is on a color mode option
    const focusedElement = await page.evaluate(() => {
      return document.activeElement?.className?.includes('color-mode-option') || false;
    });
    expect(focusedElement).toBe(true);
  });

  test('should have proper ARIA labels', async ({ page }) => {
    await page.goto('http://localhost:3000');

    // Skip to lobby
    await page.evaluate(() => {
      localStorage.setItem(
        'project-chroma-accessibility',
        JSON.stringify({
          hasCompletedFirstLaunch: true,
        })
      );
    });
    await page.reload();

    // Open Color Settings
    const colorSettingsButton = page.getByRole('button', { name: /color settings/i });
    await colorSettingsButton.click();

    // Check for ARIA attributes
    const hasAriaLabels = await page.evaluate(() => {
      const settings = document.querySelector('.color-settings');
      if (!settings) return false;

      // Check for aria-label on color mode buttons
      const colorButtons = settings.querySelectorAll('.color-mode-option[aria-label]');
      if (colorButtons.length === 0) return false;

      // Check for aria-pressed on selected mode
      const selectedMode = settings.querySelector('.color-mode-option[aria-pressed="true"]');
      if (!selectedMode) return false;

      return true;
    });

    expect(hasAriaLabels).toBe(true);
  });
});
```

### Using @axe-core/playwright for WCAG Validation

For comprehensive accessibility testing, install and use axe-core:

```bash
npm install --save-dev @axe-core/playwright
```

```typescript
import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

test.describe('Accessibility - WCAG Compliance', () => {
  test('should not have WCAG AA violations', async ({ page }) => {
    await page.goto('http://localhost:3000');

    const accessibilityScanResults = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa'])
      .analyze();

    expect(accessibilityScanResults.violations).toEqual([]);
  });

  test('should have no color contrast violations', async ({ page }) => {
    await page.goto('http://localhost:3000');

    const accessibilityScanResults = await new AxeBuilder({ page })
      .include('.color-settings')
      .analyze();

    // Filter for color-contrast violations
    const contrastViolations = accessibilityScanResults.violations.filter(
      (v) => v.id === 'color-contrast'
    );

    expect(contrastViolations).toEqual([]);
  });
});
```

### Screenshot-based Visual Testing for Color Modes

```typescript
test.describe('Visual - Color Modes', () => {
  const colorModes = ['default', 'protanopia', 'deuteranopia', 'tritanopia', 'high_contrast'];

  colorModes.forEach((mode) => {
    test(`should render ${mode} color mode correctly`, async ({ page }) => {
      // Set color mode in localStorage
      await page.goto('http://localhost:3000');
      await page.evaluate((m) => {
        localStorage.setItem(
          'project-chroma-accessibility',
          JSON.stringify({
            hasCompletedFirstLaunch: true,
            colorMode: m,
          })
        );
      }, mode);
      await page.reload();

      // Navigate to lobby
      await page.fill('#characterName', 'TestPlayer');
      await page.locator('button:has-text("Select Character")').first().click();
      await page.waitForURL('**/lobby', { timeout: 10000 });

      // Wait for rendering
      await page.waitForLoadState('networkidle');

      // Take screenshot for visual comparison
      await expect(page).toHaveScreenshot(`lobby-${mode}.png`, {
        maxDiffPixels: 100,
      });
    });
  });
});
```

## Network Request Testing

```typescript
test.describe('Network Tests', () => {
  test('should connect to websocket server', async ({ page }) => {
    // Track WebSocket connections
    const wsConnections: string[] = [];

    page.on('websocket', (ws) => {
      wsConnections.push(ws.url());
    });

    await page.goto('http://localhost:3000');
    await page.getByRole('button', { name: 'Select Character' }).click();

    // Verify WebSocket connection
    expect(wsConnections.some((url) => url.includes('2567'))).toBe(true);
  });

  test('should handle network error gracefully', async ({ page }) => {
    // Simulate network failure
    await page.route('**/api/**', (route) => route.abort());

    await page.goto('http://localhost:3000');

    // Verify error message shown
    await expect(page.getByRole('alert')).toContainText('connection failed');
  });
});
```

## Test Organization

### Group Related Tests

```typescript
test.describe('Authentication Flow', () => {
  test.describe('Character Selection', () => {
    test('should show character selection screen', async ({ page }) => {});
    test('should validate character name', async ({ page }) => {});
    test('should proceed to lobby on submit', async ({ page }) => {});
  });

  test.describe('Lobby', () => {
    test('should show connected players', async ({ page }) => {});
    test('should allow starting game', async ({ page }) => {});
  });
});
```

### Test Timeout Configuration

```typescript
test.describe('Long Running Tests', () => {
  test.describe.configure({ timeout: 60000 }); // 60 seconds

  test('should complete full gameplay loop', async ({ page }) => {
    // Longer test that needs more time
  });
});
```

## State Management Testing (Zustand)

For architectural tasks involving state management (Zustand stores), test state updates and reactivity:

```typescript
test.describe('Zustand Store Tests', () => {
  test('should update state and trigger re-renders', async ({ page }) => {
    await page.goto('http://localhost:3000');

    // Check initial state
    const initialState = await page.evaluate(() => {
      return (window as any).__ZUSTAND__?.connectionStore?.getState() ?? {};
    });

    expect(initialState.connected).toBe(false);

    // Trigger state update (connect button, etc.)
    await page.getByRole('button', { name: 'Connect' }).click();

    // Verify state changed
    const updatedState = await page.evaluate(() => {
      return (window as any).__ZUSTAND__?.connectionStore?.getState() ?? {};
    });

    expect(updatedState.connected).toBe(true);
  });
});
```

### Exposing Zustand Store for Testing

```typescript
// In development, expose stores to window object
if (import.meta.env.DEV) {
  (window as any).__ZUSTAND__ = {
    connectionStore: useConnectionStore,
    playerStore: usePlayerStore,
    matchStore: useMatchStore,
    uiStore: useUIStore,
  };
}
```

## Architectural Task Testing

For foundational architectural tasks (like arch-001 Canvas setup):

| Component      | What to Test                     | Test Pattern               |
| -------------- | -------------------------------- | -------------------------- |
| R3F Canvas     | Renders, has lighting, no errors | WebGL context verification |
| Component tree | Renders without crashes          | Error boundary testing     |
| State stores   | Create, update, DevTools access  | Store exposure pattern     |
| Build system   | Type-check, lint pass            | Run during validation      |

### Minimal Coverage for Simple Architectural Tasks

```typescript
test.describe('Architectural - Canvas Setup (arch-001)', () => {
  test('should render Canvas element', async ({ page }) => {
    await page.goto('http://localhost:3000');
    const canvas = page.locator('canvas');
    await expect(canvas).toBeVisible();
  });

  test('should initialize WebGL context', async ({ page }) => {
    await page.goto('http://localhost:3000');
    await page.locator('canvas[data-ready="1"]').waitFor();

    const hasWebGL = await page.evaluate(() => {
      const canvas = document.querySelector('canvas');
      const gl = canvas?.getContext('webgl2') || canvas?.getContext('webgl');
      return gl !== null;
    });

    expect(hasWebGL).toBe(true);
  });

  test('should have no console errors', async ({ page }) => {
    const errors: string[] = [];
    page.on('console', (msg) => {
      if (msg.type() === 'error') errors.push(msg.text());
    });

    await page.goto('http://localhost:3000');
    await page.waitForTimeout(2000); // Allow for async errors

    const filteredErrors = errors.filter(
      (e) => !/WEBGL_debug_renderer_info|WEBGL2RenderingContext/i.test(e)
    );

    expect(filteredErrors).toHaveLength(0);
  });
});
```
