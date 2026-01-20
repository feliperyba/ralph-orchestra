---
name: code-quality
description: Code quality standards and patterns checklist
category: validation
---

# Code Quality Checklist

## TypeScript Standards

- [ ] All functions have explicit return types
- [ ] All parameters have type annotations
- [ ] Interfaces defined for complex objects
- [ ] Union types preferred over enums for string literals
- [ ] Generics used appropriately
- [ ] No implicit `any`

## React Patterns

- [ ] Functional components (no class components)
- [ ] Hooks follow rules (no conditionals)
- [ ] Custom hooks start with `use`
- [ ] Props destructured in function signature
- [ ] Default values via destructuring or `??`
- [ ] Children typed as `React.ReactNode`

## R3F Patterns

- [ ] Refs used for animation (not useState)
- [ ] No object creation inside useFrame
- [ ] Dispose called on cleanup
- [ ] drei helpers used where appropriate
- [ ] Canvas settings optimized for platform

## State Management

- [ ] Zustand for global state
- [ ] Local state for component-only data
- [ ] Actions defined in store (not components)
- [ ] Selectors used for derived state
- [ ] No prop drilling beyond 2 levels

## Performance

- [ ] useMemo for expensive computations
- [ ] useCallback for callbacks passed to children
- [ ] React.memo for pure components
- [ ] Lazy loading for heavy components
- [ ] Instancing for repeated 3D objects

## File Organization

- [ ] One component per file
- [ ] File name matches export name
- [ ] Imports organized (external → internal)
- [ ] Absolute imports used (`@/`)
- [ ] Related files co-located

## Naming Conventions

| Type           | Convention           | Example                 |
| -------------- | -------------------- | ----------------------- |
| Component      | PascalCase           | `PlayerController`      |
| Hook           | camelCase with `use` | `useGameStore`          |
| Utility        | camelCase            | `calculateDistance`     |
| Constant       | SCREAMING_SNAKE      | `MAX_PLAYERS`           |
| Type/Interface | PascalCase           | `PlayerState`           |
| File           | kebab-case           | `player-controller.tsx` |

## Documentation

- [ ] Complex functions have JSDoc comments
- [ ] Shaders have explanatory comments
- [ ] Non-obvious code has inline comments
- [ ] README updated if needed
- [ ] Types serve as documentation

## Anti-Pattern Checklist

Ensure NONE of these are present:

- [ ] ~~`any` type without justification~~
- [ ] ~~`@ts-ignore` without explanation~~
- [ ] ~~`eslint-disable` without reason~~
- [ ] ~~console.log in production code~~
- [ ] ~~Magic numbers (use constants)~~
- [ ] ~~Deep nesting (> 3 levels)~~
- [ ] ~~Functions > 50 lines~~
- [ ] ~~Files > 300 lines~~
