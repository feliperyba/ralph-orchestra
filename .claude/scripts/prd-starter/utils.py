"""
PRD Starter Generator - Utility Functions

Utility functions for tech stack resolution and project location handling.
"""

import sys
from pathlib import Path
from typing import Any

from constants import TECH_STACK_COMMANDS


def resolve_tech_stack_commands(tech_stack: dict, research_data: dict = None) -> dict:
    """
    Resolve tech stack commands using 6-level priority chain.

    Priority:
    1. User explicit override (from tech_stack dict)
    2. Discovered commands (high confidence)
    3. Preset commands
    4. Discovered commands (medium confidence)
    5. Hardcoded runtime table
    6. Safe fallback (Node/npm)

    Args:
        tech_stack: User's tech_stack configuration
        research_data: Optional research data with discoveredCommands

    Returns:
        Dictionary with resolved commands and source information
    """
    runtime = tech_stack.get("runtime", "node")

    # Level 1: User explicit override
    if "initCommand" in tech_stack or "packageManager" in tech_stack:
        return {
            "runtime": runtime,
            "source": "user",
            "package_manager": tech_stack.get("packageManager", "npm"),
            "init": tech_stack.get("initCommand", "npm init -y"),
            "install": tech_stack.get("installCommand", "npm install"),
            "dev": tech_stack.get("devCommand", "npm run dev"),
            "build": tech_stack.get("buildCommand", "npm run build"),
            "test": tech_stack.get("testCommand", "npm test"),
            "type_check": tech_stack.get("typeCheckCommand", "")
        }

    # Level 2-4: Discovered commands from research
    if research_data and "discoveredCommands" in research_data.get("researchData", {}):
        discovered = research_data["researchData"]["discoveredCommands"]
        confidence = discovered.get("confidence", "low")

        # Use high confidence immediately, medium if not in hardcoded table
        if confidence == "high" or (confidence == "medium" and runtime not in TECH_STACK_COMMANDS):
            commands = discovered.get("commands", {})
            return {
                "runtime": runtime,
                "source": f"research.{confidence}",
                "package_manager": commands.get("packageManager", "unknown"),
                "init": commands.get("init", f"echo 'No init command found for {runtime}'"),
                "install": commands.get("install", ""),
                "dev": commands.get("dev", ""),
                "build": commands.get("build", ""),
                "test": commands.get("test", ""),
                "type_check": commands.get("typeCheck", "")
            }

    # Level 5: Hardcoded runtime table
    if runtime in TECH_STACK_COMMANDS:
        commands = TECH_STACK_COMMANDS[runtime]
        return {
            "runtime": runtime,
            "source": "hardcoded",
            "package_manager": commands["package_manager"],
            "init": commands["init"],
            "install": commands["install"],
            "dev": commands.get("dev", ""),
            "build": commands.get("build", ""),
            "test": commands.get("test", ""),
            "type_check": commands.get("type_check", "")
        }

    # Level 6: Safe fallback
    return {
        "runtime": runtime,
        "source": "fallback",
        "package_manager": "npm",
        "init": "npm init -y",
        "install": "npm install",
        "dev": "npm run dev",
        "build": "npm run build",
        "test": "npm test",
        "type_check": "tsc --noEmit"
    }


def resolve_project_location(state: dict, ralph_root: Path, current_dir: Path) -> Path:
    """
    Resolve the target project location from state.

    Priority:
    1. State projectLocation.path (explicit custom path)
    2. Subdirectory in ralph-orchestra root (default)
    3. Current directory (fallback)

    Args:
        state: Loaded state file dict
        ralph_root: Path to ralph-orchestra root directory
        current_dir: Current working directory

    Returns:
        Absolute path to target project directory
    """
    location_config = state.get("projectLocation", {})
    location_type = location_config.get("type", "subdirectory")
    project_name = state.get("project", {}).get("name", "new-project")

    if location_type == "current":
        return current_dir

    elif location_type == "subdirectory":
        # Default: create in ralph-orchestra root with project name
        subdirectory_name = location_config.get("subdirectoryName", project_name)
        return ralph_root / subdirectory_name

    elif location_type == "custom":
        custom_path = location_config.get("path", "")
        if custom_path:
            path = Path(custom_path)
            if not path.is_absolute():
                path = current_dir / path
            return path
        return current_dir

    else:  # fallback to subdirectory
        return ralph_root / project_name


def create_project_directory(target_path: Path) -> bool:
    """
    Create the target project directory if it doesn't exist.

    Args:
        target_path: Path where project should be created

    Returns:
        True if directory exists or was created successfully
    """
    try:
        target_path.mkdir(parents=True, exist_ok=True)
        print(f"✓ Project directory: {target_path}")
        return True
    except Exception as e:
        print(f"✗ Failed to create project directory: {e}", file=sys.stderr)
        return False
