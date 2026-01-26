"""
PRD Starter Generator - Constants

Configuration constants and mappings used across all modules.
"""

# Tech stack command mappings for agnostic project initialization
TECH_STACK_COMMANDS = {
    "node": {
        "package_manager": "npm",
        "init": "npm init -y",
        "install": "npm install",
        "dev": "npm run dev",
        "build": "npm run build",
        "test": "npm run test",
        "type_check": "tsc --noEmit"  # For TypeScript projects
    },
    "python": {
        "package_manager": "pip",
        "init": "python -m venv venv && source venv/bin/activate",
        "install": "pip install -r requirements.txt",
        "dev": "python main.py",
        "build": "python -m build",
        "test": "pytest",
        "type_check": "mypy --strict ."
    },
    "rust": {
        "package_manager": "cargo",
        "init": "cargo init",
        "install": "cargo build",
        "dev": "cargo run",
        "build": "cargo build --release",
        "test": "cargo test",
        "type_check": "cargo clippy"
    },
    "go": {
        "package_manager": "go mod",
        "init": "go mod init {PROJECT_NAME}",
        "install": "go mod tidy",
        "dev": "go run main.go",
        "build": "go build",
        "test": "go test ./...",
        "type_check": "go vet ./..."
    },
    "java": {
        "package_manager": "mvn",
        "init": "mvn archetype:generate",
        "install": "mvn install",
        "dev": "mvn spring-boot:run",
        "build": "mvn package",
        "test": "mvn test",
        "type_check": "mvn compile"
    },
    "dotnet": {
        "package_manager": "dotnet",
        "init": "dotnet new console",
        "install": "dotnet restore",
        "dev": "dotnet run",
        "build": "dotnet build",
        "test": "dotnet test",
        "type_check": "dotnet build"
    }
}

# Feedback loop commands by tech stack
FEEDBACK_LOOP_COMMANDS = {
    "node": {
        "type-check": {"command": "npm run type-check", "required": True, "description": "TypeScript type checking"},
        "lint": {"command": "npm run lint", "required": True, "description": "ESLint linting"},
        "test": {"command": "npm run test", "required": True, "description": "Run test suite"},
        "build": {"command": "npm run build", "required": True, "description": "Production build"}
    },
    "python": {
        "type-check": {"command": "mypy --strict .", "required": True, "description": "Type checking with mypy"},
        "lint": {"command": "ruff check .", "required": True, "description": "Linting with ruff"},
        "test": {"command": "pytest", "required": True, "description": "Run test suite"},
        "build": {"command": "python -m build", "required": True, "description": "Build package"}
    },
    "rust": {
        "type-check": {"command": "cargo clippy", "required": True, "description": "Clippy linting"},
        "lint": {"command": "cargo clippy", "required": True, "description": "Clippy linting"},
        "test": {"command": "cargo test", "required": True, "description": "Run test suite"},
        "build": {"command": "cargo build", "required": True, "description": "Debug build"}
    },
    "go": {
        "type-check": {"command": "go vet ./...", "required": True, "description": "Go vet analysis"},
        "lint": {"command": "golangci-lint run", "required": True, "description": "Linting"},
        "test": {"command": "go test ./...", "required": True, "description": "Run test suite"},
        "build": {"command": "go build", "required": True, "description": "Build binary"}
    }
}

# Tech stack prerequisites for README generation
TECH_STACK_PREREQUISITES = {
    "node": [
        "- **Node.js** v18+ installed from [nodejs.org](https://nodejs.org)",
        "- **npm** or **yarn** package manager"
    ],
    "python": [
        "- **Python** 3.11+ installed from [python.org](https://python.org)",
        "- **pip** package manager",
        "- Recommended: **uv** for faster dependency management"
    ],
    "rust": [
        "- **Rust** installed via [rustup.rs](https://rustup.rs)",
        "- **Cargo** package manager (included with Rust)"
    ],
    "go": [
        "- **Go** 1.21+ installed from [go.dev](https://go.dev)",
        "- **go mod** for dependency management"
    ],
    "java": [
        "- **JDK** 17+ installed from [oracle.com](https://oracle.com)",
        "- **Maven** or **Gradle** for build management"
    ],
    "dotnet": [
        "- **.NET** 8+ SDK installed from [dotnet.microsoft.com](https://dotnet.microsoft.com)",
        "- **nuget** for package management"
    ]
}

