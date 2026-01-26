# PowerShell Orchestration Guide

Welcome to the Ralph Orchestra PowerShell documentation. This section provides comprehensive coverage of the PowerShell scripts that form the core orchestration infrastructure for autonomous multi-agent development.

## Quick Start

**New to Ralph Orchestra?** Start with the [Architecture Overview](./powershell-architecture.md) for a complete introduction to the orchestration modes and script organization.

**Ready to run?** See the [Scripts README](../../.claude/scripts/README.md) for session launcher commands.

## Document Index

### Core Documentation

| Document | Description | Key Topics |
|----------|-------------|------------|
| **[Architecture Overview](./powershell-architecture.md)** | High-level overview of the PowerShell orchestration infrastructure | Mode comparison, script categories, component relationships, design principles |
| **[Event-Driven Mode](./powershell-event-mode.md)** | Deep dive on the recommended parallel orchestration mode | Named pipes, <10ms message delivery, agent lifecycle, health monitoring |
| **[Sequential Mode](./powershell-sequential-mode.md)** | Token-efficient single-agent orchestration mode | Handoff protocol, context passing, ~70% token savings |
| **[Message System](./powershell-messaging.md)** | Core communication infrastructure | Queue structure, message types, idempotency, pipe transport |
| **[Configuration Reference](./powershell-configuration.md)** | Centralized configuration and environment variables | Agent definitions, security features, timeouts, circuit breaker |
| **[Testing & Debugging](./powershell-testing.md)** | Test scripts and troubleshooting procedures | Test utilities, debug tools, log analysis, recovery |

## Where Should I Start?

### I'm new to Ralph Orchestra
1. Read [Architecture Overview](./powershell-architecture.md) - understand the orchestration modes
2. Read [Scripts README](../../.claude/scripts/README.md) - learn how to launch sessions
3. Choose your mode and run the session launcher

### I want to use event-driven mode (recommended)
1. Read [Event-Driven Mode](./powershell-event-mode.md) for detailed information on the architecture
2. Launch: `.\.claude\scripts\ralph-event-v2-session.ps1`

### I want to save tokens with sequential mode
1. Read [Sequential Mode](./powershell-sequential-mode.md) to understand handoffs
2. Launch: `.\.claude\scripts\ralph-single-session.ps1`

### I need to configure or customize behavior
1. Read [Configuration Reference](./powershell-configuration.md) for all environment variables
2. Set desired `RALPH_*` environment variables before launching

### Something isn't working
1. Read [Testing & Debugging](./powershell-testing.md) for troubleshooting procedures
2. Use debug scripts to diagnose issues
3. Check log files in `.claude/session/logs/`

## Mode Comparison

| Mode | Parallelism | Token Usage | Speed | Best For |
|------|-------------|-------------|-------|----------|
| **Event-Driven** | 5 agents simultaneously | Medium | Fastest (<10ms messaging) | Production, speed-critical projects |
| **Sequential** | 1 agent at a time | Low (~70% savings) | Medium (5-10s handoffs) | Token efficiency, smaller projects |
| **HITL** | 1 agent at a time | Low | Variable | Learning before going AFK |

## Related Documentation

- **[Quick Start](../quick-start/)** - Getting started guide
- **[Core - Orchestration Modes](../core/orchestration-modes.md)** - All orchestration modes explained
- **[Core - Architecture](../core/architecture.md)** - System architecture and message flow
- **[Core - Configuration](../core/configuration.md)** - PRD format and agent settings
- **[Main Documentation Index](../README.md)** - Full documentation

## Script Locations

All PowerShell scripts are located in [`.claude/scripts/`](../../.claude/scripts/):

- **Session Launchers** - `ralph-event-v2-session.ps1`, `ralph-single-session.ps1`
- **Watchdogs** - `watchdog-event-v2.ps1`, `watchdog-single.ps1`
- **Core Infrastructure** - `eventlog.ps1`, `event-bus.ps1`, `supervisor.ps1`, `agent-runtime.ps1`
- **Utilities** - `safe-file-io.ps1`, `context-manager.ps1`, `file-lock.ps1`
- **Testing** - `test-*.ps1`, `run-all-tests.ps1`
