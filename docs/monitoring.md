# Monitoring and Troubleshooting

This guide covers monitoring Ralph Orchestra agents and resolving common issues.

## Dashboard Overview

The watchdog displays a live dashboard during operation:

```
================================================================================
  RALPH WATCHDOG - Event-Driven Mode
================================================================================

  Uptime: 01:23:45  |  Messages: 42  |  Tasks: 3/8

  AGENT STATUS
  --------------------------------------------------------------------------
  pm         | PID: 1234 | RUNNING | Inbox: 2   | Processed: 15
  developer  | PID: 5678 | RUNNING | Inbox: 1   | Processed: 20
  qa         | PID: 9012 | RUNNING | Inbox: 0   | Processed: 7
  gamedesigner| PID: 3456 | RUNNING | Inbox: 0   | Processed: 3
  --------------------------------------------------------------------------

  Press Ctrl+C to stop watchdog
================================================================================
```

### Dashboard Metrics

| Metric | Description |
|--------|-------------|
| **Uptime** | Time since watchdog started |
| **Messages** | Total messages sent in event-driven mode |
| **Tasks** | Completed / Total tasks in PRD |
| **PID** | Process ID for each agent |
| **Status** | `RUNNING`, `STARTING`, `STOPPING`, `CRASHED` |
| **Inbox** | Pending messages for agent |
| **Processed** | Total messages processed by agent |

## Log Files

All agent output is logged to `.claude/session/logs/`:

| File | Contents |
|------|-----------|
| `pm.log` | PM agent output |
| `developer.log` | Developer agent output |
| `qa.log` | QA agent output |
| `gamedesigner.log` | Game Designer agent output |
| `watchdog-summary.log` | Session summary on exit |

### Viewing Logs

```powershell
# View agent log in real-time
Get-Content .\.claude\session\logs\developer.log -Wait -Tail 50

# View session summary
Get-Content .\.claude\session\logs\watchdog-summary.log
```

## Message Queue (Event-Driven Mode)

Messages are stored in per-agent folders under `.claude/session/messages/` and are removed after delivery. Processed message IDs are tracked in `.claude/session/message-state.json`.

```
.claude/session/messages/
├── pm/
├── developer/
├── qa/
├── gamedesigner/
└── techartist/
```

Each message file contains:
```json
{
  "id": "msg-xxx",
  "from": "pm",
  "to": "developer",
  "type": "task_assign",
  "payload": { ... },
  "timestamp": "2024-01-20T12:00:00Z"
}
```

## Troubleshooting

### Agents Not Switching (Sequential Mode)

**Symptoms:** Agent completes task but next agent doesn't start.

**Solutions:**

1. **Check handoff signal file:**
   ```powershell
   cat .\.claude\session\handoff-signal.json
   ```

2. **Run handoff test:**
   ```powershell
   .\.claude\scripts\test-handoff-detection.ps1 -CreateTestSignal
   ```

3. **Verify agent commands** include handoff instructions in AGENT.md

4. **Check watchdog logs:**
   ```powershell
   Get-Content .\.claude\session\logs\watchdog-summary.log
   ```

### Agents Stop Processing (Event-Driven Mode)

**Symptoms:** Worker or coordinator stops working after completing N tasks.

**Solutions:**

1. **Check message queue** for pending work:
   ```powershell
   ls .\.claude\session\messages\developer\
   ```

2. **Check pending delivery file** created by watchdog:
   ```powershell
   Get-Content .\.claude\session\pending-messages-developer.json
   ```

3. **Check watchdog logs** for restart or delivery errors:
   ```powershell
   Get-Content .\.claude\session\logs\watchdog.log -Tail 100
   ```

4. **Check terminal** for agent errors

### Context Window Overflow

**Symptoms:** Agent becomes slow, forgets previous context, gives inconsistent responses.

**Solutions:**

1. **Automatic reset** - Agents auto-reset at ~70% context capacity

2. **Manual reset** - Output in agent session:
   ```
   <promise>CONTEXT_RESET</promise>
   ```

3. **Check reset count:**
   ```powershell
   Get-Content .\.claude\session\context-reset-count.txt
   ```

4. **Use sequential mode** for lower token usage

### PowerShell Execution Policy

**Symptoms:** Scripts won't run due to execution policy.

**Solution:**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Claude CLI Not Found

**Symptoms:** `claude: command not found`

**Solution:**
```bash
# Install Claude CLI
npm install -g @anthropic-ai/claude-cli

# Verify installation
claude --version

# Authenticate
claude auth login
```

### Session Files Not Found

**Symptoms:** "Session file not found" or "Waiting for coordinator..."

**Solutions:**

1. **Use launcher scripts** which auto-create session:
   ```powershell
   .\.claude\scripts\ralph-event-session.ps1
   ```

2. **Create session manually** for CLI mode:
   ```powershell
   mkdir .\.claude\session
   mkdir .\.claude\session\messages\pm
   mkdir .\.claude\session\messages\developer
   mkdir .\.claude\session\messages\qa
   mkdir .\.claude\session\messages\gamedesigner
   ```

3. **Check file permissions** on session directory

### MCP Filesystem Path Errors

**Symptoms:** "Path not found" or filesystem MCP errors.

**Solutions:**

1. **Check `.claude/settings.{agent}.json`** has correct project paths

2. **Paths should be absolute** and point to current project:
   ```json
   {
     "mcpServers": {
       "filesystem": {
         "command": "npx",
         "args": ["-y", "@anthropic-ai/mcp-server-filesystem", "C:\\absolute\\path\\to\\project"]
       }
     }
   }
   ```

3. **Update paths** if project location changed

## Debug Mode

Enable verbose output for troubleshooting:

```powershell
# Event-driven mode
.\.claude\scripts\ralph-event-session.ps1 -Debug

# Sequential mode (no dashboard for clearer output)
.\.claude\scripts\ralph-single-session.ps1 -NoDashboard
```

## Health Checks

The watchdog performs several health checks:

| Check | Description | Failure Action |
|-------|-------------|----------------|
| **Process existence** | Agent process is running | Restart agent |
| **Log file growth** | Agent is producing output | Restart if idle |
| **Heartbeat** | Agent heartbeat in state file | Warning if stale |
| **Message queue** | Messages being processed | Alert if backing up |

## Getting Help

If you encounter issues not covered here:

1. Check the [main README](../README.md) for additional resources
2. Review [agent documentation](../agents/) for agent-specific issues
3. Check [script reference](../.claude/scripts/README.md) for script details
4. Open an issue on [GitHub](https://github.com/feliperyba/ralph-orchestra/issues)

## Further Reading

- [Getting Started](./getting-started.md) - Installation and first run
- [Orchestration Modes](./orchestration-modes.md) - Mode-specific behaviors
- [Configuration](./configuration.md) - Settings and tuning
