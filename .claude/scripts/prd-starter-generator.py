#!/usr/bin/env python3
"""
PRD Starter Generator - Cross-platform agent generation for Ralph Orchestra.

This module provides the core functionality for generating custom agents,
skills, and configuration files based on user input gathered by the
prd-starter agent.

Classes:
    PRDStarterGenerator: Main orchestrator for file generation
    TemplateRenderer: Jinja2-based template rendering
    ScriptUpdater: Regex-based script file modifications
    ConfigValidator: JSON schema validation for configurations

Dependencies:
    - jinja2: Template rendering
    - pyyaml: YAML processing
    - jsonschema: Configuration validation
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum
from pathlib import Path
from typing import Any, Optional

try:
    from jinja2 import Environment, FileSystemLoader, Template
except ImportError:
    print("Error: jinja2 is required. Install with: pip install jinja2", file=sys.stderr)
    sys.exit(1)

try:
    import yaml
except ImportError:
    print("Error: pyyaml is required. Install with: pip install pyyaml", file=sys.stderr)
    sys.exit(1)

try:
    from jsonschema import validate, ValidationError
except ImportError:
    print("Error: jsonschema is required. Install with: pip install jsonschema", file=sys.stderr)
    sys.exit(1)


# ============================================================================
# Type Definitions
# ============================================================================

class WorkflowPattern(Enum):
    """Workflow pattern options for agent coordination."""
    WATERFALL = "waterfall"
    COLLABORATIVE = "collaborative"
    AUTONOMOUS = "autonomous"
    CUSTOM = "custom"


class OrchestrationMode(Enum):
    """Orchestration mode for Ralph sessions."""
    EVENT_DRIVEN = "event-driven"
    SEQUENTIAL = "sequential"
    HITL = "hitl"
    CUSTOM = "custom"


class ProjectType(Enum):
    """Project type categories."""
    WEB = "web"
    GAME = "game"
    MOBILE = "mobile"
    BACKEND = "backend"
    DATA = "data"
    DEVOPS = "devops"
    OTHER = "other"


@dataclass
class AgentConfig:
    """Configuration for a single agent.

    Attributes:
        name: Lowercase, hyphenated agent identifier
        display_name: Human-readable agent name
        role: Agent role type (pm, developer, qa, etc.)
        custom_type: Custom role description if role is 'custom'
        icon: ASCII art icon (3-6 lines)
        primary_responsibility: What this agent primarily does
        cannot_do: List of things this agent should not do
        works_with: List of other agent roles this agent collaborates with
        may_write: File paths this agent may write to
        may_not_write: File paths this agent may not write to
        mcp_servers: List of MCP server names this agent uses
        skills: List of skill names this agent has access to
        sub_agents: List of sub-agent names for delegation
        quantity: Number of parallel instances (default: 1)
    """
    name: str
    display_name: str
    role: str
    custom_type: str = ""
    icon: str = ""
    primary_responsibility: str = ""
    cannot_do: list[str] = field(default_factory=list)
    works_with: list[str] = field(default_factory=list)
    may_write: list[str] = field(default_factory=list)
    may_not_write: list[str] = field(default_factory=list)
    mcp_servers: list[str] = field(default_factory=lambda: ["filesystem"])
    skills: list[str] = field(default_factory=list)
    sub_agents: list[str] = field(default_factory=list)
    quantity: int = 1


@dataclass
class ProjectConfig:
    """Configuration for the entire project.

    Attributes:
        name: Project identifier
        description: Project description
        project_type: Type of project (web, game, etc.)
        custom_type: Custom project type description
        agents: List of agent configurations
        workflow_pattern: How agents coordinate
        orchestration_mode: Session orchestration mode
        technology_stack: Technology choices
        quality_standards: Quality requirements
        features: Initial feature list
    """
    name: str
    description: str
    project_type: ProjectType
    custom_type: str = ""
    agents: list[AgentConfig] = field(default_factory=list)
    workflow_pattern: WorkflowPattern = WorkflowPattern.COLLABORATIVE
    orchestration_mode: OrchestrationMode = OrchestrationMode.EVENT_DRIVEN
    technology_stack: dict[str, Any] = field(default_factory=dict)
    quality_standards: dict[str, Any] = field(default_factory=dict)
    features: list[dict[str, Any]] = field(default_factory=list)


@dataclass
class ValidationResult:
    """Result of a validation operation.

    Attributes:
        valid: Whether validation passed
        errors: List of error messages
        warnings: List of warning messages
    """
    valid: bool
    errors: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)


# ============================================================================
# Template Renderer
# ============================================================================

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

- [ ] Source message queue: `. .\\.claude\\scripts\\message-queue.ps1`
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
{self._format_list(config.may_not_write) if config.may_not_write else '  .claude/session/'}

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

    def render_prd_json(self, project_config: ProjectConfig) -> str:
        """Render initial prd.json from template.

        Args:
            project_config: Project configuration

        Returns:
            Rendered prd.json content
        """
        if self.env:
            try:
                template = self.env.get_template("prd-template.json")
                return template.render(project=project_config, now=datetime.now())
            except Exception:
                pass

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
                "agent": self._assign_agent_to_feature(feature, project_config),
                "passes": False
            })

        return json.dumps({
            "project": project_config.name,
            "version": "1.0.0",
            "created": datetime.now().isoformat(),
            "items": prd_items
        }, indent=2)

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
            return "  (none - see .claude/skills/)"
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


# ============================================================================
# Script Updater
# ============================================================================

class ScriptUpdater:
    """Updates PowerShell script files using regex patterns."""

    # Regex patterns for script modifications
    VALIDATE_SET_PATTERN = re.compile(
        r'\[ValidateSet\((.*?)\)\]',
        re.DOTALL
    )

    AGENTS_HASHTABLE_PATTERN = re.compile(
        r'(\$Script:Agents\s*=\s*@\{.*?\})',
        re.DOTALL
    )

    AGENT_ENTRY_PATTERN = re.compile(
        r'(\w+)\s*=\s*@{[^}]*role\s*=\s*"([^"]*)"'
    )

    def __init__(self, scripts_dir: Path):
        """Initialize the script updater.

        Args:
            scripts_dir: Path to scripts directory
        """
        self.scripts_dir = scripts_dir

    def add_agent_to_validateset(self, script_path: Path, agent_name: str) -> bool:
        """Add agent to PowerShell ValidateSet attributes.

        Args:
            script_path: Path to the script file
            agent_name: Agent name to add

        Returns:
            True if modification was successful
        """
        try:
            content = script_path.read_text(encoding='utf-8')

            # Check if agent already exists
            if f'"{agent_name}"' in content or f"'{agent_name}'" in content:
                return True  # Already present

            # Find and update ValidateSet entries
            def replace_validateset(match):
                options = match.group(1)
                # Extract existing options
                existing = re.findall(r'["\']([\w-]+)["\']', options)
                if agent_name not in existing:
                    existing.append(agent_name)
                # Rebuild with sorted options, keeping existing quote style
                quote = '"' if '"' in options else "'"
                return f'[ValidateSet({", ".join(f"{quote}{a}{quote}" for a in sorted(existing))})]'

            new_content = self.VALIDATE_SET_PATTERN.sub(replace_validateset, content)

            if new_content != content:
                script_path.write_text(new_content, encoding='utf-8')
                return True
            return False

        except Exception as e:
            print(f"Error updating ValidateSet in {script_path}: {e}", file=sys.stderr)
            return False

    def add_agent_to_hashtable(self, script_path: Path, agent_name: str,
                               config: AgentConfig) -> bool:
        """Add agent to $Script:Agents hashtable.

        Args:
            script_path: Path to the script file
            agent_name: Name of the agent
            config: Agent configuration

        Returns:
            True if modification was successful
        """
        try:
            content = script_path.read_text(encoding='utf-8')

            # Check if agent already exists
            if f'{agent_name}\s*=' in content:
                return True

            # Find the Agents hashtable and add entry
            hashtable_match = self.AGENTS_HASHTABLE_PATTERN.search(content)
            if not hashtable_match:
                return False

            hashtable = hashtable_match.group(1)
            closing_brace = hashtable.rfind('}')

            # Build new agent entry
            new_entry = self._build_agent_entry(agent_name, config)

            # Insert before closing brace
            new_hashtable = hashtable[:closing_brace] + f"    {new_entry}\n" + hashtable[closing_brace:]
            new_content = content.replace(hashtable, new_hashtable)

            script_path.write_text(new_content, encoding='utf-8')
            return True

        except Exception as e:
            print(f"Error updating hashtable in {script_path}: {e}", file=sys.stderr)
            return False

    def add_agent_to_array(self, script_path: Path, agent_name: str,
                          array_name: str = "Script:Agents") -> bool:
        """Add agent to array literals in scripts.

        Args:
            script_path: Path to the script file
            agent_name: Agent name to add
            array_name: Name of the array variable

        Returns:
            True if modification was successful
        """
        try:
            content = script_path.read_text(encoding='utf-8')

            # Check if agent already exists
            if f'"{agent_name}"' in content or f"'{agent_name}'" in content:
                return True

            # Find array patterns and add agent
            # Pattern: @("pm", "developer", "qa", ...)
            array_pattern = re.compile(r'@\((.*?)\)', re.DOTALL)

            def add_to_array(match):
                items = match.group(1)
                existing = re.findall(r'["\']([\w-]+)["\']', items)
                if agent_name not in existing:
                    existing.append(agent_name)
                quote = '"' if '"' in items else "'"
                return f"@({', '.join(f'{quote}{a}{quote}' for a in sorted(existing))})"

            new_content = array_pattern.sub(add_to_array, content)

            if new_content != content:
                script_path.write_text(new_content, encoding='utf-8')
                return True
            return False

        except Exception as e:
            print(f"Error updating array in {script_path}: {e}", file=sys.stderr)
            return False

    def _build_agent_entry(self, agent_name: str, config: AgentConfig) -> str:
        """Build a PowerShell hashtable entry for an agent."""
        return f"""{agent_name} = @{{
    name = "{config.display_name}"
    role = "{config.name}"
    icon = "{config.icon[:20] if config.icon else ''}..."
}}"""


# ============================================================================
# Config Validator
# ============================================================================

class ConfigValidator:
    """Validates configurations against JSON schemas and guardrails."""

    # Allowed MCP servers
    ALLOWED_MCPS = [
        "filesystem", "github", "web-search", "brave-search",
        "playwright", "vision", "blender", "shadertoy", "image-process"
    ]

    # Standard agent roles
    STANDARD_ROLES = ["pm", "developer", "qa", "techartist", "gamedesigner"]

    # Agent name pattern
    AGENT_NAME_PATTERN = re.compile(r'^[a-z0-9_-]+$')

    def __init__(self, schemas_dir: Path):
        """Initialize the validator.

        Args:
            schemas_dir: Path to JSON schema files
        """
        self.schemas_dir = schemas_dir
        self._load_schemas()

    def _load_schemas(self) -> None:
        """Load JSON schemas from the schemas directory."""
        self.schemas: dict[str, dict] = {}

        if not self.schemas_dir.exists():
            return

        for schema_file in self.schemas_dir.glob("*.json"):
            try:
                self.schemas[schema_file.stem] = json.loads(schema_file.read_text())
            except Exception:
                pass

    def validate_agent_config(self, config: AgentConfig) -> ValidationResult:
        """Validate agent configuration against guardrails.

        Args:
            config: Agent configuration to validate

        Returns:
            ValidationResult with errors and warnings
        """
        errors = []
        warnings = []

        # Validate agent name
        if not self.AGENT_NAME_PATTERN.match(config.name):
            errors.append(
                f"Agent name '{config.name}' must be lowercase with hyphens/underscores only"
            )

        # Validate role
        if config.role not in self.STANDARD_ROLES and config.role != "custom":
            errors.append(
                f"Agent role '{config.role}' must be one of {self.STANDARD_ROLES + ['custom']}"
            )

        if config.role == "custom" and not config.custom_type:
            errors.append("Custom agents must specify custom_type")

        # Validate MCP servers
        for mcp in config.mcp_servers:
            if mcp not in self.ALLOWED_MCPS:
                errors.append(f"MCP server '{mcp}' is not in allowed list")

        # Validate file permissions
        may_write_set = set(config.may_write)
        may_not_write_set = set(config.may_not_write)
        overlap = may_write_set & may_not_write_set
        if overlap:
            errors.append(
                f"File permission overlap: {overlap} cannot be in both mayWrite and mayNotWrite"
            )

        # PM-specific validations
        if config.role == "pm":
            protected = {"src/", "server/", "public/", "app/", "lib/"}
            if protected & may_write_set:
                warnings.append(
                    f"PM typically should not write to source directories: {protected & may_write_set}"
                )

        return ValidationResult(
            valid=len(errors) == 0,
            errors=errors,
            warnings=warnings
        )

    def validate_project_config(self, config: ProjectConfig) -> ValidationResult:
        """Validate project configuration.

        Args:
            config: Project configuration to validate

        Returns:
            ValidationResult with errors and warnings
        """
        errors = []
        warnings = []

        # Validate project name
        if not config.name or len(config.name) < 3:
            errors.append("Project name must be at least 3 characters")

        # Validate agents
        if not config.agents:
            errors.append("At least one agent must be configured")

        for agent in config.agents:
            agent_result = self.validate_agent_config(agent)
            errors.extend(agent_result.errors)
            warnings.extend(agent_result.warnings)

        # Validate orchestration mode matches workflow
        if config.workflow_pattern == WorkflowPattern.WATERFALL:
            if config.orchestration_mode == OrchestrationMode.EVENT_DRIVEN:
                warnings.append(
                    "Waterfall workflow typically works best with Sequential orchestration"
                )
        elif config.workflow_pattern == WorkflowPattern.COLLABORATIVE:
            if config.orchestration_mode == OrchestrationMode.SEQUENTIAL:
                warnings.append(
                    "Collaborative workflow typically works best with Event-Driven orchestration"
                )

        return ValidationResult(
            valid=len(errors) == 0,
            errors=errors,
            warnings=warnings
        )

    def validate_against_schema(self, data: dict, schema_name: str) -> ValidationResult:
        """Validate data against a loaded JSON schema.

        Args:
            data: Data to validate
            schema_name: Name of the schema to validate against

        Returns:
            ValidationResult
        """
        if schema_name not in self.schemas:
            return ValidationResult(
                valid=False,
                errors=[f"Schema '{schema_name}' not found"]
            )

        try:
            validate(instance=data, schema=self.schemas[schema_name])
            return ValidationResult(valid=True)
        except ValidationError as e:
            return ValidationResult(
                valid=False,
                errors=[f"Schema validation failed: {e.message}"]
            )


# ============================================================================
# Main Generator
# ============================================================================

class PRDStarterGenerator:
    """Main generator class for PRD Starter functionality.

    This class orchestrates the generation of agents, skills, configuration
    files, and script modifications based on user input gathered by the
    prd-starter agent.
    """

    def __init__(self, project_root: str | Path = "."):
        """Initialize the generator.

        Args:
            project_root: Root directory of the project
        """
        self.project_root = Path(project_root).resolve()
        self.templates_dir = self.project_root / ".claude" / "templates"
        self.agents_dir = self.project_root / "agents"
        self.scripts_dir = self.project_root / ".claude" / "scripts"
        self.skills_dir = self.project_root / ".claude" / "skills"
        self.schemas_dir = self.project_root / ".claude" / "schemas"
        self.session_dir = self.project_root / ".claude" / "session"
        self.commands_dir = self.project_root / ".claude" / "commands"

        # Create directories
        self._create_directories()

        # Initialize components
        self.renderer = TemplateRenderer(self.templates_dir)
        self.script_updater = ScriptUpdater(self.scripts_dir)
        self.validator = ConfigValidator(self.schemas_dir)

    def _create_directories(self) -> None:
        """Create necessary directories if they don't exist."""
        for dir_path in [
            self.templates_dir,
            self.schemas_dir,
            self.session_dir,
            self.commands_dir
        ]:
            dir_path.mkdir(parents=True, exist_ok=True)

    # ========================================================================
    # Agent Generation
    # ========================================================================

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

            # Generate AGENT.md
            agent_md = self.renderer.render_agent_md(config, project_config)
            (agent_dir / "AGENT.md").write_text(agent_md, encoding='utf-8')

            # Generate SKILLS.md with skill index
            skills_md = self._generate_skills_index(config)
            (agent_dir / "SKILLS.md").write_text(skills_md, encoding='utf-8')

            # Create subdirectories
            (agent_dir / "checklists").mkdir(exist_ok=True)
            (agent_dir / "references").mkdir(exist_ok=True)

            return True

        except Exception as e:
            print(f"Error generating agent {config.name}: {e}", file=sys.stderr)
            return False

    def _generate_skills_index(self, config: AgentConfig) -> str:
        """Generate SKILLS.md index for an agent."""
        skills = config.skills or []
        if not skills:
            return "# Skills\n\nNo specific skills configured.\n"

        content = ["# Skills\n", "This agent has access to the following skills:\n"]

        for skill in skills:
            content.append(f"- **{skill}**")

        content.append("\nSee [../.claude/skills/](../.claude/skills/) for full skill documentation.")
        return '\n'.join(content)

    # ========================================================================
    # Settings Generation
    # ========================================================================

    def generate_agent_settings(self, agent_name: str, mcp_servers: list[str]) -> bool:
        """Generate .claude/settings.{agent}.json.

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

    # ========================================================================
    # Script Updates
    # ========================================================================

    def update_watchdog_scripts(self, agent_names: list[str]) -> bool:
        """Update watchdog scripts with new agents.

        Args:
            agent_names: List of agent names to add

        Returns:
            True if all updates were successful
        """
        success = True
        watchdog_scripts = [
            "watchdog-event.ps1",
            "watchdog-single.ps1"
        ]

        for script_name in watchdog_scripts:
            script_path = self.scripts_dir / script_name
            if script_path.exists():
                for agent in agent_names:
                    if not self.script_updater.add_agent_to_validateset(script_path, agent):
                        success = False

        return success

    def update_message_queue(self, agent_names: list[str]) -> bool:
        """Update message-queue.ps1 with new agents.

        Args:
            agent_names: List of agent names to add

        Returns:
            True if update was successful
        """
        script_path = self.scripts_dir / "message-queue.ps1"
        if not script_path.exists():
            return True  # Skip if doesn't exist

        success = True
        for agent in agent_names:
            if not self.script_updater.add_agent_to_validateset(script_path, agent):
                success = False

        return success

    def update_session_scripts(self, agent_names: list[str]) -> bool:
        """Update session scripts with new agents.

        Args:
            agent_names: List of agent names to add

        Returns:
            True if all updates were successful
        """
        success = True
        session_scripts = [
            "ralph-event-session.ps1",
            "ralph-single-session.ps1"
        ]

        for script_name in session_scripts:
            script_path = self.scripts_dir / script_name
            if script_path.exists():
                for agent in agent_names:
                    if not self.script_updater.add_agent_to_array(script_path, agent):
                        success = False

        return success

    # ========================================================================
    # PRD Generation
    # ========================================================================

    def generate_prd(self, project_config: ProjectConfig) -> bool:
        """Generate initial prd.json from project configuration.

        Args:
            project_config: Project configuration

        Returns:
            True if generation was successful
        """
        try:
            prd_content = self.renderer.render_prd_json(project_config)
            prd_file = self.project_root / "prd.json"
            prd_file.write_text(prd_content, encoding='utf-8')
            return True
        except Exception as e:
            print(f"Error generating PRD: {e}", file=sys.stderr)
            return False

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

    def generate_all(self, project_config: ProjectConfig) -> ValidationResult:
        """Generate all files from project configuration.

        Args:
            project_config: Complete project configuration

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

        # Generate PRD
        if project_config.features:
            if not self.generate_prd(project_config):
                errors.append("Failed to generate PRD")

        return ValidationResult(
            valid=len(errors) == 0,
            errors=errors,
            warnings=warnings
        )


