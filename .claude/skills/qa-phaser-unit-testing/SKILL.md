---
name: qa-phaser-unit-testing
description: Phaser unit testing patterns with MockScene. Provides patterns for testing Phaser objects, Matter.js physics, and game systems without requiring a running game instance.
category: testing
---

# Phaser Unit Testing Patterns

> "Test Phaser game objects without a running game instance."

## When to Use This Skill

Use when creating unit tests for:
- Phaser game objects (Birds, Pigs, Blocks, etc.)
- Matter.js physics bodies
- Game systems that depend on Phaser Scene
- Event-driven game logic

**CRITICAL LESSON FROM BUG-011:** Never use real Phaser Scene instances in unit tests. They require a running Phaser Game instance and will fail with errors like "scene.init is not a function". Always use MockScene pattern.

## The MockScene Pattern

### Why MockScene is Required

Real Phaser Scenes need:
- A running Phaser.Game instance
- Canvas element in DOM
- Full Phaser engine initialization
- Matter.js physics engine context

This makes unit tests:
- Slow (full engine startup)
- Brittle (DOM dependencies)
- Complex (setup/teardown)
- Unreliable (timing issues)

**MockScene Pattern Solution:**
Create comprehensive mocks that simulate Phaser Scene APIs without requiring the full engine.

### Complete MockScene Implementation

```typescript
// tests/helpers/MockScene.ts
import { EventEmitter } from 'events';

interface MockMatterBody {
  label: string;
  isStatic: boolean;
  mass: number;
  position: { x: number; y: number };
  velocity: { x: number; y: number };
  angularVelocity: number;
}

interface MockMatterImage {
  body: MockMatterBody;
  setCircle: (radius: number) => void;
  setRectangle: (width: number, height: number) => void;
  setStatic: (isStatic: boolean) => void;
  setPosition: (x: number, y: number) => void;
  setVelocity: (x: number, y: number) => void;
  setAngularVelocity: (velocity: number) => void;
}

interface MockGraphics {
  fillStyle: (color: number, alpha?: number) => MockGraphics;
  fillRect: (x: number, y: number, width: number, height: number) => MockGraphics;
  clear: () => void;
}

interface MockCamera {
  shake: (duration: number, intensity?: number) => void;
}

export class MockScene extends EventEmitter {
  public matter: {
    add: {
      image: (x: number, y: number, key: string, shape?: string) => MockMatterImage;
    }
  };

  public events: {
    emit: (event: string, ...args: any[]) => void;
    on: (event: string, handler: Function) => void;
    off: (event: string, handler?: Function) => void;
  };

  public tweens: {
    add: (config: any) => { pause: () => void; destroy: () => void };
  };

  public cameras: {
    main: MockCamera;
  };

  public add: {
    graphics: () => MockGraphics;
  };

  public time: {
    delayedCall: (delay: number, callback: Function, args?: any[]) => { destroy: () => void };
    addEvent: (config: any) => { destroy: () => void };
    now: number;
  };

  private _eventHandlers: Map<string, Set<Function>> = new Map();

  constructor() {
    super();
    this._setupMocks();
  }

  private _setupMocks() {
    // Matter.js mocks
    this.matter = {
      add: {
        image: (x: number, y: number, key: string) => ({
          body: {
            label: key,
            isStatic: false,
            mass: 1,
            position: { x, y },
            velocity: { x: 0, y: 0 },
            angularVelocity: 0,
          },
          setCircle: () => {},
          setRectangle: () => {},
          setStatic: () => {},
          setPosition: () => {},
          setVelocity: () => {},
          setAngularVelocity: () => {},
        }),
      },
    };

    // Event system
    this.events = {
      emit: (event: string, ...args: any[]) => {
        this.emit(event, ...args);
      },
      on: (event: string, handler: Function) => {
        if (!this._eventHandlers.has(event)) {
          this._eventHandlers.set(event, new Set());
        }
        this._eventHandlers.get(event)!.add(handler);
        this.on(event, handler);
      },
      off: (event: string, handler?: Function) => {
        if (handler) {
          this._eventHandlers.get(event)?.delete(handler);
          this.off(event, handler);
        } else {
          this._eventHandlers.delete(event);
          this.removeAllListeners(event);
        }
      },
    };

    // Tweens
    this.tweens = {
      add: (config: any) => ({
        pause: () => {},
        destroy: () => {},
      }),
    };

    // Camera
    this.cameras = {
      main: {
        shake: () => {},
      },
    };

    // Graphics
    this.add = {
      graphics: () => ({
        fillStyle: () => this,
        fillRect: () => this,
        clear: () => {},
      }),
    };

    // Time
    this.time = {
      delayedCall: () => ({ destroy: () => {} }),
      addEvent: () => ({ destroy: () => {} }),
      now: 0,
    };
  }

  // Cleanup method
  destroy() {
    this._eventHandlers.clear();
    this.removeAllListeners();
  }
}
```

