---
name: dev-validation-feedback-loops
description: Type-check, lint, test, build validation for Developer agent. Developer-specific patterns for R3F/gameplay validation.
category: validation
---

# Feedback Loops (Developer Agent)

> "Validate early, validate often – catch errors before they compound."

## When to Use This Skill

Use **before every commit** to ensure code quality and prevent broken builds.

## Quick Reference

```bash
npm run type-check  # 0 TypeScript errors
npm run lint        # 0 ESLint warnings
npm run test        # All tests pass
npm run build       # Build succeeds
```

## The Feedback Loop

```
┌─────────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
│ type-check  │───▶│   lint   │───▶│   test   │───▶│  build   │
│   (tsc)     │    │ (eslint) │    │ (vitest) │    │  (vite)  │
└─────────────┘    └──────────┘    └──────────┘    └──────────┘
       │                │                │               │
       ▼                ▼                ▼               ▼
   Type errors     Code style      Test failures   Bundle issues
```

## Developer-Specific Validation

### R3F Component Validation

For React Three Fiber components, verify:

```typescript
// ✅ Proper refs cleanup
useEffect(() => {
  const mesh = meshRef.current;
  return () => {
    mesh?.geometry.dispose();
    mesh?.material.dispose();
  };
}, []);
```

**Type-check catches:**
- Missing `useFrame` dependencies
- Incorrect ref types (RefObject<T>)
- Event handler type mismatches

### Gameplay State Validation

For game state with Zustand:

```typescript
// ✅ Proper typing
interface GameState {
  players: Map<string, Player>;
  phase: GamePhase;
  score: number;
}

// ✅ Action typing
const useGameStore = create<GameState & {
  addPlayer: (player: Player) => void;
}>((set) => ({ ... }));
```

**Lint catches:**
- Missing state selectors
- Unoptimized re-renders
- Action type mismatches

### Physics Integration Validation

For @react-three/rapier:

```typescript
// ✅ Proper collider typing
import type { RigidBody } from '@react-three/rapier';

interface PlayerProps {
  rigidBodyRef: RefObject<RigidBody>;
}
```

**Test catches:**
- Physics interactions not working
- Collision detection failures
- Gravity/scale issues

## When to Skip Steps

| Situation         | What to Run                                 |
| ----------------- | ------------------------------------------- |
| Small type change | type-check only (then full before commit)   |
| Styling only      | lint only (then full before commit)         |
| Quick iteration   | type-check + lint (then full before commit) |
| **Before commit** | **Always run ALL four**                     |

## Anti-Patterns

❌ **DON'T:**

- Commit without running feedback loops
- Use `@ts-ignore` or `// eslint-disable` to hide errors
- Skip tests because "it's a small change"
- Use `any` type without justification
- Comment out failing tests

✅ **DO:**

- Run all loops before every commit
- Fix errors properly, don't suppress
- Update tests when behavior changes
- Add types to all public interfaces
- Run `--fix` for auto-fixable issues

## Error Resolution Patterns

### TypeScript Error: Object Possibly Undefined

```typescript
// Error: Object is possibly 'undefined'
const value = obj.prop; // ❌

// Solution 1: Optional chaining
const value = obj?.prop;

// Solution 2: Nullish coalescing
const value = obj.prop ?? defaultValue;

// Solution 3: Non-null assertion (if you're sure)
const value = obj!.prop; // Use sparingly
```

### ESLint Error: Missing Dependencies

```typescript
// Error: React Hook useEffect has missing dependencies
useEffect(() => {
  doSomething(value);
}, []); // ❌

// Solution: Add dependency
useEffect(() => {
  doSomething(value);
}, [value]); // ✅
```

### Test Failure

```typescript
// If test is correct and code is wrong:
// → Fix the code

// If test is outdated:
// → Update test to match new behavior
// → Add comment explaining the change
```

## Never Suppress Errors

To maintain code quality:
- NO `@ts-ignore` without PM approval
- NO `eslint-disable` without PM approval
- NO skipping tests without PM approval
- NO committing with failing loops

## Commit Protocol

Only commit when ALL pass:

```bash
# Run all checks
npm run type-check && npm run lint && npm run test && npm run build

# If all pass, commit
git add .
git commit -m "[ralph] [developer] {task-id}: description"
```

## Checklist

Before committing:

- [ ] `npm run type-check` passes with 0 errors
- [ ] `npm run lint` passes with 0 warnings
- [ ] `npm run test` passes (all tests green)
- [ ] `npm run build` succeeds
- [ ] No `@ts-ignore` or `any` without justification
- [ ] Commit message follows Ralph format

## See Also

- **[shared-validation-feedback-loops](../shared-validation-feedback-loops/SKILL.md)** — Comprehensive feedback loops guide with E2E best practices
- **[dev-validation-quality-gates](../dev-validation-quality-gates/SKILL.md)** — Code review quality standards
- **[dev-validation-browser-testing](../dev-validation-browser-testing/SKILL.md)** — E2E test creation patterns
