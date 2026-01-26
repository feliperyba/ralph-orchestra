---
name: pm-configuration-vite-assets
description: Vite 6 asset configuration patterns for React Three Fiber projects
category: pm
user-invocable: false
model: inherit
agent: pm
degrees-of-freedom: medium
---

# Vite 6 Asset Configuration

> "Vite 6 asset patterns - proper placement, URLs, and configuration for 3D assets."

## When to Use

- Coordinating asset configuration between agents
- Reviewing asset loading implementations
- Resolving asset-related build issues
- Setting up 3D asset workflows

---

## Quick Start Checklist

### Before Implementation

1. **Verify asset placement:**
   - FBX/GLB: `src/assets/` (processed by Vite)
   - Static assets: `public/` (served as-is)
   - Audio: `src/assets/audio/` (spatial audio setup)

2. **Check vite.config.ts:**
   ```typescript
   assetsInclude: ['**/*.fbx', '**/*.glb', '**/*.png', '**/*.ogg'];
   optimizeDeps: { exclude: ['*.fbx']; } // Single wildcard
   ```

3. **Verify both URL patterns:**
   - `/assets/` (production)
   - `/src/assets/` (development)

---

## Asset Directory Strategy

| Asset Type | Directory | Processing | URL Pattern | Use Case |
|------------|-----------|------------|-------------|----------|
| FBX/GLB Models | `src/assets/models/` | ✅ Optimized | `/src/assets/` → `/assets/` | Characters, props |
| Audio | `src/assets/audio/` | ✅ Optimized | `/src/assets/` → `/assets/` | SFX, music |
| Textures | `src/assets/textures/` | ✅ Optimized | `/src/assets/` → `/assets/` | Materials |
| Static | `public/` | ❌ As-is | `/filename.ext` | Favicon, manifest |
| UI Assets | `src/assets/ui/` | ✅ Optimized | `/src/assets/` → `/assets/` | Sprites, icons |

---

## Wildcard Patterns (Vite 6)

| Context | Pattern | Works? |
|---------|---------|--------|
| `optimizeDeps.exclude` | `**/*.fbx` | ❌ No |
| `optimizeDeps.exclude` | `*.fbx` | ✅ Yes - single only |
| `assetsInclude` | `**/*.fbx` | ✅ Yes - double OK |

---

## Asset URL Generation

```typescript
// Development: /src/assets/
const modelUrl = '/src/assets/models/character.fbx';

// Production: /assets/ (with hash)
const modelUrl = '/assets/models/character.abc123.fbx';
```

---

## Common Pitfalls

### 1. Path Resolution

**❌ Anti-Pattern:**
```typescript
import model from '../../assets/models/character.fbx';
```

**✅ Best Practice:**
```typescript
import model from '@/assets/models/character.fbx';
const modelPath = new URL('/assets/models/character.fbx', import.meta.url).href;
```

### 2. Binary File Handling

**❌ Anti-Pattern:**
```typescript
build: { assetsInlineLimit: 4096 } // May inline FBX
```

**✅ Best Practice:**
```typescript
build: { assetsInlineLimit: 0 } // Never inline binaries
```

### 3. Dev Server Configuration

**❌ Anti-Pattern:**
```typescript
server: { fs: { strict: true; } } // Blocks src/assets
```

**✅ Best Practice:**
```typescript
server: { fs: { strict: false; } } // Allow src/assets
```

---

## Agent Coordination

### PM Tasks
1. Define asset directory structure
2. Establish naming conventions
3. Coordinate format standards (FBX vs GLB)
4. Monitor build times and bundle sizes

### Developer Notes
```typescript
import { useLoader } from '@react-three/fiber';
import { FBXLoader } from 'three/examples/jsm/loaders/FBXLoader';

function Model({ url }) {
  const model = useLoader(FBXLoader, url);
  return <primitive object={model.scene} />
}
```

### Tech Artist Guidelines
- Use FBX 2020 format
- Remove unused materials/textures
- Apply proper scale (1 unit = 1 meter)
- Optimize polygon count (< 50k for main character)
- Use OGG for audio, < 1MB where possible

---

## Configuration Template

```typescript
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import path from 'path';

function assetsPlugin() {
  return {
    name: 'assets-server',
    configureServer(server) {
      server.middlewares.use((req, res, next) => {
        const isAsset = req.url?.startsWith('/assets/') || req.url?.startsWith('/src/assets/');
        if (!isAsset) return next();

        // Normalize /assets/ to /src/assets/
        let path = req.url!;
        if (path.startsWith('/assets/') && !path.startsWith('/src/assets/')) {
          path = '/src' + path;
        }

        // Serve file with proper headers
        const filePath = path.join(__dirname, decodeURIComponent(path));
        // ... serve file
      });
    },
  };
}

export default defineConfig({
  plugins: [react(), assetsPlugin()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
      '@assets': path.resolve(__dirname, './src/assets'),
    },
  },
  server: {
    port: 3000,
    fs: { strict: false },
  },
  build: {
    assetsInlineLimit: 0,
  },
  optimizeDeps: {
    exclude: ['*.fbx'],
  },
  assetsInclude: ['**/*.fbx', '**/*.glb', '**/*.png', '**/*.ogg'],
});
```

---

## QA Checklist

### Build Tests
- [ ] FBX files copied to dist/assets/
- [ ] No "Cannot find version" errors
- [ ] Assets load in dev and production
- [ ] No 404 errors for asset URLs

### Performance Tests
- [ ] Load time < 2 seconds
- [ ] Memory usage stable
- [ ] No memory leaks
- [ ] FPS maintained with loading

### Browser Tests
- [ ] Chrome, Firefox, Safari
- [ ] Mobile device loading
- [ ] Slow network simulation
- [ ] Cache behavior verification

---

## References

- [Vite Asset Handling](https://vite.dev/guide/assets) - Official docs
- [R3F Asset Loading](https://r3f.docs.pmnd.rs/tutorials/loading-models) - R3F patterns
- [Three.js Best Practices](https://www.utsubo.com/blog/threejs-best-practices-100-tips) - Optimization