### Using MockScene in Tests

```typescript
// tests/unit/objects/Pig.test.ts
import { describe, test, expect, beforeEach, vi } from 'vitest';
import { MockScene } from '../helpers/MockScene';
import { SmallPig } from '@/objects/pigs/SmallPig';

describe('SmallPig', () => {
  let scene: MockScene;

  beforeEach(() => {
    scene = new MockScene();
  });

  describe('initialization', () => {
    test('should create pig with correct health', () => {
      const pig = new SmallPig(scene, 100, 200);

      expect(pig.health).toBe(10);
      expect(pig.maxHealth).toBe(10);
    });

    test('should create pig with correct scale', () => {
      const pig = new SmallPig(scene, 100, 200);

      // MockScene creates mock body with position
      expect(pig.body).toBeDefined();
    });
  });

  describe('damage system', () => {
    test('should reduce health when damaged', () => {
      const pig = new SmallPig(scene, 100, 200);

      pig.takeDamage(5);

      expect(pig.health).toBe(5);
    });

    test('should be destroyed when health reaches 0', () => {
      const pig = new SmallPig(scene, 100, 200);
      const destroyedSpy = vi.fn();
      scene.on('pig-destroyed', destroyedSpy);

      pig.takeDamage(10);

      expect(pig.isDestroyed()).toBe(true);
      expect(destroyedSpy).toHaveBeenCalledWith(pig);
    });
  });

  describe('visual damage state', () => {
    test('should show damage when health > 50% lost', () => {
      const pig = new SmallPig(scene, 100, 200);

      pig.takeDamage(6); // 60% damage

      expect(pig.shouldShowDamageState()).toBe(true);
    });
  });
});
```

## Testing Game Systems

### Testing PigHealthSystem

```typescript
// tests/unit/systems/PigHealthSystem.test.ts
import { describe, test, expect, beforeEach, vi } from 'vitest';
import { MockScene } from '../helpers/MockScene';
import { PigHealthSystem } from '@/systems/PigHealthSystem';
import { SmallPig } from '@/objects/pigs/SmallPig';

describe('PigHealthSystem', () => {
  let scene: MockScene;
  let system: PigHealthSystem;

  beforeEach(() => {
    scene = new MockScene();
    system = new PigHealthSystem(scene);
  });

  test('should track all pigs in scene', () => {
    const pig1 = new SmallPig(scene, 100, 200);
    const pig2 = new SmallPig(scene, 300, 200);

    system.trackPig(pig1);
    system.trackPig(pig2);

    expect(system.trackedPigCount).toBe(2);
  });

  test('should emit event when all pigs destroyed', () => {
    const pig = new SmallPig(scene, 100, 200);
    system.trackPig(pig);

    const allDestroyedSpy = vi.fn();
    scene.on('all-pigs-destroyed', allDestroyedSpy);

    pig.takeDamage(10); // Destroy pig

    expect(allDestroyedSpy).toHaveBeenCalled();
  });
});
```

## Testing Bird Abilities

```typescript
// tests/unit/objects/birds/YellowBird.test.ts
import { describe, test, expect, beforeEach } from 'vitest';
import { MockScene } from '../../helpers/MockScene';
import { YellowBird } from '@/objects/birds/YellowBird';

describe('YellowBird', () => {
  let scene: MockScene;
  let bird: YellowBird;

  beforeEach(() => {
    scene = new MockScene();
    bird = new YellowBird(scene, 100, 200);
  });

  describe('speed boost ability', () => {
    test('should increase velocity by 2.5x when activated', () => {
      bird.body.velocity = { x: 10, y: 0 };

      bird.activateAbility();

      expect(bird.body.velocity.x).toBe(25);
    });

    test('should emit ability-activated event', () => {
      const spy = vi.fn();
      scene.on('ability-activated', spy);

      bird.activateAbility();

      expect(spy).toHaveBeenCalledWith('yellow-boost', expect.any(Object));
    });
  });
});
```

