---
name: qa-reporting-bug-reporting
description: Bug report format and documentation for failed validations. Use when validation fails and status must be set to needs_fixes.
---

# Bug Reporting Skill

> "A good bug report is half the fix – be specific, be reproducible."

## When to Use

Use when validation fails and `status` must be set to `needs_fixes`.

---

## Severity Levels

| Severity | Definition | Example |
|----------|------------|---------|
| **Critical** | App crashes, data loss, blocks all testing | Build fails, app won't load |
| **High** | Major feature broken, no workaround | Player controls don't work |
| **Medium** | Feature partially works, has workaround | Physics jittery but functional |
| **Low** | Minor issue, cosmetic, edge case | Slight visual glitch on resize |

---

## Category Types

| Category | Description | Check |
|----------|-------------|-------|
| **Build** | Build or bundle fails | `npm run build` |
| **TypeScript** | Type errors | `npm run type-check` |
| **Lint** | Code style issues | `npm run lint` |
| **Test** | Unit test failure | `npm run test` |
| **Runtime** | Error during execution | Browser console |
| **Visual** | Incorrect appearance | Browser testing |
| **Performance** | FPS drops, lag, memory | Performance profiling |

---

<examples>

## Example Bug Reports by Severity

### Example 1: Critical Severity

```markdown
# Bug Report: feat-001 - Build Failure

**Reported**: 2025-01-26T10:30:00Z
**Reporter**: QA Agent
**Severity**: Critical
**Category**: Build

---

## Summary

TypeScript compilation error prevents application from building.

## Environment

- **Browser**: N/A (build failure)
- **OS**: Windows
- **Node Version**: v20.11.0

## Steps to Reproduce

1. Run `npm run build`
2. Observe TypeScript error

## Expected Behavior

Build succeeds with no errors.

## Actual Behavior

```
TS2322: Type 'string' is not assignable to type 'number'.
src/components/lobby/Lobby.tsx:67:5
```

## Console Errors

[TypeScript compiler output]

## For Developer

**Files likely involved**:
- src/components/lobby/Lobby.tsx:67

**Suggested investigation**:
- Fix type annotation for `playerCount` variable
- Change type from string to number or parse string to number
```

### Example 2: High Severity

```markdown
# Bug Report: feat-002 - Player Controls Unresponsive

**Reported**: 2025-01-26T11:15:00Z
**Reporter**: QA Agent
**Severity**: High
**Category**: Runtime

---

## Summary

WASD keyboard controls do not move the player character in E2E tests.

## Environment

- **Browser**: Chrome 120
- **OS**: Windows
- **Node Version**: v20.11.0

## Steps to Reproduce

1. Run `npm run test:e2e -- -g "keyboard controls work"`
2. Observe test failure

## Expected Behavior

Pressing W/A/S/D keys moves the character in the corresponding direction.

## Actual Behavior

Character does not move. No position change detected in test.

## Console Errors

None

## Acceptance Criteria Status

| Criterion | Status | Notes |
|-----------|--------|-------|
| Vehicle responds to WASD input | ❌ Fail | No movement detected |
| Physics runs at 60Hz | ✅ Pass | Physics engine running correctly |

## For Developer

**Files likely involved**:
- src/hooks/usePlayerInput.ts
- src/components/player/PlayerControls.tsx

**Suggested investigation**:
- Verify event listeners are attached to canvas
- Check if input is being processed by player state
- Confirm position updates are being applied
```

### Example 3: Medium Severity

```markdown
# Bug Report: feat-003 - Physics Jitter on Movement

**Reported**: 2025-01-26T12:00:00Z
**Reporter**: QA Agent
**Severity**: Medium
**Category**: Performance

---

## Summary

Player movement exhibits slight jitter when changing direction, but game remains playable.

## Environment

- **Browser**: Chrome 120
- **OS**: Windows
- **Node Version**: v20.11.0

## Steps to Reproduce

1. Start game and spawn player
2. Press W to move forward
3. Quickly press D to change direction
4. Observe slight position jitter

## Expected Behavior

Smooth directional changes without position jitter.

## Actual Behavior

Brief jitter when changing between movement directions.

## Console Errors

None

## For Developer

**Files likely involved**:
- src/hooks/usePhysics.ts
- src/components/player/Player.tsx

**Suggested investigation**:
- Check physics update timing
- Verify input polling isn't creating conflicting velocities
- Consider adding velocity damping/smoothing
```

### Example 4: Low Severity