# Agent descriptions for README generation
AGENT_DESCRIPTIONS = {
    "pm": "Project Manager - Coordinates tasks, assigns work, runs retrospectives",
    "developer": "Developer - Implements features, writes code, runs feedback loops",
    "techartist": "Tech Artist - Creates visual assets, shaders, and effects",
    "qa": "QA - Validates implementations with tests and browser checks",
    "gamedesigner": "Game Designer - Creates GDDs, provides design guidance, playtests"
}

# Files and directories that MUST be copied to the new project
RALPH_ORCHESTRA_ESSENTIALS = {
    "directories": [
        # Core orchestration scripts
        ".claude/scripts/core",
        # Session launchers
        ".claude/scripts/sessions",
        # Watchdog scripts
        ".claude/scripts/watchdog",
        # V2 event-driven architecture
        ".claude/scripts/v2-architecture",
        # Dashboard
        ".claude/scripts/dashboard",
        # Process management
        ".claude/scripts/process",
        # Config files for agents
        ".claude/scripts/config",
        # Hooks and commands
        ".claude/hooks",
        ".claude/commands",
        # Orchestration and protocols
        ".claude/orchestration",
        ".claude/protocols",
        # Skills and sub-agents (selective copy based on enabled agents)
        ".claude/skills",
        ".claude/agents",
        # Session directory structure (empty)
        ".claude/session",
    ],
    "files": [
        ".claude/ralph-config.json",
        ".claude/settings.developer.json",
        ".claude/settings.gamedesigner.json",
        ".claude/settings.pm.json",
        ".claude/settings.qa.json",
        ".claude/settings.techartist.json",
        ".claude/settings.local.json",
    ],
    "create_empty": [
        "agents/developer",
        "agents/gamedesigner",
        "agents/pm",
        "agents/qa",
        "agents/techartist",
    ]
}

# Sub-agent to parent agent mapping
SUB_AGENT_PARENTS = {
    # PM sub-agents
    "pm-architecture-validator": "pm",
    "pm-prd-creator": "pm",
    "pm-research-specialist": "pm",
    "pm-prd-organizer": "pm",
    "pm-retrospective-facilitator": "pm",
    "pm-skill-researcher": "pm",
    "pm-task-researcher": "pm",
    "pm-test-planner": "pm",
    # Developer sub-agents
    "developer-code-research": "developer",
    "developer-commit": "developer",
    "developer-implementation": "developer",
    "developer-validation": "developer",
    # Tech Artist sub-agents
    "techartist-asset-creator": "techartist",
    "techartist-asset-researcher": "techartist",
    "techartist-code-quality": "techartist",
    "techartist-particle-system-designer": "techartist",
    "techartist-performance-profiler": "techartist",
    "techartist-shader-compiler": "techartist",
    "techartist-visual-tester": "techartist",
    "techartist-visual-validator": "techartist",
    # QA sub-agents
    "qa-browser-validator": "qa",
    "qa-code-review": "qa",
    "qa-gameplay-tester": "qa",
    "qa-multiplayer-validator": "qa",
    "qa-visual-regression-tester": "qa",
    # Game Designer sub-agents
    "gamedesigner-asset-analyst": "gamedesigner",
    "gamedesigner-gdd-documenter": "gamedesigner",
    "gamedesigner-playtest-evidence-collector": "gamedesigner",
    "gamedesigner-reference-game-researcher": "gamedesigner",
    "gamedesigner-thermite-facilitator": "gamedesigner",
    "gamedesigner-visual-reference-researcher": "gamedesigner",
}

# Utility agents (always copied regardless of enabled agents)
UTILITY_AGENTS = {
    "prd-starter.agent.md",
    "devcycle-generator.agent.md",
    "workflow-generator.agent.md",
    "template-researcher.agent.md",
}

# Agent to skill category mapping
AGENT_SKILL_CATEGORIES = {
    "pm": ["pm-"],
    "developer": ["dev-"],
    "techartist": ["ta-"],
    "qa": ["qa-"],
    "gamedesigner": ["gd-"]
}
