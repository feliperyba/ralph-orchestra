# Variable Asset Scales and Pivots

> Normalizing assets from multiple sources with different unit systems.

## Problem: Different Asset Packs Use Different Scales

When combining assets from multiple sources (Blender Market, Sketchfab, vendor packs), each may use different unit systems and scale conventions.

## Solution: Asset Configuration with Normalized Transforms

```tsx
// assets/config/weapon-config.ts
export interface WeaponConfig {
  name: string;
  modelPath: string;
  // Scale normalization
  scale: number;           // Overall scale multiplier
  // Pivot correction (asset origin offset)
  position: [number, number, number];
  rotation: [number, number, number];
  // Optional: per-axis scale for non-uniform correction
  scaleVector?: [number, number, number];
}

export const weaponConfigs: Record<string, WeaponConfig> = {
  // Blaster Kit assets (small scale, ~0.15)
  blaster_rifle: {
    name: 'Blaster Rifle',
    modelPath: '/assets/models/blaster-kit/rifle.glb',
    scale: 0.15,
    position: [0, 0, 0],
    rotation: [0, 0, 0],
  },
  // Weapon Pack assets (default scale, ~1.0)
  plasma_gun: {
    name: 'Plasma Gun',
    modelPath: '/assets/models/weapon-pack/plasma.glb',
    scale: 1.0,
    position: [0, 0, 0],
    rotation: [0, Math.PI, 0],  // May need rotation flip
  },
  // Accessories pack (tiny scale, ~0.01)
  scope_attachment: {
    name: 'Scope',
    modelPath: '/assets/models/accessories/scope.glb',
    scale: 0.01,
    position: [0, 0.5, 0],  // Offset to attach point
    rotation: [0, 0, 0],
  },
};
```

## Normalized Asset Component

```tsx
import { useGLTF } from '@react-three/drei';
import type { WeaponConfig } from './weapon-config';

interface NormalizedAssetProps {
  config: WeaponConfig;
  attachTo?: THREE.Object3D;  // Optional parent attachment
}

export function NormalizedAsset({ config, attachTo }: NormalizedAssetProps) {
  const { scene } = useGLTF(config.modelPath);
  const groupRef = useRef<THREE.Group>(null);

  // Apply configured transforms
  useEffect(() => {
    if (!groupRef.current) return;

    const { scale, position, rotation, scaleVector } = config;

    // Apply scale correction
    if (scaleVector) {
      groupRef.current.scale.set(...scaleVector);
    } else {
      groupRef.current.scale.setScalar(scale);
    }

    // Apply position offset (pivot correction)
    groupRef.current.position.set(...position);

    // Apply rotation correction
    groupRef.current.rotation.set(...rotation);

    // Attach to parent if provided (e.g., hand bone)
    if (attachTo) {
      attachTo.add(groupRef.current);
    }

    return () => {
      if (attachTo && groupRef.current) {
        attachTo.remove(groupRef.current);
      }
    };
  }, [config, attachTo]);

  return (
    <group ref={groupRef}>
      <primitive object={scene} />
    </group>
  );
}
```

## Asset Scale Detection Helper

```tsx
import { useEffect, useRef } from 'react';
import { useGLTF } from '@react-three/drei';
import * as THREE from 'three';

/**
 * Helper to detect asset scale and bounding box
 * Use during development to populate config values
 */
function useAssetInfo(url: string) {
  const { scene } = useGLTF(url);
  const info = useRef<{
    boundingBox: THREE.Box3;
    size: THREE.Vector3;
    center: THREE.Vector3;
  } | null>(null);

  useEffect(() => {
    const box = new THREE.Box3().setFromObject(scene);
    const size = box.getSize(new THREE.Vector3());
    const center = box.getCenter(new THREE.Vector3());

    info.current = { boundingBox: box, size, center };

    // Log for config development
    console.log(`[Asset Info] ${url}`, {
      size: { x: size.x.toFixed(3), y: size.y.toFixed(3), z: size.z.toFixed(3) },
      center: { x: center.x.toFixed(3), y: center.y.toFixed(3), z: center.z.toFixed(3) },
    });
  }, [scene]);

  return info.current;
}
```

## Pivot Point Correction Pattern

**Problem**: Asset origin is not at the attachment point (e.g., gun grip vs. gun center).

**Solution**: Wrapper group with offset correction.

```tsx
interface PivotCorrectedProps {
  modelPath: string;
  // The point that should align with parent (e.g., hand position)
  gripOffset: [number, number, number];
  scale: number;
}

function PivotCorrectedAsset({ modelPath, gripOffset, scale }: PivotCorrectedProps) {
  const { scene } = useGLTF(modelPath);

  return (
    <group scale={scale}>
      {/* Offset wrapper shifts the model so grip point is at origin */}
      <group position={gripOffset}>
        <primitive object={scene} />
      </group>
    </group>
  );
}
```

## Common Scale Conversions

| Source System | Three.js Units | Scale Factor |
| ------------- | -------------- | ------------ |
| Blender (default) | 1 unit = 1 meter | 1.0 |
| Unreal Engine | 1 unit = 1 cm | 0.01 |
| Unity | 1 unit = 1 meter | 1.0 |
| Maya (cm) | 1 unit = 1 cm | 0.01 |
| 3ds Max (inches) | 1 unit = 1 inch | 0.0254 |

## Asset Integration Checklist for Multi-Source Projects

- [ ] Determine source unit system for each asset pack
- [ ] Create config file with scale factors for each asset type
- [ ] Test each asset in isolation to verify scale
- [ ] Measure bounding box to determine grip/handle offset
- [ ] Add rotation correction if asset faces wrong direction
- [ ] Test attachment to character hand bone
- [ ] Verify alignment with animation (weapon doesn't float or clip)

## Retrospective Notes

**Learned from bugfix-005 (2026-01-22)**:
- Asset packs have wildly different scales (0.01 to 1.0+)
- Per-weapon configuration is essential for consistent attachment
- Grip offset varies by model - cannot use universal values
