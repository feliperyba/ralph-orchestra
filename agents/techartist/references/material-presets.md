# Material Presets

Common material setups for game assets. Use these as starting points.

## Metal Materials

### Brushed Metal

```tsx
<meshStandardMaterial
  color="#808080"
  metalness={1.0}
  roughness={0.4}
  envMapIntensity={1.0}
/>
```

### Polished Chrome

```tsx
<meshStandardMaterial
  color="#ffffff"
  metalness={1.0}
  roughness={0.05}
  envMapIntensity={2.0}
/>
```

### Burnished Metal

```tsx
<meshStandardMaterial
  color="#404040"
  metalness={0.9}
  roughness={0.6}
  envMapIntensity={0.8}
/>
```

### Gold

```tsx
<meshStandardMaterial
  color="#FFD700"
  metalness={1.0}
  roughness={0.15}
  envMapIntensity={1.5}
/>
```

### Copper

```tsx
<meshStandardMaterial
  color="#B87333"
  metalness={1.0}
  roughness={0.25}
  envMapIntensity={1.2}
/>
```

## Paint Materials

### Glossy Car Paint

```tsx
<meshPhysicalMaterial
  color="#CC0000"
  metalness={0.0}
  roughness={0.15}
  clearcoat={1.0}
  clearcoatRoughness={0.05}
  envMapIntensity={1.5}
/>
```

### Matte Car Paint

```tsx
<meshStandardMaterial
  color="#CC0000"
  metalness={0.0}
  roughness={0.85}
/>
```

### Metallic Paint

```tsx
<meshPhysicalMaterial
  color="#CC0000"
  metalness={0.6}
  roughness={0.3}
  clearcoat={0.8}
  clearcoatRoughness={0.15}
  envMapIntensity={1.2}
/>
```

## Plastic Materials

### Shiny Plastic

```tsx
<meshStandardMaterial
  color="#3366FF"
  metalness={0.0}
  roughness={0.2}
/>
```

### Matte Plastic

```tsx
<meshStandardMaterial
  color="#3366FF"
  metalness={0.0}
  roughness={0.8}
/>
```

### Translucent Plastic

```tsx
<meshPhysicalMaterial
  color="#3366FF"
  metalness={0.0}
  roughness={0.3}
  transmission={0.3}
  thickness={0.5}
  transparent
/>
```

## Organic Materials

### Skin

```tsx
<meshPhysicalMaterial
  color="#E8B89C"
  metalness={0.0}
  roughness={0.5}
  clearcoat={0.0}
  sheen={1.0}
  sheenColor="#E8B89C"
/>
```

### Wood (Unfinished)

```tsx
<meshStandardMaterial
  color="#8B5A2B"
  metalness={0.0}
  roughness={0.9}
/>
```

### Wood (Polished)

```tsx
<meshStandardMaterial
  color="#8B5A2B"
  metalness={0.0}
  roughness={0.4}
/>
```

### Leather

```tsx
<meshStandardMaterial
  color="#4A3728"
  metalness={0.0}
  roughness={0.7}
/>
```

### Fabric (Cotton)

```tsx
<meshStandardMaterial
  color="#FFFFFF"
  metalness={0.0}
  roughness={0.9}
/>
```

### Fabric (Silk)

```tsx
<meshStandardMaterial
  color="#FFFFFF"
  metalness={0.0}
  roughness={0.4}
  sheen={0.5}
/>
```

## Stone Materials

### Concrete

```tsx
<meshStandardMaterial
  color="#808080"
  metalness={0.0}
  roughness={0.95}
/>
```

### Polished Marble

```tsx
<meshStandardMaterial
  color="#FFFFFF"
  metalness={0.0}
  roughness={0.1}
/>
```

### Rough Stone

```tsx
<meshStandardMaterial
  color="#696969"
  metalness={0.0}
  roughness={0.9}
/>
```

## Glass Materials

### Clear Glass

```tsx
<meshPhysicalMaterial
  color="#ffffff"
  metalness={0.0}
  roughness={0.0}
  transmission={1.0}
  thickness={0.5}
  ior={1.5}
  clearcoat={1.0}
  transparent
/>
```

### Frosted Glass

```tsx
<meshPhysicalMaterial
  color="#ffffff"
  metalness={0.0}
  roughness={0.4}
  transmission={0.9}
  thickness={0.5}
  ior={1.5}
  transparent
/>
```

### Tinted Glass

```tsx
<meshPhysicalMaterial
  color="#1a1a4a"
  metalness={0.0}
  roughness={0.0}
  transmission={0.8}
  thickness={0.5}
  ior={1.5}
  transparent
/>
```

## Liquid Materials

### Water

```tsx
<meshPhysicalMaterial
  color="#006994"
  metalness={0.1}
  roughness={0.1}
  transmission={0.9}
  thickness={1.0}
  ior={1.33}
  transparent
/>
```

### Oil

```tsx
<meshPhysicalMaterial
  color="#1a1a1a"
  metalness={0.0}
  roughness={0.15}
  transmission={0.8}
  thickness={0.3}
  ior={1.47}
  transparent
/>
```

## Emissive Materials

### Neon Glow

```tsx
<meshStandardMaterial
  color="#FF00FF"
  emissive="#FF00FF"
  emissiveIntensity={2.0}
/>
```

### LED Display

```tsx
<meshStandardMaterial
  color="#00FF00"
  emissive="#00FF00"
  emissiveIntensity={0.5}
/>
```

### Hot Metal

```tsx
<meshStandardMaterial
  color="#FF4500"
  metalness={0.8}
  roughness={0.4}
  emissive="#FF0000"
  emissiveIntensity={0.3}
/>
```

## Toon/Cel Materials

### Basic Toon

```tsx
<meshToonMaterial
  color="#FF6B35"
/>
```

### Toon with Gradient

```tsx
<meshToonMaterial
  color="#FF6B35"
  gradientMap={toonGradientTexture}
/>
```

## Skybox/Background

### Basic Sky

```tsx
<meshBasicMaterial
  color="#87CEEB"
  side={THREE.BackSide}
/>
```

### Gradient Sky

```tsx
// Use shader material for gradient
const SkyMaterial = shaderMaterial({
  topColor: new THREE.Color("#0077ff"),
  bottomColor: new THREE.Color("#ffffff"),
  offset: 33,
  exponent: 0.6,
}, vertexShader, fragmentShader);
```

## Terrain Materials

### Grass

```tsx
<meshStandardMaterial
  color="#4a7c23"
  metalness={0.0}
  roughness={0.9}
/>
```

### Dirt

```tsx
<meshStandardMaterial
  color="#5c4033"
  metalness={0.0}
  roughness={0.95}
/>
```

### Sand

```tsx
<meshStandardMaterial
  color="#f4a460"
  metalness={0.0}
  roughness={0.85}
/>
```

### Snow

```tsx
<meshStandardMaterial
  color="#ffffff"
  metalness={0.0}
  roughness={0.6}
/>
```

## Performance Notes

| Material | Draw Calls | Mobile Friendly |
| -------- | --------- | --------------- |
| Basic    | 1         | Yes             |
| Standard | 1         | Yes             |
| Physical | 2-3       | Moderate        |
| Toon     | 1         | Yes             |
| Shader   | Varies    | Test first      |
