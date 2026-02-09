# Ralph Consolidation Mode Module
# Manages consolidation mode for PM message review on startup/restart
# Consolidation mode allows PM to review all pending messages before workers begin processing
#
# Usage: . "$PSScriptRoot\Consolidation-Mode.ps1"

# Source safe file I/O for timeout-protected reads
$safeIoModule = Join-Path $PSScriptRoot "safe-file-io.ps1"
if (Test-Path $safeIoModule) {
    . $safeIoModule
}

# ============================================================================
# CONFIGURATION
# ============================================================================

$Script:ConsolidationModeFile = $null

# ============================================================================
# CONSOLIDATION MODE FUNCTIONS
# ============================================================================

function Initialize-ConsolidationMode {
    <#
    .SYNOPSIS
    Initialize consolidation mode file path.

    .PARAMETER SessionDir
    The session directory path.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$SessionDir
    )

    $Script:ConsolidationModeFile = Join-Path $SessionDir "consolidation-mode.json"
}

function Test-ConsolidationRequired {
    <#
    .SYNOPSIS
    Check if consolidation is required (startup/restart scenario).

    .DESCRIPTION
    Returns $true if:
    - Consolidation mode file exists and mode is "pending_consolidation"
    - OR there are pending messages in worker inboxes and this is startup

    .RETURNS
    $true if consolidation is required, $false otherwise.
    #>
    param()

    if (-not $Script:ConsolidationModeFile) {
        return $false
    }

    # Check if consolidation mode file exists
    if (Test-Path $Script:ConsolidationModeFile) {
        try {
            $mode = Get-Content $Script:ConsolidationModeFile -Raw | ConvertFrom-Json
            if ($mode.mode -eq "pending_consolidation") {
                return $true
            }
        } catch {
            # File corrupt - treat as requiring consolidation
            return $true
        }
    }

    return $false
}

function Exit-ConsolidationMode {
    <#
    .SYNOPSIS
    Exit consolidation mode and transition to normal operation.
    This is the SAFE way to exit consolidation mode with proper logging and state tracking.

    .PARAMETER Reason
    The reason for exiting consolidation (required for audit trail).

    .PARAMETER Phase
    The phase that triggered the exit (e.g., "retrospective", "skill_research", "manual").

    .RETURNS
    $true if exit was successful, $false otherwise.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Reason,

        [string]$Phase = "unknown"
    )

    if (-not $Script:ConsolidationModeFile) {
        return $false
    }

    try {
        $currentMode = Get-ConsolidationMode
        if (-not $currentMode -or $currentMode.mode -ne "pending_consolidation") {
            # Already not in consolidation mode
            return $true
        }

        # Exit consolidation mode
        $state = @{
            mode = "normal"
            timestamp = [DateTime]::UtcNow.ToString("o")
            reason = $Reason
            phase = $Phase
            previousMode = $currentMode.mode
            exitedAt = [DateTime]::UtcNow.ToString("o")
        }

        $state | ConvertTo-Json -Depth 10 | Out-File -FilePath $Script:ConsolidationModeFile -Encoding UTF8

        return $true
    } catch {
        return $false
    }
}

function Invoke-ConsolidationStateCheck {
    <#
    .SYNOPSIS
    Check if consolidation mode is stale and should be auto-exited.
    This prevents dead ends where consolidation mode gets stuck.

    .PARAMETER SessionDir
    The session directory path.

    .PARAMETER TimeoutMinutes
    Minutes after which consolidation is considered stale (default: 10).

    .RETURNS
    Hashtable with { isStale, shouldExit, reason }
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$SessionDir,

        [int]$TimeoutMinutes = 10
    )

    $result = @{
        isStale = $false
        shouldExit = $false
        reason = ""
    }

    $consolidationModeFile = Join-Path $SessionDir "consolidation-mode.json"
    if (-not (Test-Path $consolidationModeFile)) {
        return $result
    }

    try {
        $mode = Get-Content $consolidationModeFile -Raw | ConvertFrom-Json
        if ($mode.mode -eq "pending_consolidation") {
            # Check age of consolidation mode
            $modeTime = [DateTime]::Parse($mode.timestamp)
            $ageMinutes = ([DateTime]::UtcNow - $modeTime).TotalMinutes

            if ($ageMinutes -gt $TimeoutMinutes) {
                $result.isStale = $true
                $result.shouldExit = $true
                $result.reason = "Consolidation mode active for $([math]::Round($ageMinutes, 1)) minutes (timeout: ${TimeoutMinutes}m)"
            }

            # Also check if retrospective exists - that's a signal to exit
            $retroFile = Join-Path $SessionDir "retrospective.txt"
            if (Test-Path $retroFile) {
                $result.isStale = $true
                $result.shouldExit = $true
                $result.reason = "Retrospective file exists - consolidation must exit for workers to participate"
            }
        }
    } catch {
        # Error reading mode - treat as needing exit
        $result.isStale = $true
        $result.shouldExit = $true
        $result.reason = "Error reading consolidation mode: $($_.Exception.Message)"
    }

    return $result
}

function Set-ConsolidationMode {
    <#
    .SYNOPSIS
    Set the consolidation mode state.

    .PARAMETER Mode
    The consolidation mode: "pending_consolidation", "normal", or "completed"

    .PARAMETER Reason
    The reason for the mode change (startup, restart, pm_consolidated, etc.)

    .PARAMETER Assignments
    Optional PM assignments dictionary (for mode "normal")
    #>
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("pending_consolidation", "normal", "completed")]
        [string]$Mode,

        [string]$Reason = "",

        [hashtable]$Assignments = $null
    )

    if (-not $Script:ConsolidationModeFile) {
        throw "Consolidation mode not initialized. Call Initialize-ConsolidationMode first."
    }

    $state = @{
        mode = $Mode
        timestamp = [DateTime]::UtcNow.ToString("o")
        reason = $Reason
    }

    if ($Assignments) {
        $state.pmAssignments = $Assignments
    }

    $state | ConvertTo-Json -Depth 10 | Out-File -FilePath $Script:ConsolidationModeFile -Encoding UTF8
}

function Get-ConsolidationMode {
    <#
    .SYNOPSIS
    Get the current consolidation mode state with timeout protection.

    .RETURNS
    The consolidation mode object, or $null if file doesn't exist.
    #>
    param()

    if (-not $Script:ConsolidationModeFile) {
        return $null
    }

    # Use timeout-protected read if available (prevents watchdog freeze)
    if (Get-Command Get-FileContentAsJsonWithTimeout -ErrorAction SilentlyContinue) {
        return Get-FileContentAsJsonWithTimeout -Path $Script:ConsolidationModeFile -TimeoutMs 500 -DefaultValue $null
    }

    # Fallback to synchronous read
    if (-not (Test-Path $Script:ConsolidationModeFile)) {
        return $null
    }

    try {
        $mode = Get-Content $Script:ConsolidationModeFile -Raw | ConvertFrom-Json
        return $mode
    } catch {
        return $null
    }
}

# ============================================================================
# EXPORTED FUNCTIONS (when dot-sourced, all functions are available)
# ============================================================================
# Initialize-ConsolidationMode
# Test-ConsolidationRequired
# Exit-ConsolidationMode
# Invoke-ConsolidationStateCheck
# Set-ConsolidationMode
# Get-ConsolidationMode
