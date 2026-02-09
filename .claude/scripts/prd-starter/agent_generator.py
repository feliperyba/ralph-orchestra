"""
PRD Starter Generator - Agent File Generation

AgentGenerator class - handles generation of agent workflow skills and settings files.
Modern architecture: No more agents/ directory or AGENT.md files.
Agent logic lives in .claude/skills/{name}-workflow/SKILL.md
"""

import sys
from pathlib import Path

from renderer import TemplateRenderer
from model_types import AgentConfig, ProjectConfig


class AgentGenerator:
    """Generates agent workflow skills and configuration files."""

    def __init__(self, project_root: Path, renderer: TemplateRenderer):
        """Initialize the agent generator.

        Args:
            project_root: Root directory of the project
            renderer: TemplateRenderer instance for rendering templates
        """
        self.project_root = Path(project_root).resolve()
        self.skills_dir = self.project_root / ".claude" / "skills"
        self.agents_dir = self.project_root / ".claude" / "agents"
        self.renderer = renderer

    def generate_agent(self, config: AgentConfig, project_config: ProjectConfig) -> bool:
        """Generate agent workflow skill.

        Modern architecture generates:
        - .claude/skills/{name}-workflow/SKILL.md (agent behavior and protocols)
        - .claude/settings.{name}.json (MCP configuration)

        Args:
            config: Agent configuration
            project_config: Overall project configuration

        Returns:
            True if generation was successful
        """
        try:
            # Check if referenced subagents exist (warn if missing)
            self.ensure_subagents_exist(config)

            # Always generate workflow skill (replaces old AGENT.md)
            workflow_skill = self.renderer.render_workflow_skill(config)
            workflow_dir = self.skills_dir / f"{config.name}-workflow"
            workflow_dir.mkdir(parents=True, exist_ok=True)
            (workflow_dir / "SKILL.md").write_text(workflow_skill, encoding='utf-8')

            print(f"✓ Generated workflow skill: .claude/skills/{config.name}-workflow/SKILL.md")

            return True

        except Exception as e:
            print(f"✗ Error generating agent {config.name}: {e}", file=sys.stderr)
            return False

    def generate_agent_settings(self, agent_name: str, mcp_servers: list[str]) -> bool:
        """Generate ./.claude/settings.{agent}.json.

        Args:
            agent_name: Name of the agent
            mcp_servers: List of MCP servers

        Returns:
            True if generation was successful
        """
        try:
            settings_content = self.renderer.render_settings_json(agent_name, mcp_servers)
            settings_file = self.project_root / ".claude" / f"settings.{agent_name}.json"
            settings_file.write_text(settings_content, encoding='utf-8')
            
            print(f"✓ Generated settings: .claude/settings.{agent_name}.json")
            
            return True
        except Exception as e:
            print(f"✗ Error generating settings for {agent_name}: {e}", file=sys.stderr)
            return False

    def ensure_subagents_exist(self, agent_config: AgentConfig) -> bool:
        """Verify that subagent files referenced in config exist.

        Args:
            agent_config: Agent configuration with subAgents list

        Returns:
            True if all subagents exist or were skipped
        """
        if not agent_config.subAgents:
            return True

        missing_subagents = []
        for subagent_name in agent_config.subAgents:
            subagent_file = self.agents_dir / f"{subagent_name}.agent.md"
            if not subagent_file.exists():
                missing_subagents.append(subagent_name)

        if missing_subagents:
            print(f"⚠ Warning: Agent '{agent_config.name}' references missing subagents: {', '.join(missing_subagents)}", file=sys.stderr)
            print(f"  Expected location: .claude/agents/{{name}}.agent.md", file=sys.stderr)
            # Don't fail - just warn. Subagents might be added manually later.

        return True
