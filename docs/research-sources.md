# Research Sources for Template Discovery

This document contains the URLs and repositories that the PRD Starter wizard's template-researcher sub-agent searches when looking for existing sub-agent and skill templates.

## Overview

When configuring a new Ralph Orchestra project, the PRD Starter wizard can:
1. **Research online** for existing templates (sub-agents, skills, configurations)
2. **Adapt found templates** for your project
3. **Fall back to best practices** if no template is found

This file defines where to search and what to look for.

---

## Ralph Orchestra Official Sources

> **Note:** References to "ralph-orchestra" in this document refer to the **GitHub repository name** for searching templates online. Your local folder can be named anything - the framework is fully folder-name agnostic.

### Main Repository
- **URL**: `https://github.com/feliperyba/ralph-orchestra`
- **What to find**:
  - Example sub-agents in `.claude/agents/*.agent.md`
  - Example skills in `.claude/skills/*/SKILL.md`
  - Agent templates in `agents/*/AGENT.md`
  - Configuration templates in `.claude/templates/`

### Documentation
- **URL**: `https://github.com/feliperyba/ralph-orchestra/tree/main/docs`
- **What to find**:
  - Architecture patterns
  - Best practices guides
  - Configuration examples

---

## Sub-Agent Research Sources

### Search Terms for GitHub
```
ralph-orchestra subagent
claude code subagent example
.subagent.md
claude agent template
```

### NPM Packages
```
claude-code-agent-template
ralph-orchestra-agent
claude-subagent
```

### Key Repositories to Search

| Repository | URL | Content |
|------------|-----|---------|
| Ralph Orchestra | `github.com/feliperyba/ralph-orchestra` | Official examples |
| Claude Code Docs | `code.claude.com/docs` | Official subagent documentation |
| Awesome Claude Agents | `github.com/topics/claude-code-agent` | Community agents |

### Sub-Agent Pattern Keywords

When searching, look for these patterns:
- Research sub-agents: `code-research`, `explorer`, `finder`
- Implementation sub-agents: `implementation`, `builder`, `creator`
- Validation sub-agents: `validation`, `reviewer`, `checker`
- Commit sub-agents: `commit`, `changelog`

---

## Skill Research Sources

### Search Terms for GitHub
```
ralph-orchestra skill
claude code skill example
skill.md
claude skill template
```

### NPM Packages
```
claude-code-skill
ralph-orchestra-skill
claude-skill-template
```

### Skill Naming Conventions

Ralph Orchestra uses these prefixes for organization:

| Prefix | Agent Type | Examples |
|--------|------------|----------|
| `dev-` | Developer | `dev-r3f-r3f-fundamentals`, `dev-multiplayer-server-authoritative` |
| `ta-` | Tech Artist | `ta-shader-development`, `ta-r3f-materials`, `ta-vfx-particles` |
| `qa-` | QA | `qa-browser-testing`, `qa-multiplayer-testing`, `qa-validation-workflow` |
| `pm-` | PM | `pm-workflow`, `pm-test-planner`, `pm-retrospective-facilitation` |
| `gd-` | Game Designer | `gd-gdd-creation`, `gd-design-mechanic`, `gd-validation-playtest` |
| `shared-` | All agents | `shared-ralph-core`, `shared-worker-worktree`, `shared-file-permissions` |

### Skill Categories

| Category | Description | Examples |
|-----------|-------------|----------|
| `coordination` | Orchestration and workflow | `shared-ralph-core`, `shared-ralph-event-protocol` |
| `development` | Code implementation | `dev-r3f-r3f-fundamentals`, `dev-typescript-typescript-basics` |
| `validation` | Quality checks | `dev-validation-feedback-loops`, `qa-validation-workflow` |
| `design` | Game design | `gd-design-mechanic`, `gd-design-level` |
| `r3f` | React Three Fiber | `dev-r3f-r3f-physics`, `ta-r3f-materials` |

---

## Generic Template Sources

### Claude Code Official Examples
- **Docs**: `https://code.claude.com/docs`
- **Examples**: `https://code.claude.com/docs/en/sub-agents`
- **Skills**: `https://code.claude.com/docs/en/skills`

### Community Resources

| Resource | URL | Focus |
|----------|-----|--------|
| Awesome Claude Code | `github.com/topics/awesome-claude-code` | Curated lists |
| Claude Code Recipes | `github.com/topics/claude-code-recipe` | Workflow examples |
| Claude Agents | `github.com/topics/claude-code-agent` | Agent definitions |

---

## Framework-Specific Sources

### React Three Fiber (R3F)
- **Docs**: `https://docs.pmnd.rs/`
- **Examples**: `https://github.com/pmndrs/react-three-fiber`
- **Drei**: `https://github.com/pmndrs/drei`

### Colyseus (Multiplayer)
- **Docs**: `https://docs.colyseus.io/`
- **Examples**: `https://github.com/colyseus/colyseus-examples`

### TypeScript
- **Docs**: `https://www.typescriptlang.org/docs/`
- **Handbook**: `https://www.typescriptlang.org/docs/handbook/intro.html`

### Playwright (Testing)
- **Docs**: `https://playwright.dev/docs/intro`
- **Examples**: `https://github.com/microsoft/playwright`

---

## Adding New Research Sources

To add a new source to the research list:

1. **Add to this file** under the appropriate section
2. **Specify**:
   - URL or search pattern
   - What type of templates can be found there
   - Any specific search terms or tags

### Example Entry

```markdown
### My Custom Repository
- **URL**: `https://github.com/myorg/custom-agents`
- **What to find**: Custom sub-agents for my domain
- **Search terms**: `my-domain-agent`, `my-domain-skill`
```

---

## Template Caching

Research results are cached in `.claude/session/template-cache.json` to avoid redundant searches.

**Cache Structure:**
```json
{
  "version": "1.0.0",
  "lastUpdated": "2026-01-24T10:00:00Z",
  "sources": {
    "github:ralph-orchestra": {
      "lastChecked": "2026-01-24T10:00:00Z",
      "subagents": ["code-research", "implementation", "validation"],
      "skills": ["dev-r3f-r3f-fundamentals", "ta-shader-development"]
    }
  },
  "templates": {
    "code-research": {
      "source": "github:ralph-orchestra",
      "url": "https://raw.githubusercontent.com/...",
      "fetchedAt": "2026-01-24T10:00:00Z"
    }
  }
}
```

---

## Research Strategy

### Phase 1: Search Ralph Orchestra Repository
1. Check `.claude/agents/` for existing sub-agents
2. Check `.claude/skills/` for existing skills
3. Check `agents/*/AGENT.md` for agent templates

### Phase 2: Search GitHub Community
1. Search for `ralph-orchestra` forks with custom agents
2. Search for `claude-code-agent` with specific domains
3. Search for `claude-code-skill` with specific technologies

### Phase 3: Search Official Documentation
1. Claude Code subagent documentation
2. Claude Code skill documentation
3. Framework-specific documentation (R3F, Colyseus, etc.)

### Phase 4: Fall Back to Best Practices
If no template found:
1. Use `docs/subagent-best-practices.md`
2. Use `docs/skills-best-practices.md`
3. Create from generic template

---

## See Also

- [Sub-Agent Best Practices](./subagent-best-practices.md) - Creating custom sub-agents
- [Skills Best Practices](./skills-best-practices.md) - Creating custom skills
- [PRD Starter Guide](./prd-starter.md) - Using the setup wizard
- [Extending Ralph Orchestra](./extending.md) - Adding custom agents and skills
