---
name: auxiliary-scripts
description: Auxiliary script management rules for Ralph agents
category: orchestration
keywords: [auxiliary, scripts, automation, session, cleanup, reusable]
---

# Auxiliary Script Management

> "Auxiliary scripts in `.claude/session/` help with automation and cleanup. Session state is stored in `prd.json.session`, agent status in `prd.json.agents`."

## Script Classification

Scripts created in `.claude/session/` are automatically classified:

| Classification | Pattern | Retention |
|---------------|--------|-----------|
| **Temporary** | `*-runner.ps1`, `msg-*-*.json`, `*.exit`, `restart-flag-*.json`, `*.tmp` | Auto-deleted after 1 hour |
| **Reusable** | Documented below | Persist across sessions |
| **Unknown** | Everything else | Manual cleanup required |

## Temporary Scripts

Auto-cleaned after 1 hour:

- `*-runner.ps1` - Agent runner scripts
- `msg-*-*.json` - Individual message files (format: `msg-{agent}-{timestamp}-{seq}.json`)
- `*.exit` - Agent exit status files
- `restart-flag-*.json` - Restart signal files
- `*.tmp` - Temporary files

**Do NOT rely on these persisting.** They will be automatically deleted.

## Creating Reusable Scripts

If you create a helper script that provides value across multiple sessions:

1. **Document it** in the "Reusable Scripts" section of your AGENT.md
2. **Use descriptive naming**: `{agent}-{purpose}.ps1`
3. **Add to `AuxiliaryScripts.Reusable`** in `ralph-config.ps1`
4. **Explain its purpose** so future sessions understand its value

### Reusable Scripts Template

```powershell
# Script: {AGENT}-{PURPOSE}.ps1
# Purpose: {Brief description}
# Created: {DATE}
# Used by: {Which agents use this}

param(
    [Parameter(Mandatory=$false)]
    [string]$SomeParameter
)

# Script logic here
```

### Adding to ralph-config.ps1

```powershell
$Script:AuxiliaryScripts.Reusable = @{
    "{AGENT}-{PURPOSE}.ps1" = @{
        Purpose = "Brief description"
        Created = "2026-01-19"
        UsedBy = @("pm", "developer")
    }
}
```

## Documentation in AGENT.md

Maintain a "Reusable Scripts" section in your AGENT.md:

| Script | Purpose | Usage |
|--------|---------|-------|
| *(none yet)* | | |

Update this table when creating new reusable scripts.

## Cleanup Guidelines

### When Deleting Scripts

1. **Check if active** - ensure no agent is currently using it
2. **Check dependencies** - ensure no other scripts depend on it
3. **Document removal** - add note to progress file if significant

### When Keeping Scripts

1. **Document purpose** - add comment header explaining what it does
2. **Date stamp** - include creation date
3. **Version** - if modified, track version changes

## Common Script Patterns

### Message Delivery Script

```powershell
# Used by watchdog to deliver messages to agents
param([string]$TargetAgent, [string]$MessagePath)

$message = Get-Content $MessagePath | ConvertFrom-Json
$inbox = ".claude/session/messages/$TargetAgent/"
# Use the message's existing ID (from JSON content) for filename
$destPath = Join-Path $inbox "$($message.id).json"
Copy-Item $MessagePath $destPath
```

### Health Check Script

```powershell
# Used to check if agent is responsive
param([string]$AgentName)

$prdFile = "prd.json"
$prd = Get-Content $prdFile | ConvertFrom-Json
$lastSeen = [DateTime]::Parse($prd.agents.$AgentName.lastSeen)
$age = (Get-Date) - $lastSeen

if ($age.TotalSeconds -gt 60) {
    Write-Warning "Agent $AgentName unresponsive for $($age.TotalSeconds)s"
    return $false
}
return $true
```

## Script Permissions

- All scripts in `.claude/session/` should be executable by agents
- Never create scripts that modify source code without explicit task assignment
- Scripts should only update session files or state files

## Reference

- [file-permissions.md](file-permissions.md) — What agents can write to
- [context-management.md](context-management.md) — Context reset procedures
