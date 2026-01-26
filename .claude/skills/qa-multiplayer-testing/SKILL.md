---
name: qa-multiplayer-testing
description: E2E multiplayer testing using Playwright API with multi-client browser contexts. Validates server-authoritative patterns, state synchronization, and anti-cheat measures. Use when testing multiplayer features.
---

# Multiplayer Testing with E2E Tests

> "Server-authoritative code must be validated with actual server connections using E2E tests."

## When to Use

Use for **EVERY task** marked with `serverAuthoritative: true` or `multiplayerTested: true`.

---

## Test Categories

| Category | What to Validate |
|-----------|------------------|
| **Connection** | Multiple clients connect to same room |
| **State Sync** | All clients see same server state |
| **Movement** | Client input → Server validate → All clients see result |
| **Shooting** | Client fires → Server validates → All clients see paint |
| **Spawning** | Server assigns spawn → All clients see same location |
| **Tamper Detection** | Server rejects invalid inputs |
| **Latency** | Client prediction + server reconciliation |

---

## Core Principle

**✅ CORRECT: Multi-client E2E tests**
```typescript
test('server-authoritative movement sync', async ({ browser }) => {
  const context1 = await browser.newContext();
  const context2 = await browser.newContext();
  // Test multi-client behavior...
});
```

**❌ WRONG: Playwright MCP**
```typescript
mcp__playwright__browser_navigate('http://localhost:3000');
mcp__playwright__browser_tabs({ action: 'new' });
```

---

<examples>

## Multiplayer Test Scenarios

### Scenario 1: Multi-Client Connection

```typescript
import { test, expect } from '@playwright/test';

test('two clients connect to same room', async ({ browser }) => {
  const context1 = await browser.newContext();
  const context2 = await browser.newContext();
  const page1 = await context1.newPage();
  const page2 = await context2.newPage();

  try {
    await page1.goto('http://localhost:3000');
    await page2.goto('http://localhost:3000');

    const connected1 = await page1.evaluate(() => (window as any).gameState?.connected);
    const connected2 = await page2.evaluate(() => (window as any).gameState?.connected);

    expect(connected1).toBe(true);
    expect(connected2).toBe(true);
  } finally {
    await context1.close();
    await context2.close();
  }
});
```

### Scenario 2: State Synchronization

```typescript
test('movement syncs between clients', async ({ browser }) => {
  const context1 = await browser.newContext();
  const context2 = await browser.newContext();
  const page1 = await context1.newPage();
  const page2 = await context2.newPage();

  try {
    await page1.goto('http://localhost:3000');
    await page2.goto('http://localhost:3000');

    await page1.waitForFunction(() => (window as any).gameState?.players?.size >= 2);
    await page2.waitForFunction(() => (window as any).gameState?.players?.size >= 2);

    const initialPos = await page1.evaluate(() => {
      const localId = (window as any).gameState?.localPlayerId;
      return (window as any).gameState?.players?.get(localId)?.position;
    });

    // Player 1 moves forward
    await page1.click('canvas');
    await page1.keyboard.down('KeyW');
    await page1.waitForTimeout(1000);
    await page1.keyboard.up('KeyW');

    await page1.waitForTimeout(200); // Server sync

    // Verify Player 2 sees Player 1's new position
    const remotePos = await page2.evaluate(() => {
      const players = (window as any).gameState?.players;
      for (const [id, player] of players?.entries()) {
        if (id !== (window as any).gameState?.localPlayerId) {
          return player.position;
        }
      }
    });

    expect(remotePos.z).toBeLessThan(0); // Moved forward
  } finally {
    await context1.close();
    await context2.close();
  }
});
```

### Scenario 3: Server Authority (Anti-Cheat)

