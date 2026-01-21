# Configuration

This guide covers all aspects of configuring Ralph Orchestra, including the PRD format, max iterations, agent settings, and watchdog options.

## PRD Format

The Product Requirements Document (prd.json) defines all tasks for agents to work on.

### PRD Structure

```json
{
  "project": "my-project",
  "version": "1.0.0",
  "lastUpdated": "2024-01-20",
  "quality": "production",
  "description": "Brief project description",
  "feedbackLoops": {
    "typescript": {
      "command": "npm run type-check",
      "required": true,
      "description": "TypeScript compilation must pass"
    },
    "lint": {
      "command": "npm run lint",
      "required": true,
      "description": "ESLint must pass"
    },
    "test": {
      "command": "npm run test",
      "required": true,
      "description": "All tests must pass"
    },
    "build": {
      "command": "npm run build",
      "required": true,
      "description": "Production build must succeed"
    }
  },
  "qualityStandards": {
    "typeSafety": "strict - no 'any' types without justification",
    "testCoverage": "80% minimum for new code",
    "documentation": "Required for complex logic",
    "commitStyle": "Conventional commits with Ralph prefix",
    "codeReview": "All code must pass feedback loops"
  },
  "items": [
    {
      "id": "feat-001",
      "category": "architectural",
      "priority": "high",
      "title": "Feature Title",
      "description": "Detailed description of what needs to be done",
      "acceptanceCriteria": [
        "First criterion that must be met",
        "Second criterion that must be met"
      ],
      "verificationSteps": [
        "Step 1 to verify",
        "Step 2 to verify"
      ],
      "files": ["path/to/file1.ts", "path/to/file2.ts"],
      "agent": "developer",
      "dependencies": ["feat-000"],
      "notes": "Additional context or warnings"
    }
  ]
}
```

### Task Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | Yes | Unique identifier (e.g., `feat-001`, `iter1-001`) |
| `category` | string | No | `architectural`, `functional`, `integration`, `polish` |
| `priority` | string | No | `high`, `medium`, `low` |
| `title` | string | Yes | Human-readable task name |
| `description` | string | Yes | Detailed task description |
| `acceptanceCriteria` | array | Yes | List of pass/fail criteria |
| `verificationSteps` | array | No | Steps QA should use to verify |
| `files` | array | No | Files this task affects |
| `agent` | string | No | Target agent: `developer`, `qa`, `gamedesigner` |
| `dependencies` | array | No | Task IDs that must complete first |
| `notes` | string | No | Additional context |
| `status` | string | No | `pending`, `in_progress`, `ready_for_qa`, `passed`, `failed` |
| `passes` | boolean | Yes | `false` = needs work, `true` = completed |

### Task Status Flow

```
pending → in_progress → ready_for_qa → passed
                    ↓
                  failed → in_progress
```

### Best Practices

1. **Keep tasks focused** - Each task should be completable in one iteration
2. **Clear acceptance criteria** - Each criterion should be objectively verifiable
3. **Specify the agent** - Use the `agent` field to direct tasks
4. **Use dependencies** - Link related tasks with `dependencies` array
5. **Add verification steps** - Help QA understand how to validate

## Max Iterations

**One iteration = one complete development cycle (PM→Dev→QA→PM)**

Agents stop when **EITHER**:
1. All PRD tasks have `passes: true` → Normal completion
2. Max iterations reached → Status = `max_iterations_reached`

### Setting Max Iterations

#### Method 1: Environment Variable (Recommended)

```powershell
# Set for current session
$env:RALPH_MAX_ITERATIONS = 100
.\.claude\scripts\ralph-event-session.ps1

# Set permanently (system-wide)
[System.Environment]::SetEnvironmentVariable('RALPH_MAX_ITERATIONS', '100', 'User')
```

#### Method 2: Script Parameter

```powershell
# Event-driven mode
.\.claude\scripts\ralph-event-session.ps1 -MaxIterations 50

# Sequential mode
.\.claude\scripts\ralph-single-session.ps1 -MaxIterations 50

# Polling mode
.\.claude\scripts\ralph-multi-session.ps1 -MaxIterations 50
```

