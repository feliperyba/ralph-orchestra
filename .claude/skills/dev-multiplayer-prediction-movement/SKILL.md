---
name: prediction-movement
description: Movement prediction with server reconciliation for WASD controls. Use when implementing player movement.
---

# Movement Prediction

WASD movement with client-side prediction and server reconciliation.

## When to Use

Use when implementing player movement in multiplayer games:
- FPS/TPS character movement
- WASD movement schemes
- Platformer movement
- Vehicle controls

## Client Implementation

```typescript
import { useRef, useEffect } from '@react-three/fiber';
import { useNetworkManager } from '../../services/NetworkManager';

interface PendingInput {
  input: PlayerInput;
  sequence: number;
  timestamp: number;
}

export function PlayerController() {
  const networkManager = useNetworkManager();
  const meshRef = useRef<RapierRigidBody>(null);

  // Prediction state
  const localStateRef = useRef({
    position: { x: 0, y: 0, z: 0 },
    velocity: { x: 0, y: 0, z: 0 },
  });

  const pendingInputsRef = useRef<PendingInput[]>([]);
  const inputSequenceRef = useRef(0);

  // Server state (for reconciliation)
  const serverStateRef = useRef({
    position: { x: 0, y: 0, z: 0 },
    lastProcessedSequence: 0,
  });

  // Listen for server state updates
  useEffect(() => {
    const unsubscribe = networkManager.onStateChange((serverState) => {
      const localPlayer = serverState.players.get(networkManager.sessionId);
      if (localPlayer) {
        reconcileWithServer(localPlayer);
      }
    });
    return unsubscribe;
  }, [networkManager]);

  // Reconcile local prediction with server state
  function reconcileWithServer(serverPlayer: any) {
    const serverState = serverStateRef.current;
    const localState = localStateRef.current;

    // Remove inputs that server has processed
    pendingInputsRef.current = pendingInputsRef.current.filter(
      p => p.sequence > serverPlayer.lastProcessedSequence
    );

    // Start from server position (authoritative)
    let reconciledPosition = { ...serverPlayer.position };

    // Re-apply all pending inputs
    for (const pending of pendingInputsRef.current) {
      reconciledPosition = applyInput(
        reconciledPosition,
        pending.input,
        0.016 // Assume ~60fps for prediction
      );
    }

    // Smoothly interpolate display to reconciled position
    const smoothingFactor = 0.3;
    localState.position.x = lerp(
      localState.position.x,
      reconciledPosition.x,
      smoothingFactor
    );
    localState.position.y = lerp(
      localState.position.y,
      reconciledPosition.y,
      smoothingFactor
    );
    localState.position.z = lerp(
      localState.position.z,
      reconciledPosition.z,
      smoothingFactor
    );
  }

  // Apply input to position (local prediction)
  function applyInput(position: Vector3, input: PlayerInput, dt: number): Vector3 {
    const speed = MOVEMENT_CONFIG.walkSpeed;
    const result = { ...position };

    if (input.forward) result.z -= speed * dt;
    if (input.backward) result.z += speed * dt;
    if (input.left) result.x -= speed * dt;
    if (input.right) result.x += speed * dt;

    return result;
  }

  // Handle input frame update
  useFrame((state, dt) => {
    const input = getCurrentInput();

    if (hasInput(input)) {
      // 1. Store for prediction
      const sequence = ++inputSequenceRef.current;
      pendingInputsRef.current.push({
        input,
        sequence,
        timestamp: Date.now(),
      });

      // 2. Apply locally (immediate feedback)
      const predictedPosition = applyInput(
        localStateRef.current.position,
        input,
        dt
      );
      localStateRef.current.position = predictedPosition;

      // Update display immediately
      if (meshRef.current) {
        meshRef.current.setTranslation(predictedPosition);
      }

      // 3. Send to server (for validation)
      networkManager.send({
        type: 'player_input',
        input,
        sequence,
      });
    }
  });

  return (
    <RigidBody ref={meshRef} colliders="ball" type="kinematicPosition">
      <mesh>
        <sphereGeometry args={[0.5]} />
        <meshStandardMaterial color="orange" />
      </mesh>
    </RigidBody>
  );
}
```

## Server Implementation

