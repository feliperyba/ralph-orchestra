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

### Pattern for Master Branch Updates

When in a worktree, coordination files MUST be updated in the master branch.

**Use Read/Edit tools (bash-safe approach):**

```bash
# For PRD updates from worktree:
# 1. Read master branch prd.json
# 2. Use Edit tool to make changes
# 3. Edit tool handles atomic writes automatically

# Example: Update agent status
# Read("prd.json") - reads from master branch
# Edit("prd.json") - updates atomically in master branch
```

**Key point:** When using Read/Edit tools from a worktree, ensure you're accessing the master branch copy of `prd.json` for coordination updates.

### Master Branch Path Resolution

From any worktree, the master branch `prd.json` is at:

```
../agentic-threejs/prd.json  (if worktree is sibling to master)
```

Or use relative path from worktree to master root.

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
