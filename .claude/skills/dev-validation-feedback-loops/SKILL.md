---
name: dev-validation-feedback-loops
description: Type-check, lint, test, build validation for Developer agent. Use proactively before committing code. Consider using shared-validation-feedback-loops for comprehensive guidance.
category: validation
---

# Feedback Loops (Developer Agent)

> "Quality gates protect the codebase - ALL must pass before commit."

**Note:** This skill provides a quick reference for Developer agents. For comprehensive guidance, see `shared-validation-feedback-loops`.

## When to Use This Skill

Use when:
- Before committing any code
- After implementing a feature
- After fixing bugs
- After refactoring
- **MANDATORY** before sending WorkComplete to PM

## Quick Reference

```bash
npm run type-check  # 0 TypeScript errors
npm run lint        # 0 ESLint warnings
npm run test        # All tests pass
npm run build       # Build succeeds
```

## Progressive Guide

### Level 1: Basic Validation

```bash
# Run all quality gates in sequence
npm run type-check && npm run lint && npm run test && npm run build
```

If all pass: Proceed to commit.
If any fail: Fix and re-run.

### Level 2: Individual Gate Debugging

```bash
# Run individually to see specific errors
npm run type-check  # Check for TypeScript errors
npm run lint        # Check for ESLint warnings
npm run test        # Run unit/integration tests
npm run build       # Verify production build
```

Parse error output for specific file:line references.

### Level 3: Fix Pattern Application

```xml
<validation_failure>
1. Identify error type (type | lint | test | build)
2. Parse error message for file:line
3. Apply specific fix for error type
4. Re-run only the failed gate
5. Repeat until all gates pass
</validation_failure>
```

### Level 4: Maximum Attempts Recovery

```xml
<validation_loop max_attempts="3">
Attempt 1: Fix immediate error, re-run
Attempt 2: Different approach if same error
Attempt 3: Escalate if still failing
</validation_loop>
```

### Level 5: Framework-Specific Validation

```bash
# For React/R3F components
npm run type-check  # Check props interfaces
npm run lint        # Check React hooks rules
npm run test        # Check component rendering

# For Phaser scenes
npm run type-check  # Check scene class definitions
npm run lint        # Check Phaser API usage
npm run test        # Check scene lifecycle

# For Colyseus multiplayer
npm run type-check  # Check state schema decorators
npm run lint        # Check room handler patterns
npm run test        # Check message handling
```

## Decision Framework

| Error Type | Common Cause | Fix Strategy |
|------------|--------------|--------------|
| `TS2304` | Missing import | Add import or check tsconfig |
| `TS2307` | Module not found | Check import path, install dependency |
| `TS2345` | Type mismatch | Add proper types or assertions |
| `no-unused-vars` | Unused variable | Remove or prefix with `_` |
| `prefer-const` | Mutable variable | Change `let` to `const` |
| Test failed | Logic error | Fix implementation or test |
| Build failed | Bundling issue | Check circular dependencies, exports |

## Troubleshooting Table

| Symptom | Diagnosis | Solution |
|---------|-----------|----------|
| "Cannot find module" | Missing dependency | `npm install {module}` |
| "Unexpected token" | Syntax error | Check for typos, brackets |
| "Property does not exist" | Type error | Add type definition or cast |
| Test timeout | Async issue | Add `await`, increase timeout |
| "Module not found" after install | Cache issue | `rm -rf node_modules && npm install` |
| Type errors in test files | Test setup issue | Check test globals, mocks |
| Lint errors in generated files | Config issue | Add to .eslintignore |
| Build fails but tests pass | Runtime dependency | Check for browser-only APIs |

## Code Patterns

### Type-Check First Pattern

```bash
# Always type-check before other gates
if npm run type-check; then
  npm run lint && npm run test && npm run build
else
  echo "Type errors found - fix before continuing"
  exit 1
fi
```

### Fix-Validate Loop

```xml
<fix_validate_loop>
1. Run validation gate
2. If fail:
   a. Read error message carefully
   b. Fix specific error (don't over-fix)
   c. Re-run same gate
   d. If pass: move to next gate
   e. If fail: return to step a
3. If pass: move to next gate
</fix_validate_loop>
```

### Escalation Pattern

```xml
<escalation_after_3_attempts>
Gate: {gate_name}
Attempt 1: {what you tried} → Result: {error}
Attempt 2: {what you tried} → Result: {error}
Attempt 3: {what you tried} → Result: {error}

Action: Send WorkBlocked to PM with:
- All error messages
- Attempts made
- Root cause analysis
- Recommended solution
</escalation_after_3_attempts>
```

## Multishot Examples

### Example 1: Type Error Fix

```bash
# Error: src/components/Player.ts:23 - Property 'health' is missing
# Fix: Add health to Player interface
# Result: Type-check passes
```

### Example 2: Lint Error Fix

```bash
# Error: src/player/Movement.ts:45 - prefer-const over let
# Fix: Change 'let' to 'const' for immutable variable
# Result: Lint passes
```

### Example 3: Test Failure Recovery

```bash
# Error: Player movement test failed - expected 10, got 5
# Attempt 1: Check test expectations (found bug in test)
# Attempt 2: Fix implementation (movement formula wrong)
# Attempt 3: Re-run test → passes
```

## Anti-Patterns

**DON'T:**

- Skip validation gates to "save time"
- Suppress errors without fixing root cause
- Run gates in wrong order (always type-check first)
- Assume tests pass without running
- Commit with `--no-verify` to bypass hooks

**DO:**

- Run ALL gates before commit
- Fix each error individually
- Re-run only the failed gate after fixing
- Escalate after 3 failed attempts
- Document why you made specific fixes

## Checklist

Before committing:

- [ ] Type-check passes (0 TypeScript errors)
- [ ] Lint passes (0 ESLint warnings)
- [ ] Tests pass (all tests green)
- [ ] Build succeeds (no bundling errors)
- [ ] No `@ts-ignore` without PM approval
- [ ] No `any` types without justification
- [ ] No `eslint-disable` without PM approval

## Framework-Specific Skills

For framework-specific validation, see:

- [dev-r3f-r3f-fundamentals](../dev-r3f-r3f-fundamentals/SKILL.md) — R3F component patterns
- [dev-phaser-fundamentals](../dev-phaser-fundamentals/SKILL.md) — Phaser scene patterns
- [dev-typescript-typescript-basics](../dev-typescript-typescript-basics/SKILL.md) — Type safety patterns

## See Also

- [shared-validation-feedback-loops](../shared-validation-feedback-loops/SKILL.md) — Comprehensive feedback loops guide
- [dev-validation-quality-gates](../dev-validation-quality-gates/SKILL.md) — Quality standards definition
- [dev-validation-browser-testing](../dev-validation-browser-testing/SKILL.md) — E2E validation patterns
