---
name: dev-r3f-r3f-fundamentals
description: React Three Fiber core patterns for scene composition and game loop
category: r3f
---

# R3F Fundamentals

> "Declarative 3D – compose scenes like React components."

## When to Use This Skill

Use when:
- Setting up a new R3F scene
- Creating 3D components
- Implementing game loops with `useFrame`
- Managing canvas and renderer settings

## Quick Start

```tsx
import { Canvas } from '@react-three/fiber';
import { OrbitControls } from '@react-three/drei';

function App() {
  return (
    <Canvas camera={{ position: [0, 5, 10], fov: 50 }}>
      <ambientLight intensity={0.5} />
      <pointLight position={[10, 10, 10]} />
      <mesh>
        <boxGeometry />
        <meshStandardMaterial color="orange" />
      </mesh>
      <OrbitControls />
    </Canvas>
  );
}
```

## Decision Framework

| Need            | Use                                           |
| --------------- | --------------------------------------------- |
| Basic 3D scene  | `<Canvas>` with mesh + geometry + material    |
| Camera controls | `<OrbitControls>` or custom camera rig        |
| Animation loop  | `useFrame` hook                               |
| Access Three.js | `useThree` hook                               |
| Load assets     | `useLoader` or `<Suspense>` with drei loaders |
| Performance     | `<Instances>`, LOD, or `useInstancedMesh`     |

## Progressive Guide

### Level 1: Basic Components

```tsx
// Simple mesh component
export function Box({ position = [0, 0, 0] }) {
  return (
    <mesh position={position}>
      <boxGeometry args={[1, 1, 1]} />
      <meshStandardMaterial color="royalblue" />
    </mesh>
  );
}
```

### Level 2: Animation with useFrame

```tsx
import { useRef } from 'react';
import { useFrame } from '@react-three/fiber';

export function SpinningBox() {
  const meshRef = useRef<THREE.Mesh>(null);

  useFrame((state, delta) => {
    if (meshRef.current) {
      meshRef.current.rotation.x += delta;
      meshRef.current.rotation.y += delta * 0.5;
    }
  });

  return (
    <mesh ref={meshRef}>
      <boxGeometry />
      <meshStandardMaterial color="hotpink" />
    </mesh>
  );
}
```

### Level 3: Accessing Three.js State

```tsx
import { useThree } from '@react-three/fiber';

export function CameraLogger() {
  const { camera, gl, scene, size } = useThree();

  useFrame(() => {
    // Access camera position
    console.log(camera.position.toArray());
  });

  return null;
}
```

### Level 4: Game Loop Pattern

```tsx
import { useGameStore } from '@/store/gameStore';

export function GameLoop() {
  const { phase, updatePhase } = useGameStore();

  useFrame((state, delta) => {
    // Fixed timestep update
    const fixedDelta = Math.min(delta, 1 / 30);

    // Update game logic
    updatePhase(fixedDelta);
  });

  return null;
}
```

### Level 5: Performance Optimization

```tsx
import { Instances, Instance } from '@react-three/drei';

export function ManyBoxes({ count = 1000 }) {
  return (
    <Instances limit={count}>
      <boxGeometry />
      <meshStandardMaterial />
      {Array.from({ length: count }, (_, i) => (
        <Instance
          key={i}
          position={[Math.random() * 100 - 50, Math.random() * 100 - 50, Math.random() * 100 - 50]}
        />
      ))}
    </Instances>
  );
}
```

## Anti-Patterns

**DON'T:**

- Create new objects inside `useFrame` (causes GC pressure)
- Use `useState` for rapidly changing values (use refs instead)
- Import entire Three.js (`import * as THREE`)
- Forget to dispose of geometries and materials
- Use `position={[x, y, z]}` with changing values (creates new array each render)
- **Use manual loaders like `FBXLoader.load()` in `useEffect`** – breaks R3F's suspense system

**DO:**

- Reuse Vector3/Quaternion instances in useFrame
- Use refs for animation state
- Import specific Three.js classes
- Clean up in useEffect return
- Use `position-x`, `position-y`, `position-z` for animated values
- **Use drei hooks (`useFBX`, `useGLTF`) for model loading** – integrates with R3F suspense

