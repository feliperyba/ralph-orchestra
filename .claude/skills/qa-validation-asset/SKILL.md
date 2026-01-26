---
name: asset-validation
description: Comprehensive asset validation for Vite 6 and React Three Fiber projects. Use when validating 3D model loading, audio assets, texture loading, or build output.
---

# Asset Validation for Vite 6 Projects

## When to Use

- Validating 3D model loading (FBX, GLB)
- Testing audio asset functionality
- Verifying texture and material loading
- Checking build output for assets
- Performance testing with asset loading
- Cross-browser compatibility testing

## Quick Start

```typescript
// Asset validation test example
describe('Asset Loading Validation', () => {
  test('FBX models load without errors', async () => {
    const { screen, waitFor } = render(
      <TestScene>
        <FBXModel url="/assets/character.fbx" />
      </TestScene>
    )

    await waitFor(() => {
      const model = screen.getByTestId('model-loaded')
      expect(model).toBeInTheDocument()
    })
  })

  test('Audio assets load and play correctly', () => {
    const { screen } = render(
      <TestScene>
        <AudioEffect url="/assets/sfx/shoot.ogg" />
      </TestScene>
    )

    const audio = screen.getByTestId('audio-element')
    expect(audio).toBeInTheDocument()
  })
})
```

---

## Asset Testing Categories

### 1. 3D Model Validation

<details>
<summary>FBX Model Tests</summary>

```typescript
import { render, screen, waitFor } from '@testing-library/react'

function testFBXModel(url: string, options?: {
  expectedAnimations?: string[]
  expectedMaterials?: string[]
  maxPolygons?: number
}) {
  return async () => {
    const { container } = render(
      <Canvas>
        <Suspense fallback={<div>Loading...</div>}>
          <FBXModelTest url={url} />
        </Suspense>
      </Canvas>
    )

    // Wait for model to load
    await waitFor(() => {
      const loaded = screen.getByTestId('fbx-loaded')
      expect(loaded).toBeInTheDocument()
    })

    // Validate model structure
    const model = screen.getByTestId('model-scene')
    expect(model.children.length).toBeGreaterThan(0)

    // Test animations if present
    if (options?.expectedAnimations) {
      options.expectedAnimations.forEach(anim => {
        const animation = screen.getByTestId(`anim-${anim}`)
        expect(animation).toBeInTheDocument()
      })
    }

    // Performance check
    const renderTime = screen.getByTestId('render-time')
    expect(parseFloat(renderTime.textContent)).toBeLessThan(100) // < 100ms
  }
}
```

</details>

### 2. Audio Asset Validation

<details>
<summary>Audio Loading Tests</summary>

```typescript
function testAudioAsset(url: string, type: 'sfx' | 'music' | 'voice') {
  test(`Audio ${type} loads and plays`, () => {
    const { container } = render(
      <Canvas>
        <AudioTest url={url} type={type} />
      </Canvas>
    )

    const audio = screen.getByTestId('audio-element')
    expect(audio).toBeInTheDocument()

    // Test audio properties
    if (type === 'sfx') {
      expect(audio).toHaveProperty('volume', 1)
      expect(audio).toHaveProperty('loop', false)
    } else if (type === 'music') {
      expect(audio).toHaveProperty('loop', true)
    }

    // Test spatial audio for SFX
    if (type === 'sfx') {
      const spatial = screen.getByTestId('spatial-audio')
      expect(spatial).toBeInTheDocument()
    }
  })
}

function testAudioPerformance() {
  test('Audio loading performance', () => {
    const start = performance.now()

    render(
      <Canvas>
        <AudioTest url="/assets/sfx/shoot.ogg" />
      </Canvas>
    )

    const end = performance.now()
    const loadTime = end - start

    expect(loadTime).toBeLessThan(200) // < 200ms
  })
}
```

</details>

### 3. Texture and Material Validation

<details>
<summary>Texture Loading Tests</summary>

```typescript
function testTextureAsset(url: string) {
  test('Texture loads and applies correctly', () => {
    const { container } = render(
      <Canvas>
        <TextureTest url={url} />
      </Canvas>
    )

    await waitFor(() => {
      const texture = screen.getByTestId('texture-loaded')
      expect(texture).toBeInTheDocument()
    })

    // Test texture properties
    const material = screen.getByTestId('material-texture')
    expect(material.map).toBeDefined()

    // Test UV mapping
    const uvMap = screen.getByTestId('uv-mapping')
    expect(uvMap).toBeInTheDocument()
  })
}

function testMaterialProperties() {
  test('Material properties are correctly applied', () => {
    render(
      <Canvas>
        <MaterialTest />
      </Canvas>
    )

    const material = screen.getByTestId('test-material')

    // Test basic properties
    expect(material.material.transparent).toBe(true)
    expect(material.material.opacity).toBe(0.8)

    // Test texture loading
    expect(material.material.map).toBeDefined()
    expect(material.material.map.image).toBeDefined()
  })
}
```

