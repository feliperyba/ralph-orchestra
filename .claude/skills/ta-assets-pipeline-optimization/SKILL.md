---
name: ta-assets-pipeline-optimization
description: Optimizes 3D assets for web deployment. Use proactively when optimizing FBX/GLB models or configuring Vite plugins for asset processing.
category: techartist
---

# 3D Asset Pipeline Optimization

## When to Use

- Optimizing FBX/GLB models for web deployment
- Setting up efficient texture workflows
- Managing audio asset compression
- Creating asset LOD systems
- Optimizing shader asset loading

## Pattern Files

| Topic | Reference |
|-------|-----------|
| Model optimization | [patterns/model-optimization.md](patterns/model-optimization.md) |
| Texture & audio optimization | [patterns/texture-optimization.md](patterns/texture-optimization.md) |

## Quick Start

```markdown
## Asset Optimization Checklist

### Before Export
- [ ] FBX: Remove unused materials, animations, textures
- [ ] Textures: Compress to WebP/ASTC, power of 2 sizes
- [ ] Audio: Convert to OGG, 44.1kHz, < 1MB
- [ ] Models: Polygon count < 50k for main characters

### Vite Configuration
```typescript
// vite.config.ts
build: {
  assetsInlineLimit: 0, // Never inline binary assets
  rollupOptions: {
    output: {
      assetFileNames: 'assets/[name].[hash][extname]'
    }
  }
}
```

### Asset Loading
```typescript
// Optimized model loading with LOD
import { useGLTF, useFBX } from '@react-three/drei'

function OptimizedModel({ url, lod }) {
  const model = lod === 'low'
    ? useGLTF('/assets/low-poly/model.glb')
    : useFBX('/assets/high-poly/model.fbx')
  return <primitive object={model.scene} />
}
```

## Asset Management System

### 1. Asset Organization

```
src/assets/
├── models/
│   ├── characters/
│   │   ├── high-poly/
│   │   ├── low-poly/
│   │   └── animations/
│   ├── environment/
│   │   ├── props/
│   │   └── terrain/
│   └── weapons/
├── textures/
│   ├── characters/
│   ├── environment/
│   ├── ui/
│   └── shared/
├── audio/
│   ├── sfx/
│   ├── music/
│   └── voice/
└── shaders/
    ├── materials/
    └── post-processing/
```

### 2. Asset Metadata System

```typescript
// src/assets/metadata.ts
interface AssetMetadata {
  id: string
  name: string
  type: 'model' | 'texture' | 'audio' | 'shader'
  path: string
  size: number
  optimized: boolean
  lod?: 'high' | 'medium' | 'low'
  compression?: 'draco' | 'none'
  streaming?: boolean
}

export const assetRegistry: AssetMetadata[] = [
  {
    id: 'character-main',
    name: 'Main Character',
    type: 'model',
    path: '/assets/characters/main.fbx',
    size: 2048576, // 2MB
    optimized: true,
    lod: 'high',
    compression: 'draco'
  },
  // ... more assets
]
```

### 3. Asset Loader with Caching

```typescript
class AssetLoader {
  private cache = new Map<string, any>()
  private loading = new Map<string, Promise<any>>()

  async loadModel(url: string, lod?: string): Promise<THREE.Group> {
    const cacheKey = `${url}?lod=${lod}`

    if (this.cache.has(cacheKey)) {
      return this.cache.get(cacheKey)
    }

    if (this.loading.has(cacheKey)) {
      return this.loading.get(cacheKey)
    }

    const loadPromise = this.internalLoadModel(url, lod)
    this.loading.set(cacheKey, loadPromise)

    try {
      const model = await loadPromise
      this.cache.set(cacheKey, model)
      return model
    } finally {
      this.loading.delete(cacheKey)
    }
  }

  private async internalLoadModel(url: string, lod?: string) {
    if (url.endsWith('.glb')) {
      const gltf = await useGLTF(url)
      return gltf.scene
    } else if (url.endsWith('.fbx')) {
      const fbx = await useFBX(url)
      return fbx.scene
    }
    throw new Error('Unsupported model format')
  }
}
```

## LOD (Level of Detail) System

### 1. Asset Preparation

```markdown
**LOD Creation Workflow:**
1. Export high-poly model (100% detail)
2. Create medium-poly (50% detail)
3. Create low-poly (25% detail)
4. Create proxy (10% detail)

