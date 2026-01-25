---
name: atomic-updates
description: Atomic file update patterns to prevent corruption
category: orchestration
keywords: [atomic, update, file-lock, temp-file, corruption, concurrent, write]
---

# Atomic Updates

> "Read-modify-write with temp file - prevents corruption from concurrent writes."

## The Problem

If two agents write to the same file simultaneously, data can be lost or corrupted.

## The Solution: Atomic Updates

Always update files using the temp-file pattern:

```bash
# Read
STATE=$(cat file.json)

# Modify
NEW_STATE=$(echo "$STATE" | jq '.field = "value"')

# Write atomically
echo "$NEW_STATE" > file.json.tmp && mv file.json.tmp file.json
```

The `mv` command is atomic on Unix-like systems - either the whole rename succeeds or it fails, never leaving a partial file.

## PowerShell Atomic Update

```powershell
# Read
$state = Get-Content "file.json" | ConvertFrom-Json

# Modify
state.field = "value"

# Write atomically
$tempPath = "file.json.tmp"
$state | ConvertTo-Json -Depth 10 | Set-Content -Path $tempPath
Move-Item -Path $tempPath -Destination "file.json" -Force
```

## Master Branch Coordination (CRITICAL)

**When working in a git worktree, ALL coordination files must be updated in the master branch.**

The worktree system uses isolated branches for code/assets, but ALL state coordination must happen in the master branch. This ensures:
- PM can see worker status updates immediately
- Watchdog can monitor agent heartbeats
- Message queue works for all agents
- No merge required for coordination visibility

### What Goes to Master Branch

| File/Directory | Purpose | Who Updates |
|----------------|---------|-------------|
| `prd.json` | Task status, agent status, session state | All agents |
| `.claude/session/messages/` | Event queue for inter-agent communication | All agents |
| `.claude/session/*.json` | State files, progress tracking | All agents |

### What Goes to Worktree Branch

| Directory | Purpose | Who Updates |
|-----------|---------|-------------|
| `src/` | Code changes | Developer |
| `src/assets/` | Asset changes | TechArtist |

### PowerShell Pattern for Master Branch Updates

When in a worktree, use the path resolution helpers from `ralph-config.ps1`:

```powershell
# Source ralph-config for path helpers (do this once at startup)
. .\.claude\scripts\ralph-config.ps1

# Get master paths - these work from ANY directory
$masterPrdPath = Get-MasterPrdPath
$masterSessionPath = Get-MasterSessionPath

# Update PRD atomically in master branch
$prd = Get-Content $masterPrdPath -Raw | ConvertFrom-Json
$prd.agents.developer.status = "working"
$prd.agents.developer.lastSeen = [DateTime]::UtcNow.ToString("o")
$prd | ConvertTo-Json -Depth 10 | Set-Content -Path "$masterPrdPath.tmp"
Move-Item -Path "$masterPrdPath.tmp" -Destination $masterPrdPath -Force
```

### Helper Functions

Available after sourcing `ralph-config.ps1`:

| Function | Returns |
|----------|---------|
| `Get-MasterRootPath` | Master branch root directory |
| `Get-MasterPrdPath` | Path to `prd.json` in master |
| `Get-MasterSessionPath` | Path to `.claude/session` in master |
| `Get-MasterMessageQueuePath` | Path to `.claude/session/messages` in master |

### Example: Worker Updates Master PRD from Worktree

```powershell
# From developer-worktree, update master PRD
. .\..\.claude\scripts\ralph-config.ps1

$masterPrdPath = Get-MasterPrdPath
$prd = Get-Content $masterPrdPath -Raw | ConvertFrom-Json

# Update task status
$prd.items | Where-Object { $_.id -eq "feat-001" } | ForEach-Object {
    $_.status = "in_progress"
}

# Update agent heartbeat
$prd.agents.developer.status = "working"
$prd.agents.developer.lastSeen = [DateTime]::UtcNow.ToString("o")

# Atomic write to master
$prd | ConvertTo-Json -Depth 10 | Out-File -FilePath "$masterPrdPath.tmp" -Encoding UTF8
Move-Item -Path "$masterPrdPath.tmp" -Destination $masterPrdPath -Force
```

## Update Specific Field (jq)

```bash
# Single field update in prd.json
jq '.session.iteration += 1' prd.json > prd.json.tmp
mv prd.json.tmp prd.json

# Nested field update - agent status
jq '.agents.developer.lastSeen = "2026-01-19T12:00:00Z"' prd.json > prd.json.tmp
mv prd.json.tmp prd.json

# Task status update
jq '.items[0].status = "in_progress"' prd.json > prd.json.tmp
mv prd.json.tmp prd.json
```

## PowerShell Update-JsonFile (if available)

If the project provides `Update-JsonFile`:

```powershell
Update-JsonFile -FilePath "file.json" -UpdateScript {
    param($state)
    $state.field = "value"
    return $state
}
```

This wrapper handles the atomic pattern automatically.

## Error Handling

If atomic update fails:

1. **Log the error** - write to progress file
2. **Wait 5 seconds** - give other processes time to complete
3. **Re-read the file** - get latest state
4. **Re-apply changes** - merge your updates
5. **Try again** - attempt atomic update once more

If it fails twice, log the conflict and continue polling.

## When Atomic Updates Matter Most

- **High-contention files**: `prd.json` (session state, agent status, task items)
- **Shared log files**: `session.log` (use append-only instead)
- **PRD file**: Multiple agents may update different fields

## When Atomic Updates Don't Apply

- **Agent-specific files**: `developer-progress.txt` (only one writer)
- **Append-only logs**: These don't need atomic pattern
- **New file creation**: No existing content to protect

## Reference

- [file-permissions.md](file-permissions.md) — Who can write to what
