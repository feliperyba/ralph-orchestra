---
name: performance-basics
description: Core R3F/Three.js performance optimization principles. Use when FPS drops below 60.
---

# Performance Optimization Basics

> "Optimize for mobile, scale up for desktop – 60 FPS is the goal."

## When to Use

Use when:
- FPS drops below 60
- Debugging performance issues
- Starting optimization work

## The 16ms Budget (60 FPS)

| System     | Budget      | Notes                 |
| ---------- | ----------- | --------------------- |
| Input      | ~1ms        | Event handling        |
| Physics    | ~3ms        | Rapier/Cannon updates |
| Game Logic | ~4ms        | State, AI, animations |
| Render     | ~5ms        | Three.js draw calls   |
| Buffer     | ~3ms        | Safety margin         |
| **Total**  | **16.67ms** | 60 FPS target         |

## Quick Start Canvas Config

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

## Decision Framework

| Symptom            | Likely Cause        | Solution            |
| ------------------ | ------------------- | ------------------- |
| Low FPS everywhere | Too many draw calls | Instancing, merging |
| FPS drops on zoom  | LOD not implemented | Add LOD system      |
| Mobile slow        | DPR too high        | Limit to 1.5        |
| Memory grows       | Dispose missing     | Add cleanup         |
| Stuttering         | GC pressure         | Object pooling      |

## Progressive Optimizations

### Level 1: Basic

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

### Level 2: Object Reuse

```tsx
// Reuse Vector3, Quaternion instances
const position = useRef(new THREE.Vector3());
const rotation = useRef(new THREE.Quaternion());

useFrame(() => {
  position.current.set(0, 0, 0); // Reuse, don't create
});
```

### Level 3: Memory Management

```tsx
// CRITICAL: Dispose of Three.js objects
useEffect(() => {
  const geometry = new THREE.BoxGeometry();
  const material = new THREE.MeshStandardMaterial();

  return () => {
    geometry.dispose();
    material.dispose();
    if (material.map) material.map.dispose();
  };
}, []);
```

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

## Performance Measurement Examples

### FPS Counter with Stats

```tsx
import { useEffect, useRef } from 'react';
import { useThree } from '@react-three/fiber';
import Stats from 'three/examples/jsm/libs/stats.module';

export function PerformanceStats() {
  const statsRef = useRef<Stats>();

  useThree(({ gl }) => {
    if (!statsRef.current) {
      const stats = new Stats();
      stats.showPanel(0); // 0: fps, 1: ms, 2: mb
      document.body.appendChild(stats.dom);
      statsRef.current = stats;
    }

    const stats = statsRef.current;
    if (stats) {
      stats.begin();
      gl.render(stats.dom);
      stats.end();
    }
  });

  return null;
}
```

### Frame Time Measurement

```tsx
// Measure individual frame times
function FrameTimeProfiler() {
  const frameTimes = useRef<number[]>([]);
  const maxSamples = 60;

  useFrame((_, delta) => {
    frameTimes.current.push(delta);

    if (frameTimes.current.length > maxSamples) {
      frameTimes.current.shift();
    }

    // Calculate statistics
    if (frameTimes.current.length === maxSamples) {
      const avg = frameTimes.current.reduce((a, b) => a + b) / maxSamples;
      const max = Math.max(...frameTimes.current);
      const p99 = frameTimes.current.sort((a, b) => a - b)[54]; // 99th percentile

      console.log(`Frame time - Avg: ${avg.toFixed(2)}ms, Max: ${max.toFixed(2)}ms, P99: ${p99.toFixed(2)}ms`);
      console.log(`Estimated FPS: ${Math.round(1000 / avg)}`);
    }
  });

  return null;
}
```

### Draw Call Counter

```tsx
// Measure draw calls (Three.js info)
function DrawCallMonitor() {
  const { gl } = useThree();

  useFrame(() => {
    const info = gl.info;
    console.log(`Draw calls: ${info.render.calls}`);
    console.log(`Triangles: ${info.render.triangles}`);
    console.log(`Textures: ${info.memory.textures}`);
    console.log(`Geometries: ${info.memory.geometries}`);
  });

  return null;
}
```

### Memory Profiling

