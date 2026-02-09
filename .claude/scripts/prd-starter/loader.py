"""
PRD Starter Generator - State and Preset Loading

Functions for loading and parsing state files, preset files,
and converting them to ProjectConfig objects.
"""

import json
import sys
from pathlib import Path

from model_types import AgentConfig, ProjectConfig, WorkflowPattern, OrchestrationMode, ProjectType


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


def load_preset(preset_name: str, project_root: Path) -> dict | None:
    """Load preset configuration from .claude/presets/.

    Args:
        preset_name: Name of the preset (e.g., "indie-game-dev")
        project_root: Project root directory

    Returns:
        Preset configuration dict or None if error
    """
    presets_dir = project_root / ".claude" / "presets"
    preset_file = presets_dir / f"{preset_name}.json"

    if not preset_file.exists():
        print(f"Error: Preset file not found: {preset_file}", file=sys.stderr)
        return None

    try:
        return json.loads(preset_file.read_text(encoding='utf-8'))
    except (json.JSONDecodeError, IOError) as e:
        print(f"Error: Failed to load preset: {e}", file=sys.stderr)
        return None


def state_to_project_config(state: dict, project_root: Path = Path(".")) -> ProjectConfig:
    """Convert state file format to ProjectConfig.

    Args:
        state: State dictionary from prd-starter-state.json
        project_root: Project root directory

    Returns:
        ProjectConfig object
    """
    # Check both 'version' and '_version' fields (v4.0 template uses '_version')
    version = state.get("version") or state.get("_version", "1.0.0")
    
    # Version 3.0+ state format (with wizardMode and direct agent config)
    if version.startswith("3."):
        return _state_v3_to_project_config(state, project_root)

    # Version 4.0+ state format (with customAgents dynamic creation)
    if version.startswith("4."):
        return _state_v3_to_project_config(state, project_root)

    # Legacy state format (v2.x with phases)
    return _state_v2_to_project_config(state)


def _state_v3_to_project_config(state: dict, project_root: Path) -> ProjectConfig:
    """Convert v3.0+ state format to ProjectConfig.

    Args:
        state: State dictionary from prd-starter-state.json
        project_root: Project root directory

    Returns:
        ProjectConfig object
    """
    # Handle preset selection first
    if state.get("selectedPreset"):
        preset = load_preset(state["selectedPreset"], project_root)
        if preset:
            return _preset_to_project_config(preset, state)

    # Extract project info
    project = state.get("project", {})
    project_name = project.get("name", "My Project")
    project_description = project.get("description", "")

    # Map project category to ProjectType
    category_map = {
        "game-development": ProjectType.GAME,
        "web-application": ProjectType.WEB,
        "mobile-app": ProjectType.MOBILE,
        "api-backend": ProjectType.BACKEND,
        "data-ml": ProjectType.DATA,
        "ecommerce": ProjectType.WEB,
        "saas": ProjectType.WEB,
        "devops-infrastructure": ProjectType.DEVOPS
    }
    project_type = category_map.get(project.get("category", "other"), ProjectType.OTHER)

    # Extract agents from v3.0 format
    agents_dict = state.get("agents", {})
    agents = []

    for agent_name, agent_data in agents_dict.items():
        if not agent_data.get("enabled", False):
            continue

        # Get agent role mapping
        role_map = {
            "pm": "pm",
            "developer": "developer",
            "techartist": "techartist",
            "qa": "qa",
            "gamedesigner": "gamedesigner"
        }

        role = agent_data.get("role", agent_name)
        if role not in role_map.values():
            role = agent_name

        # Build icon (default icons based on role)
        icons = {
            "pm": "📋",
            "developer": "💻",
            "techartist": "🎨",
            "qa": "🔍",
            "gamedesigner": "🎮"
        }
        icon = agent_data.get("icon", icons.get(role, "•"))

        agents.append(AgentConfig(
            name=agent_name,
            display_name=agent_data.get("display_name", agent_name.title()),
            role=role,
            icon=icon,
            primary_responsibility=agent_data.get("primary_responsibility", f"{role} agent responsibilities"),
            cannot_do=agent_data.get("cannot_do", []),
            works_with=agent_data.get("works_with", []),
            may_write=agent_data.get("may_write", []),
            may_not_write=agent_data.get("may_not_write", []),
            mcp_servers=agent_data.get("mcpServers", ["filesystem"]),
            skills=agent_data.get("skills", []),
            sub_agents=agent_data.get("subAgents", [])
        ))

    # Extract custom agents from v4.0 format (dynamic agent creation)
    custom_agents_list = state.get("customAgents", [])
    for agent_data in custom_agents_list:
        agent_id = agent_data.get("id", "")
        if not agent_id:
            continue

        # Get agent type
        agent_type = agent_data.get("agent_type", "custom")

        # Build icon (default icons based on type)
        icons = {
            "pm": "📋",
            "developer": "💻",
            "techartist": "🎨",
            "qa": "🔍",
            "gamedesigner": "🎮",
            "custom": "⚙️"
        }
        icon = agent_data.get("icon", icons.get(agent_type, "•"))

        # Extract skills
        skills = []
        for skill_item in agent_data.get("skills", []):
            if isinstance(skill_item, dict):
                skills.append(skill_item.get("name", ""))
            else:
                skills.append(skill_item)

        # Extract sub-agents
        sub_agents = []
        for sub_item in agent_data.get("subAgents", []):
            if isinstance(sub_item, dict):
                sub_agents.append(sub_item.get("name", ""))
            else:
                sub_agents.append(sub_item)

        # Extract workflow config
        workflow = agent_data.get("workflow", {})

        agents.append(AgentConfig(
            name=agent_id,
            display_name=agent_data.get("display_name", agent_id.title()),
            role=agent_type,
            custom_type=agent_data.get("custom_type_description", ""),
            icon=icon,
            primary_responsibility=agent_data.get("primary_responsibility", f"{agent_type} agent responsibilities"),
            cannot_do=agent_data.get("cannot_do", []),
            works_with=agent_data.get("works_with", []),
            may_write=agent_data.get("may_write", []),
            may_not_write=agent_data.get("may_not_write", []),
            mcp_servers=agent_data.get("mcpServers", ["filesystem"]),
            skills=skills,
            sub_agents=sub_agents,
            main_activities=agent_data.get("main_activities", []),
            interaction_pattern=agent_data.get("interaction_pattern", "collaborate"),
            workflow=workflow,
            model=agent_data.get("model", "inherit")
        ))

    # Extract orchestration
    orchestration_data = state.get("orchestration", {})
    orchestration_mode_map = {
        "event-driven": OrchestrationMode.EVENT_DRIVEN,
        "sequential": OrchestrationMode.SEQUENTIAL,
        "hitl": OrchestrationMode.HITL
    }
    orchestration = orchestration_mode_map.get(
        orchestration_data.get("mode", "sequential"),
        OrchestrationMode.SEQUENTIAL
    )

    # Extract features
    features = state.get("features", [])

    # Build tech stack from project info
    tech_stack = {
        "frontend": {
            "enabled": bool(project.get("techStack")),
            "value": project.get("techStack", ""),
            "variant": project.get("customTechStack", "")
        }
    }

    # Extract quality standards
    quality_standards = state.get("qualityStandards", {})

    return ProjectConfig(
        name=project_name,
        description=project_description,
        project_type=project_type,
        custom_type=project.get("customCategory", ""),
        agents=agents,
        workflow_pattern=WorkflowPattern.COLLABORATIVE,
        orchestration_mode=orchestration,
        technology_stack=tech_stack,
        quality_standards=quality_standards,
        features=features
    )


