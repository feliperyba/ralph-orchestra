---
name: dev-phaser-fundamentals
description: Phaser game configuration, scenes, and lifecycle management
---

# Phaser Fundamentals

> "2D web games made simple – scenes, sprites, and physics."

## When to Use This Skill

Use when:

- Setting up a new Phaser game
- Creating game scenes
- Implementing the scene lifecycle (preload/create/update)
- Configuring game settings (scale, physics, renderer)
- Setting up the game container and canvas

## Quick Start

```typescript
import Phaser from "phaser";
import { MainScene } from "./scenes/MainScene";

const config: Phaser.Types.Core.GameConfig = {
  type: Phaser.AUTO,
  width: 800,
  height: 600,
  parent: "game-container",
  backgroundColor: "#000000",
  scale: {
    mode: Phaser.Scale.FIT,
    autoCenter: Phaser.Scale.CENTER_BOTH,
  },
  physics: {
    default: "arcade",
    arcade: {
      gravity: { y: 300 },
      debug: false,
    },
  },
  scene: [MainScene],
};

new Phaser.Game(config);
```

## Before/After: Manual DOM vs Phaser Pattern

### ❌ Before: Manual DOM Manipulation

```typescript
// Manual game loop without Phaser
const canvas = document.getElementById("game") as HTMLCanvasElement;
const ctx = canvas.getContext("2d")!;

let playerX = 400;
let playerY = 300;

// Manual asset loading
const playerImg = new Image();
playerImg.src = "assets/player.png";
playerImg.onload = () => {
  gameLoop();
};

// Manual game loop
function gameLoop() {
  // Clear canvas
  ctx.clearRect(0, 0, canvas.width, canvas.height);

  // Draw player
  ctx.drawImage(playerImg, playerX, playerY);

  // Handle input manually
  document.addEventListener("keydown", (e) => {
    if (e.key === "ArrowLeft") playerX -= 5;
    // ... more manual input handling
  });

  requestAnimationFrame(gameLoop);
}
```

**Problems:**
- Manual asset loading (no preload queue)
- No sprite management
- Manual collision detection
- No physics engine
- Scene management is manual

### ✅ After: Phaser Pattern

```typescript
// Phaser handles everything
export class GameScene extends Phaser.Scene {
  private player!: Phaser.Physics.Arcade.Sprite;

  preload() {
    // Built-in asset loading with progress tracking
    this.load.image("player", "assets/player.png");
  }

  create() {
    // Physics-enabled sprite
    this.player = this.physics.add.sprite(400, 300, "player");

    // Built-in input handling
    this.cursors = this.input.keyboard!.createCursorKeys();
  }

  update() {
    // Frame-independent movement
    if (this.cursors.left!.isDown) {
      this.player.setVelocityX(-160);
    }
    // Built-in physics handles position updates
  }
}

const config = {
  // Phaser manages the game loop, canvas, rendering
  scene: [GameScene],
  physics: { default: "arcade" },
};

new Phaser.Game(config);
```

**Benefits:**
- Asset preloading with progress events
- Built-in physics engine
- Scene lifecycle management
- Input handling abstraction
- Optimized rendering pipeline

## Decision Framework

| Need               | Use                                   |
| ------------------ | ------------------------------------- |
| Basic 2D game      | `Phaser.AUTO` renderer type           |
| Physics platformer | Arcade physics with gravity           |
| Physics puzzle     | Matter physics for realism            |
| Responsive layout  | `Phaser.Scale.FIT` with `CENTER_BOTH` |
| Multiple scenes    | Array of scene classes in config      |

## Progressive Guide

### Level 1: Basic Scene Setup

```typescript
export class MainScene extends Phaser.Scene {
  constructor() {
    super({ key: "MainScene" });
  }

  preload() {
    // Load assets before create()
    this.load.image("player", "assets/player.png");
    this.load.image("background", "assets/bg.png");
  }

  create() {
    // Create game objects
    this.add.image(400, 300, "background");
    this.player = this.physics.add.sprite(400, 300, "player");
  }

  update(time: number, delta: number) {
    // Game loop (60fps)
    // delta = time since last frame in ms
  }
}
```

### Level 2: Scene Configuration with Data

```typescript
export class GameScene extends Phaser.Scene {
  constructor() {
    super({ key: "GameScene", active: false });
  }

  init(data: { level: number; score: number }) {
    // Receive data from previous scene
    this.level = data.level || 1;
    this.score = data.score || 0;
  }

  preload() {
    // Load level-specific assets
    this.load.image(`level${this.level}`, `assets/level${this.level}.png`);
  }

  create() {
    // Setup game objects
    this.createPlayer();
    this.createEnemies();
  }

  update(time: number, delta: number) {
    this.updatePlayer();
    this.updateEnemies();
  }
}
```

