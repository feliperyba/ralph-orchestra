---
name: qa-game-testing
description: E2E gameplay testing patterns using Playwright API. Tests continuous movement, mouse control, and complete gameplay loops. Use when validating game controls, combat mechanics, and player interactions.
---

# Gameplay Testing with E2E Tests

> "Game controls must be tested with continuous input patterns, not single keypresses."

## When to Use

Use for **every game feature validation**:
- Character movement (WASD, arrow keys)
- Mouse aiming and interaction
- Combat mechanics and combos
- Special actions (jump, crouch, interact)
- UI navigation (menus, inventory, map)
- Complete gameplay loops

---

## Pattern Library

**See [tests/helpers/gameplay-patterns.ts](tests/helpers/gameplay-patterns.ts) for complete implementation.**

Quick reference of available helpers:

| Helper | Purpose |
|--------|---------|
| `moveForward()`, `moveBackward()`, `strafeLeft()`, `strafeRight()` | Continuous movement |
| `sprintForward()`, `crouchMove()` | Modified movement |
| `moveDiagonal()` | Multi-key movement |
| `aimAt()`, `leftClick()`, `rightClick()` | Mouse control |
| `jump()`, `sprintJump()`, `interact()` | Special actions |
| `executeCombo()` | Combo sequences |
| `getPlayerPosition()`, `getPlayerState()` | State getters |
| `measureFPS()` | Performance monitoring |
| `testFullMovementLoop()` | Complete movement test |
| `focusGame()` | Test setup |

---

## Core Principle: Write Test Code, Don't Use MCP

**❌ OLD (Do NOT do this):**
```typescript
mcp__playwright__browser_navigate('http://localhost:3000');
mcp__playwright__browser_press_key({ key: 'KeyW' });
```

**✅ NEW (Do this):**
```typescript
test('player can move forward', async ({ page }) => {
  await focusGame(page);
  await moveForward(page, 1000);
  const position = await getPlayerPosition(page);
  expect(position.z).not.toBe(0);
});
```

---

<examples>

## Example Tests

### Example 1: Basic WASD Movement

```typescript
import { test, expect } from '@playwright/test';
import { moveForward, strafeLeft, getPlayerPosition, focusGame } from '@/helpers/gameplay-patterns';

test.describe('WASD Movement', () => {
  test('should move forward', async ({ page }) => {
    await focusGame(page);

    const initialPos = await getPlayerPosition(page);
    await moveForward(page, 1000);
    const afterPos = await getPlayerPosition(page);

    expect(afterPos.z).toBeLessThan(initialPos.z); // Moved forward (negative Z)
  });

  test('should strafe left', async ({ page }) => {
    await focusGame(page);

    const initialPos = await getPlayerPosition(page);
    await strafeLeft(page, 1000);
    const afterPos = await getPlayerPosition(page);

    expect(afterPos.x).toBeLessThan(initialPos.x); // Moved left
  });
});
```

### Example 2: Mouse Aiming and Shooting

```typescript
import { test, expect } from '@playwright/test';
import { aimAt, leftClick, getPlayerState, focusGame } from '@/helpers/gameplay-patterns';

test.describe('Mouse Combat', () => {
  test('should aim with mouse movement', async ({ page }) => {
    await focusGame(page);

    const initialRotation = await page.evaluate(() =>
      (window as any).cameraRotation?.y || 0
    );

    await aimAt(page, 500, 300);

    const afterRotation = await page.evaluate(() =>
      (window as any).cameraRotation?.y || 0
    );

    expect(afterRotation).not.toBe(initialRotation);
  });

  test('should shoot on left click', async ({ page }) => {
    await focusGame(page);

    const initialAmmo = await getPlayerState(page).then(s => s.ammo || 30);
    await leftClick(page, 400, 300);
    const afterAmmo = await getPlayerState(page).then(s => s.ammo || 30);

    expect(afterAmmo).toBeLessThan(initialAmmo);
  });
});
```

### Example 3: Combo Sequence