```typescript
test('server validates input (anti-cheat)', async ({ browser }) => {
  const page = await browser.newPage();
  await page.goto('http://localhost:3000');

  const posBefore = await page.evaluate(() => (window as any).gameState?.localPlayer?.position);

  // Attempt to send impossible input (speed hack)
  await page.evaluate(() => {
    (window as any).networkManager?.send({
      type: 'player_input',
      input: {
        forward: true,
        speed: 999999, // Impossible speed - server should reject
      },
    });
  });

  await page.waitForTimeout(500);

  const posAfter = await page.evaluate(() => (window as any).gameState?.localPlayer?.position);

  // Position should NOT have changed dramatically
  expect(Math.abs(posAfter.x - posBefore.x)).toBeLessThan(5);
});
```

</examples>

---

<details>
<summary>Additional Test Patterns</summary>

### Shooting Synchronization

```typescript
test('shooting syncs between clients', async ({ browser }) => {
  const context1 = await browser.newContext();
  const context2 = await browser.newContext();
  const page1 = await context1.newPage();
  const page2 = await context2.newPage();

  try {
    await page1.goto('http://localhost:3000');
    await page2.goto('http://localhost:3000');

    await page1.waitForFunction(() => (window as any).gameState?.players?.size >= 2);

    // Player 1 shoots
    await page1.click('canvas');
    await page1.mouse.click(400, 300);
    await page1.waitForTimeout(100);

    // Both clients should see the paint splat
    const paintCount1 = await page1.evaluate(() => (window as any).gameState?.paintSplats?.size || 0);
    const paintCount2 = await page2.evaluate(() => (window as any).gameState?.paintSplats?.size || 0);

    expect(paintCount1).toBeGreaterThan(0);
    expect(paintCount1).toBe(paintCount2);
  } finally {
    await context1.close();
    await context2.close();
  }
});
```

### Tamper Detection (Position Hack)

```typescript
test('server rejects position hacks', async ({ browser }) => {
  const page = await browser.newPage();
  await page.goto('http://localhost:3000');

  const posBefore = await page.evaluate(() => (window as any).gameState?.localPlayer?.position);

  // Try to directly manipulate local position (client-side hack simulation)
  await page.evaluate(() => {
    const localId = (window as any).gameState?.localPlayerId;
    (window as any).gameState.players.get(localId).position = { x: 9999, y: 0, z: 9999 };
  });

  await page.waitForTimeout(500);

  // Server should have overridden the hacked position
  const posAfter = await page.evaluate(() => (window as any).gameState?.localPlayer?.position);

  expect(posAfter.x).not.toBe(9999);
  expect(Math.abs(posAfter.x - posBefore.x)).toBeLessThan(10);
});
```

### Page Object for Multiplayer Tests

```typescript
import { test, expect } from '@playwright/test';
import { MultiplayerPage } from '@/pages/multiplayer.page';

test('multiplayer state sync with page objects', async ({ browser }) => {
  const multiplayerPage = new MultiplayerPage(null);
  const players = await multiplayerPage.setupMultiPlayerTest(browser, 2);

  try {
    await multiplayerPage.connectPlayersToGame(players);
    expect(await multiplayerPage.verifyAllConnected(players)).toBe(true);

    // Player 1 moves
    await players[0].page.click('canvas');
    await players[0].page.keyboard.down('KeyW');
    await players[0].page.waitForTimeout(500);
    await players[0].page.keyboard.up('KeyW');

    // Verify sync
    const synced = await multiplayerPage.verifyStateSync(players);
    expect(synced).toBe(true);
  } finally {
    await multiplayerPage.cleanupPlayers(players);
  }
});
```

### Server-Side Integration Tests

