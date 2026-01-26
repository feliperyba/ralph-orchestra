"""
PRD Starter Generator - Modular Package

This package provides agent generation for Ralph Orchestra projects.
Split from the monolithic prd-starter-generator.py for better maintainability.
"""

from model_types import (
    WorkflowPattern,
    OrchestrationMode,
    ProjectType,
    AgentConfig,
    ProjectConfig,
    ValidationResult
)

from constants import (
    TECH_STACK_COMMANDS,
    FEEDBACK_LOOP_COMMANDS,
    TECH_STACK_PREREQUISITES,
    AGENT_DESCRIPTIONS,
    RALPH_ORCHESTRA_ESSENTIALS,
    SUB_AGENT_PARENTS,
    UTILITY_AGENTS,
    AGENT_SKILL_CATEGORIES
)

from renderer import TemplateRenderer
from updater import ScriptUpdater
from validator import ConfigValidator
from generator import PRDStarterGenerator

# Phase 2: New specialized generators
from agent_generator import AgentGenerator
from script_manager import ScriptManager
from docs_generator import DocsGenerator
from file_copier import RalphFileCopier
from readme_generator import ReadmeGenerator

__all__ = [
    # Types
    "WorkflowPattern",
    "OrchestrationMode",
    "ProjectType",
    "AgentConfig",
    "ProjectConfig",
    "ValidationResult",
    # Constants
    "TECH_STACK_COMMANDS",
    "FEEDBACK_LOOP_COMMANDS",
    "TECH_STACK_PREREQUISITES",
    "AGENT_DESCRIPTIONS",
    "RALPH_ORCHESTRA_ESSENTIALS",
    "SUB_AGENT_PARENTS",
    "UTILITY_AGENTS",
    "AGENT_SKILL_CATEGORIES",
    # Core Classes
    "TemplateRenderer",
    "ScriptUpdater",
    "ConfigValidator",
    "PRDStarterGenerator",
    # Specialized Generators (Phase 2)
    "AgentGenerator",
    "ScriptManager",
    "DocsGenerator",
    "RalphFileCopier",
    "ReadmeGenerator",
]