### Level 3: Game Config with Multiple Scenes

```typescript
const config: Phaser.Types.Core.GameConfig = {
  type: Phaser.AUTO,
  width: 800,
  height: 600,
  parent: "game-container",
  backgroundColor: "#2d2d2d",
  scale: {
    mode: Phaser.Scale.FIT,
    autoCenter: Phaser.Scale.CENTER_BOTH,
    width: 800,
    height: 600,
  },
  physics: {
    default: "arcade",
    arcade: {
      gravity: { x: 0, y: 1000 },
      debug: false,
    },
  },
  scene: [BootScene, PreloadScene, TitleScene, GameScene, UIScene],
  pipeline: { CustomPipeline: CustomPipeline },
};
```

### Level 4: Custom Game Config Extension

```typescript
interface ExtendedGameConfig extends Phaser.Types.Core.GameConfig {
  customSettings: {
    maxPlayers: number;
    gameMode: "deathmatch" | "capture";
  };
}

class CustomGame extends Phaser.Game {
  constructor(config: ExtendedGameConfig) {
    super(config);
    this.customSettings = config.customSettings;
  }
}
```

### Level 5: Scene Manager Control

```typescript
export class MainScene extends Phaser.Scene {
  create() {
    // Scene transitions
    this.scene.start("GameScene", { level: 1 });

    // Launch parallel scene (UI overlay)
    this.scene.launch("UIScene");

    // Pause current scene
    this.scene.pause();

    // Sleep scene (stops update but keeps rendering)
    this.scene.sleep("BackgroundScene");

    // Stop and remove scene
    this.scene.stop("OldScene");
  }
}
```

## Anti-Patterns

❌ **DON'T:**

- Load assets in `create()` - use `preload()`
- Create new objects in `update()` - causes GC pressure
- Use `this.scene.restart()` frequently - expensive operation
- Forget to call `super()` in scene constructor
- Use hardcoded screen dimensions - use scale manager
- Mix physics and non-physics objects without planning

✅ **DO:**

- Preload all assets in `preload()` before use
- Reuse objects with object pooling in `update()`
- Use scene data for passing values between scenes
- Clean up event listeners in `shutdown()` method
- Use `scale.manager` for responsive sizing
- Group related game objects with `this.add.group()`

## Code Patterns

### Scene Lifecycle Management

```typescript
export class GameScene extends Phaser.Scene {
  private player!: Phaser.Physics.Arcade.Sprite;
  private enemies!: Phaser.GameObjects.Group;
  private cursors!: Phaser.Types.Input.Keyboard.CursorKeys;

  constructor() {
    super({ key: "GameScene" });
  }

  create() {
    // Always setup shutdown for cleanup
    this.events.once(Phaser.Scenes.Events.SHUTDOWN, this.shutdown, this);
  }

  shutdown() {
    // Clean up listeners
    this.input.keyboard!.off("keydown-ESC");
  }

  update(time: number, delta: number) {
    // Use delta for frame-independent movement
    const dt = delta / 1000; // Convert to seconds
  }
}
```

### Scale Manager Pattern

```typescript
const config: Phaser.Types.Core.GameConfig = {
  scale: {
    mode: Phaser.Scale.FIT,
    autoCenter: Phaser.Scale.CENTER_BOTH,
    width: 800,
    height: 600,
  },
};

// In scene, get scale info
this.scale.width; // Actual canvas width
this.scale.height; // Actual canvas height
```

## Checklist

Before completing Phaser setup:

- [ ] Game config has proper scale settings
- [ ] Physics configured correctly (arcade or matter)
- [ ] Scene keys are unique
- [ ] Assets preloaded before use in create()
- [ ] Update loop is performant (no object creation)
- [ ] Shutdown handlers for cleanup
- [ ] Responsive scaling configured
- [ ] Scene transitions use proper data passing

## Common Issues

| Issue               | Solution                                 |
| ------------------- | ---------------------------------------- |
| Assets not loading  | Check `preload()` runs before `create()` |
| Physics not working | Verify physics config and body type      |
| Scene not updating  | Check scene is `active: true`            |
| Canvas size wrong   | Configure scale manager                  |
| Memory leaks        | Clean up in `shutdown()`                 |

## JSON Level Data Loading

### Loading Level Data from JSON

Phaser 3 provides built-in support for loading JSON files containing level data:

