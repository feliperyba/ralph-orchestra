---
name: dev-typescript-advanced
description: Advanced TypeScript patterns - generics, utility types, React patterns. Use for complex type scenarios.
category: typescript
---

# Advanced TypeScript Patterns

Generics, utility types, and React integration patterns.

## When to Use

Use when:
- Creating reusable generic types
- Working with complex type transformations
- Typing React components and hooks

## Generics

```typescript
// Generic pool
class ObjectPool<T> {
  private pool: T[] = [];
  private factory: () => T;

  constructor(factory: () => T, initialSize: number) {
    this.factory = factory;
    for (let i = 0; i < initialSize; i++) {
      this.pool.push(factory());
    }
  }

  acquire(): T {
    return this.pool.pop() ?? this.factory();
  }

  release(item: T): void {
    this.pool.push(item);
  }
}

// Usage
const bulletPool = new ObjectPool(() => new Bullet(), 100);
```

## Utility Types

```typescript
// Partial - make all properties optional
type PartialPlayer = Partial<Player>;

// Required - make all properties required
type RequiredConfig = Required<GameConfig>;

// Pick - select specific properties
type PlayerPosition = Pick<Player, 'x' | 'y' | 'z'>;

// Omit - exclude properties
type PlayerWithoutId = Omit<Player, 'id'>;

// Record - create object type from keys
type ScoreBoard = Record<string, number>;

// ReturnType - get return type of function
type SpawnResult = ReturnType<typeof spawnPlayer>;
```

## React Patterns

```typescript
// Component props
interface ButtonProps {
  label: string;
  onClick: () => void;
  disabled?: boolean;
  variant?: 'primary' | 'secondary';
}

// Props with children
interface ContainerProps {
  children: React.ReactNode;
  className?: string;
}

// Event handlers
interface GameCanvasProps {
  onPlayerMove: (position: Vector3Like) => void;
  onPlayerShoot: (direction: Vector3Like) => void;
}

// Ref types
const meshRef = useRef<THREE.Mesh>(null);
const rigidBodyRef = useRef<RapierRigidBody>(null);

// State with complex types
const [gameState, setGameState] = useState<GameState>({
  phase: 'loading',
  players: [],
  score: 0,
});
```

## Generic Constraints

```typescript
// Constrain generic type
interface Entity<T extends { id: string }> {
  entities: Map<string, T>;
}

function addEntity<T extends { id: string }>(state: EntityState<T>, entity: T): void {
  state.entities.set(entity.id, entity);
}
```

## Type Guards

```typescript
// Type guard for discriminated unions
function isPlayerSpawn(event: GameEvent): event is Extract<GameEvent, { type: 'PLAYER_SPAWN' }> {
  return event.type === 'PLAYER_SPAWN';
}

// Usage
function handleEvent(event: GameEvent) {
  if (isPlayerSpawn(event)) {
    // TypeScript knows event has position here
    console.log(event.position);
  }
}
```

## Reference

- **[dev-typescript-basics](../dev-typescript-basics/SKILL.md)** — Core patterns

---

## Phaser UI Component Patterns (feat-027)

**Lesson from feat-027 (Star Rating Preview):** Phaser UI components use typed configurations and event-driven updates.

### UI Component Type Definition

```typescript
// src/ui/HUD.ts - Type-safe UI configuration
interface StarRatingConfig {
  position: { x: number; y: number };
  size: number;
  emptyColor: number;  // 0xcccccc
  fillColor: number;    // 0xffcc00
  emptyAlpha: number;   // 0.3
  filledAlpha: number;  // 1.0
  pulseScale: number;    // 1.1
}

interface StarThresholds {
  twoStar: number;
  threeStar: number;
}

export class HUD extends Phaser.GameObjects.Container {
  private config: StarRatingConfig;
  private thresholds: StarThresholds;

  constructor(scene: Phaser.Scene, config: StarRatingConfig) {
    super(scene, 0, 0);
    this.config = config;
    this.setupStars();
  }

  private calculateThresholds(level: number): StarThresholds {
    // DEC-004 formula: thresholds scale with level
    return {
      twoStar: 32000 + (level * 2000),
      threeStar: 66000 + (level * 6000),
    };
  }
}
```

