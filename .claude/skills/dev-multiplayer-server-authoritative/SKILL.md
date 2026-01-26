---
name: server-authoritative
description: Server-authoritative multiplayer architecture principles. Use when designing multiplayer features.
---

# Server-Authoritative Architecture

> "All gameplay logic belongs on the server. Clients only send inputs."

## When to Use

Use for EVERY gameplay feature in a multiplayer game. Server authority is not optional for real-time multiplayer.

## Critical Architecture Principle

```
┌─────────────────────────────────────────────────────────────────┐
│                    SERVER-AUTHORITATIVE                         │
│                                                                  │
│  ┌─────────┐         ┌─────────┐         ┌─────────┐           │
│  │ Client  │         │ Client  │         │ Client  │           │
│  │   A     │         │   B     │         │   C     │           │
│  └────┬────┘         └────┬────┘         └────┬────┘           │
│       │  INPUT ONLY       │  INPUT ONLY       │  INPUT ONLY      │
│       └──────────┬────────┴──────────┬────────┘                 │
│                  │                   │                          │
│              ┌───▼───────────────────▼────┐                      │
│              │      COLYSEUS SERVER       │                      │
│              │   (SOURCE OF TRUTH)        │                      │
│              │  - Validates all inputs    │                      │
│              │  - Runs game simulation    │                      │
│              │  - Broadcasts state        │                      │
│              └───┬───────────────────┬────┘                      │
│                  │  STATE UPDATE     │                          │
│       ┌──────────┴────────┬──────────┴────────┐                 │
│       ▼                   ▼                   ▼                 │
│  ┌─────────┐         ┌─────────┐         ┌─────────┐           │
│  │ Client  │         │ Client  │         │ Client  │           │
│  │   A     │         │   B     │         │   C     │           │
│  └─────────┘         └─────────┘         └─────────┘           │
│                                                                  │
│  ✓ Anti-cheat built-in    ✗ Client-authoritative = cheatable   │
└─────────────────────────────────────────────────────────────────┘
```

## Quick Start: Server-Authoritative Player Movement

### Server Side (GameRoom.ts)

```typescript
// server/rooms/GameRoom.ts
import { Room, Client } from 'colyseus';
import { Schema, type } from '@colyseus/schema';

// 1. Define state schema (synced to clients)
class PlayerState extends Schema {
  @type('number') x = 0;
  @type('number') y = 0;
  @type('number') z = 0;
  @type('number') rotation = 0;
}

class GameRoomState extends Schema {
  @type({ map: PlayerState }) players = new MapSchema<PlayerState>();
}

export class GameRoom extends Room<GameRoomState> {
  onCreate() {
    this.setState(new GameRoomState());
    this.setSimulationInterval((dt) => this.update(dt));
  }

  onJoin(client: Client) {
    const player = new PlayerState();
    // Random spawn position
    player.x = Math.random() * 100;
    player.z = Math.random() * 100;
    this.state.players.set(client.sessionId, player);
  }

  // 2. Receive INPUT from client (not position!)
  onMessage(client: Client, data: any) {
    const player = this.state.players.get(client.sessionId);
    if (!player) return;

    switch (data.type) {
      case 'player_input':
        // Store input for simulation tick
        player.pendingInput = data.input;
        break;
    }
  }

  // 3. Server runs simulation at fixed timestep
  update(dt: number) {
    const deltaTime = dt / 1000; // Convert to seconds

    for (const [sessionId, player] of this.state.players) {
      if (!player.pendingInput) continue;

      // Apply movement SERVER-SIDE
      const speed = 10;
      const input = player.pendingInput;

      if (input.forward) player.z -= speed * deltaTime;
      if (input.backward) player.z += speed * deltaTime;
      if (input.left) player.x -= speed * deltaTime;
      if (input.right) player.x += speed * deltaTime;

      // Validate bounds (anti-cheat)
      player.x = Math.max(-50, Math.min(50, player.x));
      player.z = Math.max(-50, Math.min(50, player.z));

      player.pendingInput = null;
    }
  }

  onLeave(client: Client) {
    this.state.players.delete(client.sessionId);
  }
}
```

### Client Side (NetworkManager.ts)

