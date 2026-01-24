---
name: skill-name
description: Brief phrase describing when this skill auto-loads. Use clear, specific language that matches the task context.
category: coordination | development | qa | design
version: 1.0
---

# Skill Name

> One-line summary of what this skill does.

## When to Use This Skill

Use this skill when:
- Situation 1
- Situation 2
- Situation 3

## Quick Start

```bash
# Invocation
/skill-name

# Or explicit
Skill("skill-name")
```

## Key Concepts

### Concept 1
Description of concept 1.

### Concept 2
Description of concept 2.

## Implementation Steps

1. **Step 1** - Description
2. **Step 2** - Description
3. **Step 3** - Description

## Examples

### Example 1: Basic Usage

```
Input: {example input}
Output: {example output}
```

### Example 2: Advanced Usage

```
Input: {example input}
Output: {example output}
```

## Common Patterns

| Pattern | Description | Example |
|---------|-------------|---------|
| Pattern 1 | Description | Example |
| Pattern 2 | Description | Example |

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Issue 1 | Solution 1 |
| Issue 2 | Solution 2 |

## Related Skills

- `[related-skill-1]` - Description
- `[related-skill-2]` - Description

---

## File Structure Note

**Skills are folder-based in Ralph Orchestra:**

```
.claude/skills/
├── skill-name/
│   └── SKILL.md     <-- This file
├── another-skill/
│   └── SKILL.md
└── ...
```

When creating a skill:
1. Create a folder: `.claude/skills/skill-name/`
2. Create `SKILL.md` inside that folder with this template content

## Skill Naming Conventions

Ralph Orchestra uses these prefixes for organization:

| Prefix | Agent Type | Examples |
|--------|------------|----------|
| `dev-` | Developer | `dev-r3f-r3f-fundamentals`, `dev-typescript-typescript-basics` |
| `ta-` | Tech Artist | `ta-shader-development`, `ta-r3f-materials`, `ta-vfx-particles` |
| `qa-` | QA | `qa-browser-testing`, `qa-multiplayer-testing`, `qa-validation-workflow` |
| `pm-` | PM | `pm-workflow`, `pm-test-planning`, `pm-retrospective-facilitation` |
| `gd-` | Game Designer | `gd-gdd-creation`, `gd-design-mechanic`, `gd-validation-playtest` |
| `shared-` | All agents | `shared-ralph-core`, `shared-file-permissions`, `shared-worker-worktree` |

**Special categories:**
- `r3f-router` - Routes to appropriate R3F skills
- `ralph-*` - Core orchestration skills (ralph-core, ralph-hitl, etc.)
- `thematic-doc-generator` - Specialized documentation generation

**Folder names follow kebab-case** (lowercase with hyphens)
