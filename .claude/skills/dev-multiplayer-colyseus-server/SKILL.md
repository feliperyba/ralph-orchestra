---
name: colyseus-server
description: Colyseus server setup, room handlers, lifecycle events, and scaling. Use when setting up multiplayer server.
---

# Colyseus Server Setup

Node.js multiplayer framework - authoritative game server with real-time state sync.

## When to Use

Use when:
- Setting up Colyseus server
- Creating room handlers
- Implementing matchmaking
- Configuring server transport

## Server Setup (ESM Required)

```typescript
// server/index.ts - MUST use ESM
import { Server } from 'colyseus';
import { createServer } from 'http';
import express from 'express';
import { WebSocketTransport } from '@colyseus/ws-transport';
import { GameRoom } from './rooms/GameRoom';

const port = Number(process.env.PORT) || 2567;

const app = express();

// CORS middleware
app.use((req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  if (req.method === 'OPTIONS') {
    res.writeHead(200);
    res.end();
    return;
  }
  next();
});

const httpServer = createServer(app);

const gameServer = new Server({
  transport: new WebSocketTransport({ server: httpServer }),
});

gameServer.define('game_room', GameRoom);
gameServer.listen(port);

console.log(`Colyseus server listening on wss://localhost:${port}`);
```

**CRITICAL**: Server MUST use `"type": "module"` in package.json. Do NOT use CommonJS.

## Room Handler Definition

```typescript
import { Room, Client } from 'colyseus';
import { Schema, type, MapSchema } from '@colyseus/schema';

export class GameRoom extends Room<GameRoomState> {
  onCreate(options: any) {
    this.setState(new GameRoomState());
    console.log(`[GameRoom] Created: ${this.roomId}`);

    // Simulation tick (deltaTime in seconds)
    this.setSimulationInterval((deltaTime) => {
      this.update(deltaTime);
    });

    // One-time event
    this.clock.setTimeout(() => this.endMatch(), 5000);

    // Repeated event
    this.clock.setInterval(() => this.checkCondition(), 100);
  }

  onJoin(client: Client, options: any) {
    const player = new PlayerState();
    player.clientId = client.sessionId;
    this.state.players.set(client.sessionId, player);

    client.send('welcome', { playerId: client.sessionId });
  }

  onLeave(client: Client, consented: boolean) {
    this.state.players.delete(client.sessionId);
  }

  onMessage(client: Client, data: any) {
    switch (data.type) {
      case 'player_input':
        this.handleInput(client, data);
        break;
    }
  }

  onDispose() {
    console.log(`[GameRoom] Disposed: ${this.roomId}`);
  }
}
```

## Message Broadcasting

```typescript
// Broadcast to all clients
this.broadcast('game_event', { data: 'value' });

// Send to specific client
client.send('personal_event', { data: 'value' });

// Send to all except sender
this.broadcast('game_event', { data: 'value' }, [client.sessionId]);
```

## Server Definition Options

```typescript
// Filter rooms by options for matchmaking
gameServer
  .define('battle', BattleRoom)
  .filterBy(['mode', 'map']);

// Sort rooms for matchmaking priority
gameServer
  .define('battle', BattleRoom)
  .sortBy({ clients: -1 });  // Most players first

// Enable realtime listing
gameServer
  .define('battle', BattleRoom)
  .enableRealtimeListing();

// Listen to lifecycle events
gameServer
  .define('chat', ChatRoom)
  .on('create', (room) => console.log('Room created'))
  .on('dispose', (room) => console.log('Room disposed'))
  .on('join', (room, client) => console.log('Client joined'))
  .on('leave', (room, client) => console.log('Client left'));
```

## Transport Configuration

```typescript
import { WebSocketTransport } from '@colyseus/ws-transport';

new WebSocketTransport({
  server,                // HTTP server instance
  pingInterval: 30000,    // Ping interval (ms)
  pingMaxRetries: 3,      // Max retries before disconnect
});

// Development: simulate latency
if (process.env.NODE_ENV !== 'production') {
  gameServer.simulateLatency(200);
}
```

## Scaling with Redis

```typescript
import { Server, RedisPresence, RedisDriver } from 'colyseus';

