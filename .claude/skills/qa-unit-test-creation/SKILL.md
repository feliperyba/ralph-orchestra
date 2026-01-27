---
name: qa-unit-test-creation
description: Vitest unit test creation patterns. Provides patterns for AAA structure, mocking, fixtures, and test data factories. Use when creating unit tests for components, services, utilities, or stores.
category: workflow
---

# Vitest Unit Test Creation Patterns

> "Unit tests verify the smallest parts of your code work correctly."

## When to Use This Skill

Use when creating unit tests for:
- React components (including React Three Fiber)
- Zustand stores
- Services and utilities
- ECS components and systems
- Hooks and custom functions

## Test File Locations

**Pattern:** Mirror `src/` structure in `src/tests/`

| Source File | Test File |
| ----------- | --------- |
| `src/components/game/player/index.ts` | `src/tests/components/game/player/index.test.ts` |
| `src/services/ShootingService.ts` | `src/tests/services/ShootingService.test.ts` |
| `src/stores/gameStore.ts` | `src/tests/stores/gameStore.test.ts` |
| `src/ecs/systems/MovementSystem.ts` | `src/tests/ecs/systems/MovementSystem.test.ts` |
| `src/utils/ResourceManager.ts` | `src/tests/utils/ResourceManager.test.ts` |

## AAA Pattern (Arrange-Act-Assert)

**Every test should follow this structure:**

```typescript
test('should update position when velocity applied', () => {
  // Arrange - Set up the test data and conditions
  const position = new Position(0, 0, 0);
  const velocity = new Velocity(1, 0, 0);
  const deltaTime = 1;

  // Act - Execute the function being tested
  position.x += velocity.x * deltaTime;

  // Assert - Verify the result
  expect(position.x).toBe(1);
});
```

## Common Test Patterns

### 1. Pure Function Testing

```typescript
// src/utils/VectorMath.ts
export function addVectors(a: Vector3, b: Vector3): Vector3 {
  return { x: a.x + b.x, y: a.y + b.y, z: a.z + b.z };
}

// src/tests/utils/VectorMath.test.ts
import { describe, test, expect } from 'vitest';
import { addVectors } from '@/utils/VectorMath';

describe('addVectors', () => {
  test('should add two vectors correctly', () => {
    // Arrange
    const vec1 = { x: 1, y: 2, z: 3 };
    const vec2 = { x: 4, y: 5, z: 6 };

    // Act
    const result = addVectors(vec1, vec2);

    // Assert
    expect(result).toEqual({ x: 5, y: 7, z: 9 });
  });

  test('should handle zero vectors', () => {
    const vec1 = { x: 0, y: 0, z: 0 };
    const vec2 = { x: 1, y: 2, z: 3 };

    const result = addVectors(vec1, vec2);

    expect(result).toEqual({ x: 1, y: 2, z: 3 });
  });
});
```

### 2. Class Testing

```typescript
// src/services/ShootingService.ts
export class ShootingService {
  calculateHit(origin: Position, direction: Vector3): HitResult {
    // implementation
  }
}

// src/tests/services/ShootingService.test.ts
import { describe, test, expect, beforeEach } from 'vitest';
import { ShootingService } from '@/services/ShootingService';

describe('ShootingService', () => {
  let service: ShootingService;

  beforeEach(() => {
    service = new ShootingService();
  });

  describe('calculateHit', () => {
    test('should return hit when target is in range', () => {
      const origin = { x: 0, y: 0, z: 0 };
      const direction = { x: 1, y: 0, z: 0 };

      const result = service.calculateHit(origin, direction);

      expect(result.hit).toBe(true);
    });

    test('should return miss when target is out of range', () => {
      const origin = { x: 0, y: 0, z: 0 };
      const direction = { x: 1, y: 0, z: 0 };

      const result = service.calculateHit(origin, direction, { maxDistance: 10 });

      expect(result.hit).toBe(false);
    });
  });
});
```

### 3. Zustand Store Testing

