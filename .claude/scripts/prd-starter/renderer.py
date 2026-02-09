"""
PRD Starter Generator - Template Renderer

Jinja2-based template rendering for agent and skill generation.
"""

import json
from datetime import datetime
from pathlib import Path
from typing import Any, Optional

from jinja2 import Environment, FileSystemLoader

from constants import FEEDBACK_LOOP_COMMANDS
from model_types import AgentConfig, ProjectConfig


class TemplateRenderer:
    """Renders Jinja2 templates for agent and skill generation."""

    def __init__(self, templates_dir: Path):
        """Initialize the template renderer.

        Args:
            templates_dir: Path to directory containing Jinja2 templates
        """
        self.templates_dir = templates_dir
        self.env: Optional[Environment] = None

        if templates_dir.exists():
            self.env = Environment(
                loader=FileSystemLoader(str(templates_dir)),
                trim_blocks=True,
                lstrip_blocks=True
            )

    def render_agent_md(self, config: AgentConfig, project_config: ProjectConfig) -> str:
        """Render AGENT.md from template.

        Args:
            config: Agent configuration
            project_config: Overall project configuration

        Returns:
            Rendered AGENT.md content
        """
        # If template exists, use it
        if self.env:
            try:
                template = self.env.get_template("agent-template.md")
                return template.render(
                    agent=config,
                    project=project_config,
                    now=datetime.now()
                )
            except Exception:
                pass  # Fall through to default generation

        # Default agent template
        icon_lines = config.icon.strip().split('\n') if config.icon else []
        icon_yaml = '\n'.join(f'    {line}' for line in icon_lines)

        return f"""---
role: {config.name}
name: {config.display_name}
icon: |
{icon_yaml}
orchestration: {project_config.orchestration_mode.value}
version: 2.0
---

# {config.display_name} - Quick Reference

> "{config.primary_responsibility}"

## Role Card

| Aspect      | Description                                   |
| ----------- | --------------------------------------------- |
| **Primary** | {config.primary_responsibility}               |
| **Cannot**  | {'; '.join(config.cannot_do) if config.cannot_do else 'N/A'} |
| **Works With** | {', '.join(config.works_with) if config.works_with else 'All agents'} |
| **Startup** | `/ralph-worker-event --agent {config.name}`   |

## Quick Start Checklist

- [ ] Source message queue: `. .\\.\.claude\\scripts\\message-queue.ps1`
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

**MCPs available to {config.name.upper()}:**
{self._format_mcp_list(config.mcp_servers)}

**DO NOT create additional PowerShell or bash scripts** — use built-in tools instead.

## Subagent Delegation

Available subagents for {config.name}:
{self._format_subagent_list(config.sub_agents)}

## Core Responsibilities

### What You Do
{config.primary_responsibility}

### What You Cannot Do
{self._format_list(config.cannot_do)}

### File Permissions

**MAY write to:**
{self._format_list(config.may_write) if config.may_write else '  (none specified)'}

**MAY NOT write to:**
{self._format_list(config.may_not_write) if config.may_not_write else '  ./.claude/session/'}

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

{self._format_skill_list(config.skills)}

## Exit Conditions

Only exit when:
- Assigned work is complete
- All changes committed
- Completion message sent
"""

    def render_skill_md(self, skill_config: dict[str, Any]) -> str:
        """Render SKILL.md from template.

        Args:
            skill_config: Skill configuration dictionary

        Returns:
            Rendered SKILL.md content
        """
        if self.env:
            try:
                template = self.env.get_template("skill-template.md")
                return template.render(skill=skill_config, now=datetime.now())
            except Exception:
                pass

        # Default skill template
        name = skill_config.get("name", "skill-name")
        return f"""---
name: {name}
description: {skill_config.get("description", "Skill description")}
category: {skill_config.get("category", "user")}
depends-on: {skill_config.get("depends_on", [])}
---

# {skill_config.get("display_name", name.title())}

> "{skill_config.get("tagline", "Skill tagline")}"

## Quick Start

{skill_config.get("quick_start", "Invoke this skill when needed.")}

## When to Use This Skill

{skill_config.get("when_to_use", "Use when appropriate.")}

## Implementation

{skill_config.get("implementation", "Follow standard patterns.")}

## Anti-Patterns

{skill_config.get("anti_patterns", "- Don't overuse this skill")}

## Checklist

{skill_config.get("checklist", "- Use skill appropriately")}
"""

    def render_workflow_skill(self, config: AgentConfig) -> str:
        """Render workflow skill SKILL.md from template.

        Args:
            config: Agent configuration

        Returns:
            Rendered workflow skill content
        """
        # If template exists, use it
        if self.env:
            try:
                template = self.env.get_template("workflow-skill-template.md")
                return template.render(agent=config, now=datetime.now())
            except Exception:
                pass  # Fall through to default generation

        # Default workflow template
        agent_type = config.role if config.role != "custom" else "shared"
        return f"""---
name: {config.name}-workflow
description: {config.display_name} workflow - states, transitions, message handling for V2 event-driven coordination
category: {agent_type}
agent: {config.name}
model: {config.model}
---

# {config.display_name} Workflow

> Load this skill BEFORE starting {config.display_name} work.

## Core Flow

- **idle** - Available for work
- **working** - Actively processing tasks
- **awaiting_response** - Waiting for other agents

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│    idle     │────▶│   working   │────▶│    idle     │
│  (available)│     │ (processing)│     │  (complete) │
└─────────────┘     └─────────────┘     └─────────────┘
       ▲                                      │
       │                                      ▼
┌─────────────┐                         ┌─────────────┐
│awaiting_response│◀────────────────│   blocked   │
│  (waiting)  │                         │  (stuck)    │
└─────────────┘                         └─────────────┘
```

## Decision Framework

| Current State | Trigger | Action | Skill/Sub-Agent | Next State |
|--------------|---------|--------|-----------------|------------|
| `idle` | WorkAssign received | Load task | - | `working` |
| `working` | WorkComplete | Send message | - | `idle` |
| `working` | Need information | Send Query | - | `awaiting_response` |
| `awaiting_response` | Response received | Resume work | - | `working` |
| `working` | Blocked after 3 attempts | Send WorkBlocked | - | `blocked` |
| `blocked` | Guidance received | Resume work | - | `working` |

## Messages You Send

| Event | Type | To | Priority |
|-------|------|-------|----------|
| Work complete | `WorkComplete` | pm | high |
| Have question | `Query` | pm | high |
| Need clarification | `Query` | pm | normal |
| Blocked | `WorkBlocked` | pm | urgent |

## Messages You Receive

| Type | From | Action |
|------|------|--------|
| `WorkAssign` | pm | Load and execute task |
| `WorkAssign` (retry) | pm | Handle fix request |
| `Response` | any | Process answer |
| `Query` | any | Research and respond |

## Startup (V2 Event-Driven)

### Connection

V2 uses named pipes. Connection handled automatically by `agent-runtime.ps1`.

Named pipe: `ralph-{config.name}-main`

### Check Sequence

1. **Check messages** - Received via named pipe
2. **Read task** - From `prd.json` or message payload
3. **Process** - Based on current state (see Decision Framework)
4. **Send status** - Update `agent-status.json`
5. **Exit** - Watchdog restarts when needed

## Exit Conditions

**⚠️ BEFORE exiting, you MUST:**

1. Complete assigned work
2. Commit with `[ralph] [{config.name}]]` prefix
3. Update your status in `prd.json`
4. Send completion message to next agent or PM
5. ONLY THEN exit

**Worker pool model:** Complete work → commit → update status → send message → exit.

## References

- `shared-ralph-event-protocol` - V2 messaging system
- `shared-ralph-core` - Session structure
- `{config.name}-router` - Complete skill catalog
"""

    def render_settings_json(self, agent_name: str, mcp_servers: list[str]) -> str:
        """Render MCP settings JSON from template.

        Args:
            agent_name: Name of the agent
            mcp_servers: List of MCP server names

        Returns:
            Rendered settings JSON content
        """
        if self.env:
            try:
                template = self.env.get_template("settings-template.json")
                return template.render(
                    agent_name=agent_name,
                    mcp_servers=mcp_servers
                )
            except Exception:
                pass

        # Default settings template
        mcp_configs = self._get_mcp_configs(mcp_servers)
        return json.dumps({
            "mcpServers": mcp_configs
        }, indent=2)

    def render_prd_json(self, project_config: ProjectConfig, tech_stack: dict | None = None) -> str:
        """Render initial prd.json from template.

        Args:
            project_config: Project configuration
            tech_stack: Technology stack configuration

        Returns:
            Rendered prd.json content
        """
        if self.env:
            try:
                template = self.env.get_template("prd-template.json")
                return template.render(
                    project=project_config,
                    tech_stack=tech_stack or {},
                    now=datetime.now()
                )
            except Exception:
                pass

        # Get feedback loops based on tech stack
        feedback_loops = {}
        if tech_stack:
            runtime = tech_stack.get("runtime", "node")
            feedback_loops = FEEDBACK_LOOP_COMMANDS.get(runtime, FEEDBACK_LOOP_COMMANDS["node"])

        # Generate PRD items from features
        prd_items = []
        for i, feature in enumerate(project_config.features, 1):
            prd_items.append({
                "id": f"feat-{i:03d}",
                "category": feature.get("category", "functional"),
                "priority": feature.get("priority", "medium"),
                "title": feature.get("title", "Feature"),
                "description": feature.get("description", ""),
                "acceptanceCriteria": feature.get("acceptanceCriteria", []),
                "verificationSteps": feature.get("verificationSteps", []),
                "agent": self._assign_agent_to_feature(feature, project_config),
                "dependencies": feature.get("dependencies", []),
                "status": "pending",
                "passes": False
            })

        # Build tech stack description
        tech_desc = tech_stack.get("description", "") if tech_stack else ""
        if not tech_desc and tech_stack:
            runtime = tech_stack.get("runtime", "").title()
            framework = tech_stack.get("framework", "")
            language = tech_stack.get("language", "")
            tech_desc = f"Built with {runtime}"
            if framework:
                tech_desc += f" + {framework}"
            if language:
                tech_desc += f" ({language})"

        # Determine type safety standard
        type_safety = "strict"
        if tech_stack:
            if tech_stack.get("runtime") == "python":
                type_safety = "mypy-strict"
            elif tech_stack.get("runtime") in ["go", "rust"]:
                type_safety = "compiler-strict"

        # Determine test coverage target
        test_coverage = 80
        if project_config.quality_standards:
            test_coverage = project_config.quality_standards.get("testCoverageTarget", 80)

        prd_data = {
            "project": project_config.name,
            "version": "1.0.0",
            "lastUpdated": datetime.now().isoformat(),
            "quality": "production",
            "description": tech_desc or "Custom project configuration",
            "feedbackLoops": feedback_loops,
            "session": {
                "sessionId": "",
                "startedAt": "",
                "maxIterations": 200,
                "iteration": 0,
                "completionPromise": "RALPH_COMPLETE",
                "status": "running",
                "currentTask": None,
                "stats": {
                    "totalTasks": len(prd_items),
                    "completed": 0,
                    "failed": 0,
                    "commits": 0
                }
            },
            "qualityStandards": {
                "typeSafety": type_safety,
                "testCoverage": f"{test_coverage}%",
                "documentation": "Required for complex logic, game logic, and public APIs",
                "commitStyle": "Conventional commits with Ralph prefix",
                "codeReview": "All code must pass feedback loops before QA"
            },
            "agents": {
                "pm": {"status": "idle", "lastSeen": "", "currentTaskId": None, "pid": 0},
                "developer": {"status": "idle", "lastSeen": "", "currentTaskId": None, "pid": 0},
                "techartist": {"status": "idle", "lastSeen": "", "currentTaskId": None, "pid": 0},
                "qa": {"status": "idle", "lastSeen": "", "currentTaskId": None, "pid": 0},
                "gamedesigner": {"status": "idle", "lastSeen": "", "currentTaskId": None, "pid": 0}
            },
            "projectInitialization": {
                "status": "pending",
                "scriptPath": "./.claude/scripts/init-project.sh",
                "attempts": 0,
                "maxAttempts": 3,
                "autoInitialize": tech_stack.get("autoInitialize", True) if tech_stack else True,
                "techStack": tech_stack or {}
            },
            "items": prd_items
        }

        return json.dumps(prd_data, indent=2)

    def _format_mcp_list(self, mcp_servers: list[str]) -> str:
        """Format MCP server list for documentation."""
        if not mcp_servers:
            return "  (none)"
        mcp_names = {
            "filesystem": "**Filesystem MCP**: Directory operations, file info",
            "github": "**GitHub MCP** (zread): Repository structure, file search",
            "web-search": "**Web Search MCP**: External research, documentation",
            "brave-search": "**Brave Search MCP**: Alternative web search",
            "playwright": "**Playwright MCP**: Browser automation, testing",
            "vision": "**Vision MCP**: Image analysis, screenshots",
            "blender": "**Blender MCP**: 3D asset creation",
            "shadertoy": "**Shadertoy MCP**: Shader development",
            "image-process": "**Image Process MCP**: Image manipulation"
        }
        return '\n'.join(f"  - {mcp_names.get(s, s)}" for s in mcp_servers)

    def _format_subagent_list(self, sub_agents: list[str]) -> str:
        """Format subagent list for documentation."""
        if not sub_agents:
            return "  (none)"
        return '\n'.join(f"  - `{s}`" for s in sub_agents)

    def _format_list(self, items: list[str]) -> str:
        """Format a list as bullet points."""
        if not items:
            return "  (none)"
        return '\n'.join(f"  - {item}" for item in items)

    def _format_skill_list(self, skills: list[str]) -> str:
        """Format skill list for documentation."""
        if not skills:
            return "  (none - see ./.claude/skills/)"
        return '\n'.join(f"  - {skill}" for skill in skills)

    def _assign_agent_to_feature(self, feature: dict, project_config: ProjectConfig) -> str:
        """Assign an agent to a feature based on category and project config."""
        category = feature.get("category", "functional")
        suggested = feature.get("agent", "")

        if suggested:
            return suggested

        # Default assignments based on category
        assignments = {
            "architectural": "developer",
            "functional": "developer",
            "integration": "developer",
            "polish": "developer",
            "design": "gamedesigner",
            "visual": "techartist"
        }

        return assignments.get(category, "developer")

    def _get_mcp_configs(self, mcp_servers: list[str]) -> dict[str, Any]:
        """Get MCP server configurations by name."""
        configs: dict[str, Any] = {}

        if "filesystem" in mcp_servers:
            configs["@modelcontextprotocol/server-filesystem"] = {
                "args": {"path": "."}
            }

        if "github" in mcp_servers:
            configs["github"] = {
                "command": "npx",
                "args": ["-y", "@modelcontextprotocol/server-github"]
            }

        if "web-search" in mcp_servers:
            configs["brave-search"] = {
                "command": "npx",
                "args": ["-y", "@modelcontextprotocol/server-brave-search"]
            }

        if "brave-search" in mcp_servers:
            configs["brave-search"] = {
                "command": "npx",
                "args": ["-y", "@modelcontextprotocol/server-brave-search"]
            }

        if "playwright" in mcp_servers:
            configs["@modelcontextprotocol/server-playwright"] = {}

        if "vision" in mcp_servers:
            # Vision is typically built-in, no config needed
            pass

        return configs
