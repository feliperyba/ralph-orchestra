"""
PRD Starter Generator - Type Definitions

Type definitions used across all modules.
"""

from dataclasses import dataclass, field
from enum import Enum
from typing import Any


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
        main_activities: List of key activities this agent performs
        interaction_pattern: How this agent interacts with others
        workflow: Workflow configuration with states and transitions
        model: Default model for this agent
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
    main_activities: list[str] = field(default_factory=list)
    interaction_pattern: str = "collaborate"
    workflow: dict[str, Any] = field(default_factory=dict)
    model: str = "inherit"


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
