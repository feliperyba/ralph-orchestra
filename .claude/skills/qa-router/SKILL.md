---
name: qa-router
description: Catalog of all QA skills and sub-agents. Exposes available tooling so the agent can decide what and when to use. Use when starting validation to discover appropriate testing tools.
---

# QA Skill Router

> "Catalog of all QA tools - discover what you need, use what you choose."

## Quick Start

1. **Load this skill** at session start to see available tools
2. **Read task** to understand acceptance criteria
3. **Select skills** from catalog based on task needs
4. **Load skills** using `Skill("skill-name")` or `/skill-name`

---

## Skills Catalog

### Workflow Skills

| Skill | Purpose | When to Use |
|-------|---------|-------------|
| `qa-workflow` | Complete QA workflow with startup protocol | Load at session startup |
| `qa-test-creation` | Test coverage check and creation workflow | Before validation - ensure tests exist |
| `qa-validation-workflow` | Full validation workflow | Running complete automated checks |

### Validation Skills

| Skill | Purpose | When to Use |
|-------|---------|-------------|
| `qa-code-review` | Code quality review before validation | Start of validation - check for anti-patterns |
| `qa-browser-testing` | E2E test creation and execution | Every validation - Playwright API |
| `qa-gameplay-testing` | E2E gameplay testing patterns | Game features - movement, combat, combos |
| `qa-multiplayer-testing` | Multi-client server-authoritative tests | Multiplayer features - state sync |
| `qa-visual-testing` | Screenshot comparison + Vision MCP | Visual features - shaders, materials, UI |
| `qa-validation-asset` | Asset validation for Vite 6 | Validating 3D models, audio, textures |
| `qa-validation-asset-loading` | Asset loading performance validation | Testing FBX loading performance |
| `qa-reporting-bug-reporting` | Bug report format and documentation | When validation fails - structured reports |

### Test Creation Skills

| Skill | Purpose | When to Use |
|-------|---------|-------------|
| `qa-unit-test-creation` | Vitest unit test patterns | Creating unit tests for components |
| `qa-e2e-test-creation` | Playwright E2E test patterns | Creating E2E tests for user flows |

### Helper Skills

| Skill | Purpose | When to Use |
|-------|---------|-------------|
| `qa-mcp-helpers` | Shared helper patterns for MCP validation | Using Playwright MCP tools |

---

## Sub-Agents Catalog

| Sub-Agent | Model | Purpose | When to Invoke |
|-----------|-------|---------|----------------|
| `test-creator` | Sonnet | Creates unit and E2E tests | Tests missing |
| `qa-browser-validator` | Inherit | Playwright MCP browser testing | Basic feature validation |
| `qa-gameplay-tester` | Inherit | E2E gameplay loops and combos | Gameplay mechanics |
| `qa-multiplayer-validator` | Inherit | Server-authoritative multiplayer | Multiplayer/state sync |
| `visual-regression-tester` | Haiku | Visual regression with Vision MCP | UI/Visual changes |

---

## Quick Reference: Validation Scenarios

| Scenario | Primary Skills | Sub-Agent |
|----------|---------------|-----------|
| **New Feature** | `qa-test-creation` → `qa-code-review` → `qa-browser-testing` | `test-creator` → `qa-browser-validator` |
| **Gameplay Mechanics** | `qa-gameplay-testing` → `qa-code-review` | `qa-gameplay-tester` |
| **Multiplayer Feature** | `qa-multiplayer-testing` → `qa-code-review` | `qa-multiplayer-validator` |
| **Visual/Shaders** | `qa-visual-testing` → `qa-code-review` | `visual-regression-tester` |
| **Asset Loading** | `qa-validation-asset-loading` → `qa-browser-testing` | `qa-browser-validator` |
| **Bug Re-validation** | `qa-code-review` → `qa-browser-testing` | `qa-browser-validator` |

---

## Decision Tree

```
┌─ Task needs tests?
│  ├─ Yes → Load qa-test-creation
│  │         ├─ Unit tests needed? → qa-unit-test-creation
│  │         └─ E2E tests needed? → qa-e2e-test-creation
│  └─ No → Continue
│
├─ Code review needed? (Always: Yes)
│  └─ Load qa-code-review
│
├─ Task type?
│  ├─ Basic feature → qa-browser-testing + qa-browser-validator
│  ├─ Gameplay → qa-gameplay-testing + qa-gameplay-tester
│  ├─ Multiplayer → qa-multiplayer-testing + qa-multiplayer-validator
│  ├─ Visual/UI → qa-visual-testing + visual-regression-tester
│  └─ Assets → qa-validation-asset-loading + qa-browser-validator
│
└─ Validation failed?
   └─ Yes → qa-reporting-bug-reporting
```

---

## By Validation Stage

| Stage | Skills to Use |
|-------|---------------|
| **0. Session Start** | `qa-workflow`, `qa-router` (this skill) |
| **1. Test Coverage Check** | `qa-test-creation`, `qa-unit-test-creation`, `qa-e2e-test-creation` |
| **2. Code Review** | `qa-code-review` |
| **3. Automated Checks** | `qa-validation-workflow` |
| **4. Browser Testing** | `qa-browser-testing` + scenario-specific skill |
| **5. Bug Reporting** | `qa-reporting-bug-reporting` |

---

## Skill Selection Guidance

### Start Every Validation With

1. **Load `qa-router`** - Review available tools
2. **Read task acceptance criteria** - Understand what to validate
3. **Choose validation approach** - Pick appropriate skills from catalog

### Agile Phase Mapping

| Agile Phase | Router Action |
|-------------|---------------|
| **Sprint Planning** | Select test creation skills |
| **Sprint Review** | Select validation skills based on task type |
| **Retrospective** | Use `qa-reporting-bug-reporting` for findings |

---

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
