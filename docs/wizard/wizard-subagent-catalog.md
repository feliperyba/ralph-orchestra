# Wizard Sub-Agent Catalog

This document provides a complete catalog of all sub-agents available in Ralph Orchestra, organized by parent agent and purpose.

## Overview

Sub-agents are specialized workers that parent agents delegate work to. Each sub-agent has:
- A specific model preference (Haiku, Sonnet, Opus, or Inherit)
- A focused purpose
- Specific tools and permissions

## Developer Sub-Agents

| Sub-Agent | Model | Purpose | When to Use | File |
|-----------|-------|---------|------------|------|
| `code-research` | Haiku | Pre-implementation pattern research | **Always (Required)** - Before coding | `.claude/agents/code-research.agent.md` |
| `implementation` | Sonnet | Core feature implementation using R3F/TypeScript | **Always (Required)** - After research | `.claude/agents/implementation.agent.md` |
| `validation` | Haiku | Run feedback loops and quality gates | **Always (Required)** - Before commit | `.claude/agents/validation.agent.md` |
| `commit` | Haiku | Git operations, PRD updates, messaging | **Always (Required)** - After validation | `.claude/agents/commit.agent.md` |

**Required Flow:** code-research → implementation → validation → commit

---

## Tech Artist Sub-Agents

| Sub-Agent | Model | Purpose | When to Use | File |
|-----------|-------|---------|------------|------|
| `asset-researcher` | Haiku | Research existing assets in src/assets/ before requesting new ones | **Always (Required)** - Before assets | `.claude/agents/asset-researcher.agent.md` |
| `asset-creator` | Sonnet | Create 3D/2D visual assets following GDD specifications | Creating assets | `.claude/agents/asset-creator.agent.md` |
| `shader-compiler` | Sonnet | Create and compile GLSL/TSL shaders for R3F materials | Shader creation | `.claude/agents/shader-compiler.agent.md` |
| `particle-system-designer` | Sonnet | Create GPU particle systems for high-performance visual effects | VFX creation | `.claude/agents/particle-system-designer.agent.md` |
| `visual-validator` | Haiku | Pre-commit visual quality check - read-only analysis of visual work | **Always (Required)** - Before commit | `.claude/agents/visual-validator.agent.md` |
| `visual-tester` | Sonnet | Visual regression testing in browser using Playwright MCP | After visual changes | `.claude/agents/visual-tester.agent.md` |
| `performance-profiler` | Haiku | Analyze GPU time, draw calls, texture memory to identify optimization opportunities | Performance issues | `.claude/agents/performance-profiler.agent.md` |
| `code-quality` | Haiku | TypeScript quality checks - no @ts-ignore, no any types | **Always (Required)** - Before commit | `.claude/agents/code-quality.agent.md` |

---

## QA Sub-Agents

| Sub-Agent | Model | Purpose | When to Use | File |
|-----------|-------|---------|------------|------|
| `browser-validator` | Sonnet | Playwright MCP browser testing for visual and functional validation | **Always (Required)** - All tasks | `.claude/agents/browser-validator.agent.md` |
| `multiplayer-validator` | Sonnet | Multiplayer E2E testing - creates multiple browser contexts for server-authoritative validation | Multiplayer features | `.claude/agents/multiplayer-validator.agent.md` |
| `visual-regression-tester` | Sonnet | UI comparison with Vision MCP - detects UI changes and implementation discrepancies | Visual/UI changes | `.claude/agents/visual-regression-tester.agent.md` |
| `gameplay-tester` | Sonnet | End-to-end gameplay testing - continuous movement, combo sequences, game state transitions | Gameplay features | `.claude/agents/gameplay-tester.agent.md` |
| `code-review` | Haiku | Code quality pre-validation - checks for @ts-ignore, any types, anti-patterns | **Always (Required)** - Before validation | `.claude/agents/code-review.agent.md` |

---

## PM Sub-Agents