```typescript
import { test, expect } from '@playwright/test';
import { executeCombo, getPlayerState, focusGame } from '@/helpers/gameplay-patterns';

test.describe('Combat Combos', () => {
  test('should execute three-hit combo', async ({ page }) => {
    await focusGame(page);

    // Light, Light, Heavy combo
    await executeCombo(page, [
      { key: 'KeyJ', hold: 100 },
      { key: 'KeyJ', hold: 100, delayAfter: 50 },
      { key: 'KeyK', hold: 200 }
    ]);

    const comboCount = await getPlayerState(page).then(s => s.comboCount || 0);
    expect(comboCount).toBeGreaterThanOrEqual(3);
  });
});
```

</examples>

---

## Continuous Movement Pattern

**Critical:** Single `press()` only simulates a quick tap. Use `down()` + `waitForTimeout()` + `up()` for continuous movement.

```typescript
// ❌ Single tap - doesn't test gameplay
await page.keyboard.press('KeyW');

// ✅ Continuous movement - tests actual gameplay
await page.keyboard.down('KeyW');
await page.waitForTimeout(1000);
await page.keyboard.up('KeyW');
```

---

<details>
<summary>Additional Test Patterns Reference</summary>

### Diagonal Movement

```typescript
test('diagonal movement', async ({ page }) => {
  await focusGame(page);
  await page.keyboard.down('KeyW');
  await page.keyboard.down('KeyD');
  await page.waitForTimeout(1000);
  await page.keyboard.up('KeyD');
  await page.keyboard.up('KeyW');
});
```

### Sprint Movement

```typescript
test('sprint forward', async ({ page }) => {
  await focusGame(page);
  await page.keyboard.down('ShiftLeft');
  await page.keyboard.down('KeyW');
  await page.waitForTimeout(1000);
  await page.keyboard.up('KeyW');
  await page.keyboard.up('ShiftLeft');
});
```

### Jump Actions

```typescript
test('jump on space', async ({ page }) => {
  await focusGame(page);
  const initialY = await page.evaluate(() => (window as any).playerPosition?.y || 0);
  await page.keyboard.press('Space');
  await page.waitForTimeout(500);
  const peakY = await page.evaluate(() => (window as any).playerPosition?.y || 0);
  expect(peakY).toBeGreaterThan(initialY);
});
```

### Menu Keys

```typescript
test('pause on escape', async ({ page }) => {
  await focusGame(page);
  await page.keyboard.press('Escape');
  const isPaused = await page.evaluate(() => (window as any).gameState?.paused || false);
  expect(isPaused).toBe(true);
});
```

### Charged Attack

```typescript
test('charged attack', async ({ page }) => {
  await focusGame(page);
  await page.mouse.down({ button: 'left' });
  await page.waitForTimeout(1000); // Hold to charge
  await page.mouse.up({ button: 'left' });
  const attackType = await page.evaluate(() => (window as any).lastAttackType || 'none');
  expect(attackType).toBe('charged');
});
```

</details>

---

## Testing Checklist

For each gameplay feature:

- [ ] Movement works in all 4 directions (WASD)
- [ ] Diagonal movement works correctly
- [ ] Sprint affects movement speed
- [ ] Jump/Space key triggers correct action
- [ ] Mouse aiming responds correctly
- [ ] Left click performs primary action
- [ ] Right click performs secondary action (if applicable)
- [ ] Interact key (E/F) works with objects
- [ ] Menu keys (Escape, Tab, I, M) open correct UI
- [ ] Combo sequences execute in order
- [ ] No input lag or delayed response
- [ ] Multiple keys can be pressed simultaneously

---

## Running Gameplay Tests

```bash
# Run all gameplay tests
npm run test:e2e -- tests/e2e/gameplay-suite.spec.ts

# Run specific test
npm run test:e2e -- -g "should move forward"

# Run in headed mode to see gameplay
npm run test:e2e -- --headed

# Run with debug mode
npm run test:e2e -- --debug
```

---

## References

- **[tests/helpers/gameplay-patterns.ts](tests/helpers/gameplay-patterns.ts)** - Helper functions
- **[qa-e2e-test-creation/SKILL.md](../qa-e2e-test-creation/SKILL.md)** - Full E2E patterns
- [Playwright Keyboard API](https://playwright.dev/docs/api/class-keyboard)
- [Playwright Mouse API](https://playwright.dev/docs/api/class-mouse)
