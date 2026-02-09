"""
PRD Starter Generator - Ralph Orchestra File Copying

RalphFileCopier class - handles selective copying of Ralph Orchestra files
based on enabled agents.
"""

import shutil
from fnmatch import fnmatch
from pathlib import Path

from constants import (
    RALPH_ORCHESTRA_ESSENTIALS,
    UTILITY_AGENTS,
    AGENT_SKILL_CATEGORIES,
    SUB_AGENT_PARENTS
)


class RalphFileCopier:
    """Copies Ralph Orchestra files selectively based on enabled agents."""

    def __init__(self, project_root: Path):
        """Initialize the file copier.

        Args:
            project_root: Root directory of the project
        """
        self.project_root = Path(project_root).resolve()

    def copy_ralph_orchestra_files(self, source_root: Path, enabled_agents: list[str]) -> dict:
        """
        Copy only the necessary ralph-orchestra files to the target project.

        This method performs selective copying based on enabled agents:
        - Copies core scripts and configurations
        - Copies skills selectively based on enabled agents
        - Copies sub-agents selectively based on enabled agents
        - Always copies utility agents (prd-starter, etc.)

        Args:
            source_root: Path to ralph-orchestra root directory
            enabled_agents: List of enabled agent names (e.g., ["pm", "developer", "qa"])

        Returns:
            Dict with copied files and any errors
        """
        results = {
            "copied": [],
            "skipped": [],
            "errors": []
        }

        # Convert enabled_agents to set for faster lookup
        enabled_set = set(enabled_agents) if enabled_agents else set()

        # 1. Copy essential directories (full copy for most)
        for dir_path in RALPH_ORCHESTRA_ESSENTIALS["directories"]:
            source_dir = source_root / dir_path
            target_dir = self.project_root / dir_path

            if not source_dir.exists():
                results["skipped"].append(f"Directory not found: {dir_path}")
                continue

            try:
                if dir_path == "./.claude/skills":
                    # Selective skill copying based on enabled agents
                    self._copy_agent_skills(source_dir, target_dir, enabled_set, results)
                elif dir_path == "./.claude/agents":
                    # Selective sub-agent copying based on enabled agents
                    self._copy_sub_agents(source_dir, target_dir, enabled_set, results)
                elif dir_path == "./.claude/session":
                    # Create empty directory structure only
                    target_dir.mkdir(parents=True, exist_ok=True)
                    results["copied"].append(f"Created directory structure: {dir_path}")
                else:
                    # Full directory copy
                    if target_dir.exists():
                        shutil.rmtree(target_dir)
                    shutil.copytree(source_dir, target_dir)
                    results["copied"].append(f"Copied directory: {dir_path}")
            except Exception as e:
                results["errors"].append(f"Failed to copy {dir_path}: {e}")

        # 2. Copy essential files
        for file_path in RALPH_ORCHESTRA_ESSENTIALS["files"]:
            source_file = source_root / file_path
            target_file = self.project_root / file_path

            if not source_file.exists():
                results["skipped"].append(f"File not found: {file_path}")
                continue

            try:
                target_file.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source_file, target_file)
                results["copied"].append(f"Copied file: {file_path}")
            except Exception as e:
                results["errors"].append(f"Failed to copy {file_path}: {e}")

        # 3. Create empty agent directories
        for agent_dir in RALPH_ORCHESTRA_ESSENTIALS["create_empty"]:
            target_agent_dir = self.project_root / agent_dir
            try:
                target_agent_dir.mkdir(parents=True, exist_ok=True)
                # Only log if we created it (not if it already existed)
                results["copied"].append(f"Created agent directory: {agent_dir}")
            except Exception as e:
                results["errors"].append(f"Failed to create {agent_dir}: {e}")

        return results

    def _copy_agent_skills(self, source_dir: Path, target_dir: Path,
                          enabled_agents: set, results: dict) -> None:
        """
        Copy only skills needed by enabled agents.

        Always copies:
        - shared-* skills (common utilities)
        - Skills in enabled agents' skill lists

        Args:
            source_dir: Source ./.claude/skills directory
            target_dir: Target ./.claude/skills directory
            enabled_agents: Set of enabled agent names
            results: Results dict to update
        """
        # Always copy shared skills
        shared_patterns = ["shared-*"]

        # Build patterns to include based on enabled agents
        include_patterns = shared_patterns.copy()
        for agent in enabled_agents:
            if agent in AGENT_SKILL_CATEGORIES:
                include_patterns.extend(AGENT_SKILL_CATEGORIES[agent])

        # Create target directory
        target_dir.mkdir(parents=True, exist_ok=True)

        # Copy matching skill directories
        if source_dir.exists():
            for item in source_dir.iterdir():
                if item.is_dir():
                    skill_name = item.name
                    should_copy = any(
                        fnmatch.fnmatch(skill_name, pattern)
                        for pattern in include_patterns
                    )
                    if should_copy:
                        target_skill = target_dir / skill_name
                        if target_skill.exists():
                            shutil.rmtree(target_skill)
                        shutil.copytree(item, target_skill)
                        results["copied"].append(f"Copied skill: {skill_name}")

    def _copy_sub_agents(self, source_dir: Path, target_dir: Path,
                        enabled_agents: set, results: dict) -> None:
        """
        Copy only sub-agents needed by enabled agents.

        Always copies:
        - "always" marked utility agents (prd-starter, workflow-generator, etc.)
        - Sub-agents whose parent agent is enabled

        Args:
            source_dir: Source ./.claude/agents directory
            target_dir: Target ./.claude/agents directory
            enabled_agents: Set of enabled agent names
            results: Results dict to update
        """
        # Create target directory
        target_dir.mkdir(parents=True, exist_ok=True)

        # Copy matching sub-agent files
        if source_dir.exists():
            for item in source_dir.iterdir():
                if item.is_file() and item.suffix == ".md":
                    agent_file = item.name
                    agent_name = agent_file.replace(".agent.md", "")

                    # Check if this sub-agent should be copied
                    should_copy = (
                        agent_file in UTILITY_AGENTS or  # Always copy utilities
                        (agent_name in SUB_AGENT_PARENTS and  # Has mapping
                         SUB_AGENT_PARENTS[agent_name] in enabled_agents)  # Parent enabled
                    )

                    if should_copy:
                        target_file = target_dir / agent_file
                        shutil.copy2(item, target_file)
                        results["copied"].append(f"Copied sub-agent: {agent_file}")
