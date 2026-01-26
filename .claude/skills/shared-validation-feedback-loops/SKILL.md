---
name: shared-validation-feedback-loops
description: Type-check, lint, test, build validation sequence. Use proactively before every commit across all agents to ensure code quality and prevent broken builds.
category: validation
tags: [quality, validation, feedback-loops, commit-gate]
dependencies: []
---

# Feedback Loops

> "Validate early, validate often – catch errors before they compound."

## When to Use This Skill

Use **before every commit** to ensure code quality.

Use **proactively** when:
- Completing implementation work
- After making any code changes
- Before pushing to remote repository

---

## Quick Start

<examples>
Example 1: Full validation sequence
```bash
npm run type-check && npm run lint && npm run test && npm run build
```

Example 2: Quick iteration (type change only)
```bash
npm run type-check  # Just this, then full before commit
```

Example 3: Styling changes only
```bash
npm run lint -- --fix  # Auto-fix, then full before commit
```

Example 4: After fixing bugs
```bash
npm run type-check && npm run test && npm run build  # Skip lint for logic fix
```
</examples>

---

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

---

## Level 1: Type Check

```bash
npm run type-check
# or
npx tsc --noEmit
```

**Common Issues:**

| Issue | Solution |
|-------|----------|
| Missing type annotations | Add explicit types |
| Incompatible types | Check types match |
| Missing imports | Add import statements |
| Property doesn't exist | Check object exists |

**TypeScript Pattern:**

```typescript
// ❌ Implicit any
function process(data) { ... }

// ✅ Explicit type
function process(data: PlayerData) { ... }

// ❌ Missing null check
const name = player.name.toUpperCase();

// ✅ Safe access
const name = player?.name?.toUpperCase() ?? 'Unknown';
```

---

## Level 2: Lint

```bash
npm run lint
# or
npx eslint . --ext .ts,.tsx
```

**Common Issues:**

| Issue | Solution |
|-------|----------|
| Unused variables | Remove or use |
| Missing dependencies | Add to useEffect |
| Inconsistent formatting | Run `npm run lint -- --fix` |
| Import order | Organize imports |

**Auto-fix:**
```bash
npm run lint -- --fix
```

---

## Level 3: Test

```bash
npm run test
# or
npx vitest run
```

**If tests fail:**
1. Read the failure message carefully
2. Check which test failed
3. Review recent changes
4. Fix the code (not the test, unless test is wrong)

---

## Level 4: Build

```bash
npm run build
# or
npx vite build
```

**Common Issues:**

| Issue | Solution |
|-------|----------|
| Import errors not caught by tsc | Check import paths |
| Missing environment variables | Add to .env |
| Bundle size issues | Check for large imports |
| Asset loading problems | Verify asset paths |

---

## Decision Framework

| Step | Time | What It Catches |
|------|------|-----------------|
| type-check | ~5s | Type errors, missing imports |
| lint | ~3s | Style issues, potential bugs |
| test | ~10s | Logic errors, regressions |
| build | ~30s | Bundle issues, runtime errors |

---

## When to Skip Steps

| Situation | What to Run |
|-----------|-------------|
| Small type change | type-check only (then full before commit) |
| Styling only | lint only (then full before commit) |
| Quick iteration | type-check + lint (then full before commit) |
| **Before commit** | **Always run ALL four** |

---

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

---

## Error Resolution Patterns

### TypeScript Error

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

### ESLint Error

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

---

## Never Suppress Errors

To maintain code quality:

- **NO** `@ts-ignore` without PM approval
- **NO** `eslint-disable` without PM approval
- **NO** skipping tests without PM approval
- **NO** committing with failing loops

---

## Commit Protocol

Only commit when ALL pass:

```bash
npm run type-check && npm run lint && npm run test && npm run build

# If all pass, commit
git add .
git commit -m "[ralph] [{agent}] {task-id}: description"
```

---

## Checklist

Before committing:

- [ ] `npm run type-check` passes with 0 errors
- [ ] `npm run lint` passes with 0 warnings
- [ ] `npm run test` passes (all tests green)
- [ ] `npm run build` succeeds
- [ ] No `@ts-ignore` or `any` without justification
- [ ] Commit message follows Ralph format
