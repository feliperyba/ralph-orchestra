# Bone-Based Attachment for Animated Models

> Attaching weapons, accessories, and effects to animated character skeletons.

## Overview

When attaching objects (weapons, accessories, effects) to animated character models, use the skeleton bone system rather than direct parenting to meshes.

## Finding and Attaching to Bones

```tsx
import { useRef, useEffect } from 'react';
import { useGLTF } from '@react-three/drei';
import * as THREE from 'three';

function CharacterWithWeapon() {
  const { scene } = useGLTF('/assets/models/characterMedium.glb');
  const weaponGroupRef = useRef<THREE.Group>(null);
  const mixerRef = useRef<THREE.AnimationMixer | null>(null);

  useEffect(() => {
    // Traverse to find skinned mesh with skeleton
    scene.traverse((object) => {
      if (object.type === 'SkinnedMesh') {
        const skinnedMesh = object as THREE.SkinnedMesh;
        const skeleton = skinnedMesh.skeleton;

        // Find the specific bone by name
        const handBone = skeleton.bones.find(
          (bone) => bone.name === 'mixamorigRightHand'
          // Common bone names: 'RightHand', 'mixamorigRightHand', 'RHand', 'Hand.R'
          // Check in Blender or Three.js Inspector for exact bone names
        );

        if (handBone && weaponGroupRef.current) {
          // Parent weapon group to bone - weapon moves with animation
          handBone.add(weaponGroupRef.current);
          // Adjust position/rotation relative to bone
          weaponGroupRef.current.position.set(0, 0, 0);
          weaponGroupRef.current.rotation.set(0, 0, 0);
        }
      }
    });

    // Set up animation mixer
    mixerRef.current = new THREE.AnimationMixer(scene);
    const action = mixerRef.current.clipAction(
      scene.animations[0] // First animation
    );
    action.play();

    return () => {
      mixerRef.current?.stopAllAction();
    };
  }, [scene]);

  useFrame((state, delta) => {
    mixerRef.current?.update(delta);
  });

  return (
    <group>
      <primitive object={scene} />
      <group ref={weaponGroupRef}>
        {/* Weapon moves with hand bone */}
        <WeaponModel />
      </group>
    </group>
  );
}
```

## Bone Attachment Pattern

| Step | Action | Purpose |
| ---- | ------ | ------- |
| 1 | Load GLTF with skeleton | Character model with bone hierarchy |
| 2 | Traverse to SkinnedMesh | Find mesh containing skeleton |
| 3 | Find bone by name | Locate attachment point (hand, head, etc.) |
| 4 | Parent object to bone | `bone.add(childObject)` |
| 5 | Position/rotate relative to bone | Fine-tune attachment |
| 6 | Animation moves attachment | Bone animation moves attached object |

## Common Bone Names by Rig Format

| Rig Format | Hand Bone | Head Bone | Spine Bone |
| ---------- | --------- | --------- | ---------- |
| Mixamo | `mixamorigRightHand` | `mixamorigHead` | `mixamorigSpine` |
| Blender | `RightHand`, `Hand.R` | `Head`, `HeadTop` | `Spine`, `Hips` |
| VRM | `rightHand` | `head` | `spine` |
| Custom | Check in Three.js Inspector | Check in Three.js Inspector | Check in Three.js Inspector |

## Debugging Bone Attachments

```tsx
// During development, visualize bone positions
useEffect(() => {
  scene.traverse((object) => {
    if (object.type === 'SkinnedMesh') {
      const skinnedMesh = object as THREE.SkinnedMesh;
      const { bones } = skinnedMesh.skeleton;

      bones.forEach((bone, index) => {
        console.log(`Bone ${index}: ${bone.name}`, bone.position);
      });
    }
  });
}, [scene]);
```

## Retrospective Notes

**Learned from bugfix-004 (2026-01-22)**:
Weapon attachment to character hand requires using `skeleton.bones.find()` to locate the bone, then `bone.add(weaponGroup)` to parent the weapon. Direct mesh parenting doesn't work with animated skeletons.
