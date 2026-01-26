# Ralph Event Session V2 Launcher
# Uses the new Actor Model with Event Sourcing architecture
#
# This is the new launcher that uses:
# - watchdog-event-v2.ps1 (new supervisor-based watchdog)
# - eventlog.ps1 (event sourcing)
# - event-bus.ps1 (bidirectional pipes)
# - supervisor.ps1 (actor supervision)
# - message-protocol.ps1 (simplified messages)
# - agent-runtime.ps1 (agent runtime library)

param(
    [int]$MaxIterations = 200,
    [switch]$NoDashboard = $false,
    [switch]$Debug = $false,
    [string]$ProjectRoot = ""
)

$ErrorActionPreference = "Stop"

# Source dashboard module for startup animation (must be first, before any output)
# Use try-catch to handle encoding issues with Unicode characters
$dashboardLoaded = $false
if (-not $NoDashboard) {
    $dashboardModule = Join-Path $PSScriptRoot "..\dashboard\Dashboard-Common.ps1"
    if (Test-Path $dashboardModule) {
        $oldEA = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        try {
            # Try to load with UTF8 encoding to handle Unicode characters
            $content = Get-Content $dashboardModule -Raw -Encoding UTF8 -ErrorAction Stop
            . $dashboardModule
            $dashboardLoaded = $true
        } catch {
            Write-Warning "Dashboard module could not be loaded (encoding issue). Use -NoDashboard to suppress this warning."
            Write-Warning "Error: $_"
        }
        $ErrorActionPreference = $oldEA
    }
}

# Show startup animation FIRST - before any other output
if (-not $NoDashboard -and (Get-Command "Show-RalphStartupAnimation" -ErrorAction SilentlyContinue)) {
    $null = Show-RalphStartupAnimation -Supervisor $null -MaxDurationSeconds 4
}

# Banner
Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "RALPH ORCHESTRA V2 - EVENT-DRIVEN MODE" -ForegroundColor Cyan
Write-Host "Actor Model + Event Sourcing + CQRS Architecture" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""

# Determine project root
# Script is at: .claude/scripts/sessions/ralph-event-v2-session.ps1
# Project root is: (script dir) -> .. (scripts/) -> .. (.claude/) -> .. (project root) = 4 levels
# OR: (script dir) -> .. (scripts/) -> .. (.claude/) = .claude is the root if that's where project is
if (-not $ProjectRoot) {
    $ProjectRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
}

Write-Host "Project Root: $ProjectRoot" -ForegroundColor DarkGray
Write-Host "Max Iterations: $MaxIterations" -ForegroundColor DarkGray
Write-Host ""

# Check for PRD (try project root first, then .claude directory)
$prdPath = Join-Path $ProjectRoot "prd.json"
if (-not (Test-Path $prdPath)) {
    $prdPath = Join-Path $ProjectRoot ".claude\prd.json"
}
if (-not (Test-Path $prdPath)) {
    Write-Error "PRD not found at project root or .claude directory"
    Write-Host "Create a prd.json file before starting Ralph." -ForegroundColor Yellow
    exit 1
}

Write-Host "PRD found: $prdPath" -ForegroundColor Green
Write-Host ""

# Determine session directory (needed before sourcing watchdog)
$sessionDir = Join-Path $ProjectRoot ".claude\session"
if (-not (Test-Path $sessionDir)) {
    New-Item -ItemType Directory -Path $sessionDir -Force | Out-Null
}

# ============================================================================
# SESSION TRACKING: Track current session PID for child process management
# ============================================================================
$Script:SessionPid = $PID
$Script:SessionStartTime = [DateTime]::UtcNow
$Script:SessionMarkerFile = Join-Path $sessionDir "session-pid.txt"

# Write session marker for child process identification
@{
    SessionPid = $Script:SessionPid
    StartTime = $Script:SessionStartTime.ToString("o")
    ProjectRoot = $ProjectRoot
} | ConvertTo-Json | Out-File -FilePath $Script:SessionMarkerFile -Encoding utf8

Write-Host "Session PID: $Script:SessionPid" -ForegroundColor DarkGray
Write-Host ""

# ============================================================================
# CLEANUP: Only cleanup processes from previous sessions (not this one)
# ============================================================================
Write-Host "Checking for previous session processes..." -ForegroundColor Yellow

