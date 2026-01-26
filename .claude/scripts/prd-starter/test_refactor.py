#!/usr/bin/env python3
"""
Test script to validate the prd-starter-generator refactor.

Phase 2: Tests for all 18 modules including new specialized generators.
"""

import sys
import io
import os
from pathlib import Path
import tempfile

# Set UTF-8 encoding for Windows console
if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8')

# Add parent directory to path for imports
script_dir = Path(__file__).parent
sys.path.insert(0, str(script_dir))


def test_imports():
    """Test that all modules can be imported including Phase 2 generators."""
    print("Testing imports...")
    try:
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
            AGENT_DESCRIPTIONS,
            RALPH_ORCHESTRA_ESSENTIALS
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
        from cli import main
        print("OK All imports successful (including Phase 2 modules)")
        return True
    except ImportError as e:
        print(f"FAIL Import failed: {e}")
        return False


def test_type_creation():
    """Test that type classes work correctly."""
    print("\nTesting type creation...")
    from model_types import AgentConfig, ProjectConfig, WorkflowPattern, OrchestrationMode, ProjectType

    agent = AgentConfig(
        name="test-agent",
        display_name="Test Agent",
        role="developer"
    )
    assert agent.name == "test-agent"
    assert agent.display_name == "Test Agent"

    project = ProjectConfig(
        name="test-project",
        description="Test description",
        project_type=ProjectType.WEB,
        agents=[agent],
        workflow_pattern=WorkflowPattern.COLLABORATIVE,
        orchestration_mode=OrchestrationMode.EVENT_DRIVEN
    )
    assert project.name == "test-project"
    assert len(project.agents) == 1

    print("OK Type creation successful")
    return True


def test_renderer():
    """Test TemplateRenderer functionality."""
    print("\nTesting TemplateRenderer...")
    from renderer import TemplateRenderer
    from model_types import AgentConfig, ProjectConfig, ProjectType

    renderer = TemplateRenderer(Path(__file__).parent / ".claude" / "templates")

    # Test default rendering (no template required)
    agent = AgentConfig(
        name="test-agent",
        display_name="Test Agent",
        role="developer"
    )
    project = ProjectConfig(
        name="test-project",
        description="Test",
        project_type=ProjectType.WEB
    )

    result = renderer.render_agent_md(agent, project)
    assert "# Test Agent" in result
    assert "Role" in result

    print("OK TemplateRenderer successful")
    return True


def test_generator():
    """Test PRDStarterGenerator initialization with Phase 2 sub-generators."""
    print("\nTesting PRDStarterGenerator (Phase 2 architecture)...")
    from generator import PRDStarterGenerator

    # Use a temporary directory for testing
    with tempfile.TemporaryDirectory() as tmpdir:
        gen = PRDStarterGenerator(tmpdir)
        assert gen.project_root == Path(tmpdir).resolve()

        # Verify core components
        assert gen.renderer is not None
        assert gen.script_updater is not None
        assert gen.validator is not None

        # Verify Phase 2 specialized generators
        assert gen.agent_gen is not None
        assert gen.script_mgr is not None
        assert gen.docs_gen is not None
        assert gen.file_copier is not None
        assert gen.readme_gen is not None

    print("OK PRDStarterGenerator successful (with Phase 2 sub-generators)")
    return True


def test_agent_generator():
    """Test AgentGenerator class."""
    print("\nTesting AgentGenerator...")
    from agent_generator import AgentGenerator
    from renderer import TemplateRenderer
    from model_types import AgentConfig, ProjectConfig, ProjectType

    with tempfile.TemporaryDirectory() as tmpdir:
        renderer = TemplateRenderer(Path(__file__).parent / ".claude" / "templates")
        agent_gen = AgentGenerator(tmpdir, renderer)

        agent = AgentConfig(
            name="test-agent",
            display_name="Test Agent",
            role="developer"
        )
        project = ProjectConfig(
            name="test-project",
            description="Test",
            project_type=ProjectType.WEB
        )

        result = agent_gen.generate_agent(agent, project)
        assert result == True

        # Verify agent directory was created
        agent_dir = Path(tmpdir) / "agents" / "test-agent"
        assert agent_dir.exists()
        assert (agent_dir / "AGENT.md").exists()

    print("OK AgentGenerator successful")
    return True


def test_script_manager():
    """Test ScriptManager class."""
    print("\nTesting ScriptManager...")
    from script_manager import ScriptManager
    from updater import ScriptUpdater

    with tempfile.TemporaryDirectory() as tmpdir:
        scripts_dir = Path(tmpdir) / "scripts"
        scripts_dir.mkdir(parents=True)
        updater = ScriptUpdater(scripts_dir)
        script_mgr = ScriptManager(scripts_dir, updater)

        # Test with no scripts (should return True)
        result = script_mgr.update_watchdog_scripts([])
        assert result == True

    print("OK ScriptManager successful")
    return True


