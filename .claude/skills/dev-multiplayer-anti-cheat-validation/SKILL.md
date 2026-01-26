---
name: anti-cheat-validation
description: Input validation and anti-cheat patterns for multiplayer servers. Use when implementing server-side validation.
---

# Anti-Cheat Validation

Server-side validation to prevent cheating in multiplayer games.

## When to Use

Use when:
- Implementing input validation on the server
- Adding shooting mechanics
- Preventing speed hacks or teleportation

## Input Validation Pattern

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

## Shooting Validation

```typescript
onMessage(client: Client, data: any) {
  if (data.type !== 'shoot') return;

  const shooter = this.state.players.get(client.sessionId);
  if (!shooter) return;

  // Validate shooter can shoot
  if (shooter.ink <= 0) return;
  if (Date.now() - shooter.lastShotTime < 100) return; // 100ms cooldown

  // Validate aim direction is reasonable
  const aim = data.aimDirection;
  const aimLength = Math.sqrt(aim.x ** 2 + aim.y ** 2 + aim.z ** 2);
  if (aimLength > 1.1 || aimLength < 0.9) return; // Must be normalized

  // Server creates paint projectile
  const projectile = {
    x: shooter.x,
    y: shooter.y + 1.5,
    z: shooter.z,
    dx: aim.x * 25,
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

## Hit Detection with Lag Compensation

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
    if (!this.positionHistory.has(sessionId)) {
      this.positionHistory.set(sessionId, []);
    }
    const history = this.positionHistory.get(sessionId)!;

    // Store position for lag compensation (keep last 500ms)
    history.push({ time: now, x: player.x, y: player.y, z: player.z });

    // Remove old entries
    while (history.length > 0 && history[0].time < now - 500) {
      history.shift();
    }
  }
}
```

## Anti-Cheat Best Practices

1. **Validate all inputs** - Reject impossible values
2. **Rate limit actions** - Prevent spam exploits
3. **Track position history** - Detect teleportation
4. **Checksum game state** - Detect tampering
5. **Log suspicious activity** - For analysis/banning

## Security Considerations

### Comprehensive Input Validation Framework

**CRITICAL**: Every client input must be validated server-side before processing.

```typescript
class InputValidator {
  validate(clientId: string, data: any): ValidationResult {
    const errors: string[] = [];

    // 1. Structure validation
    if (!data || typeof data !== 'object') {
      errors.push('invalid_message_structure');
      return { valid: false, errors };
    }

    // 2. Message type allowlist
    const allowedTypes = [
      'player_input',
      'paint_fire',
      'emote',
      'chat_message'
    ];
    if (!allowedTypes.includes(data.type)) {
      errors.push('unknown_message_type');
    }

    // 3. Data type validation
    switch (data.type) {
      case 'player_input':
        this.validatePlayerInput(data, errors);
        break;
      case 'paint_fire':
        this.validatePaintFire(data, errors);
        break;
      case 'chat_message':
        this.validateChatMessage(data, errors);
        break;
    }

    // 4. Size validation (prevent memory exhaustion)
    if (JSON.stringify(data).length > 10000) {
      errors.push('message_too_large');
    }

    const valid = errors.length === 0;
    if (!valid) {
      console.warn(`Validation failed for ${clientId}:`, errors);
    }

    return { valid, errors };
  }

  private validatePlayerInput(data: any, errors: string[]): void {
    // Validate input object exists
    if (!data.input || typeof data.input !== 'object') {
      errors.push('missing_input_object');
      return;
    }

    // Validate boolean flags
    const boolFields = ['forward', 'backward', 'left', 'right', 'jump', 'sprint'];
    for (const field of boolFields) {
      if (data.input[field] !== undefined && typeof data.input[field] !== 'boolean') {
        errors.push(`invalid_${field}_type`);
      }
    }

    // No extra fields allowed (prevent injection)
    const allowedFields = [...boolFields, 'crouch'];
    const extraFields = Object.keys(data.input).filter(
      k => !allowedFields.includes(k)
    );
    if (extraFields.length > 0) {
      errors.push(`extra_fields: ${extraFields.join(',')}`);
    }
  }

  private validatePaintFire(data: any, errors: string[]): void {
    // Validate direction is normalized
    if (!data.direction || typeof data.direction !== 'object') {
      errors.push('missing_direction');
      return;
    }

    const { x, y, z } = data.direction;
    const length = Math.sqrt(x * x + y * y + z * z);

    if (length < 0.9 || length > 1.1) {
      errors.push('direction_not_normalized');
    }

    // Validate direction is reasonable (not straight up/down)
    if (Math.abs(y) > 0.95) {
      errors.push('extreme_pitch_angle');
    }
  }

  private validateChatMessage(data: any, errors: string[]): void {
    if (!data.message || typeof data.message !== 'string') {
      errors.push('missing_message');
      return;
    }

    // Length limit
    if (data.message.length > 200) {
      errors.push('message_too_long');
    }

    // Content filtering
    if (containsProfanity(data.message)) {
      errors.push('inappropriate_content');
    }
  }
}
```

### Teleportation Detection

Detect when players move faster than physically possible.

