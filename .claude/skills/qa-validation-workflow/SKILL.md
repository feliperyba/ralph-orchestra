---
name: qa-validation-workflow
description: Full validation workflow for QA agent. Runs automated checks (type-check, lint, test, build) and browser testing with E2E tests. Use when validating implementation after code review.
---

# Validation Workflow Skill

> "Trust but verify – automated tests catch regressions, browser tests catch reality."

## When to Use

- `currentTask.status === "ready_for_qa"`
- Developer has committed changes
- Ready to validate implementation

---

## Quick Start

```bash
# Run full validation suite
npm run type-check && npm run lint && npm run test && npm run build

# Then MANDATORY browser testing via Playwright MCP
# 1. Navigate to localhost:3000
# 2. Take screenshots
# 3. Verify functionality
```

---

## ⚠️ MANDATORY GATE: E2E Tests

**E2E tests are REQUIRED for every validation. NON-NEGOTIABLE.**

If E2E tests cannot be run → **FAIL validation immediately** with `"E2E tests unavailable - validation gate failed"`

**E2E tests MUST complete even if automated checks fail:**

```
[Automated Checks Fail]
        │
        ├── E2E Tests NOT run? → ❌ INVALID REPORT
        │
        └── E2E Tests COMPLETED → ✅ Valid bug report
                (includes test output, console errors, visual state)
```

**Why run E2E when automated checks fail:**
- Visual bugs may exist even when code compiles
- Console errors only appear in browser
- Runtime issues not caught by unit tests
- Test output provides evidence for developer to fix

---

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
       └──────────────────────────────────────────────────────┘
                                          │
                                          ▼
                              ┌─────────────────────┐
                              │  E2E TEST EXECUTION │ ◄── MANDATORY
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

---

<details>
<summary>Level 0: Test Coverage Check (BEFORE Automated Checks)</summary>

**⚠️ CRITICAL: Ensure tests exist before validation**

1. **Load qa-test-creation skill**: `Skill("qa-test-creation")`
2. **Check unit test coverage** - For each source file, check if `src/tests/.../{name}.test.ts` exists
3. **Check E2E test coverage** - Check if `tests/e2e/{feature}-suite.spec.ts` exists
4. **If tests missing:** Invoke test-creator sub-agent, wait for tests to be created

</details>

---

## Level 1: Automated Checks

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

---

## Level 2: E2E Test Execution (MANDATORY)

**Every validation MUST include E2E test execution:**

1. Ensure dev server running: `npm run dev:all:sh`
2. Run E2E tests: `npm run test:e2e`
3. Verify acceptance criteria via test output
4. Review test results for console errors
5. Check test screenshots for evidence

<examples>

### Example Validation Results

#### Example 1: All Pass

```markdown
## Validation Results

### Automated Checks
- TypeScript: ✅ PASS (0 errors)
- Lint: ✅ PASS (0 warnings)
- Unit Tests: ✅ PASS (12/12 tests)
- Build: ✅ PASS

### E2E Tests
- Tests passed: 5/5
- Console errors: 0
- Console warnings: 0

### Acceptance Criteria
- Vehicle responds to WASD: ✅
- Physics runs at 60Hz: ✅
- Collision detection works: ✅

### Overall Result: ✅ PASS
```

#### Example 2: Partial Failure

```markdown
## Validation Results

### Automated Checks
- TypeScript: ✅ PASS (0 errors)
- Lint: ❌ FAIL (2 warnings)
  - src/components/player/Player.tsx:45 - Unused variable 'debugMode'
  - src/hooks/usePhysics.ts:12 - Missing dependency 'velocity'
- Unit Tests: ✅ PASS (8/8 tests)
- Build: ✅ PASS

### E2E Tests
- Tests passed: 3/5
- Failed: 'player controls work', 'physics collision'
- Console errors: 2

### Overall Result: ❌ FAIL

### Bugs
1. Lint warnings must be fixed
2. Player controls unresponsive in E2E test
3. Physics collision not detected
```