```typescript
// src/services/NetworkManager.ts
import { Client } from 'colyseus.js';

class NetworkManager {
  private client: Client;
  private room: any;
  private inputSequence: number = 0;

  async connect() {
    this.client = new Client('ws://localhost:2567');
    this.room = await this.client.joinOrCreate('game_room');

    // Listen for state changes from server
    this.room.state.players.onAdd((player: any, sessionId: string) => {
      if (sessionId === this.room.sessionId) {
        // This is local player - enable prediction
        this.setupLocalPlayerPrediction();
      } else {
        // This is remote player - interpolate
        this.setupRemotePlayerInterpolation(player, sessionId);
      }
    });

    // Handle state updates
    this.room.onStateChange((state: any) => {
      // Server state updated - reconcile predictions
      this.reconcileWithServer(state);
    });
  }

  // Send INPUT only, never position
  sendInput(input: PlayerInput) {
    this.inputSequence++;
    this.room.send({
      type: 'player_input',
      input: {
        forward: input.forward,
        backward: input.backward,
        left: input.left,
        right: input.right,
        jump: input.jump,
        sequence: this.inputSequence,
      },
    });
  }
}
```

## Decision Framework

| Question                        | Answer                                         |
| ------------------------------- | ---------------------------------------------- |
| Who calculates player position? | **Server only** - client sends input (WASD)    |
| Who validates shooting?         | **Server only** - client sends aim direction   |
| Who determines score?           | **Server only** - clients just see the result  |
| Can client trust its own state? | **No** - server is source of truth             |
| What about latency?             | Client-side prediction + server reconciliation |

## Progressive Guide

### Level 1: Basic Room Setup

```typescript
// server/index.ts
import { Server } from 'colyseus';
import { WebSocketTransport } from '@colyseus/ws-transport';
import { GameRoom } from './rooms/GameRoom';

const port = Number(process.env.PORT) || 2567;

const gameServer = new Server({
  transport: new WebSocketTransport({ port }),
});

gameServer.define('game_room', GameRoom);

gameServer.listen(port);
console.log(`Colyseus server listening on ws://localhost:${port}`);
```

### Level 2: State Schema Definition

```typescript
// Always use Schema for efficient serialization
import { Schema, type, MapSchema, ArraySchema } from '@colyseus/schema';

class PlayerState extends Schema {
  @type('number') x: number = 0;
  @type('number') y: number = 0;
  @type('number') z: number = 0;
  @type('number') rotation: number = 0;
  @type('string') team: string = 'orange';
  @type('number') score: number = 0;
}

class PaintData extends Schema {
  @type('number') x: number;
  @type('number') z: number;
  @type('string') team: string;
}

class GameRoomState extends Schema {
  @type({ map: PlayerState }) players = new MapSchema<PlayerState>();
  @type([PaintData]) paintSplats = new ArraySchema<PaintData>();
  @type('number') orangeScore: number = 0;
  @type('number') blueScore: number = 0;
  @type('number') timeRemaining: number = 180;
}
```

### Level 3: Input Validation (Anti-Cheat)

```typescript
function validateInput(input: PlayerInput, player: PlayerState): boolean {
  // Sanity checks - reject impossible inputs
  if (input.movementSpeed > 20) return false; // Speed hack
  if (input.jumpHeight > 10) return false;   // Super jump hack

  // Movement constraints
  const dx = input.targetX - player.x;
  const dz = input.targetZ - player.z;
  const distance = Math.sqrt(dx * dx + dz * dz);

  // Can't move more than X meters per tick
  if (distance > 2) return false;

  return true;
}

