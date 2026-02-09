# Ralph Watchdog Common Module
# Shared utilities for watchdog scripts (event-driven and single-agent modes)
# This module contains functions that are duplicated across watchdog files
#
# Usage: . "$PSScriptRoot\Watchdog-Common.ps1"

# Source configuration if not already loaded
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not (Get-Command "Get-RalphConfig" -ErrorAction SilentlyContinue)) {
    . "$scriptDir\ralph-config.ps1"
}

# ============================================================================
# SCRIPT STRING ESCAPING
# ============================================================================

function Get-SafeScriptString {
    <#
    .SYNOPSIS
    Escapes strings for safe embedding in generated PowerShell scripts.

    .DESCRIPTION
    Prevents command injection when generating scripts by escaping:
    - Backticks (PowerShell escape character)
    - Double quotes (string delimiters)
    - Dollar signs (variable expansion)

    .PARAMETER Value
    The string value to escape.

    .EXAMPLE
    $safePath = Get-SafeScriptString -Value "C:\Path with $paces"
    # Returns: C:\Path with `$paces
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Value
    )

    # Escape in order: backticks first, then double quotes, then dollar signs
    return $Value -replace '`', '``' -replace '"', '`"' -replace '\$', '`$'
}

# ============================================================================
# PID FILE MANAGEMENT
# ============================================================================

function Get-WatchdogPidFilePath {
    <#
    .SYNOPSIS
    Gets the path to the watchdog PID file for a session.

    .PARAMETER SessionDir
    The session directory path. If not specified, uses default location.

    .RETURNS
    The full path to the watchdog PID file.
    #>
    param(
        [string]$SessionDir = ""
    )

    if (-not $SessionDir) {
        $projectRoot = (Get-Item $scriptDir).Parent.Parent.FullName
        $paths = Get-RalphPaths -ProjectRoot $projectRoot
        $SessionDir = $paths.SessionDir
    }

    return Join-Path $SessionDir "watchdog.pid"
}

function Test-WatchdogAlreadyRunning {
    <#
    .SYNOPSIS
    Checks if another watchdog instance is already running.

    .DESCRIPTION
    Reads the PID file and checks if the process is still active.
    Returns $true if a conflicting watchdog is running.

    .PARAMETER SessionDir
    The session directory path. If not specified, uses default location.

    .RETURNS
    $true if another watchdog is running, $false otherwise.
    #>
    param(
        [string]$SessionDir = ""
    )

    $pidFile = Get-WatchdogPidFilePath -SessionDir $SessionDir

    if (-not (Test-Path $pidFile)) {
        return $false
    }

    try {
        $existingPid = [int](Get-Content $pidFile -Raw -ErrorAction Stop)
        $existingProcess = Get-Process -Id $existingPid -ErrorAction SilentlyContinue

        if ($existingProcess) {
            # Process exists - check if it's actually a PowerShell/watchdog
            if ($existingProcess.ProcessName -match 'powershell|pwsh') {
                return $true
            }
        }

        # PID file is stale - remove it
        Remove-Item $pidFile -Force -ErrorAction SilentlyContinue
        return $false
    } catch {
        # Can't parse PID file - remove it
        Remove-Item $pidFile -Force -ErrorAction SilentlyContinue
        return $false
    }
}

function Write-WatchdogPidFile {
    <#
    .SYNOPSIS
    Writes the current process ID to the watchdog PID file.

    .PARAMETER SessionDir
    The session directory path. If not specified, uses default location.
    #>
    param(
        [string]$SessionDir = ""
    )

    $pidFile = Get-WatchdogPidFilePath -SessionDir $SessionDir

    try {
        $PID | Out-File -FilePath $pidFile -Encoding utf8 -Force
    } catch {
        Write-RalphLog "Failed to write PID file: $_" -Level "WARN" -Color Yellow
    }
}

function Remove-WatchdogPidFile {
    <#
    .SYNOPSIS
    Removes the watchdog PID file.

    .PARAMETER SessionDir
    The session directory path. If not specified, uses default location.
    #>
    param(
        [string]$SessionDir = ""
    )

    $pidFile = Get-WatchdogPidFilePath -SessionDir $SessionDir
    if (Test-Path $pidFile) {
        Remove-Item $pidFile -Force -ErrorAction SilentlyContinue
    }
}

# ============================================================================
# PROCESS MANAGEMENT
# ============================================================================

function Stop-ProcessTree {
    <#
    .SYNOPSIS
    Stops a process and all its child processes.

    .DESCRIPTION
    Gracefully terminates a process tree by killing child processes
    before terminating the parent process.

    .PARAMETER Process
    The System.Diagnostics.Process object to stop.

    .PARAMETER TimeoutMs
    Maximum time to wait for graceful termination (default: 5000ms).

    .EXAMPLE
    $proc = Get-Process -Id 1234
    Stop-ProcessTree -Process $proc -TimeoutMs 10000
    #>
    param(
        [Parameter(Mandatory=$true)]
        [System.Diagnostics.Process]$Process,

        [int]$TimeoutMs = 5000
    )

    if ($Process.HasExited) {
        return
    }

    try {
        # Kill child processes first
        $parentPid = $Process.Id
        Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
            Where-Object { $_.ParentProcessId -eq $parentPid } |
            ForEach-Object {
                try {
                    Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
                } catch {
                    # Child already gone
                }
            }

        # Kill the parent process
        $Process.Kill()
        $Process.WaitForExit($TimeoutMs) | Out-Null
    } catch {
        # Process may already be gone
    }
}

# ============================================================================
# EXPORTED FUNCTIONS (when dot-sourced, all functions are available)
# ============================================================================
# Get-SafeScriptString
# Get-WatchdogPidFilePath
# Test-WatchdogAlreadyRunning
# Write-WatchdogPidFile
# Remove-WatchdogPidFile
# Stop-ProcessTree
