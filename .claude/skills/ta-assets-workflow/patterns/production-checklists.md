# Production Readiness Checklists

> Pre-commit verification for Tech Artist assets.

## Integration Smoke Test (CRITICAL)

**Before marking ANY task complete**, run this quick verification:

```bash
# Smoke Test Checklist - verify in browser
# 1. Character model visible? (not placeholder geometry)
# 2. Weapon model visible? (not placeholder box/cylinder)
# 3. Projectiles visible? (not debug-gated)
# 4. Audio plays? (if audio task)
# 5. Textures loaded? (not solid colors)
# 6. Animations playing? (if animated asset)
```

## Debug Code Audit (CRITICAL)

Before committing, search for debug-gated rendering:

```bash
# Search for debug conditionals that might hide features
grep -r "{debug &&" src/
grep -r "debug.*&&" src/
grep -r "if.*debug" src/
```

**Remove ALL debug conditionals from player-facing features:**

```tsx
// ❌ WRONG - Feature hidden behind debug flag
{debug && projectiles.map(proj => (
  <mesh key={proj.id}>
    <sphereGeometry args={[0.1]} />
    <meshStandardMaterial color={proj.color} />
  </mesh>
))}

// ✅ CORRECT - Feature always visible in production
{projectiles.map(proj => (
  <mesh key={proj.id}>
    <sphereGeometry args={[0.1]} />
    <meshStandardMaterial color={proj.color} />
  </mesh>
))}

// ✅ CORRECT - Debug-only helpers use debug flag
{debug && <gridHelper args={[20, 20]} />}
{debug && <axesHelper args={[2]} />}
```

## Asset Integration Verification

After integrating an asset, verify it actually appears in the scene:

```tsx
// Add a temporary dev-mode check during development
import { useHelper } from '@react-three/drei';

function MyAsset() {
  const meshRef = useRef<THREE.Mesh>(null);

  // Temporary: visual verification during development
  useEffect(() => {
    if (meshRef.current) {
      console.log('[ASSET CHECK]', {
        type: meshRef.current.geometry.type,
        vertices: meshRef.current.geometry.attributes.position.count,
        // This confirms the REAL asset loaded, not a placeholder
      });
    }
  }, []);

  return <mesh ref={meshRef}>...</mesh>;
}
```

## Production Readiness Checklist

Before sending to QA:

- [ ] NO debug conditionals on player-visible features
- [ ] Asset loads from correct path (check browser Network tab)
- [ ] Asset renders visibly (check Three.js inspector or browser)
- [ ] Placeholder geometry replaced with actual asset
- [ ] Animations play (if applicable)
- [ ] Textures apply correctly (not solid colors/tints only)
- [ ] No console errors during asset loading
- [ ] Asset scales and positions correctly relative to scene

## Retrospective Notes

**Learned from polish-001 (2026-01-22)**:
Paint projectiles were invisible because they were gated behind `debug &&` conditional. Player-facing features must NEVER be debug-gated.
