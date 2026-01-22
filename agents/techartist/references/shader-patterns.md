# Shader Pattern Library

Reusable GLSL shader patterns for common effects.

## Utility Functions

### Noise Functions

```glsl
// Hash function for noise
float hash(vec2 p) {
  return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// 2D Value Noise
float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);

  float a = hash(i);
  float b = hash(i + vec2(1.0, 0.0));
  float c = hash(i + vec2(0.0, 1.0));
  float d = hash(i + vec2(1.0, 1.0));

  return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Fractional Brownian Motion
float fbm(vec2 p) {
  float value = 0.0;
  float amplitude = 0.5;
  for (int i = 0; i < 5; i++) {
    value += amplitude * noise(p);
    p *= 2.0;
    amplitude *= 0.5;
  }
  return value;
}

// Simplex-like noise
vec3 mod289(vec3 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec2 mod289(vec2 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec3 permute(vec3 x) { return mod289(((x*34.0)+1.0)*x); }

float snoise(vec2 v) {
  const vec4 C = vec4(0.211324865405187, 0.366025403784439,
           -0.577350269189626, 0.024390243902439);
  vec2 i  = floor(v + dot(v, C.yy));
  vec2 x0 = v - i + dot(i, C.xx);
  vec2 i1;
  i1 = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
  vec4 x12 = x0.xyxy + C.xxzz;
  x12.xy -= i1;
  i = mod289(i);
  vec3 p = permute(permute(i.y + vec3(0.0, i1.y, 1.0))
    + i.x + vec3(0.0, i1.x, 1.0));
  vec3 m = max(0.5 - vec3(dot(x0,x0), dot(x12.xy,x12.xy),
    dot(x12.zw,x12.zw)), 0.0);
  m = m*m;
  m = m*m;
  vec3 x = 2.0 * fract(p * C.www) - 1.0;
  vec3 h = abs(x) - 0.5;
  vec3 ox = floor(x + 0.5);
  vec3 a0 = x - ox;
  m *= 1.79284291400159 - 0.85373472095314 * (a0*a0 + h*h);
  vec3 g;
  g.x  = a0.x  * x0.x  + h.x  * x0.y;
  g.yz = a0.yz * x12.xz + h.yz * x12.yw;
  return 130.0 * dot(m, g);
}
```

### SDF Primitives

```glsl
// 2D SDFs
float sdCircle(vec2 p, float r) {
  return length(p) - r;
}

float sdBox2D(vec2 p, vec2 b) {
  vec2 d = abs(p) - b;
  return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

float sdRoundedBox2D(vec2 p, vec2 b, vec4 r) {
  r.xy = (p.x > 0.0) ? r.xy : r.zw;
  r.x  = (p.y > 0.0) ? r.x  : r.y;
  vec2 q = abs(p) - b + r.x;
  return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r.x;
}

// 3D SDFs
float sdSphere(vec3 p, float r) {
  return length(p) - r;
}

float sdBox(vec3 p, vec3 b) {
  vec3 q = abs(p) - b;
  return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}

float sdCylinder(vec3 p, float r, float h) {
  vec2 d = abs(vec2(length(p.xz), p.y)) - vec2(r, h);
  return min(max(d.x, d.y), 0.0) + length(max(d, 0.0));
}

float sdTorus(vec3 p, vec2 t) {
  vec2 q = vec2(length(p.xz) - t.x, p.y);
  return length(q) - t.y;
}
```

### SDF Operations

```glsl
// Smooth minimum for blending
float smin(float a, float b, float k) {
  float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
  return mix(b, a, h) - k * h * (1.0 - h);
}

// Smooth maximum
float smax(float a, float b, float k) {
  return -smin(-a, -b, k);
}

// Repeat
vec3 opRepeat(vec3 p, vec3 c) {
  return mod(p, c) - 0.5 * c;
}

// Displacement
float opDisplacement(vec3 p, float d) {
  return d + sin(p.x * 10.0) * sin(p.y * 10.0) * sin(p.z * 10.0) * 0.1;
}
```

## Color Utilities

```glsl
// RGB to HSV
vec3 rgb2hsv(vec3 c) {
  vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
  vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
  vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
  float d = q.x - min(q.w, q.y);
  float e = 1.0e-10;
  return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

// HSV to RGB
vec3 hsv2rgb(vec3 c) {
  vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
  vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
  return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

// Heat map gradient
vec3 heatmap(float t) {
  return clamp(vec3(1.5, 1.5, 1.5) - abs(vec3(-1.0, 0.0, 1.0) + t * 2.0), 0.0, 1.0);
}

// Palette generation (IQ style)
vec3 palette(float t, vec3 a, vec3 b, vec3 c, vec3 d) {
  return a + b * cos(6.28318 * (c * t + d));
}
```

## Animation Patterns

