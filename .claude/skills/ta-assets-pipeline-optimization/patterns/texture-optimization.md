# Texture and Audio Optimization

> Compressing textures and audio for web deployment.

## Texture Export Guidelines

**Format Selection:**
- Albedo: WebP (lossy, 80% quality)
- Normal: ASTC (4x4) for mobile, PNG for desktop
- Roughness/Metallic: WebP (lossless)
- AO: WebP (lossy, 70% quality)

**Size Guidelines:**
- Character textures: 1024x1024
- Environment textures: 2048x2048
- UI textures: 512x512 (power of 2)

**Compression Workflow:**

```typescript
// Texture compression function
async function compressTexture(imagePath: string): Promise<Blob> {
  const image = await loadImage(imagePath)
  const canvas = document.createElement('canvas')
  const ctx = canvas.getContext('2d')

  canvas.width = 1024
  canvas.height = 1024

  ctx.drawImage(image, 0, 0)

  return new Promise((resolve) => {
    canvas.toBlob(
      (blob) => resolve(blob!),
      'webp',
      0.8 // 80% quality
    )
  })
}
```

## Texture Memory Leaks

**❌ DON'T:**

```typescript
// Creating textures without cleanup
const texture = new THREE.TextureLoader().load('texture.png')
texture.needsUpdate = true // Updates cause memory leaks
```

**✅ DO:**

```typescript
const textureRef = useRef<THREE.Texture>()

useEffect(() => {
  textureRef.current = new THREE.TextureLoader().load('texture.png')

  return () => {
    if (textureRef.current) {
      textureRef.current.dispose()
      textureRef.current = null
    }
  }
}, [])

// Only update when necessary
if (textureRef.current && needsUpdate) {
  textureRef.current.needsUpdate = true
}
```

## Audio Compression Settings

**Format Guidelines:**
- Sound effects: OGG, 44.1kHz, mono
- Music: OGG, 44.1kHz, stereo
- Voice: OGG, 44.1kHz, mono

**File Size Targets:**
- SFX: < 100KB per file
- Music: < 1MB per minute
- Voice: < 50KB per second

**Compression Tool:**

```bash
# Using oggenc
oggenc -q 5 -r 44100 input.wav -o output.ogg
```

## Reference

- [WebP Compression Guide](https://developers.google.com/speed/webp/docs/cwebp)
- [Three.js Memory Management](https://threejs.org/docs/#manual/en/introduction/How-to-dispose-of-objects)
