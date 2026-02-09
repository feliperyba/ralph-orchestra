# Ralph Agent Context Loop (Windows PowerShell)
# Generic agent loop that manages Claude Code with forced restart after each response
# Usage: agent-loop.ps1 -AgentType <coordinator|developer|qa> -Command <claude-command>
#
# Features:
# - Idle detection: auto-restart after configurable idle timeout
# - Heartbeat tracking: updates agent status for watchdog monitoring
# - Work-in-progress save: preserves state before forced restart
# - True context reset: spawns fresh process each iteration
# - Proactive context management: detects high usage and triggers reset

param(
    [Parameter(Mandatory=$true)]
    [string]$AgentType,

    [Parameter(Mandatory=$true)]
    [string]$Command,

    [int]$MaxIterations = 0,  # 0 = use config default
    [string]$CompletionPromise = "",
    [string]$ContextResetPromise = "",
    [int]$IdleTimeoutSeconds = 0  # 0 = use config default
)

$ErrorActionPreference = "Stop"

# Source configuration and utilities
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$scriptDir\ralph-config.ps1"
. "$scriptDir\context-manager.ps1"

$config = Get-RalphConfig
$projectRoot = (Get-Item $scriptDir).Parent.Parent.FullName
$paths = Get-RalphPaths -ProjectRoot $projectRoot

# Apply config defaults if not overridden
if ($MaxIterations -eq 0) { $MaxIterations = $config.MaxIterations }
if (-not $CompletionPromise) { $CompletionPromise = $config.CompletionPromise }
if (-not $ContextResetPromise) { $ContextResetPromise = $config.ContextResetPromise }
if ($IdleTimeoutSeconds -eq 0) { $IdleTimeoutSeconds = $config.IdleTimeoutSeconds }

$SESSION_DIR = $paths.SessionDir
$PROMISE_FILE = Join-Path $SESSION_DIR "$AgentType-last-promise.txt"
$RESET_COUNT_FILE = Join-Path $SESSION_DIR "$AgentType-reset-count.txt"
$HEARTBEAT_FILE = Join-Path $SESSION_DIR "agent-$AgentType.json"

# Ensure session directory exists
Initialize-SessionDirectory -ProjectRoot $projectRoot

# Initialize context tracking
Initialize-ContextTracking -AgentName $AgentType -ProjectRoot $projectRoot | Out-Null

Write-Host "=== Ralph Agent Loop: $AgentType ===" -ForegroundColor Cyan
Write-Host "Command: claude $Command"
Write-Host "Working Dir: $projectRoot"
Write-Host "Max Iterations: $MaxIterations"
Write-Host "Idle Timeout: $IdleTimeoutSeconds seconds"
Write-Host "Heartbeat Interval: $($config.HeartbeatInterval) seconds"
Write-Host ""

# Initialize reset tracking
if (Test-Path $RESET_COUNT_FILE) {
    $resetCount = [int](Get-Content $RESET_COUNT_FILE)
} else {
    $resetCount = 0
}

# Check for work-in-progress from previous session
$wip = Get-WorkInProgress -ProjectRoot $projectRoot
if ($wip -and $wip.agent -eq $AgentType) {
    Write-Host "Resuming from work-in-progress (saved at: $($wip.savedAt))" -ForegroundColor Yellow
    Write-Host "  Task: $($wip.taskState.taskId)" -ForegroundColor Yellow
    Write-Host "  Reason: $($wip.reason)" -ForegroundColor Yellow
    Clear-WorkInProgress -ProjectRoot $projectRoot
}

# Function to update agent heartbeat
function Update-LoopHeartbeat {
    param([string]$Status = "working")
    
    $heartbeat = @{
        agent = $AgentType
        status = $Status
        lastSeen = Get-Timestamp
        iteration = $iteration
        resetCount = $resetCount
        pid = $PID
    }
    
    try {
        $heartbeat | ConvertTo-Json -Depth 5 | Out-File -FilePath $HEARTBEAT_FILE -Encoding utf8
        
        # Also update coordinator state if it exists
        Update-AgentHeartbeat -AgentName $AgentType -Status $Status -ProjectRoot $projectRoot | Out-Null
    } catch {
        # Ignore heartbeat update failures - non-critical
    }
}

