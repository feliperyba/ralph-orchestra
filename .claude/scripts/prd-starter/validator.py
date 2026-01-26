"""
PRD Starter Generator - Config Validator

JSON schema validation for configurations.
"""

import json
import re
from pathlib import Path

from jsonschema import validate, ValidationError

from model_types import AgentConfig, ProjectConfig, ValidationResult, WorkflowPattern, OrchestrationMode


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