## Testing Matter.js Physics

```typescript
// tests/unit/physics/CollisionTest.test.ts
import { describe, test, expect, beforeEach } from 'vitest';
import { MockScene } from '../../helpers/MockScene';
import { Block } from '@/objects/Block';

describe('Block Collision', () => {
  let scene: MockScene;

  beforeEach(() => {
    scene = new MockScene();
  });

  test('should detect collision between two blocks', () => {
    const block1 = new Block(scene, 100, 100, 'wood');
    const block2 = new Block(scene, 100, 100, 'glass');

    // Simulate collision
    block1.onCollide(block2);

    expect(block1.hasCollided).toBe(true);
  });

  test('should transfer momentum on collision', () => {
    const block1 = new Block(scene, 100, 100, 'wood');
    const block2 = new Block(scene, 100, 100, 'glass');

    block1.body.velocity = { x: 10, y: 0 };
    block2.body.velocity = { x: 0, y: 0 };

    block1.onCollide(block2);

    // Verify momentum transfer
    expect(block2.body.velocity.x).toBeGreaterThan(0);
  });
});
```

## Test Organization

### File Structure

```
tests/
├── helpers/
│   └── MockScene.ts          # Shared mock implementation
├── unit/
│   ├── objects/
│   │   ├── birds/
│   │   │   ├── RedBird.test.ts
│   │   │   ├── YellowBird.test.ts
│   │   │   └── BlackBird.test.ts
│   │   ├── pigs/
│   │   │   ├── Pig.test.ts
│   │   │   ├── SmallPig.test.ts
│   │   │   └── LargePig.test.ts
│   │   └── blocks/
│   │       └── Block.test.ts
│   └── systems/
│       ├── PigHealthSystem.test.ts
│       ├── BirdAbilityManager.test.ts
│       └── ScoringSystem.test.ts
```

## Common Issues and Solutions

| Issue | Cause | Solution |
|-------|-------|----------|
| "scene.init is not a function" | Using real Scene instead of MockScene | Replace with MockScene |
| "Cannot read properties of undefined" | Missing mock properties | Add missing property to MockScene |
| Event handlers not being called | Event system not mocked | Implement events.on/off/emit in MockScene |
| Tween-related failures | Tweens not mocked | Add tweens.add mock to MockScene |
| "matter.add is not a function" | Matter.js not mocked | Add matter.add mock to MockScene |

## Best Practices

1. **Always use MockScene** - Never instantiate real Phaser.Scene in unit tests
2. **Mock all scene properties used** - If code uses `scene.time.addEvent`, mock it
3. **Test behavior, not Phaser internals** - Test game logic, not framework calls
4. **Use beforeEach for clean state** - Create fresh MockScene for each test
5. **Clean up event listeners** - Remove listeners in test cleanup
6. **Test edge cases** - Zero health, max health, boundary conditions
7. **Verify event emissions** - Ensure game events fire correctly

## Anti-Patterns

❌ **DON'T:**

```typescript
// WRONG - Using real Scene
import { Game, Scene } from 'phaser';

test('should create pig', () => {
  const game = new Game(config); // Slow and brittle
  const scene = new Scene();
  game.scene.add('test', scene);
  // ... tests will fail if canvas not in DOM
});
```

✅ **DO:**

```typescript
// RIGHT - Using MockScene
import { MockScene } from '../helpers/MockScene';

test('should create pig', () => {
  const scene = new MockScene(); // Fast and reliable
  const pig = new SmallPig(scene, 100, 200);
  expect(pig.health).toBe(10);
});
```

## References

- [Phaser 3 Documentation](https://photonstorm.github.io/phaser3-docs/)
- [Matter.js Documentation](https://brm.io/matter-js/docs/)
- BUG-011 fix: `tests/unit/objects/Pig.test.ts` - Reference implementation
- qa-unit-test-creation skill - General unit testing patterns

---

**LESSON LEARNED FROM BUG-011:** The MockScene pattern is essential for testing Phaser objects. Always create comprehensive mocks for all Phaser Scene properties used by your code. This prevents test failures caused by missing Phaser Game instances.
