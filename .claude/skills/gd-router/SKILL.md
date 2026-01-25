---
name: gd-router
description: Routes to appropriate Game Designer skills and sub-agents based on task keywords and design categories.
---

# Game Designer Skill Router

> "Right skill for the right design task."

## Quick Route by Keyword

| Trigger Keywords | Route To |
| ---------------- | -------- |
| **GDD Creation** | | |
| "create GDD", "start GDD", "no GDD exists", "initialize design" | `gd-gdd-creation` skill |
| **Game Design** | | |
| "mechanic", "gameplay system", "ability", "player action" | `gd-design-mechanic` skill |
| "level design", "map layout", "environment design" | `gd-design-level` skill |
| "character", "hero", "skin", "avatar design" | `gd-design-character` skill |
| "weapon", "gun", "item design", "equipment" | `gd-design-weapon` skill |
| "game loop", "match flow", "session structure" | `gd-design-game-loop` skill |
| **Playtesting** | | |
| "playtest", "test gameplay", "validate design", "play session" | `gd-validation-playtest` skill |
| "GDD review", "design gaps", "what's missing", "GDD analysis" | `gd-playtest-gdd-review` skill |
| "skill gap", "missing skill", "worker struggles" | `gd-skill-gap-analysis` skill |
| **Assets** | | |
| "asset performance", "optimize 3D", "asset budget" | `gd-assets-impact-analysis` skill |
| "check assets", "what assets exist" | `asset-analyst` sub-agent |
| **References** | | |
| "visual ref", "art reference", "style reference", "mood image" | `visual-reference-researcher` sub-agent |
| "Splatoon", "Arc Raiders", "reference game" | `reference-game-researcher` sub-agent |
| **Design Sessions** | | |
| "design session", "Boardroom Retreat", "multi-persona discussion" | `gd-thermite-integration` skill |

## By Design Category

| Category | Skills | Sub-Agents |
| -------- | ------ | ---------- |
| **GDD** | `gd-gdd-creation` | `gdd-documenter` |
| **Mechanics** | `gd-design-mechanic`, `gd-design-game-loop` | - |
| **Content** | `gd-design-level`, `gd-design-character`, `gd-design-weapon` | - |
| **Playtesting** | `gd-validation-playtest`, `gd-playtest-gdd-review`, `gd-skill-gap-analysis` | `playtest-evidence-collector`, `gdd-review-analyst`, `skill-gap-analyst` |
| **Assets** | `gd-assets-impact-analysis` | `asset-analyst` |
| **Research** | - | `visual-reference-researcher`, `reference-game-researcher` |
| **Collaboration** | `gd-thermite-integration` | `thermite-facilitator` |

## Skill Reference

| Skill | Purpose |
| ----- | -------- |
| `gd-gdd-creation` | Create GDD structure and modules |
| `gd-thermite-integration` | Run thermite design sessions |
| `gd-design-mechanic` | Document game mechanics |
| `gd-design-level` | Map and level design |
| `gd-design-character` | Character and class design |
| `gd-design-weapon` | Weapon and item design |
| `gd-design-game-loop` | Core gameplay loop design |
| `gd-assets-impact-analysis` | Analyze asset impact on gameplay |
| `gd-validation-playtest` | Playwright + Vision MCP playtesting |
| `gd-playtest-gdd-review` | GDD review during playtest phase |
| `gd-skill-gap-analysis` | Identify skill gaps from retrospective |
| `shared-worker-task-memory` | Task memory for retrospective |

## Sub-Agent Reference

| Sub-Agent | Model | Purpose |
| --------- | ----- | ------- |
| `thermite-facilitator` | Inherit | Multi-persona design sessions |
| `playtest-evidence-collector` | Inherit | Playwright + Vision MCP playtesting |
| `gdd-documenter` | Inherit | GDD creation and maintenance |
| `gdd-review-analyst` | Inherit | GDD review during playtest |
| `skill-gap-analyst` | Haiku | Analyze pain points, identify gaps |
| `asset-analyst` | Haiku | Read-only asset inventory |
| `visual-reference-researcher` | Haiku | Web search + image analysis |
| `reference-game-researcher` | Haiku | Splatoon/Arc Raiders analysis |

## Skill Dependencies

```
gd-validation-playtest ───┬──▶ gd-playtest-gdd-review
                           └──▶ gd-skill-gap-analysis

gd-thermite-integration ───▶ thermite-facilitator (sub-agent)

gd-gdd-creation ───────────▶ gdd-documenter (sub-agent)
```

## Common Skill Combinations

**GDD Creation from Scratch:**
```
gd-gdd-creation + shared-worker-task-memory
```

**New Game Mechanic:**
```
gd-design-mechanic + gd-thermite-integration + shared-worker-task-memory
```

**Full Playtest Cycle:**
```
gd-validation-playtest + gd-playtest-gdd-review + gd-skill-gap-analysis
```

**Visual Asset Request:**
```
gd-assets-impact-analysis + asset-analyst + visual-reference-researcher
```

**Reference Game Analysis:**
```
reference-game-researcher + visual-reference-researcher
```

## References

- [agents/gamedesigner/AGENT.md](../../agents/gamedesigner/AGENT.md) — Full agent instructions
- [.claude/skills/gamedesigner-workflow/SKILL.md](../gamedesigner-workflow/SKILL.md) — Detailed workflows
- [.claude/skills/shared-ralph-router/SKILL.md](../shared-ralph-router/SKILL.md) — Cross-agent routing