**Reduction Targets:**
- Character: High=50k, Medium=25k, Low=10k, Proxy=2k
- Environment: High=100k, Medium=50k, Low=20k, Proxy=5k
```

### 2. LOD Manager

```typescript
import { useFrame, useThree } from '@react-three/fiber'
import { useRef, useState } from 'react'

function LODManager({ models }: { models: { high: string; medium: string; low: string } }) {
  const [currentLOD, setCurrentLOD] = useState<'high' | 'medium' | 'low'>('high')
  const camera = useThree((state) => state.camera)
  const [distance, setDistance] = useState(0)

  useFrame(() => {
    const dist = camera.position.distanceTo([0, 0, 0])
    setDistance(dist)

    if (dist < 10) {
      setCurrentLOD('high')
    } else if (dist < 30) {
      setCurrentLOD('medium')
    } else {
      setCurrentLOD('low')
    }
  })

  const currentModel = models[currentLOD]

  return (
    <Suspense fallback={<LoadingSpinner />}>
      <Model url={currentModel} />
    </Suspense>
  )
}
```

## Performance Monitoring

### 1. Asset Performance Tracker

```typescript
function AssetPerformanceTracker() {
  const [stats, setStats] = useState({
    loadedAssets: 0,
    totalSize: 0,
    loadTimes: [] as number[],
    memoryUsage: 0
  })

  useEffect(() => {
    const interval = setInterval(() => {
      const assets = performance.getEntriesByType('resource')
      const modelAssets = assets.filter(a =>
        a.name.includes('.fbx') ||
        a.name.includes('.glb') ||
        a.name.includes('.png') ||
        a.name.includes('.jpg')
      )

      const totalSize = modelAssets.reduce((sum, asset) => {
        return sum + (asset as any).transferSize || 0
      }, 0)

      setStats({
        loadedAssets: modelAssets.length,
        totalSize,
        loadTimes: modelAssets.map(a => a.duration),
        memoryUsage: performance.memory?.usedJSHeapSize || 0
      })
    }, 5000)

    return () => clearInterval(interval)
  }, [])

  return (
    <div className="asset-stats">
      <h3>Asset Performance</h3>
      <p>Loaded: {stats.loadedAssets}</p>
      <p>Total Size: {formatBytes(stats.totalSize)}</p>
      <p>Load Time: {stats.loadTimes.reduce((a, b) => a + b, 0).toFixed(2)}ms</p>
      <p>Memory: {formatBytes(stats.memoryUsage)}</p>
    </div>
  )
}
```

## Optimization Workflow

### 1. Asset Analysis

```typescript
function analyzeAssetPerformance() {
  const resources = performance.getEntriesByType('resource')

  const assetAnalysis = {
    totalAssets: resources.length,
    byType: {
      models: resources.filter(r => r.name.includes('.fbx') || r.name.includes('.glb')).length,
      textures: resources.filter(r => r.name.includes('.png') || r.name.includes('.jpg')).length,
      audio: resources.filter(r => r.name.includes('.ogg') || r.name.includes('.mp3')).length
    },
    avgLoadTime: resources.reduce((sum, r) => sum + r.duration, 0) / resources.length,
    largestAssets: resources
      .sort((a, b) => (b as any).transferSize - (a as any).transferSize)
      .slice(0, 5)
  }

  return assetAnalysis
}
```

### 2. Optimization Report

```typescript
function generateOptimizationReport() {
  const analysis = analyzeAssetPerformance()

  return {
    suggestions: [
      ...(analysis.avgLoadTime > 1000 ? ['Consider texture compression'] : []),
      ...(analysis.largestAssets[0]?.transferSize > 1000000 ? ['Optimize large assets'] : []),
      ...(analysis.byType.models > 10 ? ['Implement LOD system'] : [])
    ],
    recommendations: {
      compression: analysis.byType.textures > 5 ? true : false,
      lod: analysis.byType.models > 3 ? true : false,
      streaming: analysis.totalAssets > 20 ? true : false
    }
  }
}
```

## Reference

- [patterns/model-optimization.md](patterns/model-optimization.md) — Model-specific optimization
- [patterns/texture-optimization.md](patterns/texture-optimization.md) — Texture & audio optimization
- [glTF Transform Documentation](https://gltf-transform.donmccurdy.com/)
- [WebP Compression Guide](https://developers.google.com/speed/webp/docs/cwebp)
- [Three.js Memory Management](https://threejs.org/docs/#manual/en/introduction/How-to-dispose-of-objects)
