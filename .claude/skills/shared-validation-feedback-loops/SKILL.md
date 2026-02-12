---
name: shared-validation-feedback-loops
description: Type-check, lint, test, build validation sequence. Use proactively before every commit across all agents.
category: validation
---

# Feedback Loops

> "Validate early, validate often – catch errors before they compound."

## When to Use This Skill

Use **before every task related changes commit** to ensure code quality and prevent broken builds.

## Quick Start

**⚠️ PRE-REQUISITE: Test Coverage Check (BLOCKING)**

Before running feedback loops, verify test coverage exists:

```bash
# Check for modified files without tests
git diff --name-only HEAD~5 | grep '^src/' | while read file; do
  test_file="src/tests/${file#src/}"
  test_file="${test_file%.ts}.test.ts"
  if [ ! -f "$test_file" ]; then
    echo "COVERAGE GAP: $file missing $test_file"
  fi
done

# If coverage gaps found: BLOCK - invoke test-creator
```

**Then run all feedback loops in sequence:**

```bash
npm run type-check && npm run lint && npm run build
```

## Anti-Patterns

❌ **DON'T:**

- Commit without running feedback loops
- Use `@ts-ignore` or `// eslint-disable` to hide errors
- Use `any` type without justification

✅ **DO:**

- Run all loops before every commit
- Fix errors properly, don't suppress
- Add types to all public interfaces
- Run `--fix` for auto-fixable issues
