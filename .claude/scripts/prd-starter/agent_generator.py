"""
PRD Starter Generator - Agent File Generation

AgentGenerator class - handles generation of agent directories and settings files.
"""

import sys
from pathlib import Path

from renderer import TemplateRenderer
from model_types import AgentConfig, ProjectConfig


class AgentGenerator:
    """Generates agent directories and configuration files."""

    def __init__(self, project_root: Path, renderer: TemplateRenderer):
        """Initialize the agent generator.

        Args:
            project_root: Root directory of the project
            renderer: TemplateRenderer instance for rendering templates
        """
        self.project_root = Path(project_root).resolve()
        self.agents_dir = self.project_root / "agents"
        self.renderer = renderer

    def generate_agent(self, config: AgentConfig, project_config: ProjectConfig) -> bool:
        """Generate complete agent directory structure.

        Args:
            config: Agent configuration
            project_config: Overall project configuration

        Returns:
            True if generation was successful
        """
        try:
            agent_dir = self.agents_dir / config.name
            agent_dir.mkdir(parents=True, exist_ok=True)

            # Generate AGENT.md (only file in new architecture)
            agent_md = self.renderer.render_agent_md(config, project_config)
            (agent_dir / "AGENT.md").write_text(agent_md, encoding='utf-8')

            # Generate workflow skill for custom agents or when workflow config exists
            if config.role == "custom" or config.workflow:
                workflow_skill = self.renderer.render_workflow_skill(config)
                workflow_dir = self.project_root / ".claude" / "skills" / f"{config.name}-workflow"
                workflow_dir.mkdir(parents=True, exist_ok=True)
                (workflow_dir / "SKILL.md").write_text(workflow_skill, encoding='utf-8')

            return True

        except Exception as e:
            print(f"Error generating agent {config.name}: {e}", file=sys.stderr)
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
            return True
        except Exception as e:
            print(f"Error generating settings for {agent_name}: {e}", file=sys.stderr)
            return False
