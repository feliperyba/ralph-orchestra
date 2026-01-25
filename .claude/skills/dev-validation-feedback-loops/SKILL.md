---
name: dev-validation-feedback-loops
description: Type-check, lint, test, build validation for Developer agent. Use proactively before committing code. Consider using shared-validation-feedback-loops for comprehensive guidance.
---

# Feedback Loops (Developer Agent)

**Note:** This skill provides a quick reference for Developer agents. For comprehensive guidance, see `shared-validation-feedback-loops`.

Run these in order before committing code. ALL must pass.

## Quick Reference

```bash
npm run type-check  # 0 TypeScript errors
npm run lint        # 0 ESLint warnings
npm run test        # All tests pass
npm run build       # Build succeeds
```

## See Also

- [shared-validation-feedback-loops](../shared-validation-feedback-loops/SKILL.md) — Comprehensive feedback loops guide
