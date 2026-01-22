# Visual Consistency Checklist

Use this checklist to ensure visual consistency across the project.

## Color Consistency

- [ ] Colors match GDD palette
- [ ] Primary/secondary/accent colors used correctly
- [ ] No hardcoded colors (use theme variables)
- [ ] Color contrast meets accessibility (WCAG AA 4.5:1)
- [ ] Consistent color meaning (red=danger, green=success, etc.)

## Material Consistency

### PBR Values
- [ ] Metalness: 0.0-0.2 for dielectric, 0.8-1.0 for metal
- [ ] Roughness: 0.1-0.3 for polished, 0.7-1.0 for matte
- [ ] No arbitrary values without artistic reason

### Material Types by Asset
| Asset Type | Material Pattern |
| ---------- | ---------------- |
| Ground     | Low metalness, high roughness |
| Water      | Physical, transmission, high roughness |
| Metal      | High metalness, low roughness, clearcoat |
| Foliage    | Low metalness, medium roughness, subsurface |
| Fabric     | Low metalness, high roughness |
| Glass      | Physical, transmission, low roughness, IOR 1.5 |

## Scale and Proportion

- [ ] Character height consistent (reference: 1.75m)
- [ ] Door height: 2.1-2.4m
- [ ] Standard stair: 0.17m rise, 0.28m run
- [ ] Vehicle sizes proportional to characters
- [ ] Props sized for gameplay (not realistic)

## Lighting Consistency

### Indoor
- [ ] Ambient: 0.1-0.3 intensity
- [ ] Key light: 1.0-2.0 intensity
- [ ] Fill light: 0.3-0.5 intensity
- [ ] Rim light: 0.5-1.0 intensity
- [ ] Color temperature: warm (3000-4000K) or cool (5000-6500K)

### Outdoor
- [ ] Sun/Directional: 1.0-5.0 intensity
- [ ] Ambient/Hemisphere: 0.3-0.6 intensity
- [ ] Shadows: soft edge (0.5-1.5 map size)
- [ ] Color temperature: daylight (5500-6500K)

### Time of Day
- [ ] Dawn: warm orange, long shadows
- [ ] Noon: white light, short shadows
- [ ] Dusk: warm purple/red, long shadows
- [ ] Night: cool blue, no direct shadows

## UI Consistency

### Typography
- [ ] Font family: limited to 1-2 typefaces
- [ ] Font sizes: follow modular scale
- [ ] Line height: 1.4-1.6 for body text
- [ ] Font weights: limited to 3-4 (regular, medium, semibold, bold)

### Spacing
- [ ] Uses 8px base unit
- [ ] Consistent padding/margin
- [ ] Grid system followed
- [ ] No arbitrary spacing values

### Components
- [ ] Buttons: consistent size, hover states
- [ ] Cards: consistent corner radius (4-8px)
- [ ] Inputs: consistent styling, focus states
- [ ] Modals: consistent backdrop, animation

## Animation Consistency

### Timing
- [ ] Quick feedback: 100-150ms
- [ ] Standard transition: 200-300ms
- [ ] Slow/weighty: 400-500ms
- [ ] Page transition: 300-500ms

### Easing
- [ ] Enter: ease-out
- [ ] Exit: ease-in
- [ ] Continuous: ease-in-out
- [ ] Bounce: custom (used sparingly)

## Particle Consistency

### Fire
- [ ] Color: white → yellow → orange → red
- [ ] Motion: upward, some turbulence
- [ ] Lifetime: 0.5-2 seconds
- [ ] Blend: additive

### Smoke
- [ ] Color: gray gradient
- [ ] Motion: upward, expanding
- [ ] Lifetime: 2-5 seconds
- [ ] Blend: alpha

### Sparks
- [ ] Color: gold/white
- [ ] Motion: arc with gravity
- [ ] Lifetime: 0.2-0.5 seconds
- [ ] Blend: additive

## Post-Processing Consistency

### Quality Settings
- [ ] Low: vignette only
- [ ] Medium: vignette + bloom
- [ ] High: vignette + bloom + chromatic aberration
- [ ] Ultra: all effects + motion blur

### Effect Intensities
- [ ] Bloom: 0.3-0.8 intensity
- [ ] Vignette: 0.3-0.5 darkness
- [ ] Chromatic aberration: 0.001-0.005 offset
- [ ] Noise: 0.03-0.1 opacity

## Framerate Consistency

- [ ] Target: 60 FPS desktop, 30 FPS mobile
- [ ] Consistent FPS across scenes (±10%)
- [ ] No frame drops during effects
- [ ] Loading screens for heavy scenes

## Common Pitfalls to Avoid

- [ ] No pure #FF0000, #00FF00, #0000FF colors
- [ ] No 0 or 1 roughness (use small epsilon)
- [ ] No perfectly smooth surfaces (add micro-normal)
- [ ] No infinite point lights (use realistic attenuation)
- [ ] No pitch black shadows (ambient occlusion)
- [ ] No jarring transitions between scenes
