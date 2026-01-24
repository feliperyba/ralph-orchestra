---
name: model-loading
description: FBX model loading patterns for R3F with useFBX. Use when loading 3D models.
category: assets
keywords: [fbx, gltf, model, loading, drei]
---

# Model Loading (FBX/GLTF)

> "Use the R3F way: `useFBX` from drei, not manual `FBXLoader.load()`"

## When to Use

Use when:

- Loading FBX character models with animations
- Loading 3D models for R3F scenes

## Critical Anti-Pattern

**❌ DON'T: Manual FBXLoader.load() in useEffect**

```typescript
// WRONG - Does NOT work with R3F's loading system!
import { FBXLoader } from 'three-stdlib';

useEffect(() => {
  const loader = new FBXLoader();
  loader.load(url, (object) => setFbx(object));
}, [url]);
```

**Why this fails:**

1. Bypasses R3F's suspense boundary system
2. Doesn't work with Vite's asset URL generation
3. Causes "Cannot find the version number for the file given" error

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
// FBX model loading
import { useFBX } from '@react-three/drei';

function CharacterModel({ url }: { url: string }) {
  const fbx = useFBX(url);
  return <primitive object={fbx} />;
}

// GLTF/GLB model loading
import { useGLTF } from '@react-three/drei';

function EnvironmentModel() {
  const { scene } = useGLTF('/assets/environment/terrain.glb');
  return <primitive object={scene} />;
}
```

## FBX with Animations

```typescript
import { useFBX } from '@react-three/drei';
import { useMemo } from 'react';

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

  return null;
}
```

## Suspense Integration

```typescript
import { Suspense } from 'react';

function Scene() {
  return (
    <Suspense fallback={<LoadingSpinner />}>
      <CharacterModel url="/models/character.fbx" />
    </Suspense>
  );
}
```

## Vite 6 Asset Import

```typescript
// Use ?url to get the URL string that useFBX can process
import characterModelUrl from '@/assets/models/character.fbx?url';

// Then pass to useFBX
const fbx = useFBX(characterModelUrl);
```

## Path Resolution

**❌ DON'T:**

```typescript
// Hard-coded relative paths
import model from '../../assets/models/character.fbx';

// Using require() - not compatible with Vite
const model = require('../../assets/models/character.fbx');
```

**✅ DO:**

```typescript
// Using alias paths
import model from '@/assets/models/character.fbx';

// Using dynamic URL resolution
const modelUrl = new URL('/assets/models/character.fbx', import.meta.url).href;
```

## Common Mistakes

| ❌ Wrong                      | ✅ Right                          |
| ----------------------------- | --------------------------------- |
| Manual FBXLoader in useEffect | useFBX from drei                  |
| Using ?raw imports            | Use ?url imports                  |
| Hard-coded relative paths     | Use alias (@/) or import.meta.url |
| Missing Suspense boundary     | Wrap in Suspense                  |

## Reference

- [texture-loading.md](./texture-loading.md) - Texture optimization
- [audio-loading.md](./audio-loading.md) - Audio handling
- [Vite Asset Handling](https://vite.dev/guide/assets)