# Main loop
for ($iteration = 1; $iteration -le $MaxIterations; $iteration++) {
    Write-Host "`n=== Iteration $iteration/$MaxIterations (Resets: $resetCount) ===" -ForegroundColor Cyan
    Write-Host "Starting Claude Code process..."
    Write-Host ""

    # Update heartbeat at start of iteration
    Update-LoopHeartbeat -Status "starting"

    # Change to project root directory for claude command
    Push-Location $projectRoot

    # Determine MCP config path
    $mcpConfigPath = Join-Path $projectRoot ".claude\settings.$AgentType.json"
    $mcpArg = ""
    if (Test-Path $mcpConfigPath) {
        # Use single quotes for path to avoid nesting issues in outer double quotes
        $mcpArg = " --mcp-config '.\.claude\settings.$AgentType.json'"
        Write-Host "Using MCP config: .\.claude\settings.$AgentType.json" -ForegroundColor Gray
    } elseif (Test-Path (Join-Path $projectRoot ".claude\ralph-config.json")) {
        # Fallback to main config
        $mcpArg = " --mcp-config '.\.claude\ralph-config.json'"
        Write-Host "Using MCP config: .\.claude\ralph-config.json (fallback)" -ForegroundColor Gray
    }

    try {
        # Build the full command string
        # Flags first (including MCP), then prompt (command) explicitly quoted
        # Using single quotes for the inner command avoids PowerShell expansion issues
        $safeCommand = $Command -replace "'", "''"
        $fullCmd = "claude$mcpArg --dangerously-skip-permissions '$safeCommand'"

        # Start the process WITH output capture so we can monitor when it's idle
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "powershell.exe"
        $psi.Arguments = "-NoProfile -Command ""$fullCmd"""
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.WorkingDirectory = $PWD
        $psi.CreateNoWindow = $false  # Show window so user can see what's happening

        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $psi

        # Event handlers to capture output in real-time
        $outputBuilder = New-Object System.Text.StringBuilder
        $lastOutputTime = [DateTime]::UtcNow

        $outputAction = {
            if (-not [String]::IsNullOrEmpty($EventArgs.Data)) {
                $line = $EventArgs.Data
                Write-Host $line
                # Update last output time
                $Script:LastOutputTime = [DateTime]::UtcNow
                # Also append to promise file for promise detection
                if ($line -match "<promise>") {
                    $line | Out-File -FilePath "$Script:PromiseFile" -Append -Encoding utf8
                }
            }
        }

        $errorAction = {
            if (-not [String]::IsNullOrEmpty($EventArgs.Data)) {
                Write-Host $EventArgs.Data -ForegroundColor Red
                $Script:LastOutputTime = [DateTime]::UtcNow
            }
        }

        # Set script-scoped variables for event handlers (avoid $Global: pollution)
        $Script:LastOutputTime = [DateTime]::UtcNow
        $Script:PromiseFile = $PROMISE_FILE

        # Register event handlers
        $outputEvent = $null
        $errorEvent = $null
        try {
            $outputEvent = Register-ObjectEvent -InputObject $process -EventName OutputDataReceived -Action $outputAction -MessageData $outputBuilder
            $errorEvent = Register-ObjectEvent -InputObject $process -EventName ErrorDataReceived -Action $errorAction

            # Start the process
            $process.Start() | Out-Null

            # Begin async read of output streams
            $process.BeginOutputReadLine()
            $process.BeginErrorReadLine()

            # Monitor loop - check if process is idle (no new output for timeout period)
            Write-Host "[Monitoring agent output - will auto-restart after ${IdleTimeoutSeconds}s of idle...]`n" -ForegroundColor DarkGray

            $checkIntervalMs = $config.PollIntervalMs
            $timeoutMs = $IdleTimeoutSeconds * 1000
            $heartbeatIntervalMs = $config.HeartbeatInterval * 1000
            $lastHeartbeatTime = [DateTime]::UtcNow

            # Update heartbeat to working
            Update-LoopHeartbeat -Status "working"

            while (!$process.HasExited) {
                Start-Sleep -Milliseconds $checkIntervalMs

                $timeSinceLastOutput = ([DateTime]::UtcNow - $Script:LastOutputTime).TotalMilliseconds
                $timeSinceLastHeartbeat = ([DateTime]::UtcNow - $lastHeartbeatTime).TotalMilliseconds

                # Update heartbeat periodically
                if ($timeSinceLastHeartbeat -gt $heartbeatIntervalMs) {
                    Update-LoopHeartbeat -Status "working"
                    $lastHeartbeatTime = [DateTime]::UtcNow
                }

                # If no output for timeout period, assume agent is done and kill process
                if ($timeSinceLastOutput -gt $timeoutMs) {
                    Write-Host "`n--- Agent idle for ${IdleTimeoutSeconds}s, forcing restart ---" -ForegroundColor Yellow

                    # Save work-in-progress before killing
                    $currentTask = $null
                    if (Test-Path $paths.CurrentTask) {
                        try { $currentTask = Get-Content $paths.CurrentTask -Raw | ConvertFrom-Json } catch {}
                    }
                    if ($currentTask) {
                        Save-WorkInProgress -AgentName $AgentType -TaskState @{
                            taskId = $currentTask.prdId
                            status = $currentTask.status
                            idleAt = Get-Timestamp
                        } -Reason "idle_timeout" -ProjectRoot $projectRoot
                    }

                    # Try graceful shutdown first
                    if (!$process.CloseMainWindow()) {
                        # If graceful doesn't work, force kill
                        $process.Kill()
                    }

                    # Wait a bit for process to terminate
                    $process.WaitForExit(2000)

                    # If still running, force kill
                    if (!$process.HasExited) {
                        $process.Kill()
                        $process.WaitForExit(1000)
                    }

                    break
                }
            }
        } finally {
            # Cleanup event handlers - guaranteed even if monitoring loop throws
            if ($outputEvent) { 
                try { Unregister-Event -SourceIdentifier $outputEvent.Name -ErrorAction SilentlyContinue } catch {} 
            }
            if ($errorEvent) { 
                try { Unregister-Event -SourceIdentifier $errorEvent.Name -ErrorAction SilentlyContinue } catch {} 
            }
            # Dispose process object to release handles
            if ($process) {
                try { $process.Dispose() } catch {}
            }
        }

        # Update heartbeat to idle after process ends
        Update-LoopHeartbeat -Status "idle"

        $exitCode = if ($process -and $process.HasExited) { $process.ExitCode } else { -1 }

        Write-Host "`n--- Process ended (exit code: $exitCode) ---" -ForegroundColor Yellow

        # Check for completion promise in the promise file
        if (Test-Path $PROMISE_FILE) {
            $promiseContent = Get-Content $PROMISE_FILE -Raw -ErrorAction SilentlyContinue
            if ($promiseContent -match "<promise>$CompletionPromise</promise>") {
                Update-LoopHeartbeat -Status "completed"
                Write-Host "`n=== COMPLETE ===" -ForegroundColor Green
                Write-Host "[$AgentType] All tasks completed after $iteration iterations!"
                exit 0
            }
        }

        # Check for "completed" status in coordinator-state.json
        if (Test-Path "$SESSION_DIR/coordinator-state.json") {
            $stateContent = Get-Content "$SESSION_DIR/coordinator-state.json" -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json -ErrorAction SilentlyContinue
            if ($stateContent -and $stateContent.status -eq "completed") {
                Write-Host "`n=== COMPLETE ===" -ForegroundColor Green
                Write-Host "[$AgentType] All tasks completed after $iteration iterations! (detected via state file)"
                exit 0
            }
            
            # Also check for terminated status
            if ($stateContent -and $stateContent.status -eq "terminated") {
                Write-Host "`n=== TERMINATED ===" -ForegroundColor Yellow
                Write-Host "[$AgentType] Session terminated after $iteration iterations"
                exit 0
            }
        }

        # Check for context reset promise
        if (Test-Path $PROMISE_FILE) {
            $promiseContent = Get-Content $PROMISE_FILE -Raw -ErrorAction SilentlyContinue
            if ($promiseContent -match "<promise>$ContextResetPromise</promise>") {
                Record-ContextReset -AgentName $AgentType -Reason "promise" -ProjectRoot $projectRoot
                $resetCount++
                Write-Host "`n--- Context Reset Detected (Reset #$resetCount) ---" -ForegroundColor Yellow
                Write-Host "[$AgentType] Context was at ~70% capacity"
                Write-Host "Spawning fresh process with clean context window..."
                ""

                # Save reset count
                "$resetCount" | Out-File -FilePath $RESET_COUNT_FILE -Encoding UTF8

                # Clear the promise to prevent re-triggering
                Clear-Content -Path $PROMISE_FILE -ErrorAction SilentlyContinue

                # Continue loop - next iteration will be fresh context
                continue
            }
        }

        # Proactive context check - trigger reset if usage is high
        $contextUsage = Get-ContextUsage -AgentName $AgentType -ProjectRoot $projectRoot
        if ($contextUsage.isHigh) {
            Write-Host "`n--- Proactive Context Reset (Usage: $($contextUsage.percent)%) ---" -ForegroundColor Yellow
            Record-ContextReset -AgentName $AgentType -Reason "proactive_threshold" -ProjectRoot $projectRoot
            $resetCount++
            Write-Host "[$AgentType] Triggering reset before threshold breach"
            Write-Host "Spawning fresh process with clean context window..."
            ""
            continue
        }

        # Update context tracking
        Update-ContextTracking -AgentName $AgentType -TokensUsed 3500 -ProjectRoot $projectRoot | Out-Null

        # Brief pause before restarting
        Write-Host "Restarting in $($config.RestartDelaySeconds) second(s)..."
        Start-Sleep -Seconds $config.RestartDelaySeconds

    } finally {
        Pop-Location
    }
}

Write-Host "`n=== Max iterations reached ($MaxIterations) ===" -ForegroundColor Yellow
exit 1
