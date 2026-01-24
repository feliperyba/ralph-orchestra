---
name: vite-asset-loading
description: Vite 6 asset loading patterns for React Three Fiber with TypeScript
category: asset
keywords: [vite, asset, fbx, loader, drei, suspense]
version: "3.0"
changelog: "MAJOR: Project uses FBX format exclusively. Removed all GLTF/GLB references. Standardized on useFBX from @react-three/drei."
---

# Vite 6 Asset Loading for R3F

> "PROJECT STANDARD: FBX format only. Use `useFBX` from drei, not manual loaders"

## Project Format Decision

**THIS PROJECT USES FBX FORMAT EXCLUSIVELY**

- Characters: FBX format
- Weapons: FBX format
- Accessories: FBX format
- Animations: FBX format

**DO NOT** use GLTF/GLB format or `useGLTF` in this project.

## Critical Anti-Pattern (UPDATED)

**❌ DON'T: Manual FBXLoader.load() in useEffect**
```typescript
// WRONG - This does NOT work with R3F's loading system!
import { FBXLoader } from 'three-stdlib'

useEffect(() => {
  const loader = new FBXLoader();
  loader.load(url, (object) => {
    setFbx(object);
  }, (error) => {
    console.error(error);
  });
}, [url]);
```

**Why this fails:**
1. Bypasses R3F's suspense boundary system
2. Doesn't work with Vite's asset URL generation
3. Causes "Cannot find the version number for the file given" error
4. React may unmount before async load completes

**✅ DO: useFBX from @react-three/drei**
```typescript
import { useFBX } from '@react-three/drei';

function CharacterModel({ url }) {
  const fbx = useFBX(url);
  return <primitive object={fbx} />;
}
```

## Quick Start

```typescript
// CORRECT FBX model loading with drei
import { useFBX } from '@react-three/drei';

function CharacterModel({ url }: { url: string }) {
  const fbx = useFBX(url);
  return <primitive object={fbx} />;
}

// Weapon model loading example
function WeaponModel({ weaponType }: { weaponType: string }) {
  const fbx = useFBX(`/assets/Blaster Kit/Models/FBX format/${weaponType}.fbx`);
  return <primitive object={fbx} />;
}
```

## Core Patterns

### 1. FBX Model Loading - THE CORRECT R3F WAY

```typescript
import { useFBX } from '@react-three/drei';
import { Suspense } from 'react';

function CharacterModel({ url }: { url: string }) {
  // useFBX handles loading through R3F's useLoader system
  // Works correctly with Vite's ?url imports
  const fbx = useFBX(url);

  return <primitive object={fbx} />;
}

// Wrap in Suspense for loading states
function Scene() {
  return (
    <Suspense fallback={<LoadingSpinner />}>
      <CharacterModel url="/models/character.fbx" />
    </Suspense>
  );
}
```

### 2. Loading Multiple FBX Animations

```typescript
import { useFBX } from '@react-three/drei';

function AnimationLoader({ animationUrls }: { animationUrls: Record<string, string> }) {
  // Load each animation separately using useFBX
  const idleFbx = useFBX(animationUrls.idle);
  const walkFbx = useFBX(animationUrls.walk);
  const runFbx = useFBX(animationUrls.run);

  // Extract animation clips from loaded FBX objects
  const clips = useMemo(() => {
    const clips = new Map<string, THREE.AnimationClip>();

    const extractClip = (fbx: THREE.Object3D, name: string) => {
      if (fbx.animations && fbx.animations.length > 0) {
        const clip = fbx.animations[0];
        clip.name = name;
        clips.set(name, clip);
      }
    };

    if (idleFbx) extractClip(idleFbx, 'idle');
    if (walkFbx) extractClip(walkFbx, 'walk');
    if (runFbx) extractClip(runFbx, 'run');

    return clips;
  }, [idleFbx, walkFbx, runFbx]);

  return null; // Pass clips up via callback
}
```

### 3. Vite 6 Asset Import Suffixes

**For FBX models with useFBX:**
```typescript
// Use ?url to get the URL string that useFBX can process
import characterModelUrl from '@/assets/models/character.fbx?url';

// Then pass to useFBX
const fbx = useFBX(characterModelUrl);
```

