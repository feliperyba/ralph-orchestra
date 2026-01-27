---
name: qa-validation-workflow
description: Full validation workflow for QA agent. Runs automated checks (type-check, lint, test, build) and browser testing with E2E tests. Use when validating implementation after code review.
category: validation
---

# Validation Workflow Skill

> "Trust but verify – automated tests catch regressions, browser tests catch reality."

## When to Use This Skill

Use when:
- `currentTask.status === "ready_for_qa"`
- Developer has committed changes
- Ready to validate implementation

---

## Quick Start

```bash
# Run full validation suite
npm run type-check && npm run lint && npm run test && npm run build

# Then MANDATORY browser testing via E2E tests
npm run test:e2e

# For manual MCP validation (only when E2E tests fail):
# 1. Detect port: netstat -an | grep LISTEN | grep -E ":(3000|3001|5173|8080)"
# 2. Navigate to http://localhost:{detectedPort}
# 3. Take screenshots
# 4. Verify functionality
```

### MANDATORY: Port Detection Before Browser Testing

**⚠️ CRITICAL: Vite dev server may run on different ports (3000, 3001, 5173, 8080, etc.)**

**Before ANY browser interaction, ALWAYS detect the correct port:**

```bash
# Method 1: Check listening ports
netstat -an | grep LISTEN | grep -E ":(3000|3001|5173|8080)"

# Method 2: Try curl to detect Vite
curl -s http://localhost:3000 | grep -q "vite" && echo "PORT=3000" || \
curl -s http://localhost:3001 | grep -q "vite" && echo "PORT=3001" || \
curl -s http://localhost:5173 | grep -q "vite" && echo "PORT=5173"
```

**NOTE:** E2E tests use `playwright.config.ts` which automatically handles port detection via the `webServer` configuration.

**For manual MCP validation, use the detected port in navigation.**

---

## Validation Pipeline

```
      [GATE: E2E tests MUST exist - CREATE if missing]
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
       │                │         Create Tests   CANNOT PASS  │
       │                │            │          WITHOUT TEST  │
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

**⚠️ MANDATORY RULE: If E2E tests don't exist, CREATE THEM before validation can pass.**

**DO NOT mark validation as PASSED without E2E tests covering acceptance criteria.**

> **Note**: See `qa-workflow` skill for E2E mandatory gate requirements and test failure analysis.

---

## Progressive Guide

### Level 0: Test Coverage Check (BEFORE Automated Checks)

**⚠️ CRITICAL: Ensure tests exist BEFORE validation - CREATE if missing**

**VALIDATION CANNOT PASS WITHOUT E2E TESTS.**

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

4. **If E2E tests missing:**
   - ✅ **MANDATORY:** Invoke test-creator sub-agent to create E2E tests
   - ✅ **MANDATORY:** Wait for tests to be created
   - ✅ **MANDATORY:** Verify `npm run test:e2e` passes
   - ❌ **CANNOT** mark validation as PASSED without E2E tests

5. **Only AFTER E2E tests exist and pass:**
   - Proceed with Level 1 (Automated Checks)
   - Continue with full validation pipeline

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

## Server Detection (Before E2E Tests)

**⚠️ CRITICAL: Check for existing servers before starting new ones**

### Why This Matters

- Playwright's `webServer` config automatically manages servers for E2E tests
- Manually starting servers when Playwright already manages them wastes resources
- Multiple server instances can cause port conflicts (EADDRINUSE errors)

### Step 1: Check if Servers Are Running

```bash
# Check for dev server (port 3000)
netstat -an | grep :3000 || lsof -i :3000

# Check for Colyseus server (port 2567) - for multiplayer tasks
netstat -an | grep :2567 || lsof -i :2567

# Alternative: Try curl to detect Vite
curl -s http://localhost:3000 | grep -q "vite" && echo "DEV_SERVER_RUNNING" || echo "DEV_SERVER_AVAILABLE"
```

### Step 2: Decision Tree

```
                    Running E2E tests?
                            |
            ┌───────────────┴───────────────┐
            │                               │
       YES (npm run test:e2e)        NO (Manual MCP validation)
            │                               │
            ▼                               ▼
   DO NOT start servers         Check if servers running
   Playwright manages them       If YES: use existing
   Cleanup is automatic          If NO: start and track
```

### Step 3: E2E Test Path (Standard)

```bash
# Playwright handles server lifecycle via webServer config
npm run test:e2e

# NO manual server start needed
# NO manual cleanup needed - Playwright handles it
```

### Step 4: Manual MCP Validation Path (Only when needed)

```bash
# Only for manual MCP validation (NOT E2E tests)
# Check port 3000 first
if ! netstat -an | grep :3000; then
  # Start server in background
  Bash(command="npm run dev", run_in_background=true)
  # Capture shell_id for cleanup: { shell_id: "abc123" }
fi

# After validation completes:
TaskStop(task_id="abc123")  # MANDATORY cleanup
```

### Server Detection Checklist

Before running any validation:

- [ ] Checked if port 3000 is in use (`netstat -an | grep :3000`)
- [ ] Checked if port 2567 is in use (for multiplayer tasks)
- [ ] If running E2E tests: Playwright manages servers
- [ ] If manual MCP validation: Use existing or start and track
- [ ] After validation: Cleanup any servers manually started

---

### Level 2: Test Execution & Failure Analysis (MANDATORY)

**Every validation MUST include test execution:**

1. **MANDATORY**: Check server status before running tests (see Server Detection below)

2. Run unit tests: `npm run test`

3. Run E2E tests: `npm run test:e2e`

4. **IF TESTS FAIL**: Analyze and determine root cause
   - See `qa-workflow` skill for Test Failure Decision Tree

5. **MANDATORY CLEANUP** (after all tests complete, pass OR fail):
   - Use `shared-lifecycle` skill for cleanup

### Level 3: Acceptance Criteria Verification

For each acceptance criterion in `current-task-qa.json` (acceptanceCriteria array):

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

---

## Decision Framework

| Check Result                     | Action              |
| -------------------------------- | ------------------- |
| All automated pass, E2E tests pass | Mark as PASSED      |
| Automated pass, E2E tests fail    | Mark as NEEDS_FIXES |
| Automated fails                  | Mark as NEEDS_FIXES |
| Any console errors               | Mark as NEEDS_FIXES |

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

---

## E2E Test Results Template

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

---

## References

- **[qa-workflow](../qa-workflow/SKILL.md)** — Complete validation workflow with E2E gate requirements
- **[qa-code-review](../qa-code-review/SKILL.md)** — Code quality checks before validation
- **[qa-browser-testing](../qa-browser-testing/SKILL.md)** — Browser testing guide
- **[qa-mcp-helpers](../qa-mcp-helpers/SKILL.md)** — MCP patterns and Page Object Model
- **[shared-lifecycle](../shared-lifecycle/SKILL.md)** — Server lifecycle management
