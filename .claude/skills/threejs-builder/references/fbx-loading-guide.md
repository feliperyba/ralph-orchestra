# FBX Loading Guide for Three.js

Modern patterns for loading, managing, and displaying FBX models in Three.js and React Three Fiber applications.

---

## Quick Start: The Minimal Pattern

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>FBX Loader</title>
    <style>
        * { margin: 0; padding: 0; }
        body { overflow: hidden; background: #000; }
        canvas { display: block; }
    </style>
</head>
<body>
    <script type="importmap">
    {
        "imports": {
            "three": "https://unpkg.com/three@0.160.0/build/three.module.js",
            "three/addons/": "https://unpkg.com/three@0.160.0/examples/jsm/"
        }
    }
    </script>

    <script type="module">
        import * as THREE from 'three';
        import { FBXLoader } from 'three/addons/loaders/FBXLoader.js';

        // Scene setup
        const scene = new THREE.Scene();
        const camera = new THREE.PerspectiveCamera(75, window.innerWidth / window.innerHeight, 0.1, 1000);
        const renderer = new THREE.WebGLRenderer({ antialias: true });

        renderer.setSize(window.innerWidth, window.innerHeight);
        document.body.appendChild(renderer.domElement);

        // Lighting
        const ambientLight = new THREE.AmbientLight(0xffffff, 0.6);
        scene.add(ambientLight);

        const directionalLight = new THREE.DirectionalLight(0xffffff, 1);
        directionalLight.position.set(5, 10, 7);
        scene.add(directionalLight);

        // Load model
        const loader = new FBXLoader();
        loader.load(
            'path/to/model.fbx',
            (fbx) => {
                // FBXLoader returns the object directly (not a wrapper)
                console.log('Model loaded:', fbx);
                scene.add(fbx);
                camera.position.z = 5;
            },
            (progress) => {
                console.log((progress.loaded / progress.total * 100).toFixed(0) + '%');
            },
            (error) => {
                console.error('Failed to load model:', error);
            }
        );

        // Animation loop
        renderer.setAnimationLoop(() => {
            renderer.render(scene, camera);
        });

        // Handle resize
        window.addEventListener('resize', () => {
            camera.aspect = window.innerWidth / window.innerHeight;
            camera.updateProjectionMatrix();
            renderer.setSize(window.innerWidth, window.innerHeight);
        });
    </script>
</body>
</html>
```

---

## Core Concepts

### Import Maps (Essential for ES Modules)

Always use import maps to resolve Three.js module paths correctly:

```html
<script type="importmap">
{
    "imports": {
        "three": "https://unpkg.com/three@0.160.0/build/three.module.js",
        "three/addons/": "https://unpkg.com/three@0.160.0/examples/jsm/"
    }
}
</script>
```

This allows clean imports:
```javascript
import * as THREE from 'three';
import { FBXLoader } from 'three/addons/loaders/FBXLoader.js';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
```

### Key Difference: FBXLoader Return Value

Unlike glTF's GLTFLoader which returns a wrapper object `{ scene, animations, ... }`, **FBXLoader returns the object directly**:

| Aspect | glTF (GLTFLoader) | FBX (FBXLoader) |
|--------|-------------------|-----------------|
| Return type | `{ scene, animations, ... }` | `THREE.Group` (direct) |
| Scene access | `gltf.scene` | `fbx` (is the scene) |
| Animations | `gltf.animations` | `fbx.animations` (property) |

```javascript
// glTF pattern
loader.load('model.gltf', (gltf) => {
    scene.add(gltf.scene);        // Access via .scene
    const anims = gltf.animations;
});

// FBX pattern
loader.load('model.fbx', (fbx) => {
    scene.add(fbx);                // Direct object
    const anims = fbx.animations;  // Property on object
});
```

---

## Pattern 1: Basic Loading

Simplest approach - load a single model and display it.

```javascript
const loader = new FBXLoader();

loader.load(
    'models/character.fbx',
    (fbx) => {
        // Success callback - fbx is the model directly
        const model = fbx;

        // Optional: enable shadows
        model.traverse((child) => {
            if (child.isMesh) {
                child.castShadow = true;
                child.receiveShadow = true;
            }
        });

        scene.add(model);
    },
    (progress) => {
        // Progress callback (optional)
        const percentComplete = (progress.loaded / progress.total * 100);
        console.log(percentComplete + '% loaded');
    },
    (error) => {
        // Error callback
        console.error('Failed to load model:', error);
    }
);
```

---

## Pattern 2: Promise-Based Loading

For cleaner async/await syntax and easier error handling:

```javascript
const loader = new FBXLoader();

function loadModel(path) {
    return new Promise((resolve, reject) => {
        loader.load(
            path,
            (fbx) => {
                fbx.traverse((child) => {
                    if (child.isMesh) {
                        child.castShadow = true;
                        child.receiveShadow = true;
                    }
                });
                resolve(fbx);  // Resolve directly, not fbx.scene
            },
            (progress) => {
                const pct = (progress.loaded / progress.total * 100).toFixed(0);
                console.log(`Loading: ${pct}%`);
            },
            (error) => {
                console.error('Load error:', error);
                reject(error);
            }
        );
    });
}

// Usage
async function init() {
    try {
        const model = await loadModel('models/character.fbx');
        scene.add(model);
    } catch (error) {
        console.error('Failed to initialize:', error);
    }
}

init();
```

---

## Pattern 3: Loading with Fallbacks

Production-ready pattern that gracefully falls back to procedural geometry if FBX fails:

```javascript
const loader = new FBXLoader();

function loadModel(path, fallbackGeometry, fallbackMaterial) {
    return new Promise((resolve) => {
        loader.load(
            path,
            (fbx) => {
                fbx.traverse((child) => {
                    if (child.isMesh) {
                        child.castShadow = true;
                        child.receiveShadow = true;
                    }
                });
                resolve(fbx);
            },
            undefined,
            (error) => {
                console.warn(`Failed to load ${path}, using fallback:`, error);

                // Create fallback mesh
                const mesh = new THREE.Mesh(fallbackGeometry, fallbackMaterial);
                mesh.castShadow = true;
                resolve(mesh);
            }
        );
    });
}

// Usage
async function init() {
    const playerFallback = new THREE.BoxGeometry(0.4, 0.6, 0.3);
    const playerMat = new THREE.MeshStandardMaterial({ color: 0xE9F2FF });

    const player = await loadModel(
        'assets/Character_Male_1.fbx',
        playerFallback,
        playerMat
    );

    scene.add(player);
}

init();
```

---

## Pattern 4: Batch Loading Multiple Models

Load several models sequentially with status updates:

```javascript
const loader = new FBXLoader();

async function loadAssets(assetList) {
    const loaded = {};

    for (const asset of assetList) {
        try {
            console.log(`Loading ${asset.name}...`);

            const fbx = await new Promise((resolve, reject) => {
                loader.load(asset.path, resolve, undefined, reject);
            });

            // Configure the model
            fbx.traverse((child) => {
                if (child.isMesh) {
                    child.castShadow = true;
                    child.receiveShadow = true;
                }
            });

            loaded[asset.name] = fbx;
            console.log(`✓ Loaded: ${asset.name}`);

        } catch (error) {
            console.error(`✗ Failed: ${asset.name}`, error);
            // Optionally use fallback here
        }
    }

    return loaded;
}

// Usage
const assets = [
    { name: 'player', path: 'models/character.fbx' },
    { name: 'enemy', path: 'models/skeleton.fbx' },
    { name: 'ground', path: 'models/tile.fbx' }
];

loadAssets(assets).then((models) => {
    scene.add(models.player);
    scene.add(models.enemy);
    // ... position and use models
});
```

---

## Pattern 5: Caching & Reuse (with Animation Support)

Load once, clone many times for performance. **CRITICAL:** Use `SkeletonUtils.clone()` for animated/skinned models!

```javascript
import * as THREE from 'three';
import { FBXLoader } from 'three/addons/loaders/FBXLoader.js';
import * as SkeletonUtils from 'three/addons/utils/SkeletonUtils.js';

class ModelCache {
    constructor() {
        this.loader = new FBXLoader();
        this.cache = new Map();
    }

    async load(path) {
        if (this.cache.has(path)) {
            return this.cache.get(path);
        }

        return new Promise((resolve, reject) => {
            this.loader.load(
                path,
                (fbx) => {
                    fbx.traverse((child) => {
                        if (child.isMesh) {
                            child.castShadow = true;
                            child.receiveShadow = true;
                        }
                    });
                    // Store the object and its animations
                    this.cache.set(path, {
                        object: fbx,
                        animations: fbx.animations || []
                    });
                    resolve(this.cache.get(path));
                },
                undefined,
                reject
            );
        });
    }

    clone(path) {
        const cached = this.cache.get(path);
        if (!cached) {
            throw new Error(`Model ${path} not in cache. Load it first.`);
        }

        // CRITICAL: Use SkeletonUtils.clone for animated models!
        // Regular .clone() breaks skeleton bone references
        const hasAnimations = cached.animations && cached.animations.length > 0;
        return hasAnimations
            ? SkeletonUtils.clone(cached.object)
            : cached.object.clone();
    }

    getAnimations(path) {
        return this.cache.get(path)?.animations || [];
    }
}

// Usage
const cache = new ModelCache();
const mixers = []; // Track animation mixers for update loop

async function init() {
    await cache.load('models/enemy.fbx');

    // Spawn multiple animated instances
    for (let i = 0; i < 5; i++) {
        const enemy = cache.clone('models/enemy.fbx');
        enemy.position.x = i * 3;
        scene.add(enemy);

        // Setup independent animation for each clone
        const animations = cache.getAnimations('models/enemy.fbx');
        if (animations.length > 0) {
            const mixer = new THREE.AnimationMixer(enemy);
            mixer.clipAction(animations[0]).play();
            mixers.push(mixer);
        }
    }
}

// In animation loop
function animate() {
    const delta = clock.getDelta();
    mixers.forEach(mixer => mixer.update(delta));
    renderer.render(scene, camera);
}
```

**Why SkeletonUtils.clone() is required:**
- Regular `.clone()` doesn't properly duplicate skeleton/bone hierarchies
- Cloned skinned meshes reference the original skeleton's bones
- This causes cloned models to stay at origin or move with the original
- `SkeletonUtils.clone()` creates independent bone hierarchies for each clone
- **Works for BOTH FBX and glTF animated models!**

---

## Pattern 6: Model Normalization

Scale and position FBX models consistently.

**CRITICAL:** Do NOT use `box.setFromObject(model)` for animated FBX/GLTF models! It includes invisible armature bones, helpers, and skeleton rigs which extend far beyond the visible mesh. This causes models to float above the ground.

```javascript
// ❌ WRONG - includes bones/armatures, model will float
function badNormalize(model, targetSize) {
    const box = new THREE.Box3().setFromObject(model); // Includes skeleton!
    // ... model will be positioned incorrectly
}

// ✓ CORRECT - only visible mesh geometry
function normalizeModel(model, targetSize = 1.5) {
    // Reset transforms
    model.position.set(0, 0, 0);
    model.rotation.set(0, 0, 0);

    // Compute bounding box ONLY from visible mesh geometry
    const box = new THREE.Box3();
    model.traverse((child) => {
        if (child.isMesh && child.geometry) {
            child.geometry.computeBoundingBox();
            const meshBox = child.geometry.boundingBox.clone();
            meshBox.applyMatrix4(child.matrixWorld);
            box.union(meshBox);
        }
    });

    // Fallback for models without mesh children
    if (box.isEmpty()) {
        box.setFromObject(model);
    }

    const size = box.getSize(new THREE.Vector3());
    const maxDim = Math.max(size.x, size.y, size.z);

    // Apply uniform scale
    const scale = targetSize / maxDim;
    model.scale.setScalar(scale);

    // Update world matrices after scaling
    model.updateMatrixWorld(true);

    // Recompute bounds after scale (mesh-only)
    const scaledBox = new THREE.Box3();
    model.traverse((child) => {
        if (child.isMesh && child.geometry) {
            const meshBox = child.geometry.boundingBox.clone();
            meshBox.applyMatrix4(child.matrixWorld);
            scaledBox.union(meshBox);
        }
    });

    if (scaledBox.isEmpty()) {
        scaledBox.setFromObject(model);
    }

    // Position so bottom of visible mesh sits at y=0
    model.position.y = -scaledBox.min.y;

    return model;
}

// Usage
loader.load('models/character.fbx', (fbx) => {
    normalizeModel(fbx, 2.0); // 2 units tall, feet on ground
    scene.add(fbx);
});
```

**Why this matters:**
- FBX/GLTF characters have skeleton armatures for animation
- Armature bones (hips, spine, etc.) are positioned at body center, not feet
- `setFromObject()` includes these invisible bones in the bounding box
- Result: `box.min.y` is much lower than actual feet → model floats

---

## React Three Fiber Pattern

For projects using React Three Fiber with `@react-three/drei`:

```typescript
import { useFBX, useAnimations } from '@react-three/drei';
import { useEffect } from 'react';
import * as THREE from 'three';

interface CharacterProps {
  position?: [number, number, number];
  animation?: 'idle' | 'walk' | 'run';
}

function Character({ position = [0, 0, 0], animation = 'idle' }: CharacterProps) {
  // Load base character model
  const character = useFBX('/src/assets/models/characters/characterMedium.fbx');

  // Load animations from separate FBX files
  const idleAnim = useFBX('/src/assets/models/characters/animations/idle.fbx');
  const walkAnim = useFBX('/src/assets/models/characters/animations/walk.fbx');
  const runAnim = useFBX('/src/assets/models/characters/animations/run.fbx');

  // Collect all animations from the loaded FBX files
  const animations = [
    ...(idleAnim.animations || []),
    ...(walkAnim.animations || []),
    ...(runAnim.animations || []),
  ];

  const { actions, clips } = useAnimations(animations, character);

  // Play the requested animation
  useEffect(() => {
    if (!actions || Object.keys(actions).length === 0) return;

    // Find animation by name (adjust based on your asset naming)
    const actionName = Object.keys(actions).find(
      name => name.toLowerCase().includes(animation)
    );

    if (actionName && actions[actionName]) {
      actions[actionName].reset().fadeIn(0.3).play();
    }
  }, [animation, actions]);

  return <primitive object={character} position={position} scale={0.01} />;
}
```

**Key points for React Three Fiber:**
- `useFBX()` returns the FBX object directly (like FBXLoader)
- Animations are accessed via `.animations` property on each loaded FBX
- `useAnimations()` hook from `@react-three/drei` handles AnimationMixer setup
- Each animation file typically contains one animation clip

---

## Common Pitfalls & Solutions

### ❌ FBX Won't Load - File Not Found

**Problem**: 404 errors for FBX files

**Solutions**:
- Verify the file path is correct (relative to HTML file or public folder)
- Use a local web server (`python3 -m http.server 8000`)
- Check browser console for exact error

```bash
# Start local server in your project directory
python3 -m http.server 8080

# Visit http://localhost:8080
```

### ❌ Models Look Wrong - Incorrect Scale/Rotation

**Problem**: Model is huge, tiny, or upside down

**Solution**: Use the normalization pattern above, or adjust manually:

```javascript
loader.load('model.fbx', (fbx) => {
    const model = fbx;  // FBX returns object directly

    // Debug: log original bounds
    const box = new THREE.Box3().setFromObject(model);
    console.log('Bounds:', box);

    // Adjust scale and rotation
    model.scale.set(0.5, 0.5, 0.5);
    model.rotation.x = Math.PI / 2; // Rotate 90°

    scene.add(model);
});
```

### ❌ Animated Model Floats Above Ground

**Problem**: Character model hovers above the floor after positioning

**Cause**: `Box3.setFromObject()` includes invisible skeleton bones/armatures in the bounding box calculation. Armature origins are typically at hip level, not feet.

**Solution**: Compute bounds only from visible mesh geometry:

```javascript
// ❌ WRONG
const box = new THREE.Box3().setFromObject(model);
model.position.y = -box.min.y; // Model floats!

// ✓ CORRECT
const box = new THREE.Box3();
model.traverse((child) => {
    if (child.isMesh && child.geometry) {
        child.geometry.computeBoundingBox();
        const meshBox = child.geometry.boundingBox.clone();
        meshBox.applyMatrix4(child.matrixWorld);
        box.union(meshBox);
    }
});
model.position.y = -box.min.y; // Feet on ground
```

See **Pattern 6: Model Normalization** for the complete solution.

### ❌ Cloned Animated Model Stays at Origin

**Problem**: You clone an FBX model but the clone stays at position (0,0,0) and won't move, or moves with the original model instead of independently. May also flicker or render incorrectly.

**Cause**: Regular `.clone()` doesn't properly duplicate skeleton/bone hierarchies. The cloned skinned mesh still references the original model's bones.

**Solution**: Use `SkeletonUtils.clone()` for any animated/skinned model:

```javascript
import * as SkeletonUtils from 'three/addons/utils/SkeletonUtils.js';

// ❌ WRONG - clone stays at origin, animations broken
const badClone = model.clone();
badClone.position.x = 5; // Won't work!

// ✓ CORRECT - fully independent clone
const goodClone = SkeletonUtils.clone(model);
goodClone.position.x = 5; // Works!

// Each clone needs its own AnimationMixer
const mixer = new THREE.AnimationMixer(goodClone);
mixer.clipAction(animations[0]).play();
```

**Detection**: If your model has `fbx.animations` array with length > 0, it likely has a skeleton and needs `SkeletonUtils.clone()`.

**Note:** `SkeletonUtils.clone()` works for BOTH FBX and glTF animated models!

### ❌ No Shadows on FBX Models

**Problem**: Models don't cast or receive shadows

**Solution**: Enable shadows on all meshes:

```javascript
loader.load('model.fbx', (fbx) => {
    fbx.traverse((child) => {
        if (child.isMesh) {
            child.castShadow = true;
            child.receiveShadow = true;
        }
    });
    scene.add(fbx);
});
```

### ❌ Slow Loading - Large Models Block Scene

**Problem**: Page freezes while loading

**Solution**: Load in background, show progress:

```javascript
const loadingBar = document.getElementById('loading');

loader.load(
    'huge-model.fbx',
    (fbx) => {
        scene.add(fbx);
        loadingBar.style.display = 'none';
    },
    (progress) => {
        const pct = (progress.loaded / progress.total * 100);
        loadingBar.style.width = pct + '%';
    },
    (error) => {
        loadingBar.textContent = 'Load failed';
    }
);
```

---

## FBX Coordinate System Note

FBX models exported from Blender typically face **+Z** (toward viewer), unlike glTF which faces **-Z** (into screen). However, this can vary by exporter and settings.

**Always calibrate** using the reference frame contract to confirm forward direction for your specific asset pack. See `reference-frame-contract.md` for calibration procedures.

---

## Best Practices Summary

| Practice | Benefit |
|----------|---------|
| **Use import maps** | Cleaner imports, works with CDN modules |
| **Wrap in promises** | Better error handling, easier async/await |
| **Add fallbacks** | Graceful degradation if models fail |
| **Cache & clone** | Better performance when spawning many instances |
| **SkeletonUtils.clone()** | **Required** for animated/skinned models (FBX and glTF) |
| **Enable shadows** | Traverse & set castShadow/receiveShadow |
| **Normalize scale** | Consistent sizing across different models |
| **Mesh-only bounds** | Use mesh geometry, not setFromObject() for animated models |
| **Show progress** | Better UX for large models |
| **Use local server** | Avoid CORS, proper relative paths |
| **Calibrate forward** | Confirm forward direction with reference frame contract |

---

## Reference: FBXLoader Callback Signature

```javascript
loader.load(
    url,              // string: path to .fbx file
    onLoad,           // function(object): called on success
    onProgress,       // function(progress): called during load
    onError           // function(error): called on failure
);
```

**Returned FBX object:**
- Type: `THREE.Group`
- Properties:
  - `.animations: Array<THREE.AnimationClip>` - Animation clips (if present)
  - Standard Group properties (children, position, rotation, scale, etc.)

```javascript
loader.load('model.fbx', (fbx) => {
    // fbx is a THREE.Group
    console.log(fbx instanceof THREE.Group);  // true

    // Access animations
    console.log(fbx.animations);  // Array<AnimationClip> or undefined

    // Standard Group operations
    scene.add(fbx);
    fbx.position.set(0, 1, 0);
    fbx.scale.setScalar(0.01);
});
```

**progress object:**
```javascript
{
    loaded: number,   // Bytes loaded
    total: number     // Total bytes to load
}
```

---

## Comparison: glTF vs FBX in Three.js

| Aspect | glTF | FBX |
|--------|------|-----|
| **Loader** | `GLTFLoader` | `FBXLoader` |
| **Return** | `{ scene, animations, ... }` | `THREE.Group` directly |
| **Scene** | `gltf.scene` | `fbx` (is the scene) |
| **Animations** | `gltf.animations` | `fbx.animations` |
| **R3F Hook** | `useGLTF()` | `useFBX()` |
| **Default Forward** | -Z (into screen) | +Z (toward viewer) typically |
| **SkeletonUtils.clone()** | Required for animated | Required for animated |
| **File Extension** | `.gltf`, `.glb` | `.fbx` |

**Note:** Many patterns (SkeletonUtils, mesh-only bounds, AnimationMixer) work identically for both formats!
