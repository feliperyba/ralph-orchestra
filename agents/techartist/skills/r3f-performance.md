---
name: r3f-performance
description: Performance optimization techniques for R3F and Three.js
category: optimization
depends-on: [r3f-fundamentals]
---

# R3F Performance Skill

> "Optimize for mobile, scale up for desktop – 60 FPS is the goal."

## When to Use This Skill

Use when:

- FPS drops below 60
- Targeting mobile devices
- Rendering many objects
- Implementing LOD systems
- Debugging performance issues

## Quick Start

```tsx
// Performance-optimized Canvas
<Canvas
  dpr={[1, 2]} // Limit pixel ratio
  performance={{ min: 0.5 }} // Auto-reduce quality
  gl={{ antialias: false }} // Disable for mobile
>
  <Suspense fallback={null}>
    <Scene />
  </Suspense>
</Canvas>
```

## The 16ms Budget (60 FPS)

| System     | Budget      | Notes                 |
| ---------- | ----------- | --------------------- |
| Input      | ~1ms        | Event handling        |
| Physics    | ~3ms        | Rapier/Cannon updates |
| Game Logic | ~4ms        | State, AI, animations |
| Render     | ~5ms        | Three.js draw calls   |
| Buffer     | ~3ms        | Safety margin         |
| **Total**  | **16.67ms** | 60 FPS target         |

## Decision Framework

| Symptom            | Likely Cause        | Solution            |
| ------------------ | ------------------- | ------------------- |
| Low FPS everywhere | Too many draw calls | Instancing, merging |
| FPS drops on zoom  | LOD not implemented | Add LOD system      |
| Mobile slow        | DPR too high        | Limit to 1.5        |
| Memory grows       | Dispose missing     | Add cleanup         |
| Stuttering         | GC pressure         | Object pooling      |

## Progressive Guide

### Level 1: Basic Optimizations

```tsx
// Limit device pixel ratio
<Canvas dpr={Math.min(window.devicePixelRatio, 2)}>

// Disable expensive features on mobile
const isMobile = /iPhone|iPad|Android/i.test(navigator.userAgent);

<Canvas
  shadows={!isMobile}
  gl={{
    antialias: !isMobile,
    powerPreference: 'high-performance',
  }}
>
```

### Level 2: Instanced Rendering

```tsx
import { Instances, Instance } from '@react-three/drei';

// Instead of 1000 separate meshes
function OptimizedTrees({ positions }) {
  return (
    <Instances limit={positions.length}>
      <cylinderGeometry args={[0.1, 0.3, 2]} />
      <meshStandardMaterial color="brown" />
      {positions.map((pos, i) => (
        <Instance key={i} position={pos} />
      ))}
    </Instances>
  );
}
```

### Level 3: Level of Detail (LOD)

```tsx
import { Detailed } from '@react-three/drei';

function LODTree({ position }) {
  return (
    <Detailed distances={[0, 20, 50, 100]} position={position}>
      {/* Closest - high detail */}
      <HighDetailTree />
      {/* Medium distance */}
      <MediumDetailTree />
      {/* Far - low detail */}
      <LowDetailTree />
      {/* Very far - billboard or nothing */}
      <mesh>
        <planeGeometry args={[1, 2]} />
        <meshBasicMaterial map={treeBillboard} transparent />
      </mesh>
    </Detailed>
  );
}
```

### Level 4: Frustum Culling & BVH

```tsx
import { useBVH } from '@react-three/drei';

function OptimizedMesh() {
  const meshRef = useRef();

  // Enable BVH for faster raycasting
  useBVH(meshRef);

  return (
    <mesh ref={meshRef} frustumCulled>
      <complexGeometry />
      <meshStandardMaterial />
    </mesh>
  );
}
```

### Level 5: Object Pooling

```tsx
// Pool for frequently created/destroyed objects
const bulletPool = useMemo(() => {
  const pool = [];
  for (let i = 0; i < 100; i++) {
    pool.push({
      active: false,
      position: new THREE.Vector3(),
      velocity: new THREE.Vector3(),
    });
  }
  return pool;
}, []);

function getBullet() {
  return bulletPool.find((b) => !b.active);
}

function releaseBullet(bullet) {
  bullet.active = false;
}
```

## Mobile Optimization

| Feature         | Desktop | Mobile  |
| --------------- | ------- | ------- |
| Pixel Ratio     | 2.0     | 1.0-1.5 |
| Shadows         | On      | Off     |
| Anti-aliasing   | MSAA    | Off     |
| Post-processing | Full    | Minimal |
| Draw calls      | < 200   | < 50    |
| Polygons        | < 1M    | < 100K  |

```tsx
// Mobile detection and config
const config = useMemo(() => {
  const isMobile = /iPhone|iPad|Android/i.test(navigator.userAgent);
  return {
    dpr: isMobile ? 1 : Math.min(window.devicePixelRatio, 2),
    shadows: !isMobile,
    antialias: !isMobile,
    maxDrawCalls: isMobile ? 50 : 200,
  };
}, []);
```

## Memory Management

```tsx
// CRITICAL: Dispose of Three.js objects
useEffect(() => {
  const geometry = new THREE.BoxGeometry();
  const material = new THREE.MeshStandardMaterial();

  return () => {
    geometry.dispose();
    material.dispose();
    // Also dispose textures
    if (material.map) material.map.dispose();
  };
}, []);
```

## Anti-Patterns

❌ **DON'T:**

- Create objects inside useFrame
- Use high polygon models without LOD
- Skip dispose() calls
- Use shadows on mobile without testing
- Render invisible objects
- Use uncompressed textures

✅ **DO:**

- Reuse Vector3, Quaternion instances
- Implement LOD for complex scenes
- Always dispose geometries and materials
- Profile before and after optimizations
- Use Instances for repeated objects
- Compress textures (WebP, Basis)

## Performance Monitoring

```tsx
import { useFrame } from '@react-three/fiber';
import { useRef } from 'react';

function PerformanceMonitor() {
  const frameCount = useRef(0);
  const lastTime = useRef(performance.now());

  useFrame(() => {
    frameCount.current++;

    const now = performance.now();
    if (now - lastTime.current >= 1000) {
      console.log(`FPS: ${frameCount.current}`);
      frameCount.current = 0;
      lastTime.current = now;
    }
  });

  return null;
}
```

## Checklist

Performance review:

- [ ] DPR limited appropriately
- [ ] Instancing used for repeated objects
- [ ] LOD implemented for complex models
- [ ] Dispose called on cleanup
- [ ] No object creation in useFrame
- [ ] Shadows disabled on mobile
- [ ] Textures compressed
- [ ] Draw calls under budget
- [ ] FPS stable at 60

## Common Performance Killers

1. **Too many draw calls** → Use Instances
2. **High polygon count** → Use LOD
3. **Unoptimized textures** → Compress, resize
4. **No frustum culling** → Enable frustumCulled
5. **Memory leaks** → Call dispose()
6. **GC pressure** → Object pooling
7. **Expensive shaders** → Simplify, use mobile variants
8. **Post-processing** → Limit on mobile

## Reference

- [Three.js Performance Tips](https://threejs.org/manual/#en/optimize-lots-of-objects)
- [skills/r3f-fundamentals.md](r3f-fundamentals.md) — R3F basics
- [skills/r3f-materials.md](r3f-materials.md) — Material optimization
