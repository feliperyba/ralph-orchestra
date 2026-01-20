---
name: validation-checks
description: Comprehensive validation checklist for QA agent
category: validation
---

# Validation Checks Checklist

## Automated Checks

### Type Check

```bash
npm run type-check
```

- [ ] Command exits with code 0
- [ ] No TypeScript errors
- [ ] No "any" type warnings (if strict mode)

### Lint

```bash
npm run lint
```

- [ ] Command exits with code 0
- [ ] No ESLint errors
- [ ] No ESLint warnings

### Unit Tests

```bash
npm run test
```

- [ ] All tests pass
- [ ] No skipped tests (unless documented)
- [ ] Coverage meets minimum (if configured)

### Build

```bash
npm run build
```

- [ ] Build completes successfully
- [ ] No build warnings
- [ ] Bundle size reasonable

## Browser Checks

### Page Load

- [ ] Page loads in < 3 seconds
- [ ] Canvas element visible
- [ ] No blank/white screen
- [ ] No loading spinner stuck

### Console

- [ ] No JavaScript errors
- [ ] No uncaught exceptions
- [ ] No critical warnings
- [ ] WebGL context created successfully

### Visual

- [ ] Scene renders correctly
- [ ] Colors/materials as expected
- [ ] No visual glitches
- [ ] UI elements positioned correctly

### Functional

- [ ] Controls respond to input
- [ ] Game loop running
- [ ] Physics working (if applicable)
- [ ] Audio working (if applicable)

### Performance

- [ ] 60 FPS (or target FPS) stable
- [ ] No stuttering
- [ ] No memory leaks (check over 60s)
- [ ] Responsive to input

## Acceptance Criteria Verification

For each criterion in `current-task.json.acceptanceCriteria`:

```markdown
### Criterion: "{{criterion_text}}"

- **How tested**: {{description of test}}
- **Result**: ✅ PASS / ❌ FAIL
- **Evidence**: {{screenshot path or observation}}
- **Notes**: {{any additional notes}}
```

## Pass Criteria

**ALL must be true to pass:**

1. ✅ `npm run type-check` — 0 errors
2. ✅ `npm run lint` — 0 warnings
3. ✅ `npm run test` — all pass
4. ✅ `npm run build` — succeeds
5. ✅ Browser loads without errors
6. ✅ Console has no errors
7. ✅ All acceptance criteria verified
8. ✅ Performance is acceptable

## Fail Actions

If ANY check fails:

1. Document the failure
2. Create bug report (see bug-reporting.md)
3. Update `current-task.json`:
   ```json
   {
     "status": "needs_fixes",
     "bugNotes": "{{detailed report}}",
     "retryCount": {{previous + 1}}
   }
   ```
4. Commit validation failure
5. Return to polling

## Validation Results Template

```markdown
# Validation Results: {{TASK_ID}}

**Date**: {{ISO_TIMESTAMP}}
**Result**: ✅ PASSED / ❌ FAILED

## Automated Checks

| Check      | Result  | Notes     |
| ---------- | ------- | --------- |
| Type Check | ✅ / ❌ | {{notes}} |
| Lint       | ✅ / ❌ | {{notes}} |
| Tests      | ✅ / ❌ | {{notes}} |
| Build      | ✅ / ❌ | {{notes}} |

## Browser Checks

| Check       | Result  | Notes     |
| ----------- | ------- | --------- |
| Page Load   | ✅ / ❌ | {{notes}} |
| Console     | ✅ / ❌ | {{notes}} |
| Visual      | ✅ / ❌ | {{notes}} |
| Functional  | ✅ / ❌ | {{notes}} |
| Performance | ✅ / ❌ | {{notes}} |

## Acceptance Criteria

| Criterion       | Result  | Notes     |
| --------------- | ------- | --------- |
| {{criterion 1}} | ✅ / ❌ | {{notes}} |
| {{criterion 2}} | ✅ / ❌ | {{notes}} |

## Final Decision

**Status**: PASSED / NEEDS_FIXES
**Reason**: {{summary}}
```
