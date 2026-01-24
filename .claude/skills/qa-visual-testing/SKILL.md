---
name: qa-visual-testing
description: Visual regression testing and image-based validation using Vision MCP and Playwright
category: validation
---

# Visual Testing Skill

> "Visual validation catches bugs that functional tests miss."

## When to Use This Skill

Use for **every game feature validation** to:

- Compare screenshots against baseline images
- Detect game states (menu, playing, game over, win)
- Validate UI elements (HUD, health bars, buttons)
- Verify visual appearance matches design specifications

## Quick Start

```javascript
// Capture screenshot
await page.screenshot({ path: 'playwright-test/validation.png' });

// Detect game state using Vision MCP
const gameState = await detectGameState('playwright-test/validation.png');

// Compare with baseline
await expect(page).toHaveScreenshot('baseline.png', {
  maxDiffPixelRatio: 0.01,
});
```

---

## Game State Detection

### Detecting Game States

Use Vision MCP to analyze screenshots and determine current game state:

```javascript
// Detect game state from screenshot
async function detectGameState(screenshotPath) {
  const analysis = await visionAnalyze(screenshotPath, {
    prompt: `Analyze this game screenshot and determine:
    1. Is this a menu screen, gameplay, game over, victory, or loading screen?
    2. What UI elements are visible? (HUD, health bar, minimap, inventory, etc.)
    3. Is a player character visible?
    4. Are there any error messages or alerts?

    Respond in JSON format:
    {
      "state": "menu|playing|gameover|win|loading|error",
      "uiElements": ["hud", "healthBar", "minimap", ...],
      "playerVisible": true|false,
      "details": "description"
    }`,
  });

  return JSON.parse(analysis);
}

// Usage
const state = await detectGameState('screenshot.png');
console.log(state.state); // "playing"
console.log(state.uiElements); // ["hud", "healthBar", "minimap"]
```

### State-Specific Validation

```javascript
// Menu state validation
async function validateMenuState(screenshotPath) {
  const analysis = await visionAnalyze(screenshotPath, {
    prompt: `This should be a main menu screen. Check for:
    1. Game title or logo visible
    2. Menu buttons (Start, Settings, Quit, etc.)
    3. No gameplay elements visible

    Return { "valid": true|false, "issues": ["list of issues"] }`,
  });

  return JSON.parse(analysis);
}

// Gameplay state validation
async function validateGameplayState(screenshotPath) {
  const analysis = await visionAnalyze(screenshotPath, {
    prompt: `This should be active gameplay. Check for:
    1. Player character is visible
    2. HUD elements present (health, ammo, minimap if applicable)
    3. Game world is rendered (not a menu)

    Return { "valid": true|false, "issues": ["list of issues"] }`,
  });

  return JSON.parse(analysis);
}

// Game over state validation
async function validateGameOverState(screenshotPath) {
  const analysis = await visionAnalyze(screenshotPath, {
    prompt: `This should be a game over screen. Check for:
    1. "Game Over" or similar text visible
    2. Score summary visible
    3. Restart/continue button visible

    Return { "valid": true|false, "issues": ["list of issues"] }`,
  });

  return JSON.parse(analysis);
}
```

---

## Baseline Management

### Creating Baselines

```javascript
// Capture baseline screenshots for each game state
async function createBaselines(page, taskId) {
  const baselineDir = `tests/baselines/${taskId}`;

  // Menu baseline
  await page.goto('http://localhost:3000');
  await page.waitForTimeout(2000);
  await page.screenshot({ path: `${baselineDir}/menu.png` });

  // Gameplay baseline
  await page.click('canvas');
  await page.keyboard.press('Enter'); // Start game
  await page.waitForTimeout(1000);
  await page.screenshot({ path: `${baselineDir}/playing.png` });

  // Game over baseline (trigger game over)
  await page.keyboard.press('KeyK'); // Suicide command if available
  await page.waitForTimeout(2000);
  await page.screenshot({ path: `${baselineDir}/gameover.png` });
}
```

