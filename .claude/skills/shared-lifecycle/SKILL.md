---
name: shared-lifecycle
description: Process lifecycle management and auxiliary script rules for Ralph agents
category: orchestration
keywords: [process, cleanup, registry, scripts, lifecycle, background]
---

# Shared Lifecycle

> "Cleanup after yourself. Don't leave processes running when you exit."

---

## Process Management Golden Rules

1. **Check** the process registry before starting a process
2. **Register** processes you start
3. **Cleanup** your processes when done
4. **Never** start a duplicate process if one is running
5. **Never** leave background processes running when you exit

---

## Process Registry

**Location:** `.claude/session/process-registry.json`

The registry tracks all running processes across all agents.

**Format:**

```json
{
  "version": "1.0",
  "lastUpdated": "2026-01-26T10:00:00Z",
  "processes": {
    "dev-server-3000": {
      "name": "dev-server",
      "port": 3000,
      "pid": 12345,
      "agent": "qa",
      "startedAt": "2026-01-26T09:55:00Z",
      "command": "npm run dev",
      "status": "running",
      "purpose": "browser-validation"
    }
  },
  "agents": {
    "qa": ["dev-server-3000"],
    "developer": [],
    "pm": []
  }
}
```

### Using Read/Write Tools

**Check registry:**
```
Read: .claude/session/process-registry.json
```

**Update registry:**
```
Edit: .claude/session/process-registry.json
```

---

## Background Process Management

### Starting Background Processes

**Using Bash tool with `run_in_background=true`:**

```bash
# Start dev server in background
Bash(command="npm run dev", run_in_background=true)
# Returns: { shell_id: "abc123" }
```

**Capture the `shell_id`** — you need it for cleanup!

### Checking Port Availability

Before starting a process that binds to a port:

```bash
# Check if port is in use
Bash(command="netstat -an | grep :3000 || echo 'Port 3000 available'")
```

### Cleanup is MANDATORY

**Before updating status to "idle" or reporting task complete:**

```bash
# Kill the background process using shell_id
TaskStop(task_id="abc123")
```

### Cleanup Checklist

**CRITICAL: Always stop background processes before exit**

- [ ] Kill ALL background processes (use TaskStop with shell_id)
- [ ] Process registry updated (processes removed from agent's list)
- [ ] Ports are released (verify with netstat/lsof)
- [ ] No orphaned node/npm processes remain

---

## Cleanup Pattern (Even on Failure)

**Always cleanup in a finally pattern:**

```
1. Start background process (capture shell_id)
2. Try:
   - Do the work
3. Finally:
   - Stop background process (TaskStop with shell_id)
   - Update process registry
4. Only THEN: Update task status
```

**Anti-pattern:** ❌ Exiting without stopping background processes
**Good pattern:** ✅ Always cleanup, even if work fails

---

## Agent-Specific Rules

### QA Agent

| Process | Reuse? | Cleanup Timing |
|---------|--------|----------------|
| dev-server (3000) | Yes | After ALL validation complete |
| test-server (varies) | No | After tests |
| test-watcher | Yes | After test loop |

**Cleanup:** AFTER all tests complete, BEFORE reporting results (pass OR fail)

### Developer Agent

| Process | Reuse? | Cleanup Timing |
|---------|--------|----------------|
| build-watcher | Yes | After commit |
| dev-server | No | Immediately after testing |

**Cleanup:** BEFORE marking task complete or sending to PM

### PM Agent

- Usually doesn't start processes
- If starting research server: cleanup after research

---

## Common Process Types

| Type | Port | Reuse? | Cleanup |
|------|------|--------|---------|
| dev-server | 3000 | Yes | After validation |
| test-server | varies | No | After tests |
| build-watcher | N/A | Yes | After commit |
| storybook | 6006 | Yes | After review |

---

## Auxiliary Scripts

Scripts in `.claude/session/` help with automation and cleanup.

### Script Classification

| Classification | Pattern | Retention |
|---------------|--------|-----------|
| **Temporary** | `*-runner.ps1`, `msg-*.json`, `*.exit`, `*.tmp` | Auto-delete after 1 hour |
| **Reusable** | Documented below | Persist across sessions |
| **Unknown** | Everything else | Manual cleanup |

### Temporary Scripts

**Auto-cleaned after 1 hour:**
- `*-runner.ps1` — Agent runner scripts
- `msg-*.json` — Message files
- `*.exit` — Exit status files
- `*.tmp` — Temporary files

**Do NOT rely on these persisting.**

### Creating Reusable Scripts

If you create a helper script that provides value:

1. **Document purpose** — Add comment header
2. **Use descriptive naming** — `{agent}-{purpose}.ps1`
3. **Track usage** — Note which agents use it
4. **Explain value** — Future sessions should understand why it exists

**Template:**

```powershell
# Script: {AGENT}-{PURPOSE}.ps1
# Purpose: {Brief description}
# Created: {DATE}
# Used by: {Which agents}

param([string]$SomeParameter)

# Script logic here
```

### Documentation in AGENT.md

Maintain a "Reusable Scripts" section:

| Script | Purpose | Usage |
|--------|---------|-------|
| *(none yet)* | | |

---

## Script Permissions

- Scripts in `.claude/session/` executable by all agents
- Never create scripts that modify source code without explicit task
- Scripts should only update session files or state files

---

## Verification Commands

### Check Process Registry

```
Read: .claude/session/process-registry.json
```

### Check Port Usage

```bash
# Windows
netstat -an | findstr :3000

# Linux/macOS
lsof -i :3000
```

### Check for Orphaned Processes

```bash
# Check for node processes
ps aux | grep node  # Linux/macOS
Get-Process node    # Windows PowerShell
```

---

## Anti-Patterns

| Don't | Do Instead |
|-------|------------|
| Start background processes without tracking | Capture shell_id, use for cleanup |
| Leave processes running after exit | Always cleanup before status update |
| Start same process multiple times | Check registry first |
| Assume someone else will cleanup | Cleanup your own processes |
| Use PowerShell Get-Content/Set-Content | Use Read/Write tools |
| Use manual temp file pattern | Use Edit tool |

---

## Complete Example: QA Validation

```
1. Check process registry:
   Read: .claude/session/process-registry.json

2. Start dev server if needed:
   Bash(command="npm run dev", run_in_background=true)
   Capture: shell_id = "abc123"

3. Update registry:
   Edit: .claude/session/process-registry.json
   Add: {"dev-server-3000": {...}}

4. Run validation:
   npm run type-check
   npm run lint
   npm run test
   npm run build

5. Cleanup (MANDATORY):
   TaskStop(task_id="abc123")
   Edit: .claude/session/process-registry.json
   Remove: dev-server-3000 from processes

6. Only THEN: Update task status
   Edit: prd.json.agents.qa.status = "idle"
```

---

## References

- `shared-state` — File ownership, atomic updates (Edit tool)
- `shared-core` — Session structure
- `shared-messaging` — Message queue management