```glsl
// Pulsing
float pulse(float time, float speed) {
  return 0.5 + 0.5 * sin(time * speed);
}

// Wiggle
vec2 wiggle(vec2 p, float time, float amount) {
  return p + vec2(sin(time + p.y), cos(time + p.x)) * amount;
}

// Wave
float wave(vec2 p, float time, float freq, float amp) {
  return sin(p.x * freq + time) * amp;
}

// Flow
vec2 flow(vec2 p, float time) {
  return vec2(
    sin(p.y * 0.1 + time),
    cos(p.x * 0.1 + time)
  );
}
```

## UV Manipulation

```glsl
// Rotate UV
vec2 rotateUV(vec2 uv, float angle) {
  float s = sin(angle);
  float c = cos(angle);
  mat2 rot = mat2(c, -s, s, c);
  return (uv - 0.5) * rot + 0.5;
}

// Scale UV
vec2 scaleUV(vec2 uv, float scale) {
  return (uv - 0.5) / scale + 0.5;
}

// Repeat UV
vec2 repeatUV(vec2 uv, float count) {
  return fract(uv * count);
}

// Triplanar mapping (for world space textures)
vec3 triplanar(sampler2D tex, vec3 p, vec3 n) {
  vec3 colX = texture(tex, p.zy).rgb;
  vec3 colY = texture(tex, p.xz).rgb;
  vec3 colZ = texture(tex, p.xy).rgb;

  vec3 blend = abs(n);
  blend /= (blend.x + blend.y + blend.z);

  return colX * blend.x + colY * blend.y + colZ * blend.z;
}
```

## Lighting Patterns

```glsl
// Fresnel effect
float fresnel(vec3 viewDir, vec3 normal, float power) {
  return pow(1.0 - max(dot(viewDir, normal), 0.0), power);
}

// Diffuse lighting
float diffuse(vec3 normal, vec3 lightDir) {
  return max(dot(normal, lightDir), 0.0);
}

// Specular (Blinn-Phong)
float specular(vec3 normal, vec3 lightDir, vec3 viewDir, float shininess) {
  vec3 halfDir = normalize(lightDir + viewDir);
  return pow(max(dot(normal, halfDir), 0.0), shininess);
}

// Rim light
float rim(vec3 normal, vec3 viewDir, float power, float intensity) {
  float fresnelTerm = fresnel(viewDir, normal, power);
  return fresnelTerm * intensity;
}
```

## Pattern Generators

```glsl
// Grid pattern
float grid(vec2 uv, float res, float thickness) {
  vec2 grid = fract(uv * res) - 0.5;
  float line = smoothstep(0.5 - thickness, 0.5, abs(grid.x);
  line += smoothstep(0.5 - thickness, 0.5, abs(grid.y);
  return clamp(line, 0.0, 1.0);
}

// Checkerboard
float checker(vec2 uv, float res) {
  vec2 grid = floor(uv * res);
  return mod(grid.x + grid.y, 2.0);
}

// Dots
float dots(vec2 uv, float res, float size) {
  vec2 grid = fract(uv * res) - 0.5;
  float dist = length(grid);
  return 1.0 - smoothstep(size - 0.01, size, dist);
}

// Stripes
float stripes(vec2 uv, float frequency) {
  return step(0.5, fract(uv.x * frequency));
}
```

## Post-Processing Patterns

```glsl
// Vignette
float vignette(vec2 uv, float amount) {
  vec2 center = uv - 0.5;
  return 1.0 - dot(center, center) * amount;
}

// Chromatic aberration
vec3 chromaticAberration(sampler2D tex, vec2 uv, float amount) {
  float r = texture(tex, uv + vec2(amount, 0.0)).r;
  float g = texture(tex, uv).g;
  float b = texture(tex, uv - vec2(amount, 0.0)).b;
  return vec3(r, g, b);
}

// Barrel distortion
vec2 barrelDistortion(vec2 uv, float amt) {
  vec2 cc = uv - 0.5;
  float dist = dot(cc, cc);
  return uv + cc * dist * amt;
}

// Grain
float grain(vec2 uv, float time) {
  return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453 + time);
}
```

## Complete Shader Template

```glsl
// Uniforms
uniform float uTime;
uniform vec2 uResolution;
uniform vec3 uCameraPos;
uniform sampler2D uTexture;

// Varyings from vertex shader
varying vec2 vUv;
varying vec3 vPosition;
varying vec3 vNormal;

void main() {
  vec2 uv = vUv;
  vec3 color = vec3(0.0);

  // Your shader code here

  gl_FragColor = vec4(color, 1.0);
}
```

## Reference

- [The Book of Shaders](https://thebookofshaders.com/)
- [Shadertoy](https://www.shadertoy.com/)
- [Inigo Quilez Articles](https://iquilezles.org/articles/)