## Code Patterns

### Reusable Vector Pattern

```tsx
const tempVec = new THREE.Vector3();

function MovingObject() {
  const meshRef = useRef<THREE.Mesh>(null);

  useFrame((state) => {
    tempVec.set(Math.sin(state.clock.elapsedTime), 0, Math.cos(state.clock.elapsedTime));
    meshRef.current?.position.copy(tempVec);
  });

  return <mesh ref={meshRef}>...</mesh>;
}
```

### Conditional Rendering

```tsx
function ConditionalMesh({ visible }) {
  // Don't render if not visible - saves GPU
  if (!visible) return null;

  return <mesh>...</mesh>;
}
```

### FBX Model Loading Pattern

```tsx
import { useFBX } from '@react-three/drei';
import { Suspense } from 'react';

// ❌ WRONG - Manual loading breaks R3F suspense
// useEffect(() => {
//   new FBXLoader().load(url, (obj) => setFbx(obj));
// }, [url]);

// ✅ CORRECT - Use drei's useFBX hook
function CharacterModel({ url }: { url: string }) {
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

## Checklist

Before implementing R3F component:

- [ ] Using refs for animated values (not useState)
- [ ] Not creating objects inside useFrame
- [ ] Proper cleanup in useEffect
- [ ] Using appropriate drei helpers
- [ ] Canvas has proper camera settings
- [ ] Lighting is set up correctly
- [ ] For FBX/GLTF models: using `useFBX`/`useGLTF` from drei (not manual loaders)

## Reference

- [drei documentation](https://github.com/pmndrs/drei) — Helper components
- [R3F documentation](https://docs.pmnd.rs/react-three-fiber) — Official docs
- [dev-r3f-r3f-physics](../dev-r3f-r3f-physics/SKILL.md) — Physics integration
- [dev-r3f-r3f-materials](../dev-r3f-r3f-materials/SKILL.md) — Materials and shaders

## TPS Camera Reference Values

**Validated working camera distances from feat-tps-003 (2026-01-27):**

| Mode         | Distance Value | Character Framing | Notes                          |
| ------------ | -------------- | ----------------- | ------------------------------ |
| Hipfire      | 3.5 units       | 30-40% of screen   | Character waist up visible    |
| Aim (ADS)    | 1.5 units       | Closer view       | For precision shooting         |

These values provide proper TPS (Third-Person Shooter) framing where the character is clearly visible on the left side of the screen with enough surrounding context.

## TPS Camera Shoulder Offset (feat-tps-004, 2026-01-27)

**⚠️ CRITICAL: Over-the-shoulder view requires BOTH position offset AND look-at offset.**

| Parameter          | Value (left shoulder view) | Notes                              |
| ------------------ | ------------------------- | ---------------------------------- |
| shoulderOffsetRight | 0.75 units                 | Camera position offset (right)     |
| shoulderOffsetLeft  | -0.75 units                | Camera position offset (left)      |
| look-at offset      | Same as position offset    | Often missed - REQUIRED for proper composition |

**Common anti-pattern from feat-tps-004:**
- ❌ Camera position offset but look-at at center (0, 0, 0)
- ✅ Look-at point must ALSO be offset by same shoulder amount

**Example implementation:**
```tsx
// Position offset (standard)
const _vec3_position = new Vector3(0, 1.6, 3.5)
  .add(_vec3_right.clone().multiplyScalar(shoulderOffset));

// Look-at offset (CRITICAL - often missed)
const _vec3_lookAt = targetPosition.clone()
  .add(_vec3_right.clone().multiplyScalar(shoulderOffset));

camera.position.copy(_vec3_position);
camera.lookAt(_vec3_lookAt);
```

**Acceptance criteria validation:**
- Exact numerical values must match acceptance criteria (0.75, not 0.85)
- Add code comments referencing acceptance criteria values
- E2E tests required for camera validation (20+ tests covering offset, distance, swap)
