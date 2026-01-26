# Model Asset Optimization

> Compressing and optimizing 3D models for web deployment.

## FBX Export Settings (Blender)

**File Export Settings:**
- Format: FBX Binary
- Apply Modifiers: ✓
- Selection Only: ✗
- Include: Mesh, Materials, Armature, Animation
- Exclude: Cameras, Lights, Empty Objects

**Mesh Optimization:**
- Decimate modifier (50% polygon reduction)
- Remove duplicate vertices
- Clean mesh data

## GLB Compression Tools

**glTF Transform Pipeline:**

```bash
# Install
npm install -g @gltf-transform/cli

# Optimize GLB
gltf-transform input.glb output.glb \
  --prune \
  --texture-compress webp \
  --texture-size 2048 \
  --draco-compress
```

**Compression Settings:**
- Draco compression: ✓
- Texture compression: WebP
- Maximum texture size: 2048x2048
- Remove unused attributes

## Polygon Count Targets

| Asset Type | High Poly | Medium Poly | Low Poly | Proxy |
|------------|-----------|-------------|----------|-------|
| Character | 50k | 25k | 10k | 2k |
| Environment | 100k | 50k | 20k | 5k |
| Props | 10k | 5k | 2k | 500 |
| Weapons | 8k | 4k | 1k | 200 |

## Model Loading Anti-Patterns

**❌ DON'T:**

```typescript
// Loading multiple high-poly models at once
function Scene() {
  const char = useFBX('/assets/character.fbx')
  const weapon = useFBX('/assets/weapon.fbx')
  const env = useGLTF('/assets/environment.glb')

  return (
    <>
      <primitive object={char.scene} />
      <primitive object={weapon.scene} />
      <primitive object={env.scene} />
    </>
  )
}
```

**✅ DO:**

```typescript
// Lazy load assets based on camera distance
function Scene() {
  const [characterLoaded, setCharacterLoaded] = useState(false)

  useFrame(() => {
    if (camera.position.distanceTo([0, 0, 0]) < 20 && !characterLoaded) {
      setCharacterLoaded(true)
    }
  })

  return (
    <>
      {characterLoaded ? (
        <Suspense fallback={<LoadingSpinner />}>
          <CharacterModel />
        </Suspense>
      ) : (
        <PlaceholderCharacter />
      )}
    </>
  )
}
```

## Memory Management

**❌ DON'T:**

```typescript
// Not disposing of loaded assets
useEffect(() => {
  const model = useFBX('/assets/character.fbx')
  return () => {} // No cleanup
}, [])
```

**✅ DO:**

```typescript
useEffect(() => {
  let mounted = true

  const loadModel = async () => {
    const model = useFBX('/assets/character.fbx')
    return model
  }

  const model = loadModel()

  return () => {
    mounted = false
    // Dispose of geometries, materials, textures
    if (model?.scene) {
      model.scene.traverse(disposeObject)
    }
  }
}, [])

function disposeObject(object: THREE.Object3D) {
  if (object.geometry) object.geometry.dispose()
  if (object.material) {
    if (Array.isArray(object.material)) {
      object.material.forEach(mat => mat.dispose())
    } else {
      object.material.dispose()
    }
  }
}
```

## Reference

- [glTF Transform Documentation](https://gltf-transform.donmccurdy.com/)
- [Blender FBX Export Guidelines](https://docs.blender.org/manual/en/latest/files/importexport/fbx.html)
