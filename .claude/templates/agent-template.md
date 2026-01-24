{#-
  Agent Template for PRD Starter
  This template generates AGENT.md files for custom agents.

  Variables:
    agent: AgentConfig object with agent details
    project: ProjectConfig object with project details
    now: datetime object for current time
-#}
---
role: {{ agent.name }}
name: {{ agent.display_name }}
icon: |
{% for line in agent.icon.split('\n') %}{{ line }}
{% endfor %}
orchestration: {{ project.orchestration_mode.value }}
version: 2.0
---

# {{ agent.display_name }} - Quick Reference

> "{{ agent.primary_responsibility }}"

## Role Card

| Aspect      | Description                                   |
| ----------- | --------------------------------------------- |
| **Primary** | {{ agent.primary_responsibility }}             |
| **Cannot**  | {{ agent.cannot_do | join('; ') if agent.cannot_do else 'N/A' }} |
| **Works With** | {{ agent.works_with | join(', ') if agent.works_with else 'All agents' }} |
| **Startup** | `/ralph-worker-event --agent {{ agent.name }}` |

## Quick Start Checklist

- [ ] Source message queue: `. .\.claude\scripts\message-queue.ps1`
- [ ] Check for pending messages on startup
- [ ] Read coordinator-state.json and current-task.json
- [ ] Complete assigned work
- [ ] Update heartbeat while working

## Tool Preference (CRITICAL)

**ALWAYS prefer built-in Claude Code CLI tools over creating scripts:**

| Operation      | Built-in Tool | DO NOT Use                        |
| -------------- | ------------- | --------------------------------- |
| Read files     | Read tool     | cat, head, tail bash commands      |
| Write files    | Write tool    | echo with redirects, heredocs      |
| Edit files     | Edit tool     | sed, awk bash commands             |
| Find files     | Glob tool     | find bash command                  |
| Search content | Grep tool     | grep, rg bash commands             |

**MCPs available to {{ agent.name.upper() }}:**
{% for mcp in agent.mcp_servers %}
{% if mcp == 'filesystem' %}  - **Filesystem MCP**: Directory operations, file info
{% elif mcp == 'github' %}  - **GitHub MCP** (zread): Repository structure, file search
{% elif mcp == 'web-search' %}  - **Web Search MCP**: External research, documentation
{% elif mcp == 'brave-search' %}  - **Brave Search MCP**: Alternative web search
{% elif mcp == 'playwright' %}  - **Playwright MCP**: Browser automation, testing
{% elif mcp == 'vision' %}  - **Vision MCP**: Image analysis, screenshots
{% else %}  - **{{ mcp }}**: Custom MCP server
{% endif %}
{% endfor %}

**DO NOT create additional PowerShell or bash scripts** — use built-in tools instead.

## Subagent Delegation

Available subagents for {{ agent.name }}:
{% for sub in agent.sub_agents %}
  - `{{ sub }}`
{% else %}
  (none - see project subagent configuration)
{% endfor %}

## Core Responsibilities

### What You Do
{{ agent.primary_responsibility }}

### What You Cannot Do
{% for item in agent.cannot_do %}
  - {{ item }}
{% else %}
  (none specified)
{% endfor %}

### File Permissions

**MAY write to:**
{% for path in agent.may_write %}  {{ path }}
{% else %}
  (none specified)
{% endfor %}

**MAY NOT write to:**
{% for path in agent.may_not_write %}  {{ path }}
{% else %}
  .claude/session/
{% endfor %}

## Main Workflow

1. **Receive Task**: Read current-task.json
2. **Plan**: Use subagents for complex analysis
3. **Implement**: Complete assigned work
4. **Validate**: Run quality checks
5. **Commit**: Use Ralph commit format
6. **Report**: Send completion message

## Quality Standards

- No suppressed errors
- All feedback loops must pass
- Follow existing patterns
- Document complex logic

## Skills Reference

{% for skill in agent.skills %}
- **{{ skill }}**
{% else %}
See [.claude/skills/](../../.claude/skills/) for available skills.
{% endfor %}

## Exit Conditions

Only exit when:
- Assigned work is complete
- All changes committed
- Completion message sent
