"""
PRD Starter Generator - Main Generator

PRDStarterGenerator class - the main orchestrator for file generation.
This is now a thin orchestrator that delegates to specialized generators.
"""

from pathlib import Path

from agent_generator import AgentGenerator
from script_manager import ScriptManager
from docs_generator import DocsGenerator
from file_copier import RalphFileCopier
from readme_generator import ReadmeGenerator
from renderer import TemplateRenderer
from updater import ScriptUpdater
from model_types import AgentConfig, ProjectConfig, ValidationResult
from validator import ConfigValidator


class PRDStarterGenerator:
    """Main generator class for PRD Starter functionality.

    This class orchestrates the generation of agents, skills, configuration
    files, and script modifications by delegating to specialized generators.
    """

    def __init__(self, project_root: str | Path = "."):
        """Initialize the generator.

        Args:
            project_root: Root directory of the project
        """
        self.project_root = Path(project_root).resolve()
        self.templates_dir = self.project_root / ".claude" / "templates"
        self.scripts_dir = self.project_root / ".claude" / "scripts"
        self.schemas_dir = self.project_root / ".claude" / "schemas"
        self.session_dir = self.project_root / ".claude" / "session"

        # Create directories
        self._create_directories()

        # Initialize components
        self.renderer = TemplateRenderer(self.templates_dir)
        self.script_updater = ScriptUpdater(self.scripts_dir)
        self.validator = ConfigValidator(self.schemas_dir)

        # Initialize specialized generators
        self.agent_gen = AgentGenerator(self.project_root, self.renderer)
        self.script_mgr = ScriptManager(self.scripts_dir, self.script_updater)
        self.docs_gen = DocsGenerator(self.project_root, self.renderer)
        self.file_copier = RalphFileCopier(self.project_root)
        self.readme_gen = ReadmeGenerator(self.project_root)

    def _create_directories(self) -> None:
        """Create necessary directories if they don't exist."""
        for dir_path in [
            self.templates_dir,
            self.schemas_dir,
            self.session_dir
        ]:
            dir_path.mkdir(parents=True, exist_ok=True)

    # ========================================================================
    # Agent Generation (delegates to AgentGenerator)
    # ========================================================================

    def generate_agent(self, config: AgentConfig, project_config: ProjectConfig) -> bool:
        """Generate complete agent directory structure.

        Args:
            config: Agent configuration
            project_config: Overall project configuration

        Returns:
            True if generation was successful
        """
        return self.agent_gen.generate_agent(config, project_config)

    # ========================================================================
    # Settings Generation (delegates to AgentGenerator)
    # ========================================================================

    def generate_agent_settings(self, agent_name: str, mcp_servers: list[str]) -> bool:
        """Generate .claude/settings.{agent}.json.

        Args:
            agent_name: Name of the agent
            mcp_servers: List of MCP servers

        Returns:
            True if generation was successful
        """
        return self.agent_gen.generate_agent_settings(agent_name, mcp_servers)

    # ========================================================================
    # Script Updates (delegates to ScriptManager)
    # ========================================================================

    def update_watchdog_scripts(self, agent_names: list[str]) -> bool:
        """Update watchdog scripts with new agents.

        Args:
            agent_names: List of agent names to add

        Returns:
            True if all updates were successful
        """
        return self.script_mgr.update_watchdog_scripts(agent_names)

    def update_message_queue(self, agent_names: list[str]) -> bool:
        """Update message-queue.ps1 with new agents.

        Args:
            agent_names: List of agent names to add

        Returns:
            True if update was successful
        """
        return self.script_mgr.update_message_queue(agent_names)

    def update_session_scripts(self, agent_names: list[str]) -> bool:
        """Update session scripts with new agents.

        Args:
            agent_names: List of agent names to add

        Returns:
            True if all updates were successful
        """
        return self.script_mgr.update_session_scripts(agent_names)

    # ========================================================================
    # Documentation Generation (delegates to DocsGenerator)
    # ========================================================================

    def generate_init_script(self, project_config: ProjectConfig, tech_stack: dict,
                            research_data: dict = None) -> bool:
        """Generate project initialization script based on tech stack.

        Args:
            project_config: Project configuration
            tech_stack: Technology stack configuration
            research_data: Optional research data with discoveredCommands

        Returns:
            True if generation was successful
        """
        return self.docs_gen.generate_init_script(project_config, tech_stack, research_data)

    def generate_research_summary(self, research_data: dict, project_config: ProjectConfig) -> bool:
        """Generate research summary document from pm-research-specialist findings.

        Args:
            research_data: Research data collected by pm-research-specialist
            project_config: Project configuration

        Returns:
            True if generation was successful
        """
        return self.docs_gen.generate_research_summary(research_data, project_config)

    def generate_gdd_summary(self, gdd_data: dict, project_config: ProjectConfig) -> bool:
        """Generate GDD summary document from thermite facilitator findings.

        Args:
            gdd_data: GDD data collected by gamedesigner-thermite-facilitator
            project_config: Project configuration

        Returns:
            True if generation was successful
        """
        return self.docs_gen.generate_gdd_summary(gdd_data, project_config)

    def generate_prd(self, project_config: ProjectConfig, tech_stack: dict = None) -> bool:
        """Generate initial prd.json from project configuration.

        Args:
            project_config: Project configuration
            tech_stack: Technology stack configuration

        Returns:
            True if generation was successful
        """
        return self.docs_gen.generate_prd(project_config, tech_stack)

    def setup_workflow_docs_directory(self, project_config: ProjectConfig) -> bool:
        """Setup workflow documentation directory and copy template.

        Args:
            project_config: Project configuration

        Returns:
            True if setup was successful
        """
        return self.docs_gen.setup_workflow_docs_directory(project_config)

    # ========================================================================
    # Ralph Orchestra File Copying (delegates to RalphFileCopier)
    # ========================================================================

    def copy_ralph_orchestra_files(self, source_root: Path, enabled_agents: list[str]) -> dict:
        """
        Copy only the necessary ralph-orchestra files to the target project.

        Args:
            source_root: Path to ralph-orchestra root directory
            enabled_agents: List of enabled agent names

        Returns:
            Dict with copied files and any errors
        """
        return self.file_copier.copy_ralph_orchestra_files(source_root, enabled_agents)

    # ========================================================================
    # README.md and CLAUDE.md Generation (delegates to ReadmeGenerator)
    # ========================================================================

    def generate_readme(self, project_config: ProjectConfig, tech_stack: dict,
                        agents: dict, research_data: dict = None) -> bool:
        """Generate README.md with project specifications.

        Args:
            project_config: Project configuration
            tech_stack: Technology stack configuration
            agents: Agents configuration dict
            research_data: Optional research data from pm-research-specialist

        Returns:
            True if generation was successful
        """
        return self.readme_gen.generate_readme(project_config, tech_stack, agents, research_data)

    def generate_claude_md(self, project_config: ProjectConfig, tech_stack: dict,
                          agents: dict, quality_standards: dict,
                          research_data: dict = None) -> bool:
        """Generate CLAUDE.md with project-specific Claude instructions.

        Args:
            project_config: Project configuration
            tech_stack: Technology stack configuration
            agents: Agents configuration dict
            quality_standards: Quality standards from Phase 7
            research_data: Optional research data from pm-research-specialist

        Returns:
            True if generation was successful
        """
        return self.readme_gen.generate_claude_md(
            project_config,
            tech_stack,
            agents,
            quality_standards,
            research_data
        )

    # ========================================================================
    # Validation
    # ========================================================================

    def validate_config(self, project_config: ProjectConfig) -> ValidationResult:
        """Validate complete project configuration.

        Args:
            project_config: Project configuration to validate

        Returns:
            ValidationResult with errors and warnings
        """
        return self.validator.validate_project_config(project_config)

    # ========================================================================
    # Batch Operations
    # ========================================================================

    def generate_all(self, project_config: ProjectConfig, tech_stack: dict = None) -> ValidationResult:
        """Generate all files from project configuration.

        Args:
            project_config: Complete project configuration
            tech_stack: Technology stack configuration

        Returns:
            ValidationResult with any errors encountered
        """
        errors = []
        warnings = []

        # First validate
        validation = self.validate_config(project_config)
        errors.extend(validation.errors)
        warnings.extend(validation.warnings)

        if not validation.valid:
            return ValidationResult(valid=False, errors=errors, warnings=warnings)

        # Generate agents
        agent_names = []
        for agent in project_config.agents:
            if self.generate_agent(agent, project_config):
                agent_names.append(agent.name)
                self.generate_agent_settings(agent.name, agent.mcp_servers)
            else:
                errors.append(f"Failed to generate agent: {agent.name}")

        # Update scripts
        if agent_names:
            self.update_watchdog_scripts(agent_names)
            self.update_message_queue(agent_names)
            self.update_session_scripts(agent_names)

        # Generate initialization script
        if tech_stack:
            if not self.generate_init_script(project_config, tech_stack):
                errors.append("Failed to generate initialization script")
            else:
                print("✓ Generated initialization scripts")

        # Setup workflow documentation directory
        if not self.setup_workflow_docs_directory(project_config):
            errors.append("Failed to setup workflow docs directory")

        # Generate README.md
        agents_config = {}
        for agent in project_config.agents:
            agents_config[agent.name] = {
                "enabled": True,
                "display_name": agent.display_name,
                "role": agent.role
            }

        if tech_stack:
            if self.generate_readme(project_config, tech_stack, agents_config):
                print("✓ Generated README.md")
            else:
                errors.append("Failed to generate README.md")

        # Generate CLAUDE.md
        if tech_stack:
            if self.generate_claude_md(
                project_config,
                tech_stack,
                agents_config,
                project_config.quality_standards
            ):
                print("✓ Generated CLAUDE.md")
            else:
                errors.append("Failed to generate CLAUDE.md")

        # Generate research summary if research data exists
        research_data = getattr(project_config, 'research_data', None)
        if research_data and (research_data.get('similarProjects') or research_data.get('bestPractices')):
            if self.generate_research_summary(research_data, project_config):
                print("✓ Generated research summary")
            else:
                warnings.append("Failed to generate research summary")

        # Generate GDD summary if GDD data exists (games only)
        gdd_data = getattr(project_config, 'gdd_data', None)
        if gdd_data and gdd_data.get('enabled'):
            if self.generate_gdd_summary(gdd_data, project_config):
                print("✓ Generated GDD documents")
            else:
                warnings.append("Failed to generate GDD summary")

        # Generate PRD if PRD data exists
        prd_data = getattr(project_config, 'prd_data', None)
        if prd_data and prd_data.get('approved'):
            if self.generate_prd(project_config, tech_stack):
                print("✓ Generated PRD")
            else:
                warnings.append("Failed to generate PRD")

        return ValidationResult(
            valid=len(errors) == 0,
            errors=errors,
            warnings=warnings
        )