```tsx
// Track memory usage over time
function MemoryMonitor() {
  const measurements = useRef<number[]>([]);
  const interval = 1000; // Check every second

  useEffect(() => {
    const timer = setInterval(() => {
      if ('memory' in performance) {
        const mem = (performance as any).memory;
        const usedMB = mem.usedJSHeapSize / 1048576;
        measurements.current.push(usedMB);

        if (measurements.current.length > 60) {
          measurements.current.shift();
        }

        // Detect memory leak (growing trend)
        if (measurements.current.length > 10) {
          const first = measurements.current[0];
          const last = measurements.current[measurements.current.length - 1];
          const growth = last - first;

          if (growth > 10) {
            console.warn(`Memory grew by ${growth.toFixed(2)}MB over ${measurements.current.length} seconds`);
          }
        }
      }
    }, interval);

    return () => clearInterval(timer);
  }, []);

  return null;
}
```

### Component Render Time Profiler

```tsx
// Measure how long a component takes to render
function withRenderTimeProfiler<P extends object>(
  Component: React.ComponentType<P>,
  name: string
) {
  return function ProfiledComponent(props: P) {
    const startTime = useRef(performance.now());
    const renderCount = useRef(0);

    useEffect(() => {
      const endTime = performance.now();
      const renderTime = endTime - startTime.current;

      renderCount.current++;

      if (renderCount.current % 60 === 0) { // Log every 60 renders
        console.log(`${name} render time: ${renderTime.toFixed(2)}ms (avg over 60: ${(renderTime / 60).toFixed(3)}ms)`);
      }

      startTime.current = performance.now();
    });

    return <Component {...props} />;
  };
}

// Usage
export const ProfiledScene = withRenderTimeProfiler(Scene, "Scene");
```

### Batch Measurement for Optimization

```tsx
// Measure before/after an optimization
function measureOptimization<T>(
  name: string,
  fn: () => T,
  iterations: number = 100
): T {
  // Warm up
  for (let i = 0; i < 10; i++) {
    fn();
  }

  const measurements: number[] = [];
  const startTime = performance.now();

  for (let i = 0; i < iterations; i++) {
    const start = performance.now();
    fn();
    measurements.push(performance.now() - start);
  }

  const totalTime = performance.now() - startTime;
  const avgTime = measurements.reduce((a, b) => a + b) / measurements.length;
  const minTime = Math.min(...measurements);
  const maxTime = Math.max(...measurements);

  console.log(`=== ${name} (${iterations} iterations) ===`);
  console.log(`Total time: ${totalTime.toFixed(2)}ms`);
  console.log(`Average: ${avgTime.toFixed(3)}ms`);
  console.log(`Min: ${minTime.toFixed(3)}ms, Max: ${maxTime.toFixed(3)}ms`);

  return fn();
}

// Example usage
measureOptimization("Scene Render", () => {
  gl.render(scene, camera);
}, 1000);
```

### GPU Time Measurement

```tsx
// Use EXT_disjoint_timer_query for GPU timing (WebGL2)
function GPUProfiler() {
  const { gl } = useThree();

  useEffect(() => {
    const ext = gl.getExtension('EXT_disjoint_timer_query_webgl2');
    if (!ext) {
      console.warn("GPU timing not supported");
      return;
    }

    const query = gl.createQuery(ext.TIMESTAMP_EXT);
    gl.queryCounter(query, ext.QUERY_COUNTER_BITS_EXT);

    const checkResult = () => {
      const available = gl.getQueryParameter(query, gl.QUERY_RESULT_AVAILABLE);
      if (available) {
        const gpuTime = gl.getQueryParameter(query, gl.QUERY_RESULT);
        console.log(`GPU time (ns): ${gpuTime}`);
      } else {
        requestAnimationFrame(checkResult);
      }
    };

    requestAnimationFrame(checkResult);
  }, [gl]);

  return null;
}
```

## Anti-Patterns

❌ **DON'T:**
- Create objects inside useFrame
- Skip dispose() calls
- Use shadows on mobile without testing
- Render invisible objects
- Use uncompressed textures

✅ **DO:**
- Reuse Vector3, Quaternion instances
- Always dispose geometries and materials
- Profile before and after optimizations
- Compress textures (WebP, Basis)

## Checklist

- [ ] DPR limited appropriately
- [ ] No object creation in useFrame
- [ ] Dispose called on cleanup
- [ ] Shadows disabled on mobile
- [ ] Textures compressed
- [ ] FPS stable at 60

## Common Performance Killers

1. **Too many draw calls** → Use Instances
2. **High polygon count** → Use LOD
3. **Unoptimized textures** → Compress, resize
4. **No frustum culling** → Enable frustumCulled
5. **Memory leaks** → Call dispose()
6. **GC pressure** → Object pooling

## Reference

- [Three.js Performance Tips](https://threejs.org/manual/#en/optimize-lots-of-objects)
- [instancing.md](./instancing.md) - Instanced rendering
- [lod-systems.md](./lod-systems.md) - LOD techniques
