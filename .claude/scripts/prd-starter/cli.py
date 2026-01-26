"""
PRD Starter Generator - CLI Interface

Command-line argument parsing and main entry point.
"""

import argparse
import sys
from pathlib import Path

from generator import PRDStarterGenerator
from loader import load_state_file, load_config_file, load_preset, state_to_project_config
from utils import resolve_project_location, create_project_directory


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


def main() -> int:
    """Main entry point."""
    args = parse_args()

    # Detect ralph-orchestra root directory
    # Use the directory containing .claude/scripts/prd-starter as ralph root
    script_dir = Path(__file__).parent.resolve()
    ralph_root = script_dir.parent.parent.parent  # Go up from .claude/scripts/prd-starter to root

    # For the generate action, resolve project location from state
    if args.action == "generate":
        if not args.state_file:
            print("Error: --state required for generate action", file=sys.stderr)
            return 1

        state_path = Path(args.state_file)
        state = load_state_file(state_path)
        if not state:
            return 1

        # Resolve target project location from state
        current_dir = Path.cwd()
        target_location = resolve_project_location(state, ralph_root, current_dir)

        # Create target project directory
        if not create_project_directory(target_location):
            return 1

        # Create generator with target location as project root
        generator = PRDStarterGenerator(target_location)

        # Get list of enabled agents for selective copying
        enabled_agents = []
        agents_dict = state.get("agents", {})
        for agent_name, agent_data in agents_dict.items():
            if agent_data.get("enabled", False):
                enabled_agents.append(agent_name)

        # Copy ralph-orchestra files selectively
        print("\n=== Copying Ralph Orchestra Files ===")
        copy_results = generator.copy_ralph_orchestra_files(ralph_root, enabled_agents)

        if copy_results["copied"]:
            print(f"\n✓ Copied {len(copy_results['copied'])} items")
            if args.verbose:
                for item in copy_results["copied"]:
                    print(f"  - {item}")

        if copy_results["skipped"] and args.verbose:
            print(f"\n⚠ Skipped {len(copy_results['skipped'])} items")
            for item in copy_results["skipped"]:
                print(f"  - {item}")

        if copy_results["errors"]:
            print(f"\n✗ Errors copying {len(copy_results['errors'])} items")
            for error in copy_results["errors"]:
                print(f"  ✗ {error}")

        # Convert state to ProjectConfig
        project_config = state_to_project_config(state, target_location)

        # Extract tech stack from state (for v3.0+ format)
        tech_stack = None
        research_data = state.get("researchData", {})
        if state.get("version", "1.0.0").startswith(("3.", "4.")):
            # Try to get tech stack from projectInitialization section
            project_init = state.get("projectInitialization", {})
            if project_init.get("techStack"):
                tech_stack = project_init["techStack"]
            # Or from project initialization direct config
            elif "projectInitialization" in state:
                tech_stack = state["projectInitialization"].get("techStack", {})

        # For presets, extract tech stack from preset config
        if state.get("selectedPreset"):
            preset = load_preset(state["selectedPreset"], target_location)
            if preset and preset.get("techStack"):
                tech_stack = preset["techStack"]

        # Generate all files
        print("\n=== Generating Project Files ===")
        result = generator.generate_all(project_config, tech_stack)

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

    # For other actions, use current behavior
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

    return 0


if __name__ == "__main__":
    sys.exit(main())
