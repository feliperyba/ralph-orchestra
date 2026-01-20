# Browser Testing Patterns Reference

## Playwright MCP Usage

### Basic Navigation

```typescript
// Navigate to app
await page.goto('http://localhost:3000');

// Wait for canvas
await page.waitForSelector('canvas', { state: 'visible' });

// Wait for network idle
await page.waitForLoadState('networkidle');
```

### Screenshot Capture

```typescript
// Full page screenshot
await page.screenshot({ path: 'full-page.png' });

// Element screenshot
const canvas = page.locator('canvas');
await canvas.screenshot({ path: 'canvas.png' });

// With options
await page.screenshot({
  path: 'screenshot.png',
  fullPage: true,
  type: 'png',
});
```

### Console Monitoring

```typescript
// Collect all console messages
const messages: string[] = [];
page.on('console', (msg) => messages.push(msg.text()));

// Collect only errors
const errors: string[] = [];
page.on('console', (msg) => {
  if (msg.type() === 'error') {
    errors.push(msg.text());
  }
});

// Check for specific error
page.on('console', (msg) => {
  if (msg.text().includes('WebGL')) {
    console.log('WebGL issue detected:', msg.text());
  }
});
```

### Keyboard Input

```typescript
// Single key press
await page.keyboard.press('KeyW');
await page.keyboard.press('Space');
await page.keyboard.press('Escape');

// Key combination
await page.keyboard.press('Control+Z');

// Hold key
await page.keyboard.down('ShiftLeft');
await page.keyboard.press('KeyW');
await page.keyboard.up('ShiftLeft');

// Type text
await page.keyboard.type('player1');
```

### Mouse Input

```typescript
// Click
await page.click('canvas');

// Click at position
await page.mouse.click(400, 300);

// Move
await page.mouse.move(400, 300);

// Drag
await page.mouse.down();
await page.mouse.move(500, 400);
await page.mouse.up();

// Wheel
await page.mouse.wheel(0, 100);
```

### Performance Metrics

```typescript
// Get performance timing
const metrics = await page.evaluate(() => {
  const nav = performance.getEntriesByType('navigation')[0] as PerformanceNavigationTiming;
  return {
    loadTime: nav.loadEventEnd - nav.startTime,
    domContentLoaded: nav.domContentLoadedEventEnd - nav.startTime,
    firstPaint: performance.getEntriesByName('first-paint')[0]?.startTime,
  };
});

// Check FPS (requires exposed function in app)
const fps = await page.evaluate(() => {
  return (window as any).__fps || 'not available';
});
```

### Waiting Patterns

```typescript
// Wait for element
await page.waitForSelector('.game-loaded');

// Wait for timeout
await page.waitForTimeout(2000);

// Wait for function
await page.waitForFunction(() => {
  return (window as any).gameReady === true;
});

// Wait for response
await page.waitForResponse((response) => response.url().includes('/api/config'));
```

### Viewport Control

```typescript
// Set viewport size
await page.setViewportSize({ width: 1920, height: 1080 });

// Mobile viewport
await page.setViewportSize({ width: 375, height: 667 });

// Get current size
const size = page.viewportSize();
```

## Manual Testing Commands

### Browser DevTools

```javascript
// Check FPS in console
// (Run in browser DevTools)
let fps = 0;
let lastTime = performance.now();
function checkFPS() {
  const now = performance.now();
  fps = 1000 / (now - lastTime);
  lastTime = now;
  console.log('FPS:', Math.round(fps));
  requestAnimationFrame(checkFPS);
}
checkFPS();
```

```javascript
// Check memory usage
console.log('Memory:', performance.memory);
```

```javascript
// Check WebGL capabilities
const canvas = document.querySelector('canvas');
const gl = canvas.getContext('webgl2') || canvas.getContext('webgl');
console.log('WebGL Version:', gl.getParameter(gl.VERSION));
console.log('Vendor:', gl.getParameter(gl.VENDOR));
console.log('Renderer:', gl.getParameter(gl.RENDERER));
```

## Common Test Scenarios

### Scene Load Test

```typescript
test('scene loads correctly', async ({ page }) => {
  await page.goto('http://localhost:3000');

  // Wait for Three.js scene
  await page.waitForFunction(() => {
    const canvas = document.querySelector('canvas');
    if (!canvas) return false;
    const gl = canvas.getContext('webgl2') || canvas.getContext('webgl');
    return gl !== null;
  });

  // Verify no errors
  const errors: string[] = [];
  page.on('console', (msg) => {
    if (msg.type() === 'error') errors.push(msg.text());
  });

  await page.waitForTimeout(3000);
  expect(errors).toHaveLength(0);
});
```

### Input Response Test

```typescript
test('player responds to input', async ({ page }) => {
  await page.goto('http://localhost:3000');
  await page.waitForSelector('canvas');

  // Get initial state (requires app to expose)
  const initialPos = await page.evaluate(() => {
    return (window as any).getPlayerPosition?.() || { x: 0, y: 0, z: 0 };
  });

  // Press W key
  await page.keyboard.down('KeyW');
  await page.waitForTimeout(500);
  await page.keyboard.up('KeyW');

  // Get new position
  const newPos = await page.evaluate(() => {
    return (window as any).getPlayerPosition?.() || { x: 0, y: 0, z: 0 };
  });

  // Verify movement
  expect(newPos.z).not.toEqual(initialPos.z);
});
```

### Visual Regression Test

```typescript
test('visual appearance matches baseline', async ({ page }) => {
  await page.goto('http://localhost:3000');
  await page.waitForSelector('canvas');
  await page.waitForTimeout(2000); // Wait for scene to stabilize

  // Take screenshot and compare
  await expect(page).toHaveScreenshot('game-baseline.png', {
    maxDiffPixelRatio: 0.01,
    threshold: 0.2,
  });
});
```
