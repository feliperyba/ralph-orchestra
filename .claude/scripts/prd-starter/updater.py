"""
PRD Starter Generator - Script Updater

Regex-based PowerShell script file modifications.
"""

import re
import sys
from pathlib import Path

from model_types import AgentConfig


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
            if f'{agent_name}\\s*=' in content:
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
