---
name: qa-code-review
description: Code quality review before validation. Checks for @ts-ignore, any types, anti-patterns, and potential issues. Use proactively at start of QA validation.
user-invocable: true
---

# QA Code Review

> "Review code quality BEFORE running automated checks - catch issues early."

Review code quality before running type-check, lint, test, and build. This catches issues that automated tools might miss and ensures code quality standards are met.

## When to Use

Use at the start of validation, before type-check/lint/test/build loops.

---

## Quality Checks

| Check | Pattern | Severity | Action |
|-------|---------|----------|--------|
| TypeScript suppressions | `@ts-ignore`, `@ts-expect-error` | **HIGH** | FAIL - Report location |
| Any types | `: any`, `<any>`, `as any` | **HIGH** | FAIL - Report location |
| Missing dependencies | `useEffect` without deps | **HIGH** | FAIL - Report location |
| State mutations | Direct object/array mutation | **HIGH** | FAIL - Report location |
| Memory leaks | Event listeners without cleanup | **HIGH** | FAIL - Report location |
| Console logs | `console.log`, `console.error` | **MEDIUM** | WARN - Report location |
| Debug flags | `debug &&`, `DEBUG &&` | **MEDIUM** | FAIL - May hide features |
| Empty catch blocks | `catch {}` with no handling | **MEDIUM** | FAIL - Swallows errors |
| TODO comments | `TODO`, `FIXME` in production code | **LOW** | NOTE - Track separately |

---

## Process

1. **Identify changed files** from the task
2. **Grep** for anti-patterns across changed files
3. **Read** each changed file to review context
4. **Check** for quality issues using the table above
5. **Report** findings with specific file locations and line numbers

---

## Grep Patterns

```bash
# TypeScript suppressions
grep -r "@ts-ignore\|@ts-expect-error" src/

# Any types
grep -r ": any\|<any>\|as any" src/

# Console logs
grep -r "console\." src/

# Empty catch blocks
grep -r "catch {}" src/

# TODO comments
grep -r "TODO\|FIXME" src/
```

---

<output-format>

## Output Format

```markdown
## Code Review Results

### Files Reviewed
- {file1.ts}
- {file2.tsx}
- {file3.ts}

### Issues Found

{If issues found:}
| Severity | File | Line | Issue | Suggestion |
|----------|------|------|-------|------------|
| high | src/file.ts | 42 | @ts-ignore used | Remove suppression, fix type error |
| high | src/components/Button.tsx | 15 | : any type | Add proper type annotation |
| medium | src/utils/helpers.ts | 78 | console.log left | Remove before commit |

{If no issues:}
**No quality issues found.** Code is ready for automated validation.

### Overall Result
- Status: ✅ PASS / ❌ FAIL

### Notes
{Additional observations or concerns}
```

</output-format>

---

<examples>

## Example Outputs

### Example 1: Clean Code (PASS)

```markdown
## Code Review Results

### Files Reviewed
- src/components/player/Player.tsx
- src/components/player/PlayerControls.tsx
- src/hooks/usePlayerInput.ts

### Issues Found

**No quality issues found.** Code is ready for automated validation.

### Overall Result
- Status: ✅ PASS

### Notes
- Type annotations are proper
- No error suppressions detected
- Code follows established patterns
```

### Example 2: High Severity Issues (FAIL)

```markdown
## Code Review Results

### Files Reviewed
- src/components/lobby/Lobby.tsx
- src/network/networkManager.ts

### Issues Found

| Severity | File | Line | Issue | Suggestion |
|----------|------|------|-------|------------|
| high | src/components/lobby/Lobby.tsx | 47 | @ts-ignore used | Remove suppression, fix Colyseus type |
| high | src/network/networkManager.ts | 23 | : any type | Specify proper message type |
| medium | src/components/lobby/Lobby.tsx | 89 | console.log left | Remove before commit |

### Overall Result
- Status: ❌ FAIL

### Notes
- Type suppression at Lobby.tsx:47 hides potential runtime error
- Consider using proper Colyseus schema types
```

### Example 3: Debug Flags Found (FAIL)

```markdown
## Code Review Results

### Files Reviewed
- src/effects/projectiles/PaintProjectile.tsx

### Issues Found

| Severity | File | Line | Issue | Suggestion |
|----------|------|------|-------|------------|
| medium | src/effects/projectiles/PaintProjectile.tsx | 12 | debug && flag gates feature | Remove debug conditional |

### Overall Result
- Status: ❌ FAIL

### Notes
- Feature is hidden behind debug flag - not accessible in production
- This appears to be a visibility bug, not intentional debugging
```

</examples>

---

## Decision Framework

| Issue Count | Action |
|-------------|--------|
| 0 high/medium issues | PASS - Proceed to validation |
| 1+ high-severity | FAIL - Fix required before validation |
| 1+ medium-severity | FAIL - Fix recommended |
| Low-severity only | PASS - Note in report |

---

## Important

- Report exact file paths and line numbers
- Suggest specific fixes for each issue
- If ANY high-severity issue found, overall result is FAIL
- Console warnings are considered failures
- Check for debug flags that may hide features from users
- Be thorough - missed issues become bugs later

---

## Code Quality Fail Criteria

**FAIL validation if ANY found:**
- Any `any` type usage without justification
- Any `@ts-ignore` or `@ts-expect-error` comments
- Missing React hook dependencies
- Direct state mutations
- Memory leaks (event listeners not cleaned up)
- Empty catch blocks that swallow errors
- Debug flags that disable features

---

## See Also

- [qa-validation-workflow](../qa-validation-workflow/SKILL.md) — Full validation pipeline
- [dev-validation-quality-gates](../dev-validation-quality-gates/SKILL.md) — Quality gate standards