```markdown
# Bug Report: feat-004 - Visual Glitch on Window Resize

**Reported**: 2025-01-26T13:30:00Z
**Reporter**: QA Agent
**Severity**: Low
**Category**: Visual

---

## Summary

UI button briefly displays incorrect width for ~100ms after window resize.

## Environment

- **Browser**: Chrome 120
- **OS**: Windows
- **Node Version**: v20.11.0
- **Screen Resolution**: 1920x1080

## Steps to Reproduce

1. Open game in browser
2. Resize window from 1920x1080 to 1280x720
3. Observe UI button width during transition

## Expected Behavior

UI elements scale smoothly during resize.

## Actual Behavior

Button briefly expands to incorrect width before settling at correct size.

## Console Errors

None

## For Developer

**Files likely involved**:
- src/components/ui/Button.tsx
- src/styles/ui.css

**Suggested investigation**:
- Check CSS transition timing
- Consider adding resize debounce
```

</examples>

---

<details>
<summary>Bug Report Template</summary>

```markdown
# Bug Report: {{TASK_ID}} - {{BRIEF_TITLE}}

**Reported**: {{ISO_TIMESTAMP}}
**Reporter**: QA Agent
**Severity**: {{Critical | High | Medium | Low}}
**Category**: {{Build | TypeScript | Runtime | Visual | Performance}}

---

## Summary

{{One or two sentences describing the issue}}

## Environment

- **Browser**: {{Chrome / Firefox / Safari}}
- **OS**: {{Windows / macOS / Linux}}
- **Node Version**: {{v20.x.x}}

## Steps to Reproduce

1. {{First step}}
2. {{Second step}}
3. {{Third step}}

## Expected Behavior

{{What should happen}}

## Actual Behavior

{{What actually happens}}

## Console Errors

```
{{Paste errors here}}
```

## Acceptance Criteria Status

| Criterion | Status | Notes |
|-----------|--------|-------|
| {{Criterion 1}} | ✅ / ❌ | {{notes}} |
| {{Criterion 2}} | ✅ / ❌ | {{notes}} |

---

## For Developer

**Files likely involved**:
- {{file1.ts}}
- {{file2.tsx}}

**Suggested investigation**:
- {{Suggestion 1}}
- {{Suggestion 2}}
```

</details>

---

## Anti-Patterns

❌ **DON'T:**
- Report bugs without reproduction steps
- Use vague descriptions ("it doesn't work")
- Omit error messages
- Skip severity classification
- Report code issues **without thorough code review**
- Confuse valid async patterns with "bypasses"

✅ **DO:**
- Include exact steps to reproduce
- Copy full error messages
- Attach screenshots
- Specify environment details
- **Perform thorough code review before reporting**
- **Verify suspected issues by running the app**

---

## Code Review Before Bug Reporting

**CRITICAL: Before reporting a code-related bug, you MUST:**

1. **Read the actual implementation files** - Don't guess based on a quick glance
2. **Trace the execution flow** - Follow code from entry point to the suspected issue
3. **Verify the actual behavior** - Run the app and observe what happens
4. **Compare expected vs. actual** - Be specific about what should happen vs. what does

---

## prd.json Update

```json
{
  "status": "needs_fixes",
  "bugNotes": "## Summary\n\nBuild fails with TypeScript error...\n\n## Steps to Reproduce\n\n1. Run npm run build\n2. Observe error\n\n## Error\n\n```\nTS2322: Type 'string' is not assignable...\n```",
  "retryCount": 1
}
```

---

## Commit Format for Failed Validation

```
[ralph] [qa] feat-XXX: Validation FAILED

- TypeScript: pass
- Lint: pass
- Tests: FAIL - 2 tests failing
- Build: pass
- Browser: **FAIL** (MANDATORY)

Bug: Unit test 'player spawns correctly' assertion failed.
See prd.json.items[{taskId}] for full bug report.

PRD: feat-XXX | Agent: qa | Iteration: N
```

---

## Checklist

Before submitting bug report:

- [ ] **Code review performed** - Read and traced implementation files
- [ ] **Actual behavior verified** - Ran the app and observed what happens
- [ ] Summary is clear and specific
- [ ] Reproduction steps are complete
- [ ] Expected vs actual clearly stated
- [ ] Console errors included
- [ ] Screenshots attached (if visual)
- [ ] Severity assigned
- [ ] Category assigned
- [ ] Environment specified
- [ ] prd.json.items[{taskId}] updated

---

## Reference

- [agents/qa/AGENT.md](../../AGENT.md) — Full QA instructions
- [qa-validation-workflow](../qa-validation-workflow/SKILL.md) — Full workflow