onMessage(client: Client, data: any) {
  const player = this.state.players.get(client.sessionId);
  if (!player) return;

  if (data.type === 'player_input') {
    // VALIDATE before processing
    if (validateInput(data.input, player)) {
      player.pendingInput = data.input;
    } else {
      // Log potential cheater
      console.warn(`Suspicious input from ${client.sessionId}`);
    }
  }
}
```

### Level 4: Shooting Validation

```typescript
// Server-authoritative shooting
onMessage(client: Client, data: any) {
  if (data.type !== 'shoot') return;

  const shooter = this.state.players.get(client.sessionId);
  if (!shooter) return;

  // Validate shooter can shoot (has ammo, not on cooldown)
  if (shooter.ink <= 0) return;
  if (Date.now() - shooter.lastShotTime < 100) return; // 100ms cooldown

  // Validate aim direction is reasonable
  const aim = data.aimDirection;
  const aimLength = Math.sqrt(aim.x ** 2 + aim.y ** 2 + aim.z ** 2);
  if (aimLength > 1.0) return; // Normalized vector should be length 1

  // Server creates paint projectile
  const projectile = {
    x: shooter.x,
    y: shooter.y + 1.5, // Shoulder height
    z: shooter.z,
    dx: aim.x * 25, // 25 m/s
    dy: aim.y * 25,
    dz: aim.z * 25,
    owner: client.sessionId,
    team: shooter.team,
  };

  this.projectiles.push(projectile);
  shooter.ink -= 1;
  shooter.lastShotTime = Date.now();
}
```

### Level 5: Hit Detection with Lag Compensation

```typescript
// Server validates hits by rewinding time
function checkHit(shooter: PlayerState, targetId: string, aim: Vector3): boolean {
  const target = this.state.players.get(targetId);
  if (!target) return false;

  // Get target position at the time of shooting (lag compensation)
  const shotTime = Date.now();
  const latency = this.getClientLatency(shooter.sessionId);
  const rewindTime = shotTime - latency;

  // Find where target was at rewindTime
  const historicalPosition = this.getPositionHistory(targetId, rewindTime);
  if (!historicalPosition) return false;

  // Raycast from shooter to historical position
  return this.raycastHits(shooter, historicalPosition, aim);
}

// Store position history for lag compensation
private positionHistory: Map<string, Array<{time: number, x: number, y: number, z: number}>> = new Map();

update(dt: number) {
  const now = Date.now();

  for (const [sessionId, player] of this.state.players) {
    // Store position for lag compensation (keep last 500ms)
    if (!this.positionHistory.has(sessionId)) {
      this.positionHistory.set(sessionId, []);
    }
    const history = this.positionHistory.get(sessionId)!;
    history.push({ time: now, x: player.x, y: player.y, z: player.z });

    // Remove old entries
    while (history.length > 0 && history[0].time < now - 500) {
      history.shift();
    }
  }
}
```

## Client-Side Prediction (for responsiveness)

Client still feels responsive by predicting locally:

```typescript
// Client-side prediction
class LocalPlayerController {
  private pendingInputs: Array<{ input: PlayerInput; sequence: number }> = [];

  update(deltaTime: number) {
    // Apply input locally for immediate feedback
    const input = this.getCurrentInput();
    this.predictedPosition.x += input.forward * this.speed * deltaTime;

    // Store for reconciliation
    this.pendingInputs.push({
      input: input,
      sequence: this.nextSequence++,
    });

    // Send to server
    networkManager.sendInput(input);
  }

  // Reconcile when server state arrives
  reconcile(serverState: PlayerState) {
    // Remove confirmed inputs
    this.pendingInputs = this.pendingInputs.filter(
      (p) => p.sequence > serverState.lastProcessedSequence
    );

    // Start from server position
    let reconciledX = serverState.x;
    let reconciledZ = serverState.z;

    // Re-apply pending inputs
    for (const pending of this.pendingInputs) {
      reconciledX += pending.input.forward * 0.016; // ~60fps
      reconciledZ += pending.input.strafe * 0.016;
    }

    // Smoothly interpolate to reconciled position
    this.displayPosition.x = this.lerp(this.displayPosition.x, reconciledX, 0.3);
  }
}
```

## Testing Checklist

For EVERY gameplay feature:

- [ ] Server running (`npm run server`)
- [ ] Client connects successfully
- [ ] Feature works through network (not just locally)
- [ ] Server logs show player actions
- [ ] State updates propagate to all clients
- [ ] Inputs are validated server-side
- [ ] Impossible inputs are rejected
- [ ] No client-authoritative position updates

## Common Mistakes

| ❌ Wrong                          | ✅ Right                                 |
| --------------------------------- | ---------------------------------------- |
| Client sends absolute position    | Client sends input (WASD, aim)           |
| Client reports "I hit player X"   | Client sends aim, server validates hit   |
| Server trusts client score        | Server calculates score                  |
| `player.x = data.x` (from client) | `player.x += input.forward * speed * dt` |
| Client determines paint coverage  | Server tracks paint state                |

## Anti-Cheat Best Practices

1. **Validate all inputs** - Reject impossible values
2. **Rate limit actions** - Prevent spam exploits
3. **Track position history** - Detect teleportation
4. **Checksum game state** - Detect tampering
5. **Log suspicious activity** - For analysis/banning

## Security Considerations

### Input Validation

```typescript
// ALWAYS validate client inputs
function validateInput(input: any, player: PlayerState): boolean {
  // Range validation
  if (input.x < -100 || input.x > 100) return false;
  if (input.y < 0 || input.y > 50) return false;

  // Rate validation
  const now = Date.now();
  if (now - player.lastInputTime < 16) return false; // Max 60 inputs/sec

  // Sequence validation (prevent replay attacks)
  if (input.sequence <= player.lastSequence) return false;

  return true;
}
```

### Common Attack Vectors

| Attack | Description | Mitigation |
|--------|-------------|------------|
| **Speed hacking** | Client moves too fast | Validate max distance per tick |
| **Teleportation** | Client jumps across map | Check position history continuity |
| **Replay attacks** | Resend old input packets | Validate monotonically increasing sequence |
| **Packet flooding** | Spam server with messages | Rate limit per client |
| **State tampering** | Modify local state and sync | Server is source of truth |
| **Aimbot** | Perfect shooting accuracy | Server-side hit detection with lag comp |

### Rate Limiting Pattern

```typescript
class RateLimiter {
  private limits = new Map<string, { count: number; resetTime: number }>();

