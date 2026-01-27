---
name: qa-router
description: Catalog of all QA skills and sub-agents. Exposes available tooling so the agent can decide what and when to use. Use when starting validation to discover appropriate testing tools.
category: orchestration
---

# QA Skill Router

> "Catalog of all QA tools - discover what you need, use what you choose."

## Overview

This skill provides a complete catalog of available QA skills and sub-agents. It does **not** automatically load skills - the agent decides which tools to use based on task context.

## Skills Catalog

### Workflow Skills

| Skill | Purpose | When to Use |
|-------|---------|-------------|
| `qa-test-creation` | Test coverage check and creation workflow | Before validation - ensure tests exist for the feature |
| `qa-validation-workflow` | Full validation workflow | When running complete automated checks |
| `qa-workflow` | Complete QA workflow with startup protocol | Load at session startup |

### Validation Skills

| Skill | Purpose | When to Use |
|-------|---------|-------------|
| `qa-code-review` | Code quality review before validation | Start of validation - check for @ts-ignore, any types, anti-patterns |
| `qa-browser-testing` | E2E test creation and execution | Every validation - validate implementations with Playwright API |
| `qa-gameplay-testing` | E2E gameplay testing patterns | Game features - movement, combat, combos, loops |
| `qa-multiplayer-testing` | Multi-client server-authoritative tests | Multiplayer features - state sync, colyseus validation |
| `qa-visual-testing` | Screenshot comparison + Vision MCP | Visual features - shaders, materials, UI, regression |
| `qa-validation-asset` | Asset validation for Vite 6 | Validating 3D models, audio, textures, build output |
| `qa-validation-asset-loading` | Asset loading performance validation | Testing FBX model loading performance and memory usage |
| `qa-reporting-bug-reporting` | Bug report format and documentation | When validation fails - structured bug reports |

### Test Creation Skills

| Skill | Purpose | When to Use |
|-------|---------|-------------|
| `qa-unit-test-creation` | Vitest unit test patterns | Creating unit tests for components, services, utilities |
| `qa-e2e-test-creation` | Playwright E2E test patterns | Creating E2E tests for user flows and gameplay |

### Helper Skills

| Skill | Purpose | When to Use |
|-------|---------|-------------|
| `qa-mcp-helpers` | Shared helper patterns for MCP validation | Using Playwright MCP tools in validation agents |

## Sub-Agents Catalog

| Sub-Agent | Model | Purpose | When to Invoke |
|-----------|-------|---------|----------------|
| `test-creator` | Sonnet | Creates unit and E2E tests for features | Tests missing - invoke via `qa-test-creation` |
| `qa-browser-validator` | Inherit | Playwright MCP browser testing | Basic feature validation |
| `qa-gameplay-tester` | Inherit | E2E gameplay loops and combos | Gameplay mechanics validation |
| `qa-multiplayer-validator` | Inherit | Server-authoritative multiplayer testing | Multiplayer/state sync validation |
| `visual-regression-tester` | Haiku | Visual regression with Vision MCP | UI/Visual changes validation |

## Quick Reference: Validation Scenarios

| Scenario | Skills | Sub-Agent |
|----------|-------|-----------|
| **New Feature** | `qa-test-creation` → `qa-code-review` → `qa-validation-workflow` → `qa-browser-testing` | `test-creator` → `qa-browser-validator` |
| **Gameplay** | `qa-test-creation` → `qa-gameplay-testing` → `qa-code-review` | `test-creator` → `qa-gameplay-tester` |
| **Multiplayer** | `qa-test-creation` → `qa-multiplayer-testing` → `qa-code-review` | `test-creator` → `qa-multiplayer-validator` |
| **Visual/Shaders** | `qa-test-creation` → `qa-visual-testing` → `qa-code-review` | `test-creator` → `visual-regression-tester` |
| **Assets** | `qa-validation-asset` → `qa-browser-testing` | `qa-browser-validator` |
| **Bug Re-validation** | `qa-code-review` → `qa-validation-workflow` → `qa-browser-testing` | `qa-browser-validator` |

## Quick Reference: By Validation Stage

| Stage | Skills to Use |
|-------|--------------|
| **0. Session Start** | `qa-workflow`, `qa-router` (this skill) |
| **1. Message Queue** | `shared-messaging` |
| **2. Worktree Setup** | `shared-worker` |
| **3. Task Memory** | `shared-retrospective` |
| **4. Test Coverage** | `qa-test-creation` (invokes `test-creator` if needed) |
| **5. Test Execution** | `qa-validation-workflow` (type-check → lint → test → build) |
| **6. Code Review** | `qa-code-review` |
| **7. Browser Testing** | `qa-browser-testing` + scenario-specific sub-agent |
| **8. Bug Reporting** | `qa-reporting-bug-reporting` |

## Skill Selection Guidance

### Start Every Validation With

1. **Load `qa-router`** - Review available tools
2. **Read task acceptance criteria** - Understand what to validate
3. **Choose validation approach** - Pick appropriate skills from catalog

### Decision Tree

```
START VALIDATION
        │
├─→ Task needs tests?
│   └─ Yes → Load qa-test-creation → test-creator sub-agent
│   └─ No → Continue
│
├─→ Run test execution (qa-validation-workflow)
│   └─ Tests fail?
│       ├─ Test code issue? → Fix test → Re-run
│       └─ Game code issue? → Bug report → Return to Developer
│
├─→ Code review needed?
│   ├─ Yes → Load qa-code-review
│   └─ No → Skip to browser testing
│
├─→ Task type?
│   ├─ Basic feature → qa-browser-testing + qa-browser-validator
│   ├─ Gameplay → qa-gameplay-testing + qa-gameplay-tester
│   ├─ Multiplayer → qa-multiplayer-testing + qa-multiplayer-validator
│   ├─ Visual/UI → qa-visual-testing + visual-regression-tester
│   └─ Assets → qa-validation-asset + qa-browser-validator
│
└─→ Validation failed?
    └─ Yes → qa-reporting-bug-reporting
```

## Reference Files

| Skill | Path |
|-------|------|
| Test Creation | `.claude/skills/qa-test-creation/SKILL.md` |
| Code Review | `.claude/skills/qa-code-review/SKILL.md` |
| Browser Testing | `.claude/skills/qa-browser-testing/SKILL.md` |
| Gameplay Testing | `.claude/skills/qa-gameplay-testing/SKILL.md` |
| Multiplayer Testing | `.claude/skills/qa-multiplayer-testing/SKILL.md` |
| Visual Testing | `.claude/skills/qa-visual-testing/SKILL.md` |
| Validation Workflow | `.claude/skills/qa-validation-workflow/SKILL.md` |
| Asset Validation | `.claude/skills/qa-validation-asset/SKILL.md` |
| Asset Loading | `.claude/skills/qa-validation-asset-loading/SKILL.md` |
| Bug Reporting | `.claude/skills/qa-reporting-bug-reporting/SKILL.md` |
| Unit Test Creation | `.claude/skills/qa-unit-test-creation/SKILL.md` |
| E2E Test Creation | `.claude/skills/qa-e2e-test-creation/SKILL.md` |
| MCP Helpers | `.claude/skills/qa-mcp-helpers/SKILL.md` |
| QA Workflow | `.claude/skills/qa-workflow/SKILL.md` |

## Usage Pattern

```markdown
1. At session start: Load qa-router to see available tools
2. Read task: Understand acceptance criteria and requirements
3. Select skills: Choose appropriate skills from catalog
4. Load skills: Use Skill("skill-name") or /skill-name
5. Validate: Execute validation workflow
6. Report: Use qa-reporting-bug-reporting if failed
```
