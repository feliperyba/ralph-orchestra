"""
PRD Starter Generator - Script Update Management

ScriptManager class - handles updating PowerShell scripts with new agent names.
"""

from pathlib import Path

from updater import ScriptUpdater


class ScriptManager:
    """Manages PowerShell script updates for agent configuration."""

    def __init__(self, scripts_dir: Path, script_updater: ScriptUpdater):
        """Initialize the script manager.

        Args:
            scripts_dir: Directory containing scripts to update
            script_updater: ScriptUpdater instance for applying updates
        """
        self.scripts_dir = Path(scripts_dir)
        self.script_updater = script_updater

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