### Comparing Against Baselines

```javascript
// Pixel-perfect comparison with Playwright
async function compareWithBaseline(page, baselinePath, options = {}) {
  const screenshot = await page.screenshot();

  // Use Playwright's built-in comparison
  const comparison = await compareImages(screenshot, baselinePath, {
    maxDiffPixelRatio: options.threshold || 0.01,
    maxDiffPixels: options.maxPixels || 1000,
  });

  return {
    matches: comparison.diffPixels < (options.maxPixels || 1000),
    diffPixels: comparison.diffPixels,
    diffRatio: comparison.diffPixelRatio,
  };
}

// Semantic comparison with Vision MCP
async function compareSemantic(currentPath, baselinePath) {
  const comparison = await visionAnalyze([baselinePath, currentPath], {
    prompt: `Compare these two game screenshots.
    Image 1 is the baseline (expected).
    Image 2 is the current (actual).

    Determine:
    1. Are they showing the same game state?
    2. What are the visual differences?
    3. Are the differences acceptable (animation, dynamic content) or bugs?

    Return { "sameState": true|false, "differences": ["list"], "acceptable": true|false }`,
  });

  return JSON.parse(comparison);
}
```

---

## UI Element Validation

### HUD Detection

```javascript
// Validate HUD elements are present
async function validateHUD(screenshotPath) {
  const analysis = await visionAnalyze(screenshotPath, {
    prompt: `Check if this gameplay screenshot has the required HUD elements:
    1. Health bar - is it visible? What percentage is it showing?
    2. Score/counter - is it visible?
    3. Minimap (if applicable) - is it visible?
    4. Ammo count (if applicable) - is it visible?

    Return {
      "healthBar": { "visible": true|false, "value": "percentage" },
      "score": { "visible": true|false, "value": "number" },
      "minimap": { "visible": true|false },
      "ammo": { "visible": true|false, "value": "count" }
    }`,
  });

  return JSON.parse(analysis);
}
```

### Button Detection