```typescript
import { Room, Client } from "colyseus";
import { Schema, type, MapSchema } from "@colyseus/schema";

class PlayerState extends Schema {
  @type("number") x = 0;
  @type("number") y = 0;
  @type("number") z = 0;
  @type("number") rotation = 0;
  @type("number") lastProcessedSequence = 0; // For reconciliation
}

export class GameRoom extends Room<GameRoomState> {
  private inputBuffers: Map<string, PlayerInput[]> = new Map();

  onCreate() {
    this.setState(new GameRoomState());
    this.setSimulationInterval((dt) => this.update(dt));
  }

  onJoin(client: Client) {
    const player = new PlayerState();
    player.x = 0;
    player.z = 0;
    this.state.players.set(client.sessionId, player);
    this.inputBuffers.set(client.sessionId, []);
  }

  onMessage(client: Client, data: any) {
    if (data.type === 'player_input') {
      const player = this.state.players.get(client.sessionId);
      if (!player) return;

      // Store input with sequence number
      this.inputBuffers.get(client.sessionId)?.push({
        ...data.input,
        sequence: data.sequence,
      });

      // Track last processed sequence for reconciliation
      player.lastProcessedSequence = data.sequence;
    }
  }

  update(dt: number) {
    const deltaTime = dt / 1000;

    for (const [sessionId, player] of this.state.players) {
      const inputs = this.inputBuffers.get(sessionId) || [];

      // Process all pending inputs
      for (const input of inputs) {
        this.processPlayerInput(player, input, deltaTime);
      }

      // Clear processed inputs
      this.inputBuffers.set(sessionId, []);
    }
  }

  processPlayerInput(player: PlayerState, input: PlayerInput, dt: number) {
    const speed = MOVEMENT_CONFIG.walkSpeed; // Must match client!

    // Apply movement SERVER-SIDE
    if (input.forward) player.z -= speed * dt;
    if (input.backward) player.z += speed * dt;
    if (input.left) player.x -= speed * dt;
    if (input.right) player.x += speed * dt;

    // Validate bounds (anti-cheat)
    player.x = Math.max(-50, Math.min(50, player.x));
    player.z = Math.max(-50, Math.min(50, player.z));

    // Server state automatically syncs to clients via Colyseus
  }
}
```

## Smoothing Function

```typescript
// Smooth correction without "snapping"
function lerp(a: number, b: number, t: number): number {
  return a + (b - a) * t;
}

function reconcilePosition(
  displayPosition: Vector3,
  serverPosition: Vector3,
  pendingInputs: PendingInput[]
): Vector3 {
  // Calculate reconciled position
  let reconciled = { ...serverPosition };

  for (const input of pendingInputs) {
    reconciled = applyInput(reconciled, input.input, 0.016);
  }

  // Smooth interpolation (not instant snap)
  const t = 0.2; // 20% correction per frame
  return {
    x: lerp(displayPosition.x, reconciled.x, t),
    y: lerp(displayPosition.y, reconciled.y, t),
    z: lerp(displayPosition.z, reconciled.z, t),
  };
}
```

## Diagonal Movement

```typescript
// Normalize diagonal input to prevent speed advantage
function normalizeInput(input: PlayerInput): PlayerInput {
  const forward = input.forward ? 1 : 0;
  const backward = input.backward ? 1 : 0;
  const left = input.left ? 1 : 0;
  const right = input.right ? 1 : 0;

  const horizontal = left - right;
  const vertical = forward - backward;

  const length = Math.sqrt(horizontal * horizontal + vertical * vertical);

  if (length > 1) {
    // Moving diagonally - normalize
    return {
      forward: input.forward,
      backward: input.backward,
      left: input.left,
      right: input.right,
      normalizedFactor: 1 / length,
    };
  }

  return input;
}
```

## Common Mistakes

| ❌ Wrong | ✅ Right |
|----------|----------|
| Client/server speed mismatch | Use shared config |
| No diagonal normalization | Normalize diagonal input |
| Instant snap to server state | Smooth interpolation |
| Not re-applying pending inputs | Always re-apply after reconciliation |
| Fixed smoothing factor | Dynamic smoothing based on distance |

## Security Considerations

### Server-Side Boundary Enforcement

**CRITICAL**: Server must enforce all movement constraints to prevent teleport cheats.