const gameServer = new Server({
  presence: new RedisPresence(),  // Multi-process communication
  driver: new RedisDriver(),       // Room storage across processes
});
```

## Security Considerations

### Input Validation

**CRITICAL**: Never trust data from clients. Always validate server-side.

```typescript
onMessage(client: Client, data: any) {
  // Validate message structure
  if (!data || typeof data !== 'object') return;

  // Validate message type (allowlist only)
  const allowedTypes = ['player_input', 'paint_fire', 'emote'];
  if (!allowedTypes.includes(data.type)) return;

  // Validate data types
  if (data.type === 'player_input') {
    // Ensure input object exists and has expected properties
    if (!data.input || typeof data.input !== 'object') return;

    // Sanitize boolean inputs
    const input = {
      forward: Boolean(data.input?.forward),
      backward: Boolean(data.input?.backward),
      left: Boolean(data.input?.left),
      right: Boolean(data.input?.right),
      jump: Boolean(data.input?.jump),
    };

    this.handleInput(client, input);
  }
}
```

### Rate Limiting

Prevent message spam exploits that can degrade server performance.

```typescript
export class GameRoom extends Room {
  private messageCounts = new Map<string, number>();
  private lastReset = Date.now();

  onMessage(client: Client, data: any) {
    // Reset counters every second
    const now = Date.now();
    if (now - this.lastReset > 1000) {
      this.messageCounts.clear();
      this.lastReset = now;
    }

    // Count messages from this client
    const count = (this.messageCounts.get(client.sessionId) || 0) + 1;

    // Max 60 messages per second
    if (count > 60) {
      console.warn(`Rate limit exceeded: ${client.sessionId}`);
      return; // Silently drop excess messages
    }

    this.messageCounts.set(client.sessionId, count);

    // Process message...
  }
}
```

### DDoS Protection

```typescript
// Limit max connections per IP
const ipConnectionCount = new Map<string, number>();

function checkConnectionLimit(ip: string): boolean {
  const count = ipConnectionCount.get(ip) || 0;
  if (count >= 5) { // Max 5 connections per IP
    return false;
  }
  ipConnectionCount.set(ip, count + 1);
  return true;
}

// Clean up on disconnect
onLeave(client: Client) {
  const ip = client.address?.address;
  if (ip) {
    const count = Math.max(0, (ipConnectionCount.get(ip) || 0) - 1);
    ipConnectionCount.set(ip, count);
  }
}
```

### Authentication

```typescript
// Verify JWT token on join
async function verifyToken(token: string): Promise<{ userId: string } | null> {
  try {
    const decoded = await jwt.verify(token, process.env.JWT_SECRET);
    return { userId: decoded.sub };
  } catch {
    return null;
  }
}

onJoin(client: Client, options: any) {
  // Verify authentication
  if (!options.authToken) {
    client.leave(4001); // Unauthorized
    return;
  }

  const user = await verifyToken(options.authToken);
  if (!user) {
    client.leave(4001);
    return;
  }

  // Store user info for this session
  client.userData = { userId: user.userId };
}
```

### Data Sanitization

```typescript
// Sanitize strings to prevent injection attacks
function sanitizeString(input: string, maxLength: number = 100): string {
  if (typeof input !== 'string') return '';
  return input
    .slice(0, maxLength)
    .replace(/[<>]/g, ''); // Remove potential HTML
}

// Sanitize numbers to prevent overflow
function sanitizeNumber(input: any, min: number, max: number, default: number): number {
  const num = Number(input);
  if (isNaN(num)) return default;
  return Math.max(min, Math.min(max, num));
}
```

## Best Practices

1. **Always use ESM** - `"type": "module"` in package.json
2. **Validate all inputs** - Never trust client data
3. **Rate limit actions** - Prevent spam exploits
4. **Log room lifecycle** - For debugging
5. **Use Schema for state** - Efficient binary serialization
6. **Sanitize all client data** - Prevent injection attacks
7. **Implement authentication** - Verify user identity
8. **Monitor for abuse** - Track suspicious patterns

## Common Mistakes

| ❌ Wrong | ✅ Right |
|----------|----------|
| `require/module.exports` | `import/export` with `"type": "module"` |
| Server using `colyseus.js` | Server uses `colyseus` package |
| Trusting client positions | Validate all inputs server-side |

## Reference

- [Colyseus Server Docs](https://docs.colyseus.io/server)
- [Room Handlers](https://docs.colyseus.io/server/room/)
