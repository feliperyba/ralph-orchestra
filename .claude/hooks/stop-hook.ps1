# Ralph Wiggum Stop Hook (PowerShell Version)
# Blocks normal exit, creates self-referential loop by feeding same prompt back
#
# This hook is called when Claude attempts to exit. It checks the Ralph session
# state and either allows exit or signals to continue the loop.
#
# Environment Variables:
#   RALPH_COMPLETION_PROMISE - Phrase that signals completion (default: RALPH_COMPLETE)
#   RALPH_MAX_ITERATIONS - Maximum iterations before forced exit (default: 50)
#
# Session State:
#   prd.json.session - Main session state (was coordinator-state.json)
#   .claude/session/last-output.txt - Last Claude output for completion detection
#   .claude/session/context-reset-count.txt - Track number of context resets

$ErrorActionPreference = "Stop"

# Configuration
$SESSION_DIR = ".claude\session"
$PRD_FILE = "prd.json"
$LAST_OUTPUT = "$SESSION_DIR\last-output.txt"
$RESET_COUNT_FILE = "$SESSION_DIR\context-reset-count.txt"
$CONTINUE_FLAG = "$SESSION_DIR\continue-loop.flag"
$COMPLETION_PROMISE = if ($env:RALPH_COMPLETION_PROMISE) { $env:RALPH_COMPLETION_PROMISE } else { "RALPH_COMPLETE" }
$CONTEXT_RESET_PROMISE = "CONTEXT_RESET"
$MAX_ITERATIONS = if ($env:RALPH_MAX_ITERATIONS) { [int]$env:RALPH_MAX_ITERATIONS } else { 50 }

# Initialize reset counter
if (-not (Test-Path $RESET_COUNT_FILE)) {
    "0" | Out-File -FilePath $RESET_COUNT_FILE -Encoding utf8
}

# Ensure session directory exists
if (-not (Test-Path $SESSION_DIR)) {
    New-Item -ItemType Directory -Path $SESSION_DIR -Force | Out-Null
}

# Helper function to update prd.json.session
function Update-PrdSessionState {
    param(
        [hashtable]$Updates
    )

    $prdPath = $PRD_FILE
    if (-not (Test-Path $prdPath)) {
        return $false
    }

    try {
        $prdContent = Get-Content $prdPath -Raw | ConvertFrom-Json

        # Ensure session object exists
        if (-not $prdContent.session) {
            $timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
            $prdContent.session = @{
                sessionId = "ralph-" + (Get-Date).ToString("yyyyMMdd-HHmmss")
                startedAt = $timestamp
                maxIterations = $MAX_ITERATIONS
                iteration = 1
                completionPromise = $COMPLETION_PROMISE
                status = "running"
                currentTask = $null
                agents = @{
                    pm = @{ status = "idle"; lastSeen = $null }
                    developer = @{ status = "idle"; lastSeen = $null }
                    qa = @{ status = "idle"; lastSeen = $null }
                }
                stats = @{
                    totalTasks = 0
                    completed = 0
                    failed = 0
                    commits = 0
                }
            }
        }

        # Apply updates
        foreach ($key in $Updates.Keys) {
            $prdContent.session[$key] = $Updates[$key]
        }

        # Write back to file
        $prdContent | ConvertTo-Json -Depth 32 | Out-File -FilePath "$prdPath.tmp" -Encoding utf8
        Move-Item -Path "$prdPath.tmp" -Destination $prdPath -Force
        return $true
    } catch {
        return $false
    }
}

# Read current state from prd.json.session
$STATUS = "running"
$ITERATION = 1
$MAX = $MAX_ITERATIONS

if (Test-Path $PRD_FILE) {
    try {
        $prdContent = Get-Content $PRD_FILE -Raw | ConvertFrom-Json
        if ($prdContent.session) {
            $STATUS = $prdContent.session.status
            $ITERATION = $prdContent.session.iteration
            $MAX = if ($prdContent.session.maxIterations) { $prdContent.session.maxIterations } else { $MAX_ITERATIONS }
        }
    } catch {
        # Use defaults
    }
}

# ============================================================================
# FORCED RESTART GUARDRAIL
# ============================================================================
# This hook ALWAYS signals restart (continue flag) after each response.
# Only max iterations allows actual exit - the external loop script
# (agent-loop.ps1) becomes the primary authority on when to stop.
# ============================================================================

# Check max iterations FIRST - this is the ONLY exit condition
if ($ITERATION -gt $MAX) {
    Write-Host "=== Max iterations reached ($ITERATION/$MAX) ===" -ForegroundColor Yellow
    Write-Host "Ralph loop stopping..."
    # Update status in prd.json.session
    Update-PrdSessionState -Updates @{ status = "max_iterations_reached" }
    exit 0
}

# Check for terminated status (manual cancellation via /cancel-ralph)
if ($STATUS -eq "terminated" -or $STATUS -eq "terminating") {
    Write-Host "=== Ralph loop terminated (status: $STATUS) ===" -ForegroundColor Yellow
    exit 0
}

# Check for context reset promise - track it but still continue
if (Test-Path $LAST_OUTPUT) {
    $lastOutputContent = Get-Content $LAST_OUTPUT -Raw
    $resetPattern = "<promise>$CONTEXT_RESET_PROMISE</promise>"

    if ($lastOutputContent -match [regex]::Escape($resetPattern)) {
        # Increment reset counter
        $resetCount = [int](Get-Content $RESET_COUNT_FILE -Raw)
        $resetCount++
        $resetCount.ToString() | Out-File -FilePath $RESET_COUNT_FILE -Encoding utf8
        Write-Host "--- Context reset detected (reset #$resetCount) ---" -ForegroundColor Cyan

        # Clear the promise from last-output to prevent re-triggering
        "" | Out-File -FilePath $LAST_OUTPUT -Encoding utf8
    }
}

# Check for completion promise - update status but still continue
# The external loop script will detect completion and stop
if (Test-Path $LAST_OUTPUT) {
    $lastOutputContent = Get-Content $LAST_OUTPUT -Raw
    $completionPattern = "<promise>$COMPLETION_PROMISE</promise>"

    if ($lastOutputContent -match [regex]::Escape($completionPattern)) {
        Write-Host "--- Completion promise detected, updating status ---" -ForegroundColor Green
        Update-PrdSessionState -Updates @{ status = "completed" }
        # Note: We still continue - external loop will detect "completed" status
    }
}

# Increment iteration counter
Update-PrdSessionState -Updates @{ iteration = $ITERATION + 1 }

# ALWAYS signal restart - create continue flag file
# The external loop script (agent-loop.ps1) checks for this flag
"continue" | Out-File -FilePath $CONTINUE_FLAG -Encoding utf8
Write-Host "=== Ralph iteration $ITERATION/$MAX - forcing restart ===" -ForegroundColor Cyan

# Exit code 42 signals "run again with same prompt" to Claude Code CLI
# The continue-flag file provides backup signaling for agent-loop.ps1
exit 42