#### Example 3: Build Failure

```markdown
## Validation Results

### Automated Checks
- TypeScript: ❌ FAIL
  - TS2322: Type 'string' is not assignable to type 'number'
  - Location: src/components/lobby/Lobby.tsx:67
- Lint: Not run (TypeScript failed)
- Unit Tests: Not run (TypeScript failed)
- Build: ❌ FAIL

### E2E Tests (Still run per MANDATORY GATE)
- Tests passed: 0/1
- Error: Application failed to load due to TypeScript error

### Overall Result: ❌ FAIL

### Bug Report
TypeScript error at Lobby.tsx:67 prevents application from loading.
Fix type annotation for 'playerCount' variable.
```

</examples>

---

<details>
<summary>Level 3: Acceptance Criteria & Performance Details</summary>

### Acceptance Criteria Verification

For each criterion in `prd.json.items[{taskId}]`:

```markdown
## Acceptance Criteria Verification

### Criterion 1: "Vehicle responds to WASD input"
- **Test**: Pressed W, A, S, D keys
- **Result**: ✅ PASS
- **Notes**: Vehicle moves forward, left, backward, right correctly

### Criterion 2: "Physics simulation runs at 60Hz"
- **Test**: Checked physics debug panel
- **Result**: ✅ PASS
- **Notes**: Physics running at target rate
```

### Performance Validation

```markdown
## Performance Check

- [ ] FPS stable at 60 (or target)
- [ ] No memory leaks during extended use
- [ ] Load time acceptable (< 3s)
- [ ] No stuttering during interaction

### Metrics:
- Initial FPS: __
- FPS after 60s: __
- Memory usage: __ MB
- Load time: __ s
```

</details>

---

## Decision Framework

| Check Result | Action |
|--------------|--------|
| All automated pass, E2E tests pass | Mark as PASSED |
| Automated pass, E2E tests fail | Mark as NEEDS_FIXES |
| Automated fails | Mark as NEEDS_FIXES |
| Any console errors | Mark as NEEDS_FIXES |

---

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

---

<details>
<summary>Pass & Fail Protocols</summary>

### Pass Protocol

When ALL checks pass:

**Step 1: Delete validation screenshots**
```bash
rm .claude/session/playwright-test/${taskId}-*.png 2>/dev/null || true
```

**Step 2: Update task files**
```json
{
  "id": "{{TASK_ID}}",
  "passes": true,
  "status": "passed",
  "validatedAt": "{{ISO_TIMESTAMP}}"
}
```

**Step 3: Commit**
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

### Fail Protocol

When ANY check fails:

**Step 1: Clean up screenshots**
```bash
rm .claude/session/playwright-test/${taskId}-*.png 2>/dev/null || true
```

**Step 2: Update prd.json.items[{taskId}]**
```json
{
  "status": "needs_fixes",
  "bugNotes": "Detailed description of failures...",
  "retryCount": {{PREVIOUS + 1}}
}
```

Include in bug notes:
- Which check failed
- Error messages
- Steps to reproduce
- Expected vs actual behavior
- Screenshots if applicable

</details>

---

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

---

<details>
<summary>Integration Smoke Test (For Asset Tasks)</summary>

**For ANY task involving assets (models, textures, audio, shaders):**

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
grep -r "{debug &&" src/components/
grep -r "debug.*&&" src/
```

**Integration Test Questions:**
1. Can I see the asset in the browser?
2. Is it the actual asset or a placeholder?
3. Does it animate/function as expected?
4. Are there any debug flags hiding the feature?

</details>

---

## Reference

- [agents/qa/AGENT.md](../../AGENT.md) — Full QA instructions
- [qa-browser-testing](../qa-browser-testing/SKILL.md) — Browser testing guide
- [qa-reporting-bug-reporting](../qa-reporting-bug-reporting/SKILL.md) — Bug report format