def test_docs_generator():
    """Test DocsGenerator class."""
    print("\nTesting DocsGenerator...")
    from docs_generator import DocsGenerator
    from renderer import TemplateRenderer
    from model_types import ProjectConfig, ProjectType

    with tempfile.TemporaryDirectory() as tmpdir:
        renderer = TemplateRenderer(Path(__file__).parent / ".claude" / "templates")
        docs_gen = DocsGenerator(tmpdir, renderer)

        project = ProjectConfig(
            name="test-project",
            description="Test project",
            project_type=ProjectType.WEB
        )

        # Test workflow docs setup
        result = docs_gen.setup_workflow_docs_directory(project)
        assert result == True

        # Verify directory was created
        workflows_dir = Path(tmpdir) / "docs" / "workflows"
        assert workflows_dir.exists()

    print("OK DocsGenerator successful")
    return True


def test_file_copier():
    """Test RalphFileCopier class."""
    print("\nTesting RalphFileCopier...")
    from file_copier import RalphFileCopier

    with tempfile.TemporaryDirectory() as tmpdir:
        copier = RalphFileCopier(tmpdir)

        # Test with no source (should return empty results)
        source_root = Path(tmpdir) / "source"
        source_root.mkdir(parents=True)

        results = copier.copy_ralph_orchestra_files(source_root, [])
        assert "copied" in results
        assert "skipped" in results
        assert "errors" in results

    print("OK RalphFileCopier successful")
    return True


def test_readme_generator():
    """Test ReadmeGenerator class."""
    print("\nTesting ReadmeGenerator...")
    from readme_generator import ReadmeGenerator
    from model_types import ProjectConfig, ProjectType

    with tempfile.TemporaryDirectory() as tmpdir:
        readme_gen = ReadmeGenerator(tmpdir)

        project = ProjectConfig(
            name="test-project",
            description="Test project",
            project_type=ProjectType.WEB
        )

        tech_stack = {
            "runtime": "node",
            "teamSize": "Solo"
        }

        agents = {}

        # Test README generation
        result = readme_gen.generate_readme(project, tech_stack, agents)
        assert result == True

        # Verify README.md was created
        readme_path = Path(tmpdir) / "README.md"
        assert readme_path.exists()

    print("OK ReadmeGenerator successful")
    return True


def test_constants():
    """Test that constants are accessible."""
    print("\nTesting constants...")
    from constants import TECH_STACK_COMMANDS, AGENT_DESCRIPTIONS

    assert 'node' in TECH_STACK_COMMANDS
    assert 'python' in TECH_STACK_COMMANDS
    assert 'pm' in AGENT_DESCRIPTIONS

    print("OK Constants accessible")
    return True


def test_utils():
    """Test utility functions."""
    print("\nTesting utility functions...")
    from utils import resolve_tech_stack_commands

    result = resolve_tech_stack_commands({'runtime': 'node'})
    assert result['runtime'] == 'node'
    assert result['package_manager'] == 'npm'

    print("OK Utility functions successful")
    return True


def test_cli():
    """Test CLI argument parsing."""
    print("\nTesting CLI...")
    from cli import parse_args

    # Test default args by simulating sys.argv
    original_argv = sys.argv
    try:
        sys.argv = ['test_script', '--action', 'generate']
        args = parse_args()
        assert args.action == 'generate'
    finally:
        sys.argv = original_argv

    # Test with state file
    try:
        sys.argv = ['test_script', '--state', 'test.json']
        args = parse_args()
        assert args.state_file == 'test.json'
    finally:
        sys.argv = original_argv

    print("OK CLI parsing successful")
    return True


def run_all_tests():
    """Run all validation tests."""
    print("=" * 60)
    print("PRD Starter Generator Refactor Validation Tests (Phase 2)")
    print("=" * 60)

    tests = [
        test_imports,
        test_type_creation,
        test_renderer,
        test_generator,
        test_agent_generator,
        test_script_manager,
        test_docs_generator,
        test_file_copier,
        test_readme_generator,
        test_constants,
        test_utils,
        test_cli
    ]

    results = []
    for test in tests:
        try:
            results.append(test())
        except Exception as e:
            print(f"FAIL Test failed with exception: {e}")
            import traceback
            traceback.print_exc()
            results.append(False)

    print("\n" + "=" * 60)
    print(f"Results: {sum(results)}/{len(results)} tests passed")
    print("=" * 60)

    return all(results)


if __name__ == "__main__":
    success = run_all_tests()
    sys.exit(0 if success else 1)
