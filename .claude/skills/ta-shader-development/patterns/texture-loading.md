# Texture Loading for Shaders

> Asset loading patterns and Vite path handling for shader textures.

## Loading Textures with R3F

```tsx
import { useTexture } from '@react-three/drei';
import { useLoader } from '@react-three/fiber';
import { TextureLoader } from 'three';

// Option 1: Using useTexture hook (recommended)
function MyMesh() {
  const texture = useTexture('/assets/textures/MyTexture.png');
  return <mesh><meshStandardMaterial map={texture} /></mesh>;
}

// Option 2: Using useLoader with TextureLoader
function MyMesh2() {
  const texture = useLoader(TextureLoader, '/assets/textures/MyTexture.png');
  return <mesh><meshStandardMaterial map={texture} /></mesh>;
}

// Option 3: Loading multiple textures
function TexturedMesh() {
  const textures = useTexture({
    map: '/assets/textures/diffuse.png',
    normal: '/assets/textures/normal.png',
    roughness: '/assets/textures/roughness.png',
  });
  return <mesh><meshStandardMaterial {...textures} /></mesh>;
}
```

## Vite Asset Path Handling with Spaces

**CRITICAL**: When asset folder names contain spaces (e.g., "Splat Pack"), you must:

### 1. URL-encode the paths in TypeScript code

```tsx
// WRONG - Will fail to load
const texturePath = '/assets/Splat Pack/splat1.png';

// CORRECT - URL encoded
const texturePath = '/assets/Splat%20Pack/splat1.png';
```

### 2. Extend Vite's assetsPlugin for non-standard file types

```ts
// vite.config.ts
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { viteSingleFile } from 'vite-plugin-singlefile';

export default defineConfig({
  plugins: [
    react(),
    viteSingleFile(),
    {
      name: 'assets-plugin',
      configureServer(server) {
        server.middlewares.use((req, res, next) => {
          // Serve image files from assets folder
          if (req.url?.startsWith('/assets/')) {
            next(); // Let Vite handle it
          } else {
            next();
          }
        });
      },
    },
  ],
  assetsInclude: ['**/*.png', '**/*.jpg', '**/*.jpeg', '**/*.webp', '**/*.gif'],
});
```

### 3. Create a centralized texture manager

```tsx
// src/components/game/effects/SplatTextureManager.ts
const SPLAT_TEXTURE_BASE = '/assets/Splat%20Pack';

export const SPLAT_TEXTURES = [
  `${SPLAT_TEXTURE_BASE}/Splat_A_01.png`,
  `${SPLAT_TEXTURE_BASE}/Splat_A_02.png`,
  // ... more textures
] as const;

export function getRandomSplatTexture(): string {
  return SPLAT_TEXTURES[
    Math.floor(Math.random() * SPLAT_TEXTURES.length)
  ];
}
```

## Preloading Textures

```tsx
import { useLoader } from '@react-three/fiber';
import { TextureLoader } from 'three';

// Preload multiple textures before scene renders
function TexturePreloader({ urls, onLoaded }: { urls: string[], onLoaded: () => void }) {
  useLoader(
    TextureLoader,
    urls,
    (loader) => {
      // All textures loaded
      onLoaded();
    }
  );
  return null;
}
```

## Texture Best Practices

✅ **DO:**
- URL-encode paths with spaces (`%20` for space)
- Use relative paths from `/public` folder: `/assets/...`
- Preload textures before they're needed
- Use `useTexture` from `@react-three/drei` for automatic disposal
- Implement texture atlases for many small textures

❌ **DON'T:**
- Use un-encoded paths with spaces in URLs
- Import large textures directly in JSX (causes bundle bloat)
- Forget to dispose unused textures (memory leak)
- Load full-resolution textures for mobile devices

## Asset Folder Structure

```
/public
  /assets
    /Splat Pack          <- Spaces in names need encoding
    /Weapon Pack
    /Character Models
    /Audio
```

## Reference

- [Vite Static Asset Handling](https://vite.dev/guide/assets) — Official Vite docs
- [Public vs Src Assets in Vite](https://www.thatsoftwaredude.com/content/14144/public-vs-src-assets-when-to-use-each-approach-in-vite) — Asset placement guide