**What NOT to do:**
```typescript
// ❌ ?raw imports corrupts binary FBX data
import characterModel from '@/assets/models/character.fbx?raw';

// ❌ Manual imports without suffix won't work in Vite 6
import characterModel from '@/assets/models/character.fbx';
```

### 4. Audio Asset Loading

```typescript
import { useRef, useEffect } from 'react'

function SoundEffect({ url, volume = 1 }) {
  const audioRef = useRef<HTMLAudioElement>(null);

  useEffect(() => {
    if (!audioRef.current) return;

    const audio = audioRef.current;
    audio.src = url;
    audio.volume = volume;

    audio.onended = () => {
      audio.currentTime = 0;
    };

    return () => {
      audio.pause();
      audio.src = '';
    };
  }, [url, volume]);

  return <audio ref={audioRef} />;
}
```

### 5. Texture Loading with Optimization

```typescript
import { useLoader } from '@react-three/fiber'
import { TextureLoader } from 'three'
import { useMemo } from 'react'

function TexturedMaterial({ textureUrl, color = '#ffffff' }) {
  const texture = useLoader(TextureLoader, textureUrl)

  // Optimize texture settings
  useMemo(() => {
    if (texture) {
      texture.generateMipmaps = true
      texture.minFilter = THREE.LinearMipmapLinearFilter
      texture.magFilter = THREE.LinearFilter
      texture.anisotropy = 4
    }
  }, [texture])

  return (
    <meshBasicMaterial
      map={texture}
      color={color}
      transparent={true}
    />
  )
}
```

## Advanced Patterns

### 1. Conditional Asset Loading

```typescript
import { Suspense, lazy } from 'react'

// Load models only when needed
const HeavyModel = lazy(() => import('./HeavyModel'))
const LightModel = lazy(() => import('./LightModel'))

function ModelSwitcher({ useHighDetail }) {
  return (
    <Suspense fallback={<LoadingSpinner />}>
      {useHighDetail ? <HeavyModel /> : <LightModel />}
    </Suspense>
  )
}
```

### 2. Asset Preloading

```typescript
import { useEffect, useRef, useState } from 'react'

function AssetPreloader({ assets }) {
  const [loaded, setLoaded] = useState(false)
  const [progress, setProgress] = useState(0)

  useEffect(() => {
    const loadedCount = new Set()
    const totalAssets = assets.length

    assets.forEach(({ type, url, onLoad }) => {
      let loader;

      switch (type) {
        case 'fbx':
          // Use drei's preloading
          preload(url, typeof url === 'string' ? url : url.default);
          onLoad?.(url);
          break;
        case 'texture':
          loader = new TextureLoader()
          loader.load(url, (asset) => {
            loadedCount.add(url)
            onLoad?.(asset)
            setProgress((loadedCount.size / totalAssets) * 100)

            if (loadedCount.size === totalAssets) {
              setLoaded(true)
            }
          })
          break;
      }
    })
  }, [assets])

  return loaded ? null : <LoadingProgress progress={progress} />
}
```

## TypeScript Integration

### Asset Type Definitions

```typescript
// types/assets.d.ts
declare module '*.fbx' {
  const value: string
  export default value
}

declare module '*.ogg' {
  const value: string
  export default value
}

declare module '*.mp3' {
  const value: string
  export default value
}
```

## Checklist

Before using asset loading:

- [ ] Using `useFBX` from drei (not manual loaders)
- [ ] Assets in `src/assets/` or `public/` folder
- [ ] Using `/assets/` path prefix (mapped by Vite plugin)
- [ ] Suspense boundary wraps asset-using components
- [ ] Error handling for failed loads
- [ ] Proper cleanup on component unmount
- [ ] Textures are power-of-2 for mipmaps

## Reference

- [Vite Asset Handling Documentation](https://vite.dev/guide/assets)
- [React Three Fiber useLoader Hook](https://docs.pmnd.rs/react-three-fiber/api/hooks#useloader)
- `developer/r3f/r3f-fundamentals.md` — R3F basics
