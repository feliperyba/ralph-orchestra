# Asset Quality Checklist

Use this checklist before marking any asset as ready for QA.

## General Requirements

- [ ] Asset follows naming conventions (`{Name}{Type}.{ext}`)
- [ ] Asset placed in correct directory
- [ ] Component has TypeScript types
- [ ] Props documented with JSDoc comments
- [ ] Example usage included in comments

## 3D Models

### File Format
- [ ] Exported as GLB/GLTF format
- [ ] Binary format (.glb) for production
- [ ] Draco compression applied (if needed)
- [ ] Scene is cleaned (no unused objects/materials)

### Geometry
- [ ] Polygon count within budget
- [ ] No ngons (all quads/tris)
- [ ] Normals are correctly oriented
- [ ] UVs are non-overlapping (unless intentional)
- [ ] Vertex count optimized (no excessive subdivision)

### Materials
- [ ] PBR materials used correctly
- [ ] Roughness/metalness values appropriate
- [ ] Textures are power-of-2 dimensions
- [ ] Textures are compressed (WebP/Basis)
- [ ] Material slots merged where possible

### LOD Levels
- [ ] LOD0: High detail (< 5000 tris for characters)
- [ ] LOD1: Medium detail (~50% tris)
- [ ] LOD2: Low detail (~25% tris)
- [ ] LOD3: Billboard or simple geometry

## Textures

### Technical Requirements
- [ ] Power-of-2 dimensions (512, 1024, 2048, 4096)
- [ ] Compressed format (WebP, KTX2, or Basis)
- [ ] Mipmaps generated
- [ ] Color profile: sRGB for color, Linear for data

### Texture Types
- [ ] **Albedo/Color**: No lighting info, base colors only
- [ ] **Normal**: Tangent space, +Y up (OpenGL convention)
- [ ] **Roughness**: Grayscale, 0=glossy, 1=matte
- [ ] **Metalness**: 0=non-metal, 1=metal (mostly binary)
- [ ] **AO**: Ambient occlusion in separate channel
- [ ] **Emissive**: Light emission info

### Size Guidelines
| Asset Type | Color Map | Normal Map | Roughness |
| ---------- | --------- | ---------- | --------- |
| Props      | 512-1024  | 512        | 512       |
| Characters | 1024-2048 | 1024-2048  | 1024      |
| Vehicles   | 1024-2048 | 1024-2048  | 1024      |
| Environment| 2048-4096 | 2048       | 1024      |

## Shaders

### Code Quality
- [ ] GLSL compiles without errors or warnings
- [ ] No dynamic branching (avoid if/else in loops)
- [ ] Uniforms properly typed
- [ ] Varyings match between vertex/fragment
- [ ] Comments explain complex math

### Performance
- [ ] Tested on mobile (if required)
- [ ] Instruction count reasonable
- [ ] No texture lookups in loops (if possible)
- [ ] Uses simpler math when equivalent

### Compatibility
- [ ] Works on target GLSL version
- [ ] Fallback for unsupported features
- [ ] Tested on target hardware

## Components

### Structure
```tsx
/**
 * ComponentName
 *
 * Brief description of what this component renders.
 *
 * @example
 * ```tsx
 * <ComponentName prop="value" />
 * ```
 */
export interface ComponentNameProps {
  /** Prop description */
  prop: string;
}

export const ComponentName = forwardRef<THREE.Group, ComponentNameProps>(
  (props, ref) => {
    // Implementation
  }
);

ComponentName.displayName = 'ComponentName';
```

### Requirements
- [ ] Forward ref support (for R3F)
- [ ] Props interface exported
- [ ] Default props documented
- [ ] Display name set
- [ ] Suspense boundary for async loading

## Performance

- [ ] Asset loads within acceptable time
- [ ] Memory usage is appropriate
- [ ] No frame drops on target hardware
- [ ] LOD system implemented for complex models
- [ ] Instancing used for repeated objects

## Visual Quality

- [ ] Matches GDD art direction
- [ ] Consistent with game style
- [ ] No visible seams or artifacts
- [ ] Good silhouette at distance
- [ ] Colors match palette

## Testing

- [ ] Renders correctly in scene
- [ ] Works with different lighting conditions
- [ ] Animations play correctly (if applicable)
- [ ] Collision bounds match visual (if applicable)
- [ ] Tested in browser (Playwright or manual)

## Before Submitting to QA

Final verification:

- [ ] All feedback loops pass (type-check, lint, build)
- [ ] Asset tested in actual scene context
- [ ] Screenshot or video recorded (for visual validation)
- [ ] Commit message follows Ralph format
- [ ] Task status updated to "ready_for_qa"