# ============================================================================
# CLI Interface
# ============================================================================

def parse_args() -> argparse.Namespace:
    """Parse command-line arguments."""
    parser = argparse.ArgumentParser(
        description="PRD Starter Generator - Generate agents and configs for Ralph Orchestra",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Generate from state file
  python prd-starter-generator.py --action generate --state prd-starter-state.json

  # Validate configuration
  python prd-starter-generator.py --action validate --config agent-config.json

  # Reset project state
  python prd-starter-generator.py --action reset
        """
    )

    parser.add_argument(
        "--action", "-a",
        choices=["generate", "validate", "reset"],
        default="generate",
        help="Action to perform"
    )

    parser.add_argument(
        "--state", "-s",
        dest="state_file",
        help="Path to prd-starter-state.json file"
    )

    parser.add_argument(
        "--config", "-c",
        dest="config_file",
        help="Path to agent configuration JSON file"
    )

    parser.add_argument(
        "--project-root", "-p",
        default=".",
        help="Project root directory (default: current directory)"
    )

    parser.add_argument(
        "--verbose", "-v",
        action="store_true",
        help="Enable verbose output"
    )

    return parser.parse_args()


def load_state_file(state_path: Path) -> dict | None:
    """Load state from JSON file.

    Args:
        state_path: Path to state file

    Returns:
        Parsed state dict or None if error
    """
    if not state_path.exists():
        print(f"Error: State file not found: {state_path}", file=sys.stderr)
        return None

    try:
        return json.loads(state_path.read_text(encoding='utf-8'))
    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON in state file: {e}", file=sys.stderr)
        return None


def load_config_file(config_path: Path) -> dict | None:
    """Load configuration from JSON file.

    Args:
        config_path: Path to config file

    Returns:
        Parsed config dict or None if error
    """
    if not config_path.exists():
        print(f"Error: Config file not found: {config_path}", file=sys.stderr)
        return None

    try:
        return json.loads(config_path.read_text(encoding='utf-8'))
    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON in config file: {e}", file=sys.stderr)
        return None


def state_to_project_config(state: dict) -> ProjectConfig:
    """Convert state file format to ProjectConfig.

    Args:
        state: State dictionary from prd-starter-state.json

    Returns:
        ProjectConfig object
    """
    phases = state.get("phases", {})

    # Extract project info
    project_phase = phases.get("project_identification", {}).get("data", {})
    project_type = ProjectType.OTHER
    if project_phase.get("projectType") in [e.value for e in ProjectType]:
        project_type = ProjectType(project_phase["projectType"])

    # Extract agents
    agents_phase = phases.get("agent_configuration", {}).get("data", {})
    agents = []
    for agent_data in agents_phase.get("agents", []):
        agents.append(AgentConfig(
            name=agent_data.get("id", "custom-agent").replace("agent-", ""),
            display_name=agent_data.get("displayName", "Custom Agent"),
            role=agent_data.get("type", "custom"),
            custom_type=agent_data.get("customType", ""),
            icon=agent_data.get("icon", ""),
            primary_responsibility=agent_data.get("primaryResponsibility", ""),
            cannot_do=agent_data.get("cannotDo", []),
            works_with=agent_data.get("worksWith", []),
            may_write=agent_data.get("filePermissions", {}).get("mayWrite", []),
            may_not_write=agent_data.get("filePermissions", {}).get("mayNotWrite", []),
            mcp_servers=agent_data.get("mcpServers", ["filesystem"]),
            skills=agent_data.get("skills", []),
            quantity=agent_data.get("quantity", 1)
        ))

    # Extract workflow
    workflow_phase = phases.get("workflow_pattern", {}).get("data", {})
    workflow = WorkflowPattern.COLLABORATIVE
    if workflow_phase.get("pattern") in [e.value for e in WorkflowPattern]:
        workflow = WorkflowPattern(workflow_phase["pattern"])

    # Extract orchestration
    orch_phase = phases.get("orchestration_mode", {}).get("data", {})
    orchestration = OrchestrationMode.EVENT_DRIVEN
    if orch_phase.get("mode") in [e.value for e in OrchestrationMode]:
        orchestration = OrchestrationMode(orch_phase["mode"])

    # Extract tech stack
    tech_phase = phases.get("technology_stack", {}).get("data", {})
    tech_stack = {}
    for key in ["frontend", "backend", "database", "buildTools", "testing"]:
        data = tech_phase.get(key, {})
        if data.get("enabled"):
            tech_stack[key] = data.get("value", "")

    # Extract quality standards
    quality_phase = phases.get("quality_standards", {}).get("data", {})
    quality_standards = {
        "typescript": quality_phase.get("typescript", False),
        "testCoverage": quality_phase.get("testCoverage", 80),
        "linting": quality_phase.get("linting", False),
        "precommit": quality_phase.get("precommit", False),
        "cicd": quality_phase.get("cicd", False),
        "documentation": quality_phase.get("documentation", False),
        "security": quality_phase.get("security", False),
        "performance": quality_phase.get("performance", False)
    }

    # Extract features
    features_phase = phases.get("initial_features", {}).get("data", {})
    features = features_phase.get("parsedFeatures", [])

    return ProjectConfig(
        name=project_phase.get("projectName", "My Project"),
        description=project_phase.get("projectDescription", ""),
        project_type=project_type,
        custom_type=project_phase.get("customDescription", ""),
        agents=agents,
        workflow_pattern=workflow,
        orchestration_mode=orchestration,
        technology_stack=tech_stack,
        quality_standards=quality_standards,
        features=features
    )


def main() -> int:
    """Main entry point."""
    args = parse_args()
    generator = PRDStarterGenerator(args.project_root)

    if args.action == "reset":
        # Reset session state
        state_file = generator.session_dir / "prd-starter-state.json"
        if state_file.exists():
            state_file.unlink()
            print("Reset: State file removed")
        return 0

    if args.action == "validate":
        if not args.config_file:
            print("Error: --config required for validate action", file=sys.stderr)
            return 1

        config_path = Path(args.config_file)
        config_data = load_config_file(config_path)
        if not config_data:
            return 1

        # Convert and validate
        # (This would need proper conversion logic based on config format)
        print("Validation not yet implemented for config files")
        return 0

    if args.action == "generate":
        if not args.state_file:
            print("Error: --state required for generate action", file=sys.stderr)
            return 1

        state_path = Path(args.state_file)
        state = load_state_file(state_path)
        if not state:
            return 1

        # Convert state to ProjectConfig
        project_config = state_to_project_config(state)

        # Generate all files
        result = generator.generate_all(project_config)

        # Report results
        if args.verbose or result.errors or result.warnings:
            print("\n=== Generation Results ===")

        if result.valid:
            print("✓ Generation completed successfully")

            if result.warnings:
                print("\nWarnings:")
                for warning in result.warnings:
                    print(f"  ⚠ {warning}")
        else:
            print("✗ Generation failed")

            print("\nErrors:")
            for error in result.errors:
                print(f"  ✗ {error}")

            if result.warnings:
                print("\nWarnings:")
                for warning in result.warnings:
                    print(f"  ⚠ {warning}")

        return 0 if result.valid else 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