```typescript
class TeleportDetector {
  private positions = new Map<string, PositionHistory>();

  validateMovement(clientId: string, newX: number, newY: number, newZ: number): boolean {
    const history = this.positions.get(clientId);
    if (!history) {
      this.positions.set(clientId, {
        positions: [{ x: newX, y: newY, z: newZ, time: Date.now() }]
      });
      return true;
    }

    const now = Date.now();
    const maxSpeed = 20; // meters per second
    const maxDistance = maxSpeed * 0.1; // per tick (100ms)

    // Check recent positions
    for (const pos of history.positions) {
      const dt = (now - pos.time) / 1000;
      const dx = newX - pos.x;
      const dy = newY - pos.y;
      const dz = newZ - pos.z;
      const distance = Math.sqrt(dx * dx + dy * dy + dz * dz);

      // Allow some network jitter tolerance
      const tolerance = maxDistance * dt + 0.5;

      if (distance > tolerance) {
        console.warn(`Teleport detected: ${distance}m in ${dt}s`);
        return false;
      }
    }

    // Add to history
    history.positions.push({ x: newX, y: newY, z: newZ, time: now });

    // Keep last 5 seconds of history
    history.positions = history.positions.filter(p => now - p.time < 5000);

    return true;
  }
}
```

### Behavior Analysis

Track player behavior patterns to detect bots and cheaters.

```typescript
class BehaviorAnalyzer {
  private playerStats = new Map<string, PlayerStats>();

  analyzeAction(clientId: string, action: string, data: any): CheatScore {
    const stats = this.playerStats.get(clientId) || this.createStats(clientId);
    this.playerStats.set(clientId, stats);

    let suspicion = 0;

    // Check reaction times (too fast = aimbot)
    if (action === 'hit') {
      const reactionTime = data.reactionTime || 0;
      if (reactionTime < 50) { // < 50ms is superhuman
        suspicion += 10;
      }
    }

    // Check accuracy (100% accuracy across many shots = aimbot)
    if (action === 'shot') {
      stats.shotCount++;
      if (data.hit) {
        stats.hitCount++;
      }

      const accuracy = stats.hitCount / stats.shotCount;
      if (stats.shotCount > 50 && accuracy > 0.95) {
        suspicion += 20;
      }
    }

    // Check for impossible patterns
    if (this.hasImpossiblePattern(stats)) {
      suspicion += 50;
    }

    return { suspicion, stats };
  }

  private hasImpossiblePattern(stats: PlayerStats): boolean {
    // No human can hit 100% of shots while moving at max speed
    return stats.maxSpeedWhileShooting > 15 && stats.accuracy > 0.9;
  }
}
```

### Rate Limiting by Action Type

Different actions have different rate limits.

```typescript
class ActionRateLimiter {
  private limits = {
    'player_input': { max: 60, window: 1000 },    // 60/sec
    'paint_fire': { max: 10, window: 1000 },       // 10/sec (600 RPM)
    'chat_message': { max: 2, window: 5000 },     // 2 per 5 sec
    'emote': { max: 5, window: 10000 },          // 5 per 10 sec
  };

  private trackers = new Map<string, Map<string, number[]>>();

  canPerform(clientId: string, actionType: string): boolean {
    const limit = this.limits[actionType];
    if (!limit) return true;

    if (!this.trackers.has(clientId)) {
      this.trackers.set(clientId, new Map());
    }

    const tracker = this.trackers.get(clientId)!;
    if (!tracker.has(actionType)) {
      tracker.set(actionType, []);
    }

    const timestamps = tracker.get(actionType)!;
    const now = Date.now();

    // Remove old timestamps outside window
    while (timestamps.length > 0 && timestamps[0] < now - limit.window) {
      timestamps.shift();
    }

    // Check limit
    if (timestamps.length >= limit.max) {
      console.warn(`Rate limit exceeded: ${clientId} ${actionType}`);
      return false;
    }

    // Record this action
    timestamps.push(now);
    return true;
  }
}
```

### State Integrity Verification

Periodically verify game state hasn't been tampered.

```typescript
class StateIntegrityChecker {
  private checksums = new Map<string, string>();

  // Calculate checksum of player state
  calculateChecksum(player: PlayerState): string {
    const data = `${player.x},${player.y},${player.z},${player.score},${player.ink}`;
    return simpleHash(data);
  }

  // Verify state periodically
  verifyState(room: GameRoom): void {
    for (const [clientId, player] of room.state.players) {
      const checksum = this.calculateChecksum(player);
      const stored = this.checksums.get(clientId);

      if (stored && stored !== checksum) {
        console.error(`State tampering detected: ${clientId}`);
        // Could reset player, kick, or ban
      }

      this.checksums.set(clientId, checksum);
    }
  }
}

function simpleHash(str: string): string {
  let hash = 0;
  for (let i = 0; i < str.length; i++) {
    const char = str.charCodeAt(i);
    hash = ((hash << 5) - hash) + char;
    hash = hash & hash; // Convert to 32-bit integer
  }
  return hash.toString(36);
}
```

## Testing Checklist

- [ ] Server running successfully
- [ ] Feature works through network (not just locally)
- [ ] Server logs show player actions
- [ ] State updates propagate to all clients
- [ ] Inputs are validated server-side
- [ ] Impossible inputs are rejected
- [ ] No client-authoritative position updates
- [ ] Rate limiting prevents spam
- [ ] Suspicious activity is logged
- [ ] Cheaters are detected and handled

## Common Mistakes

| ❌ Wrong | ✅ Right |
|----------|----------|
| Trust client position | Validate all inputs |
| No rate limiting | Add cooldowns |
| No logging | Log suspicious activity |
| Client determines hit | Server validates hit |

## Reference

- [server-authoritative.md](./server-authoritative.md) - Architecture principles
- [prediction-shooting.md](./prediction-shooting.md) - Shooting prediction
