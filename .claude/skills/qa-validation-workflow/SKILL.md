---
name: qa-validation-workflow
description: Full validation workflow for QA agent. Runs automated checks (type-check, lint, test, build) and browser testing with E2E tests. Use when validating implementation after code review.
---

# Validation Workflow Skill

> "Trust but verify – automated tests catch regressions, browser tests catch reality."

## When to Use This Skill

Use when:

- `currentTask.status === "ready_for_qa"`
- Developer has committed changes
- Ready to validate implementation

## Quick Start

```bash
# Run full validation suite
npm run type-check && npm run lint && npm run test && npm run build

# Then MANDATORY browser testing via Playwright MCP
# 1. Navigate to localhost:3000
# 2. Take screenshots
# 3. Verify functionality
```

## ⚠️ VALIDATION GATE

**E2E tests are REQUIRED for every validation.**

If E2E tests cannot be run:

→ **FAIL validation immediately**
→ Report: `"E2E tests unavailable - validation gate failed"`
→ **DO NOT** proceed with any other checks

**This is NON-NEGOTIABLE** - there is NO manual testing fallback.

## ⚠️ MANDATORY GATE: E2E Tests Must Complete

**Running E2E tests is NON-NEGOTIABLE.**

- E2E tests MUST complete even if automated checks (type-check, lint, test, build) fail
- If automated checks fail → report bugs AND run E2E tests to document visual state
- NO exceptions for "blocked by test failure"
- If E2E tests unavailable → FAIL validation with severity "critical"

**Enforcement Flow:**

```
[Automated Checks Fail]
        │
        ├── E2E Tests NOT run? → ❌ INVALID REPORT
        │
        └── E2E Tests COMPLETED → ✅ Valid bug report
                (includes test output, console errors, visual state)
```

**Why run E2E tests when automated checks fail:**

- Visual bugs may exist even when code compiles
- Console errors only appear in browser
- Runtime issues not caught by unit tests
- Test output provides evidence for developer to fix

## Validation Pipeline

```
      [GATE: E2E tests MUST be available]
                  │
                  ▼
┌─────────────┐    ┌──────────┐    ┌──────────────┐    ┌──────────┐
│ Type Check  │───▶│   Lint   │───▶│ TEST CHECK   │───▶│  Build   │
│    (tsc)    │    │ (eslint) │    │  (Coverage)  │    │  (vite)  │
└─────────────┘    └──────────┘    └──────────────┘    └──────────┘
       │                │                   │                  │
       ▼                ▼                   ▼                  ▼
   Pass/Fail       Pass/Fail          Tests Missing?      Pass/Fail
       │                │                   │                  │
       │                │            ┌──────┴──────┐          │
       │                │            │             │          │
       │                │         Create Tests   Skip         │
       │                │            │             │          │
       │                └────────────┴─────────────┘          │
       │                                                      │
       └──────────────────────────────────────────────────────┘
                                          │
                                          ▼
                              ┌─────────────────────┐
                              │  E2E TEST EXECUTION │ ◄── MANDATORY GATE
                              │  (npm run test:e2e)  │     NO EXCEPTIONS
                              └─────────────────────┘
                                          │
                              ┌──────────┴──────────┐
                              │                     │
                         PASS                   FAIL
                          │                        │
                          ▼                        ▼
                    Update PRD            Report bugs
```

## Progressive Guide

### Level 0: Test Coverage Check (BEFORE Automated Checks)

**⚠️ CRITICAL: Ensure tests exist before validation**

1. **Load qa-test-creation skill**
   ```bash
   Skill("qa-test-creation")
   ```

2. **Check unit test coverage**
   - For each source file, check if `src/tests/.../{name}.test.ts` exists
   - Example: `src/components/game/player/index.ts` → `src/tests/components/game/player/index.test.ts`

3. **Check E2E test coverage**
   - Check if `tests/e2e/{feature}-suite.spec.ts` exists
   - Example: `tests/e2e/gameplay-suite.spec.ts`

4. **If tests missing:**
   - Invoke test-creator sub-agent
   - Wait for tests to be created
   - Verify `npm run test` passes
   - Verify `npm run test:e2e` passes

### Level 1: Automated Checks

```bash
# Step 1: Type Check
npm run type-check
# Expected: 0 errors

# Step 2: Lint
npm run lint
# Expected: 0 warnings

# Step 3: Unit Tests
npm run test
# Expected: All tests pass

# Step 4: Build
npm run build
# Expected: Build succeeds
```

### Level 2: E2E Test Execution (MANDATORY)

**Every validation MUST include E2E test execution:**

1. Ensure dev server running: `npm run dev:all:sh`
2. Run E2E tests: `npm run test:e2e`
3. Verify acceptance criteria via test output
4. Review test results for console errors
5. Check test screenshots for evidence

```markdown
## E2E Test Results

**Command**: npm run test:e2e
**Test File**: tests/e2e/{feature}-suite.spec.ts

### Checks Performed:

- [ ] Page loads without errors
- [ ] Canvas renders correctly
- [ ] No console errors
- [ ] Controls respond to input
- [ ] Performance is acceptable (60 FPS)
- [ ] All acceptance criteria covered by tests

### Test Output:

- Tests passed: X/Y
- Failed tests: [list]
- Screenshots captured: test-results/
```

### Level 3: Acceptance Criteria Verification

For each acceptance criterion in `prd.json.items[{taskId}]`:

```markdown
## Acceptance Criteria Verification

### Criterion 1: "Vehicle responds to WASD input"

- **Test**: Pressed W, A, S, D keys
- **Result**: ✅ PASS / ❌ FAIL
- **Notes**: Vehicle moves forward, left, backward, right correctly

### Criterion 2: "Physics simulation runs at 60Hz"

- **Test**: Checked physics debug panel
- **Result**: ✅ PASS / ❌ FAIL
- **Notes**: Physics running at target rate
```

### Level 4: Performance Validation

```markdown
## Performance Check

- [ ] FPS stable at 60 (or target)
- [ ] No memory leaks during extended use
- [ ] Load time acceptable (< 3s)
- [ ] No stuttering during interaction

### Metrics:

- Initial FPS: \_\_
- FPS after 60s: \_\_
- Memory usage: \_\_ MB
- Load time: \_\_ s
```

## Decision Framework

| Check Result                     | Action              |
| -------------------------------- | ------------------- |
| All automated pass, E2E tests pass | Mark as PASSED      |
| Automated pass, E2E tests fail    | Mark as NEEDS_FIXES |
| Automated fails                  | Mark as NEEDS_FIXES |
| Any console errors               | Mark as NEEDS_FIXES |

## Anti-Patterns

❌ **DON'T:**

- Skip E2E tests
- Use Playwright MCP directly for validation
- Assume automated tests are sufficient
- Mark as passed without running E2E tests
- Ignore console warnings
- Skip performance verification

✅ **DO:**

- Always run E2E tests for validation
- Verify each acceptance criterion via test output
- Review test screenshots as evidence
- Document any concerns in bug notes
- Check console for errors in test output

## Pass Protocol

When ALL checks pass:

**Step 1: Delete validation screenshots** (always clean up after validation)

```bash
# PowerShell
Remove-Item ".claude/session/playwright-test/${taskId}-*.png" -Force -ErrorAction SilentlyContinue

# Bash
rm .claude/session/playwright-test/${taskId}-*.png 2>/dev/null || true
```

**Step 2: Update task files**

```json
// Update prd.json.items[{taskId}]
{
  "id": "{{TASK_ID}}",
  "passes": true,
  "status": "passed",
  "validatedAt": "{{ISO_TIMESTAMP}}"
}

// Update prd.json.session
{
  "qa": {
    "status": "idle",
    "lastActivity": "{{ISO_TIMESTAMP}}"
  }
}
```

Commit validation:

```
[ralph] [qa] feat-XXX: Validation PASSED

- TypeScript: pass
- Lint: pass
- Tests: pass
- Build: pass
- Browser: pass

All acceptance criteria verified.

PRD: feat-XXX | Agent: qa | Iteration: N
```

## Fail Protocol

When ANY check fails:

**Step 1: Clean up screenshots**

```bash
# PowerShell
Remove-Item ".claude/session/playwright-test/${taskId}-*.png" -Force -ErrorAction SilentlyContinue

# Bash
rm .claude/session/playwright-test/${taskId}-*.png 2>/dev/null || true
```

**Step 2: Update prd.json.items[{taskId}]**

```json
{
  "status": "needs_fixes",
  "bugNotes": "Detailed description of failures...",
  "retryCount": {{PREVIOUS + 1}}
}

// Update prd.json.agents.qa
{
  "status": "idle",
  "lastActivity": "{{ISO_TIMESTAMP}}"
}
```

Include in bug notes:

- Which check failed
- Error messages
- Steps to reproduce
- Expected vs actual behavior
- Screenshots if applicable

## Checklist

Before marking as passed:

- [ ] `npm run type-check` — 0 errors
- [ ] `npm run lint` — 0 warnings
- [ ] `npm run test` — all pass
- [ ] `npm run build` — succeeds
- [ ] Browser loads correctly
- [ ] No console errors
- [ ] All acceptance criteria verified
- [ ] Performance acceptable
- [ ] Screenshots taken

## Integration Smoke Test (MANDATORY for Polish/Asset Tasks)

**For ANY task involving assets (models, textures, audio, shaders):**

Run this quick visual verification before starting full validation:

```bash
# Integration Smoke Test Checklist
# 1. Character model visible? (not placeholder box/capsule)
# 2. Weapon model visible? (not placeholder geometry)
# 3. Projectiles/Effects visible? (not debug-gated)
# 4. Textures loaded? (not solid colors)
# 5. Audio plays? (if audio task)
# 6. Shaders applied? (not default materials)
```

**CRITICAL: Check for debug-gated features**

If assets appear missing or invisible:

```bash
# Search for debug conditionals hiding features
grep -r "{debug &&" src/components/
grep -r "debug.*&&" src/
```

**Learned from polish-001 retrospective (2026-01-22):**
QA did not catch that paint projectiles were invisible because they were gated behind `debug &&` conditional. Always verify player-facing features are visible, not debug-hidden.

**Integration Test Questions:**

1. Can I see the asset in the browser? (not just that code compiles)
2. Is it the actual asset or a placeholder?
3. Does it animate/function as expected?
4. Are there any debug flags hiding the feature?

## Reference

- [agents/qa/AGENT.md](../../AGENT.md) — Full QA instructions
- [agents/qa/skills/browser-testing.md](browser-testing.md) — Browser testing guide
- [agents/qa/skills/bug-reporting.md](bug-reporting.md) — Bug report format