#### Method 3: Edit Configuration Default

Edit `.claude/scripts/ralph-config.ps1`:

```powershell
MaxIterations = Get-EnvInt -Name "RALPH_MAX_ITERATIONS" -Default 100
```

### Default Values

| Configuration | Default Value |
|---------------|---------------|
| Config file | 200 iterations |
| Environment variable | `RALPH_MAX_ITERATIONS` |
| Script parameter | Overrides env var |
| Hardcoded fallback | 50 iterations |

### Monitoring Iteration Progress

```powershell
Get-Content .claude\session\coordinator-state.json | ConvertFrom-Json
```

```json
{
  "maxIterations": 200,
  "iteration": 5,
  "status": "running"
}
```

## Agent Settings

Each agent can have custom Claude CLI settings in `.claude/settings.{agent}.json`:

```json
{
  "model": "claude-sonnet-4-20250514",
  "permissions": {
    "allow": ["Read", "Write", "Edit", "Bash"],
    "deny": []
  },
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@anthropic-ai/mcp-server-filesystem", "C:\\path\\to\\project"]
    },
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"]
    }
  }
}
```

### Per-Agent MCP Servers

| Agent | Typical MCP Servers |
|-------|---------------------|
| PM | GitHub, web-search, filesystem |
| Developer | GitHub, filesystem, web-search, brave-search |
| QA | Playwright, filesystem, GitHub |
| Game Designer | GitHub, filesystem, web-search |

## Watchdog Configuration

### Sequential Mode Parameters

```powershell
.\.claude\scripts\ralph-single-session.ps1 `
    -InitialAgent "pm" `           # Start with PM (default)
    -GracefulShutdownSeconds 30 `  # Wait time before force-kill
    -MaxRestarts 3 `               # Retries before longer wait
    -NoDashboard                   # Disable live dashboard
```

### Event-Driven Mode Parameters

```powershell
.\.claude\scripts\ralph-event-session.ps1 `
    -NoDashboard `                 # Disable live dashboard
    -Debug `                       # Enable verbose output
    -ProjectRoot "C:\path"         # Custom project root
```

### Polling Mode Parameters

```powershell
.\.claude\scripts\ralph-multi-session.ps1 `
    -IdleTimeoutSeconds 120 `      # Restart if no activity
    -CheckIntervalMs 2000 `        # Health check frequency
    -Agents "pm","developer","qa" `  # Which agents to run
    -Wait                          # Wait for completion
```

### Configuration File

Edit `.claude/scripts/ralph-config.ps1` to change defaults:

```powershell
$Script:AgentConfig = @{
    "pm" = @{
        Type = "coordinator"
        Command = "/ralph-coordinator-event"
        DisplayName = "PM (Coordinator)"
        Color = "Magenta"
    }
    "developer" = @{
        Type = "worker"
        Command = "/ralph-worker-event --agent developer"
        DisplayName = "Developer"
        Color = "Cyan"
    }
    # Add more agents here...
}

$Script:DefaultConfig = @{
    IdleTimeoutSeconds = 120
    StartupGraceSeconds = 60
    CheckIntervalMs = 2000
    MaxRestarts = 5
}
```

## Environment Variables

| Variable | Purpose | Default |
|----------|---------|---------|
| `RALPH_MAX_ITERATIONS` | Maximum iterations | 200 |
| `RALPH_PROJECT_ROOT` | Project directory | Auto-detected |

## Quality Standards

All Ralph work follows these production standards:

- **No `any` types** without justification
- **80% test coverage** minimum for new code
- **Documentation** for complex logic, public APIs
- **Conventional commits** with "Ralph" prefix
- **All feedback loops must pass** (type-check, lint, test, build)

## Further Reading

- [Getting Started](./getting-started.md) - Installation and first run
- [Architecture](./architecture.md) - System architecture overview
- [Extending](./extending.md) - Adding custom agents and skills
