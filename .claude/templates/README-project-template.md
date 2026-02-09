# {project_name}

{project_description}

## Overview

{project_description_extended}

- **Category:** {project_category}
- **Tech Stack:** {tech_stack}
- **Team Size:** {team_size}

## Quick Start

### Prerequisites

{tech_prerequisites}

### Installation

```bash
{init_commands}
```

### Development

```bash
{dev_commands}
```

## Project Structure

```
{project_root}/
├── src/           # Source code
├── tests/         # Test files
├── docs/          # Documentation
├── ./.claude/        # Claude Code configuration
├── prd.json       # Project requirements
└── {config_file}  # Project config
```

## Development

### Available Agents

This project uses Ralph Orchestra with the following agents:

{agents_table}

### Ralph Commands

```bash
# Start event-driven mode (recommended)
.\.claude\scripts\ralph-event-session.ps1

# Start sequential mode (token-efficient)
.\.claude\scripts\ralph-single-session.ps1

# Start HITL mode (learning)
/ralph-hitl
```

## Documentation

{documentation_links}

## License

{license}