```typescript
// src/stores/gameStore.ts
import { create } from 'zustand';

interface GameState {
  players: Player[];
  gameState: 'character-selection' | 'lobby' | 'playing';
  addPlayer: (player: Player) => void;
  setGameState: (state: string) => void;
}

export const useGameStore = create<GameState>((set) => ({
  players: [],
  gameState: 'character-selection',
  addPlayer: (player) => set((state) => ({ players: [...state.players, player] })),
  setGameState: (gameState) => set({ gameState }),
}));

// src/tests/stores/gameStore.test.ts
import { describe, test, expect, beforeEach } from 'vitest';
import { useGameStore } from '@/stores/gameStore';

describe('useGameStore', () => {
  beforeEach(() => {
    // Reset store to initial state before each test
    useGameStore.setState({
      players: [],
      gameState: 'character-selection',
      addPlayer: useGameStore.getState().addPlayer,
      setGameState: useGameStore.getState().setGameState,
    });
  });

  test('should initialize with default state', () => {
    const state = useGameStore.getState();

    expect(state.players).toEqual([]);
    expect(state.gameState).toBe('character-selection');
  });

  test('should add player when addPlayer is called', () => {
    const store = useGameStore.getState();
    const newPlayer = { id: 'player1', name: 'Test Player', team: 'orange' };

    store.addPlayer(newPlayer);

    const state = useGameStore.getState();
    expect(state.players).toHaveLength(1);
    expect(state.players[0]).toEqual(newPlayer);
  });

  test('should add multiple players', () => {
    const store = useGameStore.getState();

    store.addPlayer({ id: 'player1', name: 'Player 1', team: 'orange' });
    store.addPlayer({ id: 'player2', name: 'Player 2', team: 'blue' });

    const state = useGameStore.getState();
    expect(state.players).toHaveLength(2);
  });

  test('should update game state', () => {
    const store = useGameStore.getState();

    store.setGameState('playing');

    const state = useGameStore.getState();
    expect(state.gameState).toBe('playing');
  });
});
```

### 4. React Hook Testing

```typescript
// src/components/game/player/usePlayerMovement.ts
export function usePlayerMovement() {
  const position = useGameStore((state) => state.position);
  const velocity = useGameStore((state) => state.velocity);

  const move = (direction: Vector3) => {
    // implementation
  };

  return { position, velocity, move };
}

// src/tests/components/game/player/usePlayerMovement.test.ts
import { describe, test, expect, beforeEach } from 'vitest';
import { renderHook, act } from '@testing-library/react';
import { usePlayerMovement } from '@/components/game/player/usePlayerMovement';
import { useGameStore } from '@/stores/gameStore';

describe('usePlayerMovement', () => {
  beforeEach(() => {
    // Reset store before each test
    useGameStore.setState(useGameStore.getInitialState());
  });

  test('should return current position', () => {
    const { result } = renderHook(() => usePlayerMovement());

    expect(result.current.position).toBeDefined();
  });

  test('should update position when move is called', () => {
    const { result } = renderHook(() => usePlayerMovement());

    act(() => {
      result.current.move({ x: 1, y: 0, z: 0 });
    });

    // Assert position changed
  });
});
```

### 5. ECS Component Testing

```typescript
// src/ecs/components/Position.ts
export class Position {
  constructor(
    public x: number = 0,
    public y: number = 0,
    public z: number = 0
  ) {}

  equals(other: Position): boolean {
    return this.x === other.x && this.y === other.y && this.z === other.z;
  }
}

// src/tests/ecs/components/Position.test.ts
import { describe, test, expect } from 'vitest';
import { Position } from '@/ecs/components/Position';

describe('Position', () => {
  test('should create default position at origin', () => {
    const position = new Position();

    expect(position.x).toBe(0);
    expect(position.y).toBe(0);
    expect(position.z).toBe(0);
  });

  test('should create position with coordinates', () => {
    const position = new Position(1, 2, 3);

    expect(position.x).toBe(1);
    expect(position.y).toBe(2);
    expect(position.z).toBe(3);
  });

  test('should compare positions correctly', () => {
    const pos1 = new Position(1, 2, 3);
    const pos2 = new Position(1, 2, 3);
    const pos3 = new Position(4, 5, 6);

    expect(pos1.equals(pos2)).toBe(true);
    expect(pos1.equals(pos3)).toBe(false);
  });
});
```

