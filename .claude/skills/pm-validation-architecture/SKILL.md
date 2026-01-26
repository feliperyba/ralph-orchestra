---
name: pm-validation-architecture
description: Detect and validate client-authoritative vs server-authoritative architecture gaps
category: pm
user-invocable: false
model: haiku
agent: pm
degrees-of-freedom: medium
---

# Architecture Validation

> "Server-authoritative code must have specific validation markers. If markers are missing, code is likely client-authoritative."

## When to Use

During retrospective synthesis when analyzing why multiplayer features may not be truly server-authoritative.

## Critical Detection Pattern

**Finding**: Tasks marked `serverAuthoritative: true` had 100% client-side implementation.

**Detection Pattern:**
1. Task marked `serverAuthoritative: true`
2. Client calculates state directly
3. Server only logs input, doesn't process
4. TODO comments exist in server code

---

## Validation Checklist

For each task marked `serverAuthoritative: true`:

### Step 1: Check Client Code

```bash
# Search for direct state manipulation (anti-pattern)
grep -r "velocity\.x = " src/components/game/player/
grep -r "position\.x += " src/components/game/player/
grep -r "rigidBody\.setVelocity" src/components/game/

# These indicate CLIENT-SIDE physics (not server-authoritative)
```

| Pattern | Indicates | Correct Pattern |
|---------|-----------|-----------------|
| `rigidBody.setVelocity()` | Client-authoritative | `networkManager.send({ type: 'input' })` |
| `position.x += input.x` | Client-authoritative | Server applies velocity |
| `if (hit) spawnDecal()` | Client-authoritative | Server confirms, then spawn |
| `score += 10` | Client-authoritative | Server calculates score |

### Step 2: Check Server Code

```bash
# Search for actual input processing (good pattern)
grep -A 10 "onMessage" server/rooms/GameRoom.ts

# Look for TODO comments (warning sign)
grep -r "TODO" server/rooms/GameRoom.ts
```

| Pattern | Indicates | Correct Pattern |
|---------|-----------|-----------------|
| `console.log(data)` only | Server not processing | Input validation + simulation |
| `TODO: Forward to ECS` | Incomplete | ECS integration complete |
| Empty message handler | Server ignores | Handler processes input |

### Step 3: Check Message Flow

```typescript
// CORRECT: Server-authoritative message flow
// Client
networkManager.send({
  type: 'player_input',
  input: { forward, backward, left, right, jump },
  sequence: inputSequence++
});

// Server
onMessage(client, data) {
  if (data.type === 'player_input') {
    const input = data.input;

    // VALIDATE
    if (!validateInput(input, player)) return;

    // PROCESS
    const velocity = calculateVelocity(input);
    player.x += velocity.x * dt;

    // BROADCAST
    this.broadcast({
      type: 'player_state',
      position: { x: player.x, z: player.z }
    });
  }
}
```

---

## Detection Commands

```bash
# Check if movement is client-authoritative
rg "rigidBody\.velocity|setVelocity|setLinvel" src/components/game/player/

# Check if shooting is client-authoritative
rg "spawnProjectile|createProjectile" src/components/game/weapons/

# Check for TODO comments indicating incomplete server implementation
rg "TODO.*server|TODO.*ECS" server/
```

---

## Architecture Gap Detection Matrix

| Feature | Client Code | Server Code | Gap? |
|---------|-------------|-------------|------|
| **Movement** | PlayerController:520-678 (direct velocity) | GameRoom:265-282 (log only) | ✗ Client-authoritative |
| **Shooting** | PaintGun:208-394 (spawn projectile) | GameRoom:287-299 (broadcast only) | ✗ Client-authoritative |
| **Score** | HUD.tsx (local calculation) | No server score tracking | ✗ Client-authoritative |

---

## Red Flags

| Symptom | Check | Result |
|---------|-------|--------|
| TODO comments in GameRoom.ts | `rg "TODO" server/rooms/GameRoom.ts` | "TODO: Forward to player entity in ECS" |
| Direct physics on client | `rg "setVelocity|velocity\.x\s*=" src/` | Client controls physics |
| No input validation on server | Check `onMessage` handlers | Only console.log |
| Server doesn't calculate state | Check server update loop | MovementSystem.ts only syncs |

---

## Decision Framework

| Question | Yes → | No → |
|----------|-------|------|
| Client sends input (WASD, aim)? | Continue | ❌ Not server-authoritative |
| Server validates input? | Continue | ❌ Client-authoritative |
| Server calculates state? | Continue | ❌ Client-authoritative |
| Server broadcasts state? | Continue | ❌ Client-authoritative |
| Server rejects invalid input? | ✓ Server-authoritative | ⚠️ Partial |

---

## Retrospective Questions

Ask Developer:

1. **Does client send input or state?**
   - Input (WASD, aim) → ✓ Correct
   - State (position, velocity) → ✗ Wrong

2. **Does server validate input?**
   - Yes (speed limits, cooldowns) → ✓ Correct
   - No (accepts all) → ✗ Wrong

3. **Does server calculate game state?**
   - Yes (physics, collisions) → ✓ Correct
   - No (client calculates) → ✗ Wrong

4. **Are there TODO comments in server code?**
   - Yes → ⚠️ Incomplete
   - No → ✓ Likely complete

---

## Anti-Patterns

| ❌ Don't | ✅ Do |
|----------|-------|
| Trust PRD `serverAuthoritative: true` without review | Code review every task |
| Assume server processes input without checking | Check for actual processing |
| Skip checking for TODO comments | TODO comments = warning signs |
| Ignore client-side state manipulation | Check client code directly |

---

## PRD Update Pattern

When gaps detected:

```json
{
  "id": "iter4-002",
  "serverAuthoritative": false,
  "revalidationRequired": true,
  "notes": "Currently 100% client-side. Needs server-authoritative implementation."
}
```

Create validation task:

```json
{
  "id": "validate-001",
  "title": "Server-Authoritative Movement Implementation",
  "acceptanceCriteria": [
    "Client sends input via NetworkManager (not velocity)",
    "Server receives input in GameRoom",
    "Server validates input (speed limits, jump cooldowns)",
    "Server calculates velocity server-side",
    "TODO at GameRoom.ts:273 resolved"
  ]
}
```

---

## Validation Script

```typescript
function validateServerAuthoritative(taskId: string) {
  const issues = [];
  let clientAuthoritative = false;

  // Check client code for direct state manipulation
  const clientFiles = globSync(`src/components/game/**/*.tsx`);
  for (const file of clientFiles) {
    const content = readFileSync(file, 'utf-8');

    if (content.includes('rigidBody.setVelocity') ||
        content.includes('velocity.x =') ||
        content.includes('position.x +=')) {
      issues.push(`${file}: Direct state manipulation`);
      clientAuthoritative = true;
    }
  }

  // Check server code
  const serverFiles = globSync(`server/**/*.ts`);
  for (const file of serverFiles) {
    const content = readFileSync(file, 'utf-8');

    if (content.includes('TODO')) {
      issues.push(`${file}: TODO comment indicates incomplete`);
      clientAuthoritative = true;
    }

    if (content.includes('console.log') && !content.includes('validate')) {
      issues.push(`${file}: Input logged but not validated`);
      clientAuthoritative = true;
    }
  }

  return { taskId, clientAuthoritative, issues };
}
```

---

## References

- [dev-multiplayer-server-authoritative](../dev-multiplayer-server-authoritative/SKILL.md) - Implementation
- [qa-multiplayer-testing](../qa-multiplayer-testing/SKILL.md) - Testing