### Event-Driven UI Updates

```typescript
// Subscribe to game events for real-time updates
export class HUD extends Phaser.GameObjects.Container {
  setupListeners(scene: Phaser.Scene): void {
    // Listen to score changes
    scene.events.on('totalScoreUpdate', this.handleScoreUpdate, this);
  }

  private handleScoreUpdate(data: { score: number }): void {
    const { score } = data;
    const level = this.scene.registry.get('currentLevel');

    // Calculate new star state
    const thresholds = this.calculateThresholds(level);
    const newState = this.calculateStarState(score, thresholds);

    // Only update if state changed (prevents unnecessary tweens)
    if (newState !== this.currentState) {
      this.animateStateChange(newState);
      this.currentState = newState;
    }
  }

  destroy(): void {
    // Clean up event listeners
    this.scene.events.off('totalScoreUpdate', this.handleScoreUpdate, this);
    super.destroy();
  }
}
```

### Typed Event Callbacks

```typescript
// Type-safe event system
interface GameEvents {
  'totalScoreUpdate': { score: number; level: number };
  'levelComplete': { level: number; stars: number };
  'pigDestroyed': { pigId: string; points: number };
}

class EventManager {
  on<K extends keyof GameEvents>(
    event: K,
    callback: (data: GameEvents[K]) => void
  ): void {
    this.scene.events.on(event, callback);
  }

  emit<K extends keyof GameEvents>(
    event: K,
    data: GameEvents[K]
  ): void {
    this.scene.events.emit(event, data);
  }
}
```

### Animation State Management

```typescript
// Track animation state to prevent tweens from accumulating
class Star extends Phaser.GameObjects.Image {
  private tweenState: {
    isAnimating: boolean;
    targetFill: boolean;
  } = { isAnimating: false, targetFill: false };

  setFill(fill: boolean): void {
    // Don't tween if already at target state
    if (this.tweenState.isAnimating && this.tweenState.targetFill === fill) {
      return;
    }

    this.tweenState.isAnimating = true;
    this.tweenState.targetFill = fill;

    this.scene.tweens.add({
      targets: this,
      duration: 300,
      ease: Phaser.Math.Easing.Quadratic.Out,
      props: {
        tint: fill ? 0xffcc00 : 0xcccccc,
        alpha: fill ? 1.0 : 0.3,
      },
      onComplete: () => {
        this.tweenState.isAnimating = false;
      }
    });
  }
}
```

### Color Utility Types

```typescript
// Type-safe color management
namespace GameColors {
  export const STAR_EMPTY = 0xcccccc;
  export const STAR_FULL = 0xffcc00;
  export const UI_BG = 0x000000;

  export function interpolateColor(
    color1: number,
    color2: number,
    t: number
  ): number {
    // Phaser color interpolation
    const c1 = Phaser.Display.Color.IntegerToColor(color1);
    const c2 = Phaser.Display.Color.IntegerToColor(color2);
    const result = Phaser.Display.Color.Interpolate.ColorWithColor(c1, c2, t);
    return result.getColor();
  }
}
```

## Anti-Patterns for Phaser UI

❌ **DON'T:**

```typescript
// WRONG - Untyped configuration
updateStar(score: number, level: number) {
  const twoStar = 32000 + level * 2000; // Untyped math
  this.star.tint = score > twoStar ? 0xffcc00 : 0xcccccc;
}
```

✅ **DO:**

```typescript
// RIGHT - Typed, testable configuration
interface Thresholds {
  twoStar: number;
  threeStar: number;
}

const calculateThresholds = (level: number): Thresholds => ({
  twoStar: 32000 + (level * 2000),
  threeStar: 66000 + (level * 6000),
});

updateStar(score: number, level: number): void {
  const thresholds = calculateThresholds(level);
  this.star.tint = score > thresholds.twoStar ? GameColors.STAR_FULL : GameColors.STAR_EMPTY;
}
```