### 6. ECS System Testing

```typescript
// src/ecs/systems/MovementSystem.ts
export class MovementSystem {
  update(entities: Entity[], deltaTime: number): void {
    for (const entity of entities) {
      const position = entity.get(Position);
      const velocity = entity.get(Velocity);

      if (position && velocity) {
        position.x += velocity.x * deltaTime;
        position.y += velocity.y * deltaTime;
        position.z += velocity.z * deltaTime;
      }
    }
  }
}

// src/tests/ecs/systems/MovementSystem.test.ts
import { describe, test, expect, beforeEach } from 'vitest';
import { MovementSystem } from '@/ecs/systems/MovementSystem';
import { Entity } from '@/ecs/Entity';
import { Position } from '@/ecs/components/Position';
import { Velocity } from '@/ecs/components/Velocity';

describe('MovementSystem', () => {
  let system: MovementSystem;

  beforeEach(() => {
    system = new MovementSystem();
  });

  test('should update position based on velocity', () => {
    const entity = new Entity();
    entity.add(new Position(0, 0, 0));
    entity.add(new Velocity(1, 2, 3));

    system.update([entity], 1);

    const position = entity.get(Position);
    expect(position?.x).toBe(1);
    expect(position?.y).toBe(2);
    expect(position?.z).toBe(3);
  });

  test('should apply deltaTime to movement', () => {
    const entity = new Entity();
    entity.add(new Position(0, 0, 0));
    entity.add(new Velocity(10, 0, 0));

    system.update([entity], 0.5);

    const position = entity.get(Position);
    expect(position?.x).toBe(5); // 10 * 0.5
  });

  test('should skip entities without velocity', () => {
    const entity = new Entity();
    entity.add(new Position(0, 0, 0));

    system.update([entity], 1);

    const position = entity.get(Position);
    expect(position?.x).toBe(0);
  });
});
```

## Mocking with Vitest

### Mocking External Modules

```typescript
// src/services/NetworkManager.ts
import { Colyseus } from 'colyseus.js';

export class NetworkManager {
  async connect(): Promise<void> {
    const client = new Colyseus.Client('ws://localhost:2567');
    // ...
  }
}

// src/tests/services/NetworkManager.test.ts
import { describe, test, expect, vi, beforeEach } from 'vitest';
import { NetworkManager } from '@/services/NetworkManager';

// Mock the Colyseus module
vi.mock('colyseus.js', () => ({
  Colyseus: {
    Client: vi.fn(() => ({
      joinOrCreate: vi.fn(),
      onMessage: vi.fn(),
    })),
  },
}));

describe('NetworkManager', () => {
  test('should connect to server', async () => {
    const manager = new NetworkManager();
    await manager.connect();

    // Assert connection was attempted
  });
});
```

### Mocking Functions

```typescript
import { vi, describe, test, expect } from 'vitest';

describe('with mocked function', () => {
  test('should track calls', () => {
    const mockFn = vi.fn();

    mockFn('hello');
    mockFn('world');

    expect(mockFn).toHaveBeenCalledTimes(2);
    expect(mockFn).toHaveBeenCalledWith('hello');
    expect(mockFn).toHaveBeenLastCalledWith('world');
  });

  test('should return mock value', () => {
    const mockFn = vi.fn().mockReturnValue(42);

    expect(mockFn()).toBe(42);
  });

  test('should return different values', () => {
    const mockFn = vi.fn()
      .mockReturnValueOnce(1)
      .mockReturnValueOnce(2)
      .mockReturnValue(3);

    expect(mockFn()).toBe(1);
    expect(mockFn()).toBe(2);
    expect(mockFn()).toBe(3);
  });
});
```

## Test Data Factories