</details>

---

## Build and Deployment Validation

### Asset Build Tests

```typescript
describe('Asset Build Validation', () => {
  test('FBX files are copied to dist', () => {
    expect(fs.existsSync('dist/assets/models/character.fbx')).toBe(true);
  });

  test('Textures are optimized in build', () => {
    const textureSize = fs.statSync('dist/assets/textures/character.png').size;
    expect(textureSize).toBeLessThan(500000); // < 500KB
  });

  test('Audio files are compressed', () => {
    const audioSize = fs.statSync('dist/assets/sfx/shoot.ogg').size;
    expect(audioSize).toBeLessThan(100000); // < 100KB
  });

  test('Asset URLs are hashed', () => {
    const htmlContent = fs.readFileSync('dist/index.html', 'utf-8');
    expect(htmlContent).toMatch(/character\.[a-f0-9]+\.fbx/);
  });
});
```

### Performance Validation

```typescript
describe('Asset Performance Tests', () => {
  test('Model loading doesn\'t block UI', async () => {
    const start = performance.now()

    render(
      <Canvas>
        <TestScene>
          <FBXModel url="/assets/character.fbx" />
        </TestScene>
      </Canvas>
    )

    // UI should remain responsive during loading
    const end = performance.now()
    expect(end - start).toBeLessThan(100) // < 100ms response time
  })

  test('Memory usage remains stable', () => {
    const initialMemory = performance.memory?.usedJSHeapSize || 0

    render(
      <Canvas>
        <TestScene>
          <FBXModel url="/assets/character.fbx" />
        </TestScene>
      </Canvas>
    )

    const finalMemory = performance.memory?.usedJSHeapSize || 0
    const memoryIncrease = finalMemory - initialMemory

    expect(memoryIncrease).toBeLessThan(50 * 1024 * 1024) // < 50MB
  })
});
```

---

## Cross-Browser Testing

```typescript
describe('Cross-Browser Asset Loading', () => {
  const browsers = ['chromium', 'firefox', 'webkit'];

  browsers.forEach((browser) => {
    test(`Assets load in ${browser}`, async () => {
      const browserContext = await browser.newContext();
      const page = await browserContext.newPage();

      await page.goto('http://localhost:3000');

      // Test model loading
      await page.waitForSelector('[data-testid="model-loaded"]', { timeout: 5000 });
      expect(await page.$('[data-testid="model-loaded"]')).toBeTruthy();

      // Test audio loading
      await page.waitForSelector('[data-testid="audio-loaded"]', { timeout: 5000 });
      expect(await page.$('[data-testid="audio-loaded"]')).toBeTruthy();

      // Test texture loading
      await page.waitForSelector('[data-testid="texture-loaded"]', { timeout: 5000 });
      expect(await page.$('[data-testid="texture-loaded"]')).toBeTruthy();
    });
  });
});
```

---

## Network and Loading Validation

<details>
<summary>Asset Loading States & Network Conditions</summary>

### Loading States

```typescript
test('Asset loading states are handled correctly', () => {
  render(
    <Canvas>
      <Suspense fallback={<LoadingSpinner />}>
        <FBXModel url="/assets/character.fbx" />
      </Suspense>
    </Canvas>
  )

  // Initial loading state
  const loading = screen.getByTestId('loading-spinner')
  expect(loading).toBeInTheDocument()

  // Success state
  const loaded = screen.getByTestId('model-loaded')
  expect(loaded).toBeInTheDocument()

  // Error state simulation
  const error = screen.queryByTestId('error-display')
  expect(error).not.toBeInTheDocument()
})
```

### Network Conditions

