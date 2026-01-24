{#-
  Skill Template for PRD Starter
  This template generates SKILL.md files for custom skills.

  Variables:
    skill: Dictionary with skill details
    now: datetime object for current time
-#}
---
name: {{ skill.name }}
description: {{ skill.description }}
category: {{ skill.category | default('user') }}
depends-on: {{ skill.depends_on | default([]) }}
---

# {{ skill.display_name | default(skill.name | title) }}

> "{{ skill.tagline | default('Skill tagline') }}"

## Quick Start

{{ skill.quick_start | default('Invoke this skill when needed.') }}

## When to Use This Skill

{{ skill.when_to_use | default('Use when appropriate based on task requirements.') }}

## Implementation

{{ skill.implementation | default('Follow standard patterns for this type of work.') }}

## Anti-Patterns

{{ skill.anti_patterns | default('- Don\\'t overuse this skill for simple tasks\n- Don\\'t use this skill outside its domain') }}

## Checklist

{{ skill.checklist | default('- Use skill appropriately\n- Follow best practices\n- Validate results') }}