| Sub-Agent | Model | Purpose | When to Use | File |
|-----------|-------|---------|------------|------|
| `task-researcher` | Sonnet | PM task research - research tasks before assignment | **Always (Recommended)** - Before task selection | `.claude/agents/task-researcher.agent.md` |
| `retrospective-facilitator` | Sonnet | Run retrospective sessions - collect contributions from workers and synthesize findings | After task completion | `.claude/agents/retrospective-facilitator.agent.md` |
| `skill-researcher` | Sonnet | Research skill improvements - uses web search to find best practices | During retrospectives | `.claude/agents/skill-researcher.agent.md` |
| `prd-organizer` | Sonnet | Reorganize PRD based on retrospectives - extract tasks and update backlog | After retrospectives | `.claude/agents/prd-organizer.agent.md` |
| `test-planner` | Sonnet | Create test plans for features - collaborate with QA and Game Designer | Before QA validation | `.claude/agents/test-planner.agent.md` |
| `architecture-validator` | Sonnet | Validate architecture decisions - detect client-authoritative vs server-authoritative gaps | Before implementation | `.claude/agents/architecture-validator.agent.md` |

---

## Game Designer Sub-Agents

| Sub-Agent | Model | Purpose | When to Use | File |
|-----------|-------|---------|------------|------|
| `asset-analyst` | Haiku | Review existing assets in src/assets/ before requesting new ones from Tech Artist | **Always (Required)** - Before requests | `.claude/agents/asset-analyst.agent.md` |
| `visual-reference-researcher` | Sonnet | Collect visual inspiration from web - uses web search and vision analysis | Visual asset creation | `.claude/agents/visual-reference-researcher.agent.md` |
| `reference-game-researcher` | Sonnet | Deep research on reference games - analyzes gameplay mechanics, UI patterns, design decisions | Mechanic/level design | `.claude/agents/reference-game-researcher.agent.md` |
| `thermite-facilitator` | Opus | Run thermite-design sessions - multi-persona simulation for structured design decisions | Design discussions | `.claude/agents/thermite-facilitator.agent.md` |
| `gdd-documenter` | Sonnet | Create and maintain GDDs - documentation needs, playtest findings | Documentation needs | `.claude/agents/gdd-documenter.agent.md` |
| `playtest-evidence-collector` | Sonnet | Collect playtest evidence with Playwright - captures screenshots, analyzes game states, validates GDD compliance | Playtesting sessions | `.claude/agents/playtest-evidence-collector.agent.md` |

---

## Sub-Agent Model Selection Guide

### Haiku (Cost-Efficient)
Best for:
- Research and pattern matching
- Code review
- Pre-validation checks
- Read-only analysis

### Sonnet (Capable)
Best for:
- Most implementation tasks
- Validation requiring browser access
- Test planning
- Documentation creation

### Opus (Creative)
Best for:
- Complex architecture decisions
- Debugging difficult issues
- Creative work (design sessions)
- Thermite design facilitation

### Inherit (Parent's Model)
Best for:
- Tasks that don't need specific model tuning
- When parent agent's model is optimal

---

## Sub-Agent File Template

All sub-agents use the template at `.claude/templates/SUBAGENT_TEMPLATE.md`:

```yaml
---
name: sub-agent-name
description: Brief description
model: haiku | sonnet | opus | inherit
skills: (optional)
tools: Read, Write, Edit, Bash, Task, Skill, AskUserQuestion
disallowedTools: (optional)
---

You are the {Role Name}. Your purpose is {brief purpose statement}.
```

---

## Creating Custom Sub-Agents

To create a custom sub-agent:

1. Copy the template from `.claude/templates/SUBAGENT_TEMPLATE.md`
2. Create a new file in `.claude/agents/{subagent-name}.agent.md`
3. Configure the YAML frontmatter:
   - Set `name` (kebab-case)
   - Set `description` (when to use)
   - Set `model` (haiku, sonnet, opus, or inherit)
   - Optionally add `skills` that the sub-agent can use
   - Configure `tools` and `disallowedTools`
4. Add the sub-agent to the parent agent's configuration in state file

---

## See Also

- [Wizard Presets](wizard-presets.md) - Preset documentation
- [Wizard Skill Catalog](wizard-skill-catalog.md) - Skill catalog
- [../.claude/templates/SUBAGENT_TEMPLATE.md](../.claude/templates/SUBAGENT_TEMPLATE.md) - Sub-agent template
- [../.claude/skills/ralph-prd-starter/SKILL.md](../.claude/skills/ralph-prd-starter/SKILL.md) - Wizard skill documentation