```javascript
// Validate menu buttons are present and visible
async function validateMenuButtons(screenshotPath, expectedButtons) {
  const analysis = await visionAnalyze(screenshotPath, {
    prompt: `Check if this menu screenshot has the following buttons:
    ${expectedButtons.join(', ')}

    For each button, return:
    - "visible": true|false
    - "enabled": true|false (can you tell if it's grayed out?)
    - "position": "top|middle|bottom" (approximate)

    Return {
      "buttons": {
        "Play": { "visible": true|false, "enabled": true|false, "position": "..." },
        "Settings": { ... },
        ...
      }
    }`,
  });

  return JSON.parse(analysis);
}
```

### Character Detection

```javascript
// Validate player character is visible and correct
async function validatePlayerCharacter(screenshotPath) {
  const analysis = await visionAnalyze(screenshotPath, {
    prompt: `In this gameplay screenshot:
    1. Is a player character visible?
    2. What is the character doing? (idle, running, jumping, attacking)
    3. Is the character facing the expected direction?
    4. Are there any visual glitches with the character?

    Return {
      "visible": true|false,
      "action": "idle|running|jumping|attacking|...",
      "facing": "left|right|up|down",
      "issues": ["list of visual problems if any"]
    }`,
  });

  return JSON.parse(analysis);
}
```

---

## Visual Regression Testing

### Full Workflow

```javascript
// Complete visual regression test
async function runVisualRegression(page, taskId) {
  const baselineDir = `tests/baselines/${taskId}`;
  const currentDir = `playwright-test/${taskId}`;
  const results = [];

  // Define states to test
  const states = ['menu', 'playing', 'gameover'];

  for (const state of states) {
    const baselinePath = `${baselineDir}/${state}.png`;
    const currentPath = `${currentDir}/${state}.png`;

    // Capture current state
    await navigateToState(page, state);
    await page.screenshot({ path: currentPath });

    // Pixel comparison
    const pixelResult = await compareWithBaseline(page, baselinePath, {
      threshold: 0.01,
      maxPixels: 1000,
    });

    // Semantic comparison
    const semanticResult = await compareSemantic(currentPath, baselinePath);

    results.push({
      state,
      pixelMatch: pixelResult.matches,
      diffPixels: pixelResult.diffPixels,
      semanticMatch: semanticResult.sameState,
      differences: semanticResult.differences,
    });
  }

  return results;
}
```

### Tolerance Guidelines

| Scenario              | Max Diff Ratio | Max Pixels |
| --------------------- | -------------- | ---------- |
| Static UI (menus)     | 0.001          | 100        |
| Gameplay (animations) | 0.05           | 5000       |
| Particle effects      | 0.10           | 10000      |
| Text content          | 0.0001         | 10         |

---

## GDD Compliance Validation

### Validate Against Design Specs

```javascript
// Validate visuals match GDD description
async function validateAgainstGDD(screenshotPath, gddDescription) {
  const analysis = await visionAnalyze(screenshotPath, {
    prompt: `According to the Game Design Document:
    "${gddDescription}"

    Does this screenshot match that description?
    Check:
    1. Overall visual style matches
    2. Required elements are present
    3. Colors/theme are correct
    4. Layout matches specification

    Return {
      "matches": true|false,
      "deviations": [
        { "element": "name", "expected": "description", "actual": "what you see" }
      ],
      "overall": "accurate|minor-deviations|major-deviations"
    }`,
  });

  return JSON.parse(analysis);
}

// Example usage
const characterGDD = 'A knight in silver armor with a blue cape, holding a broadsword';
const result = await validateAgainstGDD('screenshot.png', characterGDD);
```

---

## 3D Asset Visual Regression

### Testing 3D Models and Materials

3D assets require specialized visual validation beyond 2D UI testing:

```javascript
// Validate 3D model appearance from multiple angles
async function validate3DAsset(page, assetName) {
  const angles = [
    { name: 'front', rotation: [0, 0, 0] },
    { name: 'side', rotation: [0, Math.PI / 2, 0] },
    { name: 'top', rotation: [Math.PI / 2, 0, 0] },
    { name: 'iso', rotation: [Math.PI / 4, Math.PI / 4, 0] },
  ];

  const results = [];

  for (const angle of angles) {
    // Rotate camera to viewing angle
    await page.evaluate((rot) => {
      // Assuming camera control via global or exposed API
      window.gameCamera?.setPosition(rot[0], rot[1], rot[2]);
    }, angle.rotation);

    await page.waitForTimeout(500); // Let render settle

    // Screenshot from this angle
    const path = `validation/${assetName}-${angle.name}.png`;
    await page.screenshot({ path });

    // Analyze asset visibility
    const analysis = await visionAnalyze(path, {
      prompt: `Analyze this 3D model screenshot:
      1. Is the ${assetName} model fully visible?
      2. Are there any visual artifacts (clipping, z-fighting, missing textures)?
      3. Is the material rendering correctly (normal maps, specular, roughness)?
      4. Are there any lighting issues (too dark, overexposed)?

      Return {
        "visible": true|false,
        "artifacts": ["list of issues"],
        "material": "correct|incorrect",
        "lighting": "good|bad",
        "overall": "pass|fail"
      }`,
    });

    results.push({ angle: angle.name, ...JSON.parse(analysis) });
  }

  return results;
}
```

### Paint Projectile Visual Validation

```javascript
// Validate paint projectile appearance specifically
async function validatePaintProjectiles(page) {
  // Trigger shooting
  await page.mouse.click(400, 300); // Center of canvas

  // Capture during flight
  await page.waitForTimeout(100);
  const flightScreenshot = 'validation/projectile-flight.png';
  await page.screenshot({ path: flightScreenshot });

  // Capture impact
  await page.waitForTimeout(500);
  const impactScreenshot = 'validation/projectile-impact.png';
  await page.screenshot({ path: impactScreenshot });

  // Validate projectile visibility
  const flightAnalysis = await visionAnalyze(flightScreenshot, {
    prompt: `Check for paint projectile in flight:
    1. Is a visible sphere/projectile in the air?
    2. Does it have team color (orange or blue)?
    3. Is there a glow/emissive effect?
    4. Is there a trail effect behind it?

    Return {
      "visible": true|false,
      "teamColor": "orange|blue|none",
      "glow": true|false,
      "trail": true|false,
      "issues": ["any problems"]
    }`,
  });

  // Validate decal at impact
  const impactAnalysis = await visionAnalyze(impactScreenshot, {
    prompt: `Check for paint decal at impact point:
    1. Is a paint splat visible on the surface?
    2. Is it the correct team color?
    3. Does it look like wet paint (shiny/glossy)?
    4. Is it properly oriented on the surface?

    Return {
      "visible": true|false,
      "teamColor": "orange|blue|none",
      "wetLook": true|false,
      "orientation": "correct|incorrect",
      "issues": ["any problems"]
    }`,
  });

  return {
    projectile: JSON.parse(flightAnalysis),
    decal: JSON.parse(impactAnalysis),
  };
}
```

### Character Model Validation

```javascript
// Validate character model in gameplay
async function validateCharacterModel(page, characterType) {
  // Navigate to gameplay
  await page.goto('http://localhost:3000');
  await completeCharacterSelection(page, characterType);
  await startGame(page);

  await page.waitForTimeout(2000); // Let character spawn

  const screenshot = `validation/character-${characterType}.png`;
  await page.screenshot({ path: screenshot });

  const analysis = await visionAnalyze(screenshot, {
    prompt: `Validate the character model for ${characterType}:
    1. Is the correct character model visible? (not a placeholder box/cylinder)
    2. Is the model textured? (not gray/pink default material)
    3. Is the model scaled correctly relative to the environment?
    4. Are animations playing? (check for pose variation)
    5. Are there any clipping issues with the environment?

    Return {
      "correctModel": true|false,
      "textured": true|false,
      "scaled": true|false,
      "animating": true|false,
      "clipping": ["list of clipping issues"],
      "overall": "pass|fail"
    }`,
  });

  return JSON.parse(analysis);
}
```

### Weapon Model Validation

```javascript
// Validate weapon attached to character
async function validateWeaponModel(page, weaponType) {
  const screenshot = `validation/weapon-${weaponType}.png`;
  await page.screenshot({ path: screenshot });

  const analysis = await visionAnalyze(screenshot, {
    prompt: `Check the weapon model attached to the character:
    1. Is a weapon visible in/near the character's hand?
    2. Is it the correct weapon type? (${weaponType})
    3. Is it a proper 3D model? (not placeholder geometry)
    4. Is it positioned correctly? (grip alignment, not floating)
    5. Does it move with character animation?

    Return {
      "visible": true|false,
      "correctType": true|false,
      "is3DModel": true|false,
      "position": "correct|floating|misaligned",
      "followsAnimation": true|false,
      "issues": ["any problems"]
    }`,
  });

  return JSON.parse(analysis);
}
```

### Terrain Shader Validation

```javascript
// Validate raymarching terrain appearance
async function validateTerrainShader(page) {
  // Look at ground/terrain
  await page.evaluate(() => {
    window.gameCamera?.lookAt(0, 0, 0); // Look at terrain center
  });

  const screenshot = 'validation/terrain-shader.png';
  await page.screenshot({ path: screenshot });

  const analysis = await visionAnalyze(screenshot, {
    prompt: `Validate the raymarching terrain shader:
    1. Is the terrain smooth? (not blocky/voxel-like)
    2. Are there visible height variations?
    3. Is paint visible on the terrain surface?
    4. Do team colors render correctly?
    5. Are there any shader artifacts? (flickering, seams, NaN pixels)

    Return {
      "smooth": true|false,
      "heightVariation": true|false,
      "paintVisible": true|false,
      "teamColors": "correct|incorrect",
      "artifacts": ["list of shader issues"],
      "overall": "pass|fail"
    }`,
  });

  return JSON.parse(analysis);
}
```

---

## Automated Shader Visual Regression Testing

### Why Shader Visual Tests Matter

Shaders (raymarching, GLSL, TSL) are critical for game visuals but difficult to test:

- **Code review isn't enough** - visual bugs may not be apparent from code
- **GPU rendering varies** - different GPUs may render differently
- **Shader errors are visual** - NaN pixels, incorrect normals, missing textures
- **Changes are subtle** - a wrong parameter (e.g., FrontSide vs BackSide) breaks everything

### Playwright Screenshot Baselines for Shaders

Use Playwright's built-in `toHaveScreenshot()` for automated visual regression:

```javascript
import { test, expect } from '@playwright/test';

test('terrain shader visual regression', async ({ page }) => {
  // Start dev server and navigate to game
  await page.goto('http://localhost:3000');
  await completeCharacterSelection(page);
  await startGame(page);

  // Wait for terrain to render
  await page.waitForTimeout(2000);

  // Position camera for consistent terrain view
  await page.evaluate(() => {
    // Access game camera if exposed globally
    if (window.gameCamera) {
      window.gameCamera.position.set(0, 10, 20);
      window.gameCamera.lookAt(0, 0, 0);
    }
  });

  // Wait for render to settle
  await page.waitForTimeout(500);

  // Compare against baseline - creates baseline on first run
  await expect(page).toHaveScreenshot('terrain-shader-baseline.png', {
    maxDiffPixels: 500, // Allow some GPU variation
    threshold: 0.02, // 2% pixel difference tolerance
  });
});
```

### Shader-Specific Test Configuration

```javascript
// playwright.config.ts - Shader testing settings
import { defineConfig } from '@playwright/test';

export default defineConfig({
  expect: {
    // Shader rendering has more GPU variation than DOM
    toHaveScreenshot: {
      maxDiffPixels: 1000, // Higher for shaders vs UI
      threshold: 0.05, // 5% tolerance for GPU differences
      animations: 'allow', // Allow minor animation differences
    },
  },

  // Use consistent viewport for shader tests
  use: {
    viewport: { width: 1920, height: 1080 },
  },

  // Projects for different rendering backends
  projects: [
    {
      name: 'chromium-webgl',
      use: { browserName: 'chromium' },
    },
    {
      name: 'firefox-webgl',
      use: { browserName: 'firefox' },
    },
  ],
});
```

### Multi-Angle Shader Validation

Shaders should be tested from multiple viewing angles:

```javascript
test('terrain shader from multiple angles', async ({ page }) => {
  await page.goto('http://localhost:3000');
  await startGame(page);
  await page.waitForTimeout(2000);

  const cameraPositions = [
    { name: 'front', pos: [0, 10, 20], target: [0, 0, 0] },
    { name: 'side', pos: [20, 10, 0], target: [0, 0, 0] },
    { name: 'top-down', pos: [0, 30, 5], target: [0, 0, 0] },
    { name: 'iso', pos: [15, 15, 15], target: [0, 0, 0] },
  ];

  for (const angle of cameraPositions) {
    // Position camera
    await page.evaluate(
      (pos, target) => {
        if (window.gameCamera) {
          window.gameCamera.position.set(...pos);
          window.gameCamera.lookAt(...target);
        }
      },
      angle.pos,
      angle.target
    );

    await page.waitForTimeout(300); // Let render settle

    // Screenshot with angle-specific name
    await expect(page).toHaveScreenshot(`terrain-${angle.name}.png`, {
      maxDiffPixels: 500,
      threshold: 0.02,
    });
  }
});
```

### LOD System Validation

For shaders with Level of Detail (LOD):

```javascript
test('terrain LOD transitions', async ({ page }) => {
  await page.goto('http://localhost:3000');
  await startGame(page);

  // Test near distance (high LOD)
  await page.evaluate(() => {
    if (window.gameCamera) {
      window.gameCamera.position.set(0, 5, 10);
    }
  });
  await page.waitForTimeout(300);
  await expect(page).toHaveScreenshot('terrain-lod-near.png', {
    maxDiffPixels: 800,
  });

  // Test far distance (low LOD)
  await page.evaluate(() => {
    if (window.gameCamera) {
      window.gameCamera.position.set(0, 20, 80);
    }
  });
  await page.waitForTimeout(300);
  await expect(page).toHaveScreenshot('terrain-lod-far.png', {
    maxDiffPixels: 800,
  });
});
```

### Paint Overlay Validation

Test shader paint/overlay integration:

```javascript
test('terrain paint overlay visibility', async ({ page }) => {
  await page.goto('http://localhost:3000');
  await startGame(page);

  // Screenshot before paint
  await page.evaluate(() => {
    if (window.gameCamera) {
      window.gameCamera.position.set(0, 10, 15);
      window.gameCamera.lookAt(0, 0, 0);
    }
  });
  await page.waitForTimeout(300);
  await expect(page).toHaveScreenshot('terrain-before-paint.png');

  // Shoot to create paint
  await page.mouse.click(960, 540); // Center screen
  await page.waitForTimeout(500);

  // Screenshot after paint
  await expect(page).toHaveScreenshot('terrain-after-paint.png', {
    maxDiffPixels: 2000, // Allow larger diff for new paint
  });

  // Verify paint visible via Vision MCP
  const screenshot = await page.screenshot();
  const analysis = await visionAnalyze(screenshot, {
    prompt: `Check for paint on terrain:
    1. Is there a colored splat/decal on the ground?
    2. What color is it? (orange or blue)
    3. Is it properly positioned on the surface?

    Return { visible: true|false, color: "orange|blue|none", issues: [] }`,
  });

  const result = JSON.parse(analysis);
  expect(result.visible).toBe(true);
  expect(['orange', 'blue']).toContain(result.color);
});
```

### Updating Shader Baselines

When shader changes are intentional (not bugs):

```bash
# Update all shader screenshot baselines
npx playwright test --update-snapshots

# Update specific test
npx playwright test terrain-shader.spec.ts --update-snapshots
```

### CI/CD Considerations

Shader visual tests in CI need stable GPU rendering:

```yaml
# .github/workflows/visual-tests.yml
name: Visual Regression Tests

on: [push, pull_request]

jobs:
  shader-tests:
    runs-on: ubuntu-latest
    container:
      image: mcr.microsoft.com/playwright:v1.48.0-jammy
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20

      - name: Install dependencies
        run: npm ci

      - name: Start dev server
        run: npm run dev:all:sh &
        env:
          CI: true

      - name: Wait for server
        run: npx wait-on http://localhost:3000

      - name: Run shader visual tests
        run: npx playwright test shader-visual.spec.ts

      - name: Upload screenshots
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: shader-screenshots
          path: test-results/
```

### Shader Visual Testing Checklist

For each shader feature:

- [ ] Baseline screenshots created from multiple angles
- [ ] Playwright `toHaveScreenshot()` tests written
- [ ] Threshold configured appropriately for GPU variation
- [ ] LOD transitions tested if applicable
- [ ] Paint/overlay effects tested
- [ ] Baselines committed to git
- [ ] CI pipeline runs visual tests
- [ ] Failed screenshots reviewed as artifacts

### Troubleshooting Shader Visual Tests

**Issue: Tests fail on different machines**

GPU rendering varies by:

- Browser version
- GPU driver
- Operating system
- Headless vs headed mode

**Solution**: Use per-project baselines in playwright.config.ts:

```typescript
projects: [
  { name: 'chromium-linux', use: { browserName: 'chromium' } },
  { name: 'chromium-windows', use: { browserName: 'chromium' } },
  { name: 'chromium-macos', use: { browserName: 'chromium' } },
];
```

**Issue: Flaky tests due to timing**

**Solution**: Add explicit render waits:

```javascript
// Wait for Three.js render loop to complete
await page.evaluate(() => {
  return new Promise((resolve) => {
    requestAnimationFrame(() => requestAnimationFrame(resolve));
  });
});
```

---

### Material Quality Validation

```javascript
// Check material rendering quality
async function validateMaterialQuality(page, objectName) {
  const analysis = await visionAnalyze(page, {
    prompt: `Analyze the material quality on ${objectName}:
    1. Are normal maps visible? (surface detail, bumps)
    2. Is roughness map working? (specular highlights correct)
    3. Is metallic map working? (metal vs non-metal areas)
    4. Are textures loading at correct resolution? (not blurry/pixelated)
    5. Are UVs mapped correctly? (no stretched/distorted textures)

    Return {
      "normalMap": "working|missing|incorrect",
      "roughness": "working|missing|incorrect",
      "metallic": "working|missing|incorrect",
      "textureResolution": "correct|tooLow|stretched",
      "uvs": "correct|distorted|seams",
      "overall": "pass|fail"
    }`,
  });

  return JSON.parse(analysis);
}
```

### Animation Validation

```javascript
// Verify character animations are playing
async function validateAnimations(page) {
  const screenshots = [];

  // Capture animation frames
  for (let i = 0; i < 10; i++) {
    await page.waitForTimeout(100); // 100ms between frames
    screenshots.push(`validation/anim-frame-${i}.png`);
    await page.screenshot({ path: screenshots[i] });
  }

  // Compare frames to detect animation
  const analysis = await visionAnalyze(screenshots, {
    prompt: `Compare these 10 screenshots from a game:
    1. Is the character changing pose between frames?
    2. What animation state is visible? (idle, walk, run, jump)
    3. Is the animation smooth? (check frame-to-frame continuity)
    4. Are there any animation glitches? (t-pose, ragdoll, sliding)

    Return {
      "animating": true|false,
      "detectedState": "idle|walk|run|jump|unknown",
      "smooth": true|false,
      "glitches": ["list of issues"],
      "overall": "pass|fail"
    }`,
  });

  return JSON.parse(analysis);
}
```

### 3D Visual Regression Checklist

For each 3D asset validation:

- [ ] Model visible from multiple angles (front, side, top, iso)
- [ ] No placeholder geometry (box/cylinder)
- [ ] Textures loading correctly
- [ ] Materials rendering properly (normal, roughness, metallic)
- [ ] No shader artifacts (flickering, NaN pixels, seams)
- [ ] Animations playing smoothly
- [ ] Proper scale and positioning
- [ ] No clipping with environment
- [ ] Team colors rendering correctly (for paint/team assets)
- [ ] Performance acceptable (60 FPS maintained)

---

## Screenshot Evidence Management

### Screenshot File Organization

```
screenshots/
├── baselines/
│   ├── feat-001/
│   │   ├── menu.png
│   │   ├── playing.png
│   │   └── gameover.png
├── validation/
│   ├── feat-001-initial.png
│   ├── feat-001-after-fix.png
│   └── feat-001-final.png
└── bugs/
    ├── bug-001-visual-glitch.png
    └── bug-002-hud-missing.png
```

### Screenshot Naming Convention

```
{taskId}-{state}-{timestamp}.{ext}

Examples:
- feat-001-menu-20250121.png
- feat-001-playing-after-jump.png
- feat-001-gameover.png
- bug-001-health-bar-missing.png
```

---

## Vision MCP Integration

### Vision MCP Prompt Patterns

**State Detection:**

```
"Analyze this game screenshot. What state is it in? (menu|playing|gameover|win|loading)
Describe visible UI elements. Is player character visible?"
```

**Comparison:**

```
"Compare Image 1 (baseline) and Image 2 (current).
List visual differences. Are differences acceptable (animations) or bugs?"
```

**Validation:**

```
"Check if this screenshot meets criteria: [criteria]
Return { valid: true|false, issues: [list] }"
```

**GDD Compliance:**

```
"Given this GDD spec: [spec]
Does screenshot match? List deviations with severity (low|medium|high)"
```

---

## Testing Checklist

For each validation:

- [ ] Baseline screenshots captured for all game states
- [ ] Current screenshots compared against baselines
- [ ] Game state detection returns correct state
- [ ] UI elements validated (HUD, buttons, menus)
- [ ] Visual appearance matches design/GDD
- [ ] No visual glitches detected
- [ ] Screenshots saved as evidence
- [ ] Deviations documented with severity

---

## Common Issues

### Issue: False positives in comparison

**Solution**: Use semantic comparison for dynamic content:

```javascript
// Pixel comparison alone fails with animations
// Use Vision MCP for semantic understanding
const semantic = await compareSemantic(current, baseline);
if (semantic.acceptable) {
  // Pass even if pixels differ
}
```

### Issue: State detection inaccurate

**Solution**: Provide more specific prompts:

```javascript
const analysis = await visionAnalyze(screenshot, {
  prompt: `Look SPECIFICALLY for:
  1. "Game Over" text or similar death indicator
  2. Score summary screen
  3. Respawn/continue button

  Only return "gameover" if at least 2 of 3 are present.`,
});
```

### Issue: Baselines become stale

**Solution**: Version your baselines:

```javascript
const baselineVersion = await getGameVersion(); // from package.json
const baselinePath = `baselines/v${baselineVersion}/${state}.png`;
```

---

## Complete Example

```javascript
test('visual validation of new character', async ({ page }) => {
  const taskId = 'feat-001';

  // Navigate to game
  await page.goto('http://localhost:3000');
  await page.click('canvas');
  await page.waitForTimeout(1000);

  // Capture screenshot
  const screenshot = `playwright-test/${taskId}-character.png`;
  await page.screenshot({ path: screenshot });

  // Detect game state
  const state = await detectGameState(screenshot);
  expect(state.state).toBe('playing');
  expect(state.playerVisible).toBe(true);

  // Validate character appearance
  const character = await validatePlayerCharacter(screenshot);
  expect(character.visible).toBe(true);
  expect(character.issues).toHaveLength(0);

  // Compare with baseline (semantic)
  const baseline = `tests/baselines/${taskId}/character.png`;
  const comparison = await compareSemantic(screenshot, baseline);
  expect(comparison.sameState).toBe(true);

  // If deviations exist, document them
  if (comparison.differences.length > 0) {
    console.log('Visual deviations:', comparison.differences);
  }
});
```

---

## Reference

- [Playwright Screenshot API](https://playwright.dev/docs/api/class-page#page-screenshot)
- [Playwright Visual Testing / Test Snapshots](https://playwright.dev/docs/test-snapshots)
- [Playwright SnapshotAssertions API](https://playwright.dev/docs/api/class-snapshotassertions)
- [Three.js WebGPU + Playwright Testing](https://threejs.org/docs/#manual/en/introduction/WebGPU) — For TSL/WebGPU shader testing
- [`agents/qa/skills/browser-testing.md`](browser-testing.md) — Basic browser testing
- [`agents/qa/skills/game-testing.md`](game-testing.md) — Game control patterns

### Research Sources (Skill Update: 2026-01-23)

- Playwright Official Documentation on Visual Comparisons
- Visual regression testing best practices for GPU-based rendering
- Multi-browser shader validation approaches
- CI/CD patterns for automated visual testing
