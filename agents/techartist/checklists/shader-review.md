# Shader Review Checklist

Use this checklist when reviewing or creating shaders.

## Pre-Flight Checks

- [ ] Shader has clear purpose documented
- [ ] Reference/screenshot of desired look available
- [ ] Target hardware known (mobile/desktop)
- [ ] Performance budget defined

## Vertex Shader

### Inputs
- [ ] All attributes used (position, uv, normal)
- [ ] Unused attributes removed
- [ ] Custom attributes have clear naming

### Outputs (Varyings)
- [ ] Varyings properly declared in vertex shader
- [ ] Varyings properly declared in fragment shader
- [ ] Types match between stages
- [ ] No unused varyings

### Calculations
- [ ] No expensive operations in vertex shader (if avoidable)
- [ ] Matrix multiplications minimized
- [ ] Normal matrix applied correctly
- [ ] View/projection transforms correct

## Fragment Shader

### Color Output
- [ ] Output is in [0,1] range for RGB
- [ ] Alpha channel set correctly
- [ ] Premultiplied alpha considered
- [ ] HDR output handled (if applicable)

### Texture Lookups
- [ ] Textures sampled with correct UVs
- [ ] Texture coordinates not out of range
- [ ] Mipmapping considered (use texture2D vs texture2DLod)
- [ ] Texture formats appropriate for content

### Lighting
- [ ] Normal vectors normalized
- [ ] View direction calculated correctly
- [ ] Light direction/position correct
- [ ] Attenuation applied (if needed)

### Math Operations
- [ ] Division by zero prevented
- [ ] Square root of positive numbers only
- [ ] trig functions inputs in radians
- [ ] mix() used instead of if/else for blends

## Performance

### Instruction Count
- [ ] Fragment shader < 100 ALU instructions (mobile)
- [ ] Fragment shader < 500 ALU instructions (desktop)
- [ ] Vertex shader < 50 ALU instructions
- [ ] No loops with unbounded iteration

### Memory Bandwidth
- [ ] Texture fetches minimized
- [ ] No dependent texture reads in loops
- [ ] Varyings minimized (pack when possible)

### Branching
- [ ] No dynamic branching in fragment shader (if avoidable)
- [ ] Branch prediction friendly when necessary
- [ ] Uses mix/step/smoothstep instead of if/else

## Code Quality

### Readability
- [ ] Complex operations commented
- [ ] Magic numbers extracted as constants
- [ ] Functions have descriptive names
- [ ] Consistent formatting

### Reusability
- [ ] Common functions extracted
- [ ] No duplicate code
- [ ] Uniforms grouped by purpose
- [ ] Shader can be tweaked via uniforms

## Debugging

### Visual Debugging
- [ ] Can visualize individual components
- [ ] Debug modes available (via uniforms)
- [ ] Error states visually distinct

### Console Output
- [ ] No GLSL compilation errors
- [ ] No GLSL compilation warnings
- [ ] Three.js console clean

## Cross-Platform

### Compatibility
- [ ] Works on WebGL 1 (if required)
- [ ] Works on WebGL 2
- [ ] Tested on Chrome
- [ ] Tested on Firefox
- [ ] Tested on Safari
- [ ] Tested on mobile (if required)

### Precision
- [ ] Precision qualifiers set appropriately
- [ ] highp for positions
- [ ] mediump for UVs, colors
- [ ] lowp for simple blends

## Specific Shader Types

### Post-Processing Shaders
- [ ] Input texture sampled correctly
- [ ] Output handles all pixels (no black edges)
- [ ] UV coordinate space handled correctly
- [ ] Aspect ratio considered

### Particle Shaders
- [ ] Point size attenuation calculated
- [ ] Soft particles implemented
- [ ] Fade-out at particle lifetime end
- [ ] Correct blending mode set

### Terrain Shaders
- [ ] Heightmap sampled correctly
- [ ] Slope-based variation works
- [ ] Texture tiling appropriate
- [ ] Triplanar mapping for steep surfaces

## Before Committing

- [ ] Shader tested in actual scene
- [ ] Performance profiled on target hardware
- [ ] Screenshots captured for reference
- [ ] Documented any known limitations
- [ ] Code formatted consistently