```typescript
// In preload(), load the JSON file
preload() {
  // Load individual level files
  this.load.json('level001', 'data/levels/level001.json');

  // Load level index
  this.load.json('levels', 'data/levels.json');
}

// In create(), access the loaded data
create() {
  // Get level index
  const levelsIndex = this.cache.json.get('levels');
  console.log('Available levels:', levelsIndex.levels);

  // Get specific level data
  const level001Data = this.cache.json.get('level001');
  console.log('Level 1 pigs:', level001Data.pigs);

  // Use the data to spawn objects
  level001Data.pigs.forEach(pigData => {
    this.spawnPig(pigData.x, pigData.y, pigData.type);
  });

  level001Data.blocks.forEach(blockData => {
    this.spawnBlock(blockData.x, blockData.y, blockData.material);
  });
}
```

### JSON Schema Validation (TypeScript)

For type-safe JSON level loading, use Ajv for runtime validation:

```typescript
import Ajv, { JSONSchemaType } from 'ajv';

// Define your level schema
interface LevelData {
  id: string;
  name: string;
  birds: string[];
  pigs: Array<{ x: number; y: number; type: string }>;
  blocks: Array<{ x: number; y: number; material: string; rotation: number }>;
  starThresholds: { one: number; two: number; three: number };
}

const levelSchema: JSONSchemaType<LevelData> = {
  type: 'object',
  required: ['id', 'name', 'birds', 'pigs', 'blocks', 'starThresholds'],
  properties: {
    id: { type: 'string' },
    name: { type: 'string' },
    birds: { type: 'array', items: { type: 'string' } },
    pigs: {
      type: 'array',
      items: {
        type: 'object',
        required: ['x', 'y', 'type'],
        properties: {
          x: { type: 'number' },
          y: { type: 'number' },
          type: { type: 'string' }
        }
      }
    },
    blocks: {
      type: 'array',
      items: {
        type: 'object',
        required: ['x', 'y', 'material', 'rotation'],
        properties: {
          x: { type: 'number' },
          y: { type: 'number' },
          material: { type: 'string' },
          rotation: { type: 'number' }
        }
      }
    },
    starThresholds: {
      type: 'object',
      required: ['one', 'two', 'three'],
      properties: {
        one: { type: 'number' },
        two: { type: 'number' },
        three: { type: 'number' }
      }
    }
  }
};

// Validate before using
const ajv = new Ajv();
const validate = ajv.compile(levelSchema);

const levelData = this.cache.json.get('level001');
if (!validate(levelData)) {
  console.error('Invalid level data:', validate.errors);
  throw new Error('Level validation failed');
}
```

### Plugin-Based Asset Loading

For dynamic level loading at runtime, use Phaser's plugin system:

```typescript
class LevelLoaderPlugin extends Phaser.Plugins.BasePlugin {
  constructor(pluginManager: Phaser.Plugins.PluginManager) {
    super(pluginManager);
  }

  async loadLevel(levelId: string): Promise<any> {
    const scene = this.scene;
    const response = await fetch(`data/levels/${levelId}.json`);
    const levelData = await response.json();

    // Validate schema
    if (!this.validateLevel(levelData)) {
      throw new Error(`Invalid level data for ${levelId}`);
    }

    return levelData;
  }

  private validateLevel(data: any): boolean {
    // Schema validation logic
    return true;
  }
}
```

### Best Practices for JSON Level Data

1. **Always validate JSON structure** - Use Ajv or similar for runtime validation
2. **Use TypeScript interfaces** - Define types matching your JSON structure
3. **Cache loaded data** - Use Phaser's cache system to avoid re-loading
4. **Handle errors gracefully** - Provide fallback or error messages on load failure
5. **Use consistent naming** - Follow a pattern for level IDs and file names

## Common Issues

| Issue               | Solution                                 |
| ------------------- | ---------------------------------------- |
| Assets not loading  | Check `preload()` runs before `create()` |
| Physics not working | Verify physics config and body type      |
| Scene not updating  | Check scene is `active: true`            |
| Canvas size wrong   | Configure scale manager                  |
| Memory leaks        | Clean up in `shutdown()`                 |
| JSON not loading    | Verify file path and file extension      |
| Invalid level data  | Add schema validation with Ajv           |

## Reference

- [Phaser 3 Documentation](https://photonstorm.github.io/phaser3-docs/) — Official API docs
- [Phaser Examples](https://phaser.io/examples) — Code examples
- [Phaser TypeScript Types](https://github.com/photonstorm/phaser/tree/master/types) — Type definitions
- [Ajv - JSON Schema Validator](https://ajv.js.org/) — TypeScript-first JSON validation
- [Phaser JSON Loading](https://photonstorm.github.io/phaser3-docs/Phaser.Cache.BaseCache.html#get__anchor) — Cache API for JSON data