```typescript
// server/tests/integration/room.test.ts
import { describe, it, expect, beforeEach } from 'vitest';
import { GameRoom } from '../rooms/GameRoom';
import { Client, Room } from 'colyseus';

describe('GameRoom Server Authority', () => {
  let room: GameRoom;

  beforeEach(() => {
    room = new GameRoom();
    room.onCreate({});
  });

  it('validates player input speed', () => {
    const mockClient = { sessionId: 'test-player' } as Client;
    room.onJoin(mockClient);

    const player = room.state.players.get('test-player');

    // Send input with impossible speed
    room.onMessage(mockClient, {
      type: 'player_input',
      input: { speed: 9999 },
    });

    // Position should NOT have changed dramatically
    expect(player.x).toBeCloseTo(0, 0);
  });

  it('validates shooting cooldown', () => {
    const mockClient = { sessionId: 'test-player' } as Client;
    room.onJoin(mockClient);

    const player = room.state.players.get('test-player');
    player.lastShotTime = Date.now();

    // Try to shoot again immediately
    room.onMessage(mockClient, {
      type: 'shoot',
      aim: { x: 1, y: 0, z: 0 },
    });

    // No projectile should have been created
    expect(room.projectiles?.length || 0).toBe(0);
  });
});
```

### Network Latency Simulation

```typescript
test('client prediction works with latency', async ({ browser, context }) => {
  // Simulate high latency
  await context.route('**/*', async (route) => {
    await new Promise((resolve) => setTimeout(resolve, 200));
    route.continue();
  });

  const page = await browser.newPage();
  await page.goto('http://localhost:3000');

  await page.click('canvas');

  const posBefore = await page.evaluate(() => (window as any).gameState?.localPlayer?.position);
  await page.keyboard.down('KeyW');
  await page.waitForTimeout(100);
  await page.keyboard.up('KeyW');

  const predictedPos = await page.evaluate(() => (window as any).gameState?.localPlayer?.position);

  // Local prediction should have applied
  expect(predictedPos.z).toBeLessThan(posBefore.z);
});
```

</details>

---

## Server Validation Checklist

Before running multiplayer E2E tests:

```bash
# Terminal 1: Start servers
npm run dev:all:sh
# Expected: "listening on ws://localhost:2567"
# Expected: "Local: http://localhost:3000"
```

**If server is NOT running, FAIL validation immediately.**

---

## Testing Checklist

- [ ] Server running (`npm run dev:all:sh`)
- [ ] 2+ browser contexts created in test
- [ ] All clients connect to same room
- [ ] Client input sends to server (not local state)
- [ ] Server validates input (check logs)
- [ ] Server broadcasts state updates
- [ ] All clients see synchronized state
- [ ] Tamper attempts are rejected
- [ ] No console errors on any client
- [ ] No server errors in terminal
- [ ] Cleanup: contexts closed in finally block

---

## Common Mistakes

| ❌ Wrong | ✅ Right |
|-----------|------------|
| Test with 1 browser context | Test with 2+ contexts |
| Don't check server logs | Verify server receives and processes input |
| Assume state syncs | Assert state values match across clients |
| Test local state only | Test REMOTE player state from other client |
| Ignore server validation | Test that invalid inputs are rejected |
| Don't cleanup contexts | Always close contexts in finally block |

---

## Validation Failure Criteria

**FAIL validation if:**

- Server is not running
- Clients cannot connect to same room
- State does not sync between clients within 500ms
- Server logs show no input processing
- Invalid inputs are not rejected
- Console errors on any client
- Server crashes or throws errors

---

## Running Multiplayer Tests

```bash
# Run all multiplayer tests
npm run test:e2e -- tests/e2e/multiplayer-suite.spec.ts

# Run specific test
npm run test:e2e -- -g "server-authoritative movement sync"

# Run in headed mode
npm run test:e2e -- --headed

# Run with debug mode
npm run test:e2e -- --debug
```

---

## References

- **[tests/pages/multiplayer.page.ts](tests/pages/multiplayer.page.ts)** - Multiplayer page object
- **[qa-e2e-test-creation/SKILL.md](../qa-e2e-test-creation/SKILL.md)** - Full E2E patterns
- [Colyseus Testing Guide](https://docs.colyseus.io/colyseus/server/testing/)
