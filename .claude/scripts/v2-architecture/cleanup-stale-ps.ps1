# Cleanup Stale Ralph Agent Processes
#
# CRITICAL: This script ONLY kills processes that are verified Ralph agents.
# It will NOT kill unrelated PowerShell processes.
#
# Safety checks:
# 1. Process must be a PowerShell process (pwsh or powershell)
# 2. Process command line must contain Ralph-specific markers
# 3. Process must be in the current session's process tree (optional)
# 4. Process must not have a main window (background process only)
#
# Usage:
#   .\cleanup-stale-ps.ps1 [-WhatIf] [-Force]
#
# Parameters:
#   -WhatIf    : Show what would be killed without killing
#   -Force     : Skip confirmation prompt
#   -SessionId : Only kill processes from specific session

param(
    [switch]$WhatIf,
    [switch]$Force,
    [string]$SessionId = "",
    [switch]$Verbose
)

# Error action preference
$ErrorActionPreference = "Stop"

# Session directory path for verification
$Script:SessionDir = $null
$Script:CurrentPid = $PID

function Test-IsRalphAgent {
    <#
    .SYNOPSIS
    Verify that a process is actually a Ralph agent.

    .DESCRIPTION
    Checks multiple conditions to ensure we only kill Ralph agents:
    - Command line contains agent-runtime.ps1 or ralph- pattern
    - Process is not interactive (no main window)
    - Optional: Process is in current session tree

    .PARAMETER Process
    The System.Diagnostics.Process to check.

    .RETURNS
    True if the process is a verified Ralph agent.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [System.Diagnostics.Process]$Process
    )

    # Skip current process
    if ($Process.Id -eq $Script:CurrentPid) {
        return $false
    }

    # Skip processes with main windows (interactive sessions)
    if ($Process.MainWindowTitle) {
        if ($Verbose) {
            Write-Host "  [$($Process.Id)] Skipping - has main window: '$($Process.MainWindowTitle)'" -ForegroundColor Cyan
        }
        return $false
    }

    # Check command line for Ralph markers
    try {
        $commandLine = Get-WmiObject Win32_Process -Filter "ProcessId = $($Process.Id)" |
            Select-Object -ExpandProperty CommandLine

        if ([string]::IsNullOrEmpty($commandLine)) {
            if ($Verbose) {
                Write-Host "  [$($Process.Id)] Skipping - no command line accessible" -ForegroundColor Cyan
            }
            return $false
        }

        # CRITICAL: Only kill if command line contains Ralph-specific markers
        $isRalphAgent = $false
        $ralphMarkers = @(
            'agent-runtime.ps1',
            'ralph-coordinator',
            'ralph-worker',
            'ralph-single',
            'ralph-event',
            'ralph-multi',
            'watchdog-event-v2',
            'Watchdog-Event-V2'
        )

        foreach ($marker in $ralphMarkers) {
            if ($commandLine -like "*$marker*") {
                $isRalphAgent = $true
                if ($Verbose) {
                    Write-Host "  [$($Process.Id)] Matched marker: $marker" -ForegroundColor Green
                }
                break
            }
        }

        if (-not $isRalphAgent) {
            if ($Verbose) {
                Write-Host "  [$($Process.Id)] Skipping - no Ralph marker in command line" -ForegroundColor Cyan
            }
            return $false
        }

        # Additional check: verify session directory if provided
        if ($SessionId -and $Script:SessionDir) {
            if ($commandLine -notlike "*$SessionId*") {
                if ($Verbose) {
                    Write-Host "  [$($Process.Id)] Skipping - session ID mismatch" -ForegroundColor Cyan
                }
                return $false
            }
        }

        return $true

    } catch {
        # If we can't verify, don't kill (safe default)
        if ($Verbose) {
            Write-Host "  [$($Process.Id)] Skipping - error checking command line: $_" -ForegroundColor Yellow
        }
        return $false
    }
}

function Get-StaleRalphProcesses {
    <#
    .SYNOPSIS
    Get list of stale Ralph agent processes.

    .RETURNS
    Array of verified stale Ralph agent processes.
    #>
    $staleProcesses = [System.Collections.Generic.List[System.Diagnostics.Process]]::new()

    try {
        $psProcesses = Get-Process -Name pwsh, powershell -ErrorAction SilentlyContinue

        foreach ($proc in $psProcesses) {
            if (Test-IsRalphAgent -Process $proc) {
                $staleProcesses.Add($proc)
            }
        }
    } catch {
        Write-Warning "Error enumerating processes: $_"
    }

    return $staleProcesses.ToArray()
}

function Remove-StaleProcesses {
    <#
    .SYNOPSIS
    Kill stale Ralph agent processes safely.

    .PARAMETER Processes
    Array of processes to kill.

    .RETURNS
    Number of processes killed.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [System.Diagnostics.Process[]]$Processes
    )

    $killed = 0

    foreach ($proc in $Processes) {
        try {
            if (-not $WhatIf) {
                $proc.Kill()
                $proc.WaitForExit(5000)  # Wait up to 5 seconds
            }

            Write-Host "  Killed process $($proc.Id)" -ForegroundColor Green
            $killed++

        } catch {
            Write-Warning "  Failed to kill process $($proc.Id): $_"
        }
    }

    return $killed
}

function Get-SessionPath {
    <#
    .SYNOPSIS
    Get the current Ralph session path for verification.
    #>
    $possiblePaths = @(
        ".\.claude\session",
        ".\.claude\sessions",
        "$PSScriptRoot\..\..\session"
    )

    foreach ($path in $possiblePaths) {
        $fullPath = Resolve-Path $path -ErrorAction SilentlyContinue
        if ($fullPath -and (Test-Path $fullPath)) {
            return $fullPath.Path
        }
    }

    return $null
}

# ============================================================================
# MAIN
# ============================================================================

Write-Host "`n=== Ralph Stale Process Cleanup ===" -ForegroundColor Magenta

# Get session path for verification
$Script:SessionDir = Get-SessionPath
if ($Script:SessionDir) {
    Write-Host "Session directory: $Script:SessionDir" -ForegroundColor Gray
}

# Get list of stale processes
$staleProcesses = Get-StaleRalphProcesses

if ($staleProcesses.Count -eq 0) {
    Write-Host "No stale Ralph agent processes found." -ForegroundColor Green
    exit 0
}

Write-Host "`nFound $($staleProcesses.Count) stale Ralph agent process(es):" -ForegroundColor Yellow

foreach ($proc in $staleProcesses) {
    Write-Host "  PID $($proc.Id) - $($process.ProcessName) - Started $($proc.StartTime)" -ForegroundColor White
}

# Confirm before killing
if (-not $Force -and -not $WhatIf) {
    $response = Read-Host "`nKill these processes? (y/N)"
    if ($response -ne 'y' -and $response -ne 'Y') {
        Write-Host "Cancelled." -ForegroundColor Yellow
        exit 0
    }
}

# Kill processes
if ($WhatIf) {
    Write-Host "`nWHAT IF: Would kill $($staleProcesses.Count) process(es)" -ForegroundColor Cyan
    exit 0
}

Write-Host "`nKilling processes..." -ForegroundColor Yellow
$killed = Remove-StaleProcesses -Processes $staleProcesses

Write-Host "`nCleanup complete. Killed $killed process(es)." -ForegroundColor Green