```typescript
processPlayerInput(player: PlayerState, input: PlayerInput, dt: number) {
  // Apply movement
  if (input.forward) player.z -= speed * dt;
  if (input.backward) player.z += speed * dt;
  if (input.left) player.x -= speed * dt;
  if (input.right) player.x += speed * dt;

  // ❌ WRONG - No boundary validation
  // Player can teleport anywhere

  // ✅ RIGHT - Strict boundary enforcement
  player.x = Math.max(MAP_MIN_X, Math.min(MAP_MAX_X, player.x));
  player.y = Math.max(MAP_MIN_Y, Math.min(MAP_MAX_Y, player.y));
  player.z = Math.max(MAP_MIN_Z, Math.min(MAP_MAX_Z, player.z));
}
```

### Speed Limit Validation

Detect and prevent speed hacks where players move faster than possible.

```typescript
class SpeedValidator {
  private lastPositions = new Map<string, { x: number; z: number; time: number }>();

  validate(clientId: string, newX: number, newZ: number, currentTime: number): boolean {
    const last = this.lastPositions.get(clientId);
    if (!last) {
      this.lastPositions.set(clientId, { x: newX, z: newZ, time: currentTime });
      return true;
    }

    const dt = (currentTime - last.time) / 1000;
    const dx = newX - last.x;
    const dz = newZ - last.z;
    const distance = Math.sqrt(dx * dx + dz * dz);

    // Max speed = walkSpeed + small buffer for network jitter
    const maxDistance = MOVEMENT_CONFIG.walkSpeed * dt + 0.5;

    if (distance > maxDistance) {
      console.warn(`Speed hack detected: ${distance}m in ${dt}s (max: ${maxDistance})`);
      // Reject movement or clamp to max
      return false;
    }

    this.lastPositions.set(clientId, { x: newX, z: newZ, time: currentTime });
    return true;
  }
}
```

### Invalid Sequence Detection

Detect when clients send malformed or malicious sequence numbers.

```typescript
onMessage(client: Client, data: any) {
  const player = this.state.players.get(client.sessionId);
  if (!player) return;

  // Validate sequence number
  const expectedSeq = player.lastProcessedSequence + 1;

  if (data.sequence < expectedSeq) {
    // Old sequence - duplicate or reordered packet
    console.warn(`Old sequence ${data.sequence} (expected ${expectedSeq})`);
    return;
  }

  if (data.sequence > expectedSeq + 10) {
    // Large sequence gap - may indicate packet manipulation
    console.warn(`Large sequence gap from ${client.sessionId}`);
    // Could reset or require reconnect
    return;
  }

  // Accept valid input
  this.inputBuffers.get(client.sessionId)?.push({
    ...data.input,
    sequence: data.sequence,
  });

  player.lastProcessedSequence = data.sequence;
}
```

### Movement Sanitization

Sanitize input flags to prevent injection attacks through boolean inputs.

```typescript
onMessage(client: Client, data: any) {
  // ❌ WRONG - Direct use of client data
  if (data.input.jump) player.jump();

  // ✅ RIGHT - Sanitize boolean inputs
  const sanitized = {
    forward: Boolean(data.input?.forward),
    backward: Boolean(data.input?.backward),
    left: Boolean(data.input?.left),
    right: Boolean(data.input?.right),
    jump: Boolean(data.input?.jump),
    sprint: Boolean(data.input?.sprint),
    // Ensure no extra properties
    crouch: Boolean(data.input?.crouch),
  };

  this.processPlayerInput(player, sanitized);
}
```

### Delta Time Protection

Prevent clients from sending malicious delta time values to speed up movement.

```typescript
// ❌ WRONG - Client sends deltaTime
onMessage(client: Client, data: any) {
  const position = applyInput(player.position, data.input, data.deltaTime);
  // Client can speed up by sending larger deltaTime!
}

// ✅ RIGHT - Server uses authoritative deltaTime
onMessage(client: Client, data: any) {
  // Client only sends input, server controls timing
  this.inputBuffers.get(client.sessionId)?.push({
    ...data.input,
    sequence: data.sequence,
    // No deltaTime - server uses fixed simulation tick
  });
}

// Server uses fixed tick rate
update(dt: number) {
  const deltaTime = dt / 1000;

  // Cap deltaTime to prevent spiral of death
  const safeDelta = Math.min(deltaTime, 0.1);

  for (const [sessionId, player] of this.state.players) {
    // Process with server-controlled timing
    this.updatePlayerPosition(player, safeDelta);
  }
}
```

## Reference

- [prediction-basics.md](./prediction-basics.md) - Core concepts
- [prediction-shooting.md](./prediction-shooting.md) - Shooting with rollback
