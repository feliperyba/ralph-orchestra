---
name: colyseus-client
description: Colyseus client SDK for React, connection methods, room events, and messaging. Use when connecting to multiplayer server.
---

# Colyseus Client SDK

Connect to Colyseus server from React applications with colyseus.js.

## When to Use

Use when:
- Connecting to game server from client
- Handling room state changes
- Sending/receiving messages
- Managing room lifecycle

## Basic Connection

```typescript
import { Client, Room } from 'colyseus.js';

const client = new Client('ws://localhost:2567');

async function joinGame() {
  try {
    const room = await client.joinOrCreate('game_room', {});

    room.onStateChange((state) => {
      console.log('New state:', state);
    });

    room.onMessage('game_event', (data) => {
      console.log('Received:', data);
    });

    room.onLeave((code) => {
      console.log('Left room:', code);
    });
  } catch (e) {
    console.error('Join error:', e);
  }
}
```

## Connection Methods

```typescript
// Join existing or create new
const room = await client.joinOrCreate('room_name', { options: 'value' });

// Create new (fails if exists)
const room = await client.create('room_name', { options: 'value' });

// Join existing only (fails if full/not found)
const room = await client.join('room_name', { options: 'value' });

// Join by specific room ID
const room = await client.joinById('room_id_here', { options: 'value' });

// Reconnect to previous room
const room = await client.reconnect(reconnectionToken);

// Consume seat reservation
const room = await client.consumeSeatReservation(reservation);
```

## React Integration

```tsx
import { useEffect, useRef, useState } from 'react';
import { Client, Room } from 'colyseus.js';

const client = new Client('ws://localhost:2567');

function GameRoom() {
  const roomRef = useRef<Room>();
  const [isConnecting, setIsConnecting] = useState(true);
  const [players, setPlayers] = useState([]);

  useEffect(() => {
    const req = client.joinOrCreate('my_room', {});

    req.then((room) => {
      roomRef.current = room;
      setIsConnecting(false);

      room.onStateChange((state) => setPlayers(state.players.toJSON()));
    });

    return () => {
      req.then((room) => room.leave());
    };
  }, []);

  return (
    <div>
      {isConnecting ? 'Connecting...' :
        players.map((player) => (
          <div key={player.id}>{player.name}</div>
        ))
      }
    </div>
  );
}
```

## Room Methods

```typescript
// Properties
room.state        // Current room state (Schema instance)
room.sessionId    // Unique client identifier
room.id           // Room identifier (shareable)
room.name         // Room handler name

// Send message to server
room.send('message_type', { data: 'value' });

// Send raw bytes
room.sendBytes(0, [0x01, 0x02, 0x03]);

// Leave room
room.leave();              // Consented leave
room.leave(false);         // Forced leave

// Remove all listeners
room.removeAllListeners();
```

## Room Events

```typescript
// Message events
room.onMessage('message_type', (data) => {
  console.log('Received:', data);
});

// State change events
room.onStateChange((state) => {
  console.log('State updated:', state.toJSON());
});

// One-time state change (first state only)
room.onStateChange.once((state) => {
  console.log('Initial state:', state);
});

// Leave event
room.onLeave((code) => {
  console.log('Left room with code:', code);
  // 1000 = normal shutdown
  // 4000-4999 = custom codes
});

// Error event
room.onError((code, message) => {
  console.error('Room error:', code, message);
});
```

## HTTP Requests

```typescript
// GET request
client.http.get('/api/endpoint').then(response => {
  console.log(response.data);
});

// POST request
client.http.post('/api/endpoint', { body: 'data' }).then(response => {
  console.log(response.data);
});

// PUT request
client.http.put('/api/endpoint', { body: 'data' }).then(response => {
  console.log(response.data);
});

// DELETE request
client.http.delete('/api/endpoint').then(response => {
  console.log(response.data);
});
```

## React Context Provider Pattern

```tsx
// RoomContext.tsx
import React, { createContext, useContext, useState, useEffect } from 'react';
import { Client, Room } from 'colyseus.js';

interface RoomContextType {
  room: Room | null;
  state: any;
  isConnected: boolean;
  join: () => void;
}

export const RoomContext = createContext<RoomContextType>({} as RoomContextType);

export function useRoom() {
  return useContext(RoomContext);
}

export function RoomProvider({ children }: { children: React.ReactNode }) {
  const [room, setRoom] = useState<Room | null>(null);
  const [state, setState] = useState<any>(null);
  const [isConnected, setIsConnected] = useState(false);

  const join = async () => {
    try {
      const client = new Client('ws://localhost:2567');
      const joinedRoom = await client.joinOrCreate('game_room');

      setRoom(joinedRoom);
      setIsConnected(true);

      joinedRoom.onStateChange((newState) => {
        setState(newState.toJSON());
      });

      joinedRoom.onLeave(() => {
        setIsConnected(false);
        setRoom(null);
      });
    } catch (e) {
      console.error('Failed to join:', e);
    }
  };

  return (
    <RoomContext.Provider value={{ room, state, isConnected, join }}>
      {children}
    </RoomContext.Provider>
  );
}
```

## Authentication

```typescript
// Anonymous sign-in
client.auth.signInAnonymously()
  .then((response) => {
    console.log('Authenticated:', response.user);
  })
  .catch((error) => {
    console.error('Auth error:', error);
  });

// Listen to auth changes
client.auth.onChange((authData) => {
  if (authData.token) {
    console.log('User logged in:', authData.user);
  } else {
    console.log('User logged out');
  }
});

// Auth tokens sent automatically with HTTP requests
client.http.get('/profile').then(response => {
  // Authorization header included
});
```