try {
    # Read previous session marker if exists
    $prevSessionPid = $null
    if (Test-Path $Script:SessionMarkerFile) {
        try {
            $prevSession = Get-Content $Script:SessionMarkerFile | ConvertFrom-Json
            $prevSessionPid = $prevSession.SessionPid
        } catch {
            # Invalid or corrupted file
        }
    }

    # Get current parent-child relationships
    $currentProcess = Get-Process -Id $PID -ErrorAction SilentlyContinue
    $currentParentPid = if ($currentProcess) { $currentProcess.Parent.Id } else { $null }

    # Function to check if a process belongs to our session tree
    function Test-IsSessionChildProcess {
        param([int]$TargetPid)

        # Never kill the current session process
        if ($TargetPid -eq $Script:SessionPid) { return $false }

        try {
            $targetProc = Get-Process -Id $TargetPid -ErrorAction SilentlyContinue
            if (-not $targetProc) { return $false }

            # Check if it's a direct child of our session
            if ($targetProc.Parent.Id -eq $Script:SessionPid) { return $true }

            # Check if it's from a previous session (same parent but different PID)
            if ($prevSessionPid -and $targetProc.Parent.Id -eq $prevSessionPid) { return $true }

            # Check command line for Ralph-specific patterns AND verify it's not our current process tree
            try {
                $cmdLine = (Get-WmiObject Win32_Process -Filter "ProcessId = $TargetPid" -ErrorAction SilentlyContinue).CommandLine
                if ($cmdLine -and ($cmdLine.Contains("Start-AgentLoop") -or $cmdLine.Contains("watchdog-event-v2"))) {
                    # Only kill if it's not part of our current process tree
                    # Check all ancestors to see if any is our session PID
                    $ancestorPid = $targetProc.Parent.Id
                    $maxDepth = 5
                    $depth = 0
                    $isOurTree = $false

                    while ($ancestorPid -and $depth -lt $maxDepth) {
                        if ($ancestorPid -eq $Script:SessionPid) {
                            $isOurTree = $true
                            break
                        }
                        try {
                            $ancestorProc = Get-Process -Id $ancestorPid -ErrorAction SilentlyContinue
                            if ($ancestorProc) {
                                $ancestorPid = $ancestorProc.Parent.Id
                            } else {
                                break
                            }
                        } catch {
                            break
                        }
                        $depth++
                    }

                    # Not our tree - safe to kill
                    return -not $isOurTree
                }
            } catch {
                # WMI failed - can't determine, be safe
            }

            return $false
        } catch {
            return $false
        }
    }

    # Find and kill stale Ralph processes (NOT from our current session)
    $killedCount = 0
    $pwshProcesses = Get-Process -Name "pwsh", "powershell" -ErrorAction SilentlyContinue

    foreach ($proc in $pwshProcesses) {
        if (Test-IsSessionChildProcess -TargetPid $proc.Id) {
            try {
                Write-Host "  Killing stale process (PID: $($proc.Id))" -ForegroundColor DarkGray
                $proc.Kill()
                $killedCount++
            } catch {
                # Already exited or access denied
            }
        }
    }

    if ($killedCount -gt 0) {
        Start-Sleep -Milliseconds 500
        Write-Host "Killed $killedCount stale process(es)" -ForegroundColor Green
    } else {
        Write-Host "No stale processes found" -ForegroundColor Green
    }

    Write-Host "Cleanup complete" -ForegroundColor Green
} catch {
    Write-Warning "Cleanup encountered an error: $_"
}
Write-Host ""

# Source the V2 watchdog
. "$PSScriptRoot\..\watchdog\watchdog-event-v2.ps1"

# Start the watchdog
try {
    Start-WatchdogV2 `
        -MaxIterations $MaxIterations `
        -NoDashboard:$NoDashboard `
        -Debug:$Debug `
        -ProjectRoot $ProjectRoot
}
catch {
    Write-Error "Watchdog failed: $_"
    Write-Host ""
    Write-Host "For troubleshooting, check the watchdog log at:" -ForegroundColor Yellow
    Write-Host "  .claude/session/logs/watchdog.log" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "Ralph session completed." -ForegroundColor Green
Write-Host ""