def _preset_to_project_config(preset: dict, state: dict) -> ProjectConfig:
    """Convert preset configuration to ProjectConfig.

    Args:
        preset: Preset configuration dictionary
        state: State dictionary for overrides

    Returns:
        ProjectConfig object
    """
    project = state.get("project", {})

    # Map preset category to ProjectType
    category_map = {
        "Game Development": ProjectType.GAME,
        "Web Application": ProjectType.WEB,
        "Technical": ProjectType.OTHER
    }
    project_type = category_map.get(preset.get("category", "other"), ProjectType.OTHER)

    # Extract agents from preset
    agents_dict = preset.get("agents", {})
    agents = []

    for agent_name, agent_data in agents_dict.items():
        if not agent_data.get("enabled", False):
            continue

        icons = {
            "pm": "📋",
            "developer": "💻",
            "techartist": "🎨",
            "qa": "🔍",
            "gamedesigner": "🎮"
        }
        icon = agent_data.get("icon", icons.get(agent_data.get("role", ""), "•"))

        # Handle preset customizations
        skills = list(agent_data.get("skills", []))
        sub_agents = list(agent_data.get("subAgents", []))

        customizations = state.get("presetCustomizations", {})
        if customizations:
            skills.extend(customizations.get("additionalSkills", []))
            for skill in customizations.get("removedSkills", []):
                if skill in skills:
                    skills.remove(skill)

            sub_agents.extend(customizations.get("additionalSubAgents", []))
            for sub_agent in customizations.get("removedSubAgents", []):
                if sub_agent in sub_agents:
                    sub_agents.remove(sub_agent)

        agents.append(AgentConfig(
            name=agent_name,
            display_name=agent_data.get("display_name", agent_name.title()),
            role=agent_data.get("role", agent_name),
            icon=icon,
            primary_responsibility=agent_data.get("primary_responsibility", ""),
            cannot_do=agent_data.get("cannot_do", []),
            works_with=agent_data.get("works_with", []),
            may_write=agent_data.get("may_write", []),
            may_not_write=agent_data.get("may_notWrite", []),
            mcp_servers=agent_data.get("mcpServers", ["filesystem"]),
            skills=skills,
            sub_agents=sub_agents
        ))

    # Orchestration from preset or override
    orchestration_data = state.get("orchestration", {})
    preset_orchestration = preset.get("orchestration", {})

    orchestration_mode_map = {
        "event-driven": OrchestrationMode.EVENT_DRIVEN,
        "sequential": OrchestrationMode.SEQUENTIAL,
        "hitl": OrchestrationMode.HITL
    }

    mode = orchestration_data.get("mode") or preset_orchestration.get("recommendedMode", "sequential")
    orchestration = orchestration_mode_map.get(mode, OrchestrationMode.SEQUENTIAL)

    # Features from state (user input)
    features = state.get("features", [])

    return ProjectConfig(
        name=project.get("name", preset.get("displayName", "My Project")),
        description=project.get("description", preset.get("description", "")),
        project_type=project_type,
        agents=agents,
        workflow_pattern=WorkflowPattern.COLLABORATIVE,
        orchestration_mode=orchestration,
        technology_stack={"frontend": {"enabled": True, "value": project.get("techStack", "")}},
        quality_standards=preset.get("qualityStandards", {}),
        features=features
    )


def _state_v2_to_project_config(state: dict) -> ProjectConfig:
    """Convert v2.x state format to ProjectConfig (legacy support).

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
