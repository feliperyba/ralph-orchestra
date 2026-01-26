# Asset Loading Patterns

> Progressive loading strategies for better UX and performance.

## Progressive Loading with Suspense

**Problem**: Large assets cause long loading times with no feedback.

**Solution**: Use nested Suspense boundaries for progressive loading.

```tsx
import { Suspense } from 'react';
import { Canvas } from '@react-three/fiber';
import { useGLTF } from '@react-three/drei';

function Model({ url }: { url: string }) {
  const { scene } = useGLTF(url);
  return <primitive object={scene} />;
}

function App() {
  return (
    <Suspense fallback={<LoadingScreen />}>
      <Canvas>
        <Suspense fallback={<LowQualityModel />}>
          {/* High quality loads last */}
          <Model url="/assets/models/high-quality.glb" />
        </Suspense>
      </Canvas>
    </Suspense>
  );
}

// Initial low-quality placeholder
function LowQualityModel() {
  const { scene } = useGLTF('/assets/models/low-quality.glb');
  return <primitive object={scene} />;
}
```

## Loading States with useLoader

**Pattern**: Track loading progress for better UX.

```tsx
import { useLoader } from '@react-three/fiber';
import { GLTFLoader } from 'three/examples/jsm/loaders/GLTFLoader';

function ModelWithProgress({ url }: { url: string }) {
  // GLTFLoader is cached automatically by useLoader
  const gltf = useLoader(GLTFLoader, url);

  return <primitive object={gltf.scene} />;
}

// With Suspense, the fallback shows while loading
function Scene() {
  return (
    <Suspense fallback={<LoadingSpinner />}>
      <ModelWithProgress url="/assets/models/character.glb" />
    </Suspense>
  );
}
```

## Asset Preloading Pattern

**Pattern**: Preload critical assets before they're needed.

```tsx
import { useEffect, useState } from 'react';
import { useGLTF } from '@react-three/drei';

function usePreloadGLTF(urls: string[]) {
  const [loaded, setLoaded] = useState(false);

  useEffect(() => {
    let mounted = true;

    Promise.all(urls.map(url => useGLTF.preload(url)))
      .then(() => {
        if (mounted) setLoaded(true);
      });

    return () => { mounted = false; };
  }, urls);

  return loaded;
}

// Usage: preload assets before showing scene
function Game() {
  const assetsReady = usePreloadGLTF([
    '/assets/models/player.glb',
    '/assets/models/weapon.glb',
  ]);

  if (!assetsReady) {
    return <LoadingScreen progress="Loading assets..." />;
  }

  return <GameScene />;
}
```

## Cached Asset Loading

**Pattern**: `useLoader` and `useGLTF` automatically cache assets by URL.

```tsx
// First call loads and caches
const { scene: scene1 } = useGLTF('/assets/models/tree.glb');

// Subsequent calls use cached version - instant!
const { scene: scene2 } = useGLTF('/assets/models/tree.glb');

// Both share the same GPU memory
```

## Asset Loading Error Boundaries

**Pattern**: Handle loading failures gracefully.

```tsx
import { Component, ReactNode } from 'react';
import { useGLTF } from '@react-three/drei';

class AssetErrorBoundary extends Component<
  { children: ReactNode; fallback?: ReactNode },
  { hasError: boolean }
> {
  constructor(props) {
    super(props);
    this.state = { hasError: false };
  }

  static getDerivedStateFromError() {
    return { hasError: true };
  }

  render() {
    if (this.state.hasError) {
      return this.props.fallback || <FallbackAsset />;
    }
    return this.props.children;
  }
}

// Wrap assets in error boundary
function SafeModel({ url }: { url: string }) {
  return (
    <AssetErrorBoundary fallback={<ErrorMesh />}>
      <Suspense fallback={<LoadingMesh />}>
        <Model url={url} />
      </Suspense>
    </AssetErrorBoundary>
  );
}

function Model({ url }: { url: string }) {
  const { scene } = useGLTF(url);
  return <primitive object={scene} />;
}
```

## Fallback Assets for Loading States

**Pattern**: Show placeholder while real asset loads.

```tsx
// Simple placeholder mesh
function LoadingMesh() {
  return (
    <mesh>
      <boxGeometry args={[1, 2, 0.5]} />
      <meshStandardMaterial color="#666" wireframe />
    </mesh>
  );
}

// Error fallback
function ErrorMesh() {
  return (
    <mesh>
      <sphereGeometry args={[0.5]} />
      <meshStandardMaterial color="red" />
    </mesh>
  );
}
```

## Texture Optimization

```bash
# Optimize textures before importing
# Resize to power-of-2 dimensions
convert input.jpg -resize 512x512 output.png

# Compress to WebP
convert input.png -quality 80 output.webp

# Or use basis universal for GPU compression
basisu -q 1 input.png -output output.basis
```

## GLTF Export Settings (Blender)

```
Export Settings:
- Format: glTF Binary (.glb)
- Include: Selected Objects
- Mesh: + Apply Modifiers
- Mesh: - Tangents (compute at runtime)
- Mesh: - Blending: Obsolete
- LoD: Simplify disabled
- Armature: + Only Keyframes
- Animation: - Limit to Selected
- Geometry: - UV Map
- Geometry: - Normals
- Geometry: + Tangents
- Geometry: + Vertex Colors
- Objects: - PBR Ext
```

## Retrospective Notes

**Learned from bugfix-005 (2026-01-22)**:
- Large weapon models may have load delays
- Always use Suspense boundaries for async asset loading
- Consider loading states for better UX during asset fetch
