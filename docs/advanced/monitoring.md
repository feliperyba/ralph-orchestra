# Monitoring and Troubleshooting

This guide covers monitoring Ralph Orchestra agents and resolving common issues.

## Dashboard Overview

The watchdog displays a live dashboard during operation:

```
================================================================================
  RALPH WATCHDOG V2 - Event-Driven Mode
================================================================================

  Uptime: 01:23:45  |  Events: 42  |  Tasks: 3/8

  AGENT STATUS
  --------------------------------------------------------------------------
  pm         | PID: 1234 | RUNNING | LastSeen: 12:00:00 | Restarts: 0
  developer  | PID: 5678 | RUNNING | LastSeen: 12:00:05 | Restarts: 1
  techartist | PID: 9012 | RUNNING | LastSeen: 11:59:58 | Restarts: 0
  qa         | PID: 3456 | RUNNING | LastSeen: 12:00:02 | Restarts: 0
  gamedesigner| PID: 7890 | RUNNING | LastSeen: 11:59:55 | Restarts: 0
  --------------------------------------------------------------------------

  Event Log: 156 events | Undelivered: 0
  Press Ctrl+C to stop watchdog
================================================================================
```

### Dashboard Metrics

| Metric | Description |
|--------|-------------|
| **Uptime** | Time since watchdog started |
| **Events** | Total events in event log |
| **Tasks** | Completed / Total tasks in PRD |
| **PID** | Process ID for each agent |
| **Status** | `RUNNING`, `STARTING`, `STOPPING`, `CRASHED` |
| **LastSeen** | Last heartbeat timestamp from agent |
| **Restarts** | Number of times agent was restarted |
| **Event Log** | Total events logged |
| **Undelivered** | Messages that failed delivery (retry pending) |

## Log Files

All agent output is logged to `.claude/session/logs/`:

| File | Contents |
|------|-----------|
| `pm.log` | PM agent output |
| `developer.log` | Developer agent output |
| `techartist.log` | Tech Artist agent output |
| `qa.log` | QA agent output |
| `gamedesigner.log` | Game Designer agent output |
| `watchdog-summary.log` | Session summary on exit |

### Viewing Logs

```powershell
# View agent log in real-time
Get-Content .\.claude\session\logs\developer.log -Wait -Tail 50

# View session summary
Get-Content .claude\session\logs\watchdog-summary.log
```

## Message History (Event-Driven V2)

**Note:** V2 uses the **event log** instead of message archives:

```
.claude/session/
├── eventlog.jsonl             # Append-only event log (all events)
├── agent-status.json          # Materialized view from event log
└── undelivered.jsonl          # Failed delivery queue
```

**Viewing event history:**
```powershell
# View recent events
Get-Content .\.claude\session\eventlog.jsonl -Tail 20 | ForEach-Object {
    $_ | ConvertFrom-Json | Select-Object type, timestamp, from, to
}

# Filter by message type
Get-Content .\.claude\session\eventlog.jsonl | Select-String "MessageSent" | ConvertFrom-Json
```

**Event format:**
```json
{
  "seq": 42,
  "type": "MessageSent",
  "timestamp": "2025-01-25T12:00:00Z",
  "data": {
    "from": "pm",
    "to": "developer",
    "messageId": "msg-xxx"
  }
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
   Get-Content .claude\session\logs\watchdog-summary.log
   ```

### Agents Stop Working (Event-Driven V2)

**Symptoms:** Worker or coordinator stops working after completing N tasks.

**Solutions:**

1. **Check YAML frontmatter** in skill files has `category` field:
   ```yaml
   ---
   name: my-skill
   description: My skill
   category: domain  # REQUIRED
   ---
   ```

2. **Verify stop-hook** returns exit code 42:
   ```powershell
   # Check .claude/hooks/stop-hook.ps1
   # Should exit with code 42 to keep agent running
   ```

3. **Check terminal** for error messages

4. **Check undelivered queue** (event-driven):
   ```powershell
   Get-Content .\.claude\session\undelivered.jsonl
   ```

5. **Check agent status** via event log:
   ```powershell
   Get-Content .\.claude\session\agent-status.json | ConvertFrom-Json
   ```

**Note:** Polling mode is deprecated. Use event-driven V2 or sequential mode instead.

### Named Pipe Issues (V2)

**Symptoms:** Messages not delivering, agents not receiving tasks.

**Solutions:**

1. **Check named pipe endpoints exist:**
   ```powershell
   ls .\.claude\session\pipes\
   ```

2. **Verify watchdog V2 is running** - Named pipes are created by ActorSupervisor

3. **Check undelivered queue** - Failed deliveries are queued here:
   ```powershell
   Get-Content .\.claude\session\undelivered.jsonl
   ```

4. **Check pipe connectivity** - Watchdog V2 automatically retries undelivered messages

5. **Restart session** - Named pipe issues are usually resolved by restarting

**V2 Note:** The event-bus.ps1 handles pipe failures gracefully by queuing to undelivered.jsonl and automatically retrying.

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
   Get-Content .claude\session\context-reset-count.txt
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

### Session Files Not Found (V2)

**Symptoms:** "Session file not found" or "Waiting for coordinator..."

**Solutions:**

1. **Use launcher scripts** which auto-create session:
   ```powershell
   # Event-driven V2 (recommended)
   .\.claude\scripts\ralph-event-v2-session.ps1

   # Sequential mode
   .\.claude\scripts\ralph-single-session.ps1
   ```

2. **Create session manually** for CLI mode:
   ```powershell
   # V2 only needs the session directory
   mkdir .\.claude\session
   mkdir .\.claude\session\logs
   mkdir .\.claude\session\pipes

   # Event log and agent-status.json are auto-created by watchdog
   ```

3. **Check file permissions** on session directory

**V2 Note:** Message queue directories (`messages/pm/`, etc.) are no longer needed. V2 uses named pipes and event log instead.

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
# Event-driven V2 mode
.\.claude\scripts\ralph-event-v2-session.ps1 -Debug

# Sequential mode (no dashboard for clearer output)
.\.claude\scripts\ralph-single-session.ps1 -NoDashboard
```

## Health Checks

The watchdog V2 performs several health checks via ActorSupervisor:

| Check | Description | Failure Action |
|-------|-------------|----------------|
| **Process existence** | Agent process is running | Restart with exponential backoff |
| **Named pipe connectivity** | Pipe connection active | Queue to undelivered.jsonl |
| **Event log** | Events being written | Warning if not growing |
| **Heartbeat** | Agent heartbeat in event log | Warning if stale (>90s) |
| **Crash detection** | Abnormal process exit | Auto-restart (max 3 attempts) |

## Getting Help

If you encounter issues not covered here:

1. Check the [main README](../../README.md) for additional resources
2. Review [agent documentation](../../agents/) for agent-specific issues
3. Check [script reference](../../.claude/scripts/README.md) for script details
4. Open an issue on [GitHub](https://github.com/feliperyba/ralph-orchestra/issues)

## Further Reading

- [Getting Started](../quick-start/getting-started.md) - Installation and first run
- [Orchestration Modes](../core/orchestration-modes.md) - Mode-specific behaviors
- [Configuration](../core/configuration.md) - Settings and tuning