## Best Practices

1. **Leave room on unmount** - Prevent memory leaks
2. **Handle errors** - Network failures are common
3. **Use reconnection tokens** - For seamless reconnection
4. **Send inputs, not positions** - Server-authoritative
5. **Handle state changes** - Use schema callbacks for updates
6. **Validate server responses** - Don't blindly trust server data
7. **Secure WebSocket endpoints** - Use WSS in production
8. **Store tokens securely** - Use httpOnly cookies or secure storage

## Security Considerations

### Secure WebSocket Connection

**CRITICAL**: Always use WSS (WebSocket Secure) in production. Never send sensitive data over plain WS.

```typescript
// ❌ WRONG - Plain WebSocket (insecure)
const client = new Client('ws://localhost:2567');

// ✅ RIGHT - Secure WebSocket
const client = new Client('wss://your-game-server.com');

// Environment-based configuration
const wsUrl = process.env.NODE_ENV === 'production'
  ? 'wss://your-game-server.com'
  : 'ws://localhost:2567';

const client = new Client(wsUrl);
```

### Token Storage Security

Store authentication tokens securely, never in plain localStorage.

```typescript
// ❌ WRONG - Stored in plain localStorage (vulnerable to XSS)
localStorage.setItem('authToken', token);

// ✅ RIGHT - Use httpOnly cookie (set by server)
// Token automatically sent with requests, not accessible to JS

// ✅ ACCEPTABLE - Use secure sessionStorage for session-only tokens
sessionStorage.setItem('authToken', token);
// Cleared when browser tab closes

// ✅ BEST - Backend-for-frontend pattern
// Token never exposed to client at all
async function joinGame() {
  // Server validates session server-side
  const room = await client.joinOrCreate('game_room', {
    sessionId: await getServerSessionId()
  });
}
```

### Input Sanitization Before Sending

While server validation is critical, client-side sanitization prevents accidental issues.

```typescript
function sendMessage(room: Room, type: string, data: any) {
  // Sanitize data before sending
  const sanitized = {
    type,
    // Ensure strings are length-limited
    message: sanitizeString(data.message, 200),
    // Ensure numbers are within valid ranges
    x: sanitizeNumber(data.x, -1000, 1000, 0),
    y: sanitizeNumber(data.y, -1000, 1000, 0),
    // Ensure booleans
    flag: Boolean(data.flag),
  };

  room.send(type, sanitized);
}

function sanitizeString(input: any, maxLength: number): string {
  if (typeof input !== 'string') return '';
  return input.slice(0, maxLength).trim();
}

function sanitizeNumber(input: any, min: number, max: number, defaultVal: number): number {
  const num = Number(input);
  if (isNaN(num)) return defaultVal;
  return Math.max(min, Math.min(max, num));
}
```

### Handling Server Errors

Always handle server errors gracefully - they may indicate security issues.

```typescript
room.onError((code, message) => {
  // Security-related error codes
  if (code === 4001) {
    // Unauthorized - token invalid or expired
    console.error('Authentication failed');
    redirectToLogin();
  } else if (code === 4003) {
    // Kicked by server
    showMessage('You were removed from the game');
  } else if (code >= 4000 && code < 5000) {
    // Custom server errors - may indicate cheating detected
    console.warn(`Server error ${code}: ${message}`);
  }

  // Always clear local state on error
  clearLocalGameState();
});
```

### Message Rate Limiting (Client-Side)

Prevent accidental spam from buggy client code.

```typescript
class RateLimitedSender {
  private lastSend = 0;
  private sendCount = 0;
  private readonly maxPerSecond = 30;
  private readonly minInterval = 33; // ~30fps max

  send(room: Room, type: string, data: any) {
    const now = Date.now();

    // Rate limiting
    if (now - this.lastSend < this.minInterval) {
      console.warn('Message dropped - rate limit exceeded');
      return false;
    }

    // Reset counter each second
    if (now - this.lastSend > 1000) {
      this.sendCount = 0;
    }

    if (++this.sendCount > this.maxPerSecond) {
      console.warn('Message dropped - too many messages');
      return false;
    }

    this.lastSend = now;
    room.send(type, data);
    return true;
  }
}
```

### Validate Server Responses

Even server data should be validated before use.

```typescript
room.onStateChange((state) => {
  // Validate state structure
  if (!state || typeof state !== 'object') {
    console.error('Invalid state from server');
    return;
  }

  // Validate nested data
  if (state.players) {
    for (const [id, player] of state.players) {
      // Ensure player data is valid
      if (player.x < -1000 || player.x > 1000) {
        console.warn(`Invalid player position from server: ${player.x}`);
        // Use fallback or ignore
        continue;
      }
    }
  }
});
```

## Common Mistakes

| ❌ Wrong | ✅ Right |
|----------|----------|
| Not leaving room on unmount | Always `room.leave()` in cleanup |
| Using CommonJS imports | Use `import { Client } from 'colyseus.js'` |
| Client sends absolute position | Client sends input (WASD, aim) |
| Ignoring error events | Always handle `onError` |

## Reference

- [Colyseus Client Docs](https://docs.colyseus.io/client)
- [React Integration](https://docs.colyseus.io/getting-started/react)