```typescript
// src/tests/helpers/testData.ts
export class TestDataFactory {
  static player(overrides?: Partial<Player>): Player {
    return {
      id: 'test-player-' + Math.random(),
      name: 'Test Player',
      team: 'orange',
      position: { x: 0, y: 0, z: 0 },
      rotation: { x: 0, y: 0, z: 0 },
      ...overrides,
    };
  }

  static position(overrides?: Partial<Position>): Position {
    return {
      x: 0,
      y: 0,
      z: 0,
      ...overrides,
    };
  }

  static velocity(overrides?: Partial<Velocity>): Velocity {
    return {
      x: 0,
      y: 0,
      z: 0,
      ...overrides,
    };
  }
}

// Usage in tests
import { TestDataFactory } from '@/tests/helpers/testData';

describe('PlayerEntity', () => {
  test('should create player with data', () => {
    const playerData = TestDataFactory.player({ name: 'Custom Name' });
    const entity = PlayerEntity.create(playerData);

    expect(entity.get(Player)?.name).toBe('Custom Name');
  });
});
```

## Test Organization

### Nested Describe Blocks

```typescript
describe('ShootingService', () => {
  describe('calculateHit', () => {
    test('should hit target in range', () => {});
    test('should miss target out of range', () => {});
  });

  describe('applyDamage', () => {
    test('should reduce health', () => {});
    test('should not reduce below zero', () => {});
  });
});
```

### Test Setup with beforeEach

```typescript
describe('Entity', () => {
  let entity: Entity;
  let position: Position;
  let velocity: Velocity;

  beforeEach(() => {
    entity = new Entity();
    position = new Position(0, 0, 0);
    velocity = new Velocity(1, 0, 0);
  });

  test('should add component', () => {
    entity.add(position);
    expect(entity.has(Position)).toBe(true);
  });

  test('should get component', () => {
    entity.add(position);
    expect(entity.get(Position)).toBe(position);
  });
});
```

## Common Matchers

```typescript
// Equality
expect(value).toBe(expected);           // Strict equality (===)
expect(value).toEqual(expected);        // Deep equality
expect(value).toStrictEqual(expected);  // Deep strict equality

// Truthiness
expect(value).toBeTruthy();
expect(value).toBeFalsy();
expect(value).toBeDefined();
expect(value).toBeUndefined();
expect(value).toBeNull();

// Numbers
expect(value).toBeGreaterThan(5);
expect(value).toBeLessThan(10);
expect(value).toBeCloseTo(0.1, 1);  // Approximate

// Strings
expect(value).toMatch(/regex/);
expect(value).toContain('substring');

// Arrays
expect(array).toHaveLength(3);
expect(array).toContain(item);
expect(array).toEqual(expect.arrayContaining([item1, item2]));

// Objects
expect(object).toHaveProperty('key');
expect(object).toMatchObject({ key: 'value' });

// Functions
expect(fn).toHaveBeenCalled();
expect(fn).toHaveBeenCalledTimes(3);
expect(fn).toHaveBeenCalledWith(arg1, arg2);
expect(fn).toHaveBeenLastCalledWith(lastArg);

// Async
await expect(promise).resolves.toBe(value);
await expect(promise).rejects.toThrow(error);
```

## Running Tests

```bash
# Run all tests
npm run test

# Run in watch mode
npm run test -- --watch

# Run specific file
npm run test -- src/tests/components/game/player/index.test.ts

# Run with coverage
npm run test -- --coverage

# Run only tests matching pattern
npm run test -- --grep "ShootingService"
```

## Best Practices

1. **One assertion per test** - Tests should verify one thing
2. **Descriptive names** - Test names should explain what is being tested
3. **Arrange-Act-Assert** - Follow this pattern consistently
4. **Test edge cases** - Empty inputs, null, undefined, boundary values
5. **Mock external dependencies** - Don't make network calls in unit tests
6. **Keep tests fast** - Unit tests should run in milliseconds
7. **Use beforeEach** - Set up clean state for each test
8. **Test behavior, not implementation** - Test what the code does, not how

## References

- [Vitest Documentation](https://vitest.dev/)
- [Testing Library](https://testing-library.com/)
- [server/vitest.config.ts](server/vitest.config.ts) - Vitest configuration
- [qa-e2e-test-creation](.claude/skills/qa-e2e-test-creation/SKILL.md) - E2E test patterns