  canExecute(sessionId: string, maxPerSecond: number): boolean {
    const now = Date.now();
    const limit = this.limits.get(sessionId);

    if (!limit || now > limit.resetTime) {
      this.limits.set(sessionId, { count: 1, resetTime: now + 1000 });
      return true;
    }

    if (limit.count >= maxPerSecond) {
      return false; // Rate limit exceeded
    }

    limit.count++;
    return true;
  }
}

// Usage in room
onMessage(client: Client, data: any) {
  if (!this.rateLimiter.canExecute(client.sessionId, 60)) {
    console.warn(`Rate limit exceeded: ${client.sessionId}`);
    return; // Drop message
  }
  // Process message...
}
```

### State Integrity Protection

```typescript
// Server-side state validation
function validateGameState(state: GameRoomState): boolean {
  // Score sanity checks
  if (state.orangeScore < 0) return false;
  if (state.blueScore < 0) return false;

  // Player count validation
  if (state.players.size > this.maxPlayers) return false;

  // Time remaining validation
  if (state.timeRemaining < 0) return false;

  return true;
}

// Run periodically
setSimulationInterval((dt) => {
  this.update(dt);
  if (!validateGameState(this.state)) {
    console.error("Game state corruption detected!");
    // Recovery action: reset to last known good state
  }
});
```

### Authentication & Authorization

```typescript
// Token-based room access
onAuth(client: Client, options: any, request: any) {
  // Verify JWT token
  const token = options.token;
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    return { userId: decoded.userId, username: decoded.username };
  } catch (e) {
    throw new Error("Invalid authentication token");
  }
}

// Role-based access
onJoin(client: Client, options: any) {
  const authData = client.auth;
  if (!authData) {
    throw new Error("Not authenticated");
  }

  // Check if user has permission to join this room
  if (options.privateRoom && !authData.isPremium) {
    throw new Error("Premium membership required");
  }
}
```

### DDoS Protection

```typescript
// IP-based rate limiting for room creation
const ipRequestCount = new Map<string, { count: number; resetTime: number }>();

function allowCreateRoom(ip: string): boolean {
  const now = Date.now();
  const record = ipRequestCount.get(ip);

  if (!record || now > record.resetTime) {
    ipRequestCount.set(ip, { count: 1, resetTime: now + 60000 });
    return true;
  }

  if (record.count > 5) {
    return false; // Max 5 rooms per minute per IP
  }

  record.count++;
  return true;
}
```

## Reference

- [Colyseus Documentation](https://docs.colyseus.io/) — Official framework docs
- [Colyseus Best Practices](https://0-15-x.docs.colyseus.io/best-practices/) — Performance and architecture
- [Valve Latency Compensation](https://developer.valvesoftware.com/wiki/Latency_Compensating_Methods_in_Client/Server_In-game_Protocol_Design_and_Optimization) — Classic netcode patterns
- [Gaffer On Games - Networking](https://gafferongames.com/post/what_every_programmer_needs_to_know_about_game_networking/) — Game networking fundamentals
- `developer/multiplayer/prediction-basics.md` — Client-side prediction patterns