```typescript
describe('Network Condition Testing', () => {
  test('Slow network handling', async () => {
    // Simulate slow network (3G)
    await page.emulateNetworkConditions({
      offline: false,
      downloadThroughput: (500 * 1024) / 8, // 500kbps
      uploadThroughput: (500 * 1024) / 8,
      latency: 400, // 400ms RTT
    });

    const startTime = performance.now();
    await page.goto('http://localhost:3000');

    // Wait for model to load with slow network
    await page.waitForSelector('[data-testid="model-loaded"]', { timeout: 15000 });

    const loadTime = performance.now() - startTime;
    console.log(`Model loaded in ${loadTime}ms on slow network`);
  });

  test('Offline behavior', async () => {
    await page.emulateNetworkConditions({ offline: true });
    await page.goto('http://localhost:3000');

    // Should show cached assets or appropriate message
    const offlineMessage = await page.$('[data-testid="offline-message"]');
    if (offlineMessage) {
      expect(offlineMessage).toBeTruthy();
    }
  });
});
```

</details>

---

## Integration Testing

<details>
<summary>Multi-Asset & Interaction Tests</summary>

### Multi-Asset Loading

```typescript
test('Multiple assets load correctly together', async () => {
  render(
    <Canvas>
      <TestScene>
        <FBXModel url="/assets/character.fbx" />
        <GLTFModel url="/assets/environment.glb" />
        <AudioEffect url="/assets/sfx/music.ogg" />
        <TextureMaterial url="/assets/textures/skin.png" />
      </TestScene>
    </Canvas>
  )

  // Wait for all assets to load
  await Promise.all([
    screen.findByTestId('character-loaded'),
    screen.findByTestId('environment-loaded'),
    screen.findByTestId('audio-loaded'),
    screen.findByTestId('texture-loaded')
  ])

  // Verify all assets are present
  expect(screen.getByTestId('character-loaded')).toBeInTheDocument()
  expect(screen.getByTestId('environment-loaded')).toBeInTheDocument()
  expect(screen.getByTestId('audio-loaded')).toBeInTheDocument()
  expect(screen.getByTestId('texture-loaded')).toBeInTheDocument()

  // Test performance with multiple assets
  const fps = await screen.findByTestId('fps-counter')
  expect(parseFloat(fps.textContent)).toBeGreaterThan(30) // > 30 FPS
})
```

### Asset Interactions

```typescript
test('User interactions with loaded assets', async () => {
  const { user } = render(
    <Canvas>
      <TestScene>
        <InteractiveCharacter url="/assets/character.fbx" />
      </TestScene>
    </Canvas>
  )

  // Test character movement
  const character = screen.getByTestId('character')
  await user.click(character)

  // Animation should play
  expect(screen.getByTestId('anim-walk')).toBeInTheDocument()

  // Test weapon interaction
  const weapon = screen.getByTestId('weapon')
  await user.hover(weapon)

  expect(screen.getByTestId('weapon-highlight')).toBeInTheDocument()
})
```

</details>

---

## Anti-Patterns

| ❌ DON'T | ✅ DO |
|----------|-------|
| No error handling for failed assets | Wrap in ErrorBoundary, test error state |
| Not testing memory cleanup | Unmount component, verify memory freed |
| Only testing basic functionality | Test performance (load time, memory, FPS) |

<details>
<summary>Correct Patterns</summary>

### Error Handling

```typescript
// ✅ DO: Test error handling
test('Assets load with proper error handling', async () => {
  render(
    <Canvas>
      <ErrorBoundary>
        <FBXModel url="/missing.fbx" />
      </ErrorBoundary>
    </Canvas>
  )

  await waitFor(() => {
    const error = screen.getByTestId('error-display')
    expect(error).toBeInTheDocument()
    expect(error.textContent).toContain('Failed to load model')
  })
})
```

### Memory Testing

```typescript
// ✅ DO: Test memory cleanup
test('Models clean up memory properly', async () => {
  const { unmount } = render(<Canvas><FBXModel url="/model.fbx" /></Canvas>)

  await waitFor(() => {
    expect(screen.getByTestId('model-loaded')).toBeInTheDocument()
  })

  unmount()

  // Verify memory is cleaned up
  const initialMemory = performance.memory?.usedJSHeapSize || 0
  if (global.gc) global.gc()

  const finalMemory = performance.memory?.usedJSHeapSize || 0
  expect(finalMemory).toBeLessThan(initialMemory + 1024 * 1024) // < 1MB increase
})
```

</details>

---

## References

- [Testing Library Documentation](https://testing-library.com/)
- [Three.js Testing Patterns](https://github.com/pmndrs/three-stdlib/tree/main/test)
- [Vite Build Testing](https://vite.dev/guide/api-javascript#build)
- **[qa-validation-asset-loading/SKILL.md](../qa-validation-asset-loading/SKILL.md)** - Loading performance validation
