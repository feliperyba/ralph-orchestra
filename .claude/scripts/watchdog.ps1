# Ralph Watchdog (PowerShell)
# Spawns agents in separate visible windows and monitors their activity via log files
# Run: .\.claude\scripts\watchdog.ps1
#
# Features:
# 1. Each agent runs in its own visible PowerShell window
# 2. Output is tee'd to log files for activity monitoring
# 3. Detects idle agents (no log activity for timeout period)
# 4. Auto-restarts crashed or idle agents
# 5. Dashboard showing process status and activity

param(
    [int]$IdleTimeoutSeconds = 120,     # Restart if no output for this long
    [int]$StartupGraceSeconds = 60,     # Don't check idle during startup
    [int]$CheckIntervalMs = 2000,
    [int]$MaxRestarts = 5,
    [switch]$NoDashboard = $false,
    [switch]$NoAutoRestart = $false,
    [string]$ProjectRoot = "",
    [string[]]$Agents = @("pm", "developer", "qa")
)

$ErrorActionPreference = "Stop"

# Determine project root
if (-not $ProjectRoot) {
    $ProjectRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
}

# Source configuration
. "$PSScriptRoot\ralph-config.ps1"

$config = Get-RalphConfig
$paths = Get-RalphPaths -ProjectRoot $ProjectRoot

# Log directory for activity monitoring
$Script:LogDir = Join-Path $paths.SessionDir "logs"
if (-not (Test-Path $Script:LogDir)) {
    New-Item -ItemType Directory -Path $Script:LogDir -Force | Out-Null
}

# ============================================================================
# AGENT STATE TRACKING
# ============================================================================

# Security: Valid agent names whitelist
$Script:ValidAgentNames = @("pm", "developer", "qa")

$Script:AgentStates = @{}
$Script:WatchdogStartTime = [DateTime]::UtcNow
$Script:TotalIterations = 0

# Security: Escape strings for safe script generation
function Get-SafeScriptString {
    param([string]$Value)
    # Escape backticks and dollar signs to prevent injection
    return $Value -replace '`', '``' -replace '\$', '`$' -replace '"', '`"'
}

function New-AgentState {
    param([string]$Name)
    return @{
        Name = $Name
        Process = $null
        StartTime = $null
        LastActivityTime = $null
        RestartCount = 0
        Status = "not_started"  # starting, running, idle, exited, error
        LogFile = Join-Path $Script:LogDir "$Name.log"
    }
}

# ============================================================================
# AGENT MANAGEMENT
# ============================================================================

function Get-AgentCommand {
    param([string]$AgentName)
    
    # Return the slash command with proper argument format
    # Note: Claude CLI slash commands use format: /command "arg1" "arg2"
    switch ($AgentName) {
        "pm" { return '/ralph-coordinator' }
        "developer" { return '"/ralph-worker --agent developer"' }
        "qa" { return '"/ralph-worker --agent qa"' }
        default { return "/ralph-worker --agent $AgentName" }
    }
}

function Start-AgentProcess {
    param(
        [Parameter(Mandatory=$true)]
        [string]$AgentName
    )
    
    # Security: Validate agent name against whitelist
    if ($AgentName -notin $Script:ValidAgentNames) {
        Write-Host "[WATCHDOG] Invalid agent name: $AgentName" -ForegroundColor Red
        return $false
    }
    
    # Create or get agent state
    if (-not $Script:AgentStates[$AgentName]) {
        $Script:AgentStates[$AgentName] = New-AgentState -Name $AgentName
    }
    
    $state = $Script:AgentStates[$AgentName]
    $logFile = $state.LogFile
    
    # Clear old log file
    if (Test-Path $logFile) {
        Remove-Item $logFile -Force
    }
    "" | Out-File -FilePath $logFile -Encoding utf8
    
    # Build the command based on agent type
    # The slash command with arguments needs to be quoted as a single argument to claude
    $slashCommand = switch ($AgentName) {
        "pm" { "/ralph-coordinator" }
        "developer" { "/ralph-worker --agent developer" }
        "qa" { "/ralph-worker --agent qa" }
    }
    
    Write-Host "[WATCHDOG] Starting $AgentName in new window..." -ForegroundColor Cyan
    Write-Host "[WATCHDOG]   Command: claude `"$slashCommand`" --dangerously-skip-permissions" -ForegroundColor DarkGray
    Write-Host "[WATCHDOG]   Log: $logFile" -ForegroundColor DarkGray
    
    # Build the command to run in the new window
    # Write a temp script file to avoid escaping issues
    $windowTitle = "Ralph Agent: $AgentName"
    $scriptFile = Join-Path $Script:LogDir "$AgentName-runner.ps1"
    
    # Security: Sanitize values for script generation
    $safeProjectRoot = Get-SafeScriptString -Value $ProjectRoot
    $safeLogFile = Get-SafeScriptString -Value $logFile
    
    # Create the runner script content
    # Use Start-Transcript for logging since piping breaks Claude CLI's interactive output
    $scriptContent = @"
`$Host.UI.RawUI.WindowTitle = "$windowTitle"
Set-Location "$safeProjectRoot"

Write-Host "========================================"  -ForegroundColor Cyan
Write-Host "  RALPH AGENT: $AgentName" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Slash Command: $slashCommand"
Write-Host "Working Dir: $safeProjectRoot"
Write-Host "Log File: $safeLogFile"
Write-Host ""
Write-Host "Starting Claude CLI..." -ForegroundColor Yellow
Write-Host ""

# Start transcript for activity monitoring
Start-Transcript -Path "$safeLogFile" -Append -Force | Out-Null

# Run claude directly - don't pipe output as it breaks the interactive CLI
`$exitCode = 0
try {
    claude "$slashCommand" --dangerously-skip-permissions
    `$exitCode = `$LASTEXITCODE
} catch {
    Write-Host "ERROR: `$_" -ForegroundColor Red
    `$exitCode = 1
}

Stop-Transcript | Out-Null

Write-Host ""
Write-Host "========================================"  -ForegroundColor Yellow
Write-Host "  Agent process ended (exit code: `$exitCode)" -ForegroundColor Yellow
Write-Host "  Window will close in 30 seconds..." -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow

# Write exit status to a status file for watchdog
`$exitCode | Out-File -FilePath "$safeLogFile.exit" -Encoding utf8

Start-Sleep -Seconds 30
"@

    # Write the script file
    $scriptContent | Out-File -FilePath $scriptFile -Encoding utf8 -Force

    try {
        # Start in a new visible window by running the script file
        $process = Start-Process "powershell.exe" `
            -ArgumentList "-NoExit", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $scriptFile `
            -PassThru `
            -WindowStyle Normal
        
        $state.Process = $process
        $state.StartTime = [DateTime]::UtcNow
        $state.LastActivityTime = [DateTime]::UtcNow
        $state.Status = "starting"
        
        Write-Host "[WATCHDOG] $AgentName started (PID: $($process.Id))" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "[WATCHDOG] Failed to start $AgentName : $_" -ForegroundColor Red
        $state.Status = "error"
        return $false
    }
}

function Stop-AgentProcess {
    param(
        [Parameter(Mandatory=$true)]
        [string]$AgentName
    )
    
    $state = $Script:AgentStates[$AgentName]
    if (-not $state -or -not $state.Process) {
        return
    }
    
    Write-Host "[WATCHDOG] Stopping $AgentName ..." -ForegroundColor Yellow
    
    try {
        # Null safety: check if process object exists and has expected properties
        if ($null -ne $state.Process -and $state.Process.Id -gt 0) {
            if (-not $state.Process.HasExited) {
                # Kill child processes first (claude spawns subprocesses)
                $parentPid = $state.Process.Id
                Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | 
                    Where-Object { $_.ParentProcessId -eq $parentPid } | 
                    ForEach-Object {
                        try { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue } catch {}
                    }
                
                $state.Process.Kill()
                $state.Process.WaitForExit(5000) | Out-Null
            }
        }
    } catch {}
    finally {
        # Dispose process handle to free resources
        if ($null -ne $state.Process) {
            try { $state.Process.Dispose() } catch {}
            $state.Process = $null
        }
    }
    
    $state.Status = "exited"
}

function Restart-AgentProcess {
    param(
        [Parameter(Mandatory=$true)]
        [string]$AgentName,
        [string]$Reason = "unknown"
    )
    
    $state = $Script:AgentStates[$AgentName]
    
    if ($state) {
        $state.RestartCount++
        
        if ($state.RestartCount -gt $MaxRestarts) {
            Write-Host "[WATCHDOG] $AgentName exceeded max restarts ($MaxRestarts) - giving up" -ForegroundColor Red
            $state.Status = "error"
            return $false
        }
        
        Write-Host "[WATCHDOG] Restarting $AgentName (attempt $($state.RestartCount)/$MaxRestarts) - Reason: $Reason" -ForegroundColor Yellow
    }
    
    Stop-AgentProcess -AgentName $AgentName
    Start-Sleep -Seconds 2
    return Start-AgentProcess -AgentName $AgentName
}

function Test-AgentInGracePeriod {
    param([string]$AgentName)
    
    $state = $Script:AgentStates[$AgentName]
    if (-not $state -or -not $state.StartTime) {
        return $false
    }
    
    $elapsed = ([DateTime]::UtcNow - $state.StartTime).TotalSeconds
    return $elapsed -lt $StartupGraceSeconds
}

function Get-AgentLastActivity {
    param([string]$AgentName)
    
    $state = $Script:AgentStates[$AgentName]
    if (-not $state) { return $null }
    
    $logFile = $state.LogFile
    
    # FIRST: Check if agent is waiting for input - if so, don't update activity time
    # This prevents CPU background activity from masking a stuck state
    $isWaitingForInput = $false
    if (Test-Path $logFile) {
        try {
            $lines = Get-Content $logFile -Tail 30 -ErrorAction SilentlyContinue
            $content = $lines -join "`n"
            
            # Patterns that indicate Claude is waiting for user input
            $inputPatterns = @(
                'Which agent.*should this worker run as',
                'Enter to select',
                'Type something',
                'to navigate.*Esc to cancel',
                'Agent Type',
                '\d+\.\s+Developer',
                '\d+\.\s+QA',
                'Chat about this',
                'Press Enter to',
                'waiting for.*input',
                '>\s*$'  # Prompt at end of content
            )
            
            foreach ($pattern in $inputPatterns) {
                if ($content -match $pattern) {
                    $isWaitingForInput = $true
                    break
                }
            }
        } catch {}
    }
    
    # If waiting for input, don't update activity - let idle timer grow
    if ($isWaitingForInput) {
        $state.IsWaitingForInput = $true
        return $state.LastActivityTime
    }
    $state.IsWaitingForInput = $false
    
    # Method 1: Check log file modification/size
    $logUpdated = $false
    if (Test-Path $logFile) {
        try {
            $fileInfo = Get-Item $logFile
            $lastWrite = $fileInfo.LastWriteTimeUtc
            $fileSize = $fileInfo.Length
            $previousSize = if ($state.LastLogSize) { $state.LastLogSize } else { 0 }
            
            if ($lastWrite -gt $state.LastActivityTime -or $fileSize -gt $previousSize) {
                $state.LastActivityTime = [DateTime]::UtcNow
                $state.LastLogSize = $fileSize
                $logUpdated = $true
            }
        } catch {}
    }
    
    # Method 2: Check if process tree is consuming CPU (indicates activity)
    if (-not $logUpdated -and $state.Process -and -not $state.Process.HasExited) {
        try {
            # Get all child processes (claude.exe and node.exe processes spawned by the PowerShell window)
            $parentPid = $state.Process.Id
            $childProcesses = Get-CimInstance Win32_Process | Where-Object { $_.ParentProcessId -eq $parentPid }
            
            foreach ($child in $childProcesses) {
                # Check if any child is named claude or node
                if ($child.Name -match 'claude|node') {
                    # Get CPU usage by comparing UserModeTime + KernelModeTime
                    $proc = Get-Process -Id $child.ProcessId -ErrorAction SilentlyContinue
                    if ($proc) {
                        $currentCpuTime = $proc.TotalProcessorTime.TotalMilliseconds
                        $lastCpuKey = "LastCpuTime_$($child.ProcessId)"
                        $previousCpuTime = if ($state.$lastCpuKey) { $state.$lastCpuKey } else { 0 }
                        
                        if ($currentCpuTime -gt $previousCpuTime) {
                            # Process is consuming CPU = active
                            $state.LastActivityTime = [DateTime]::UtcNow
                            $state.$lastCpuKey = $currentCpuTime
                        }
                    }
                }
            }
            
            # Also check grandchildren (claude spawns node)
            foreach ($child in $childProcesses) {
                $grandchildren = Get-CimInstance Win32_Process | Where-Object { $_.ParentProcessId -eq $child.ProcessId }
                foreach ($grandchild in $grandchildren) {
                    if ($grandchild.Name -match 'claude|node') {
                        $proc = Get-Process -Id $grandchild.ProcessId -ErrorAction SilentlyContinue
                        if ($proc) {
                            $currentCpuTime = $proc.TotalProcessorTime.TotalMilliseconds
                            $lastCpuKey = "LastCpuTime_$($grandchild.ProcessId)"
                            $previousCpuTime = if ($state.$lastCpuKey) { $state.$lastCpuKey } else { 0 }
                            
                            if ($currentCpuTime -gt $previousCpuTime) {
                                $state.LastActivityTime = [DateTime]::UtcNow
                                $state.$lastCpuKey = $currentCpuTime
                            }
                        }
                    }
                }
            }
        } catch {}
    }
    
    # If we have substantial log content, mark as running
    if ($state.LastLogSize -and $state.LastLogSize -gt 500 -and ($state.Status -eq "starting" -or $state.Status -eq "idle")) {
        $state.Status = "running"
    }
    
    return $state.LastActivityTime
}

function Test-AgentWaitingForInput {
    param([string]$AgentName)
    
    $state = $Script:AgentStates[$AgentName]
    if (-not $state) { return $false }
    
    $logFile = $state.LogFile
    
    if (Test-Path $logFile) {
        try {
            # Get last 20 lines and look for input prompts
            $lines = Get-Content $logFile -Tail 20 -ErrorAction SilentlyContinue
            $content = $lines -join "`n"
            
            # Patterns that indicate Claude is waiting for user input
            $inputPatterns = @(
                'Which agent.*should this worker run as',
                'Enter to select',
                'Type something',
                'to navigate.*Esc to cancel',
                'Agent Type',
                '\d+\.\s+Developer',
                '\d+\.\s+QA',
                'Chat about this'
            )
            
            foreach ($pattern in $inputPatterns) {
                if ($content -match $pattern) {
                    return $true
                }
            }
        } catch {}
    }
    
    return $false
}

function Get-AgentIdleSeconds {
    param([string]$AgentName)
    
    $lastActivity = Get-AgentLastActivity -AgentName $AgentName
    if (-not $lastActivity) { return 0 }
    
    return ([DateTime]::UtcNow - $lastActivity).TotalSeconds
}

function Test-AgentMaxIterationsReached {
    param([string]$AgentName)
    
    $state = $Script:AgentStates[$AgentName]
    if (-not $state) { return $false }
    
    $logFile = $state.LogFile
    
    if (Test-Path $logFile) {
        try {
            # Check last 50 lines for max iterations message
            $lines = Get-Content $logFile -Tail 50 -ErrorAction SilentlyContinue
            $content = $lines -join "`n"
            
            # Patterns that indicate max iterations reached
            $completionPatterns = @(
                'max.*iterations.*reached',
                'maximum.*iterations.*reached',
                'iteration limit.*reached',
                'completed.*all.*iterations',
                'task.*completed.*successfully',
                'all.*tasks.*done',
                'session.*complete',
                'exiting.*max.*iterations'
            )
            
            foreach ($pattern in $completionPatterns) {
                if ($content -imatch $pattern) {
                    return $true
                }
            }
        } catch {}
    }
    
    return $false
}

function Get-AgentExitCode {
    param([string]$AgentName)
    
    $state = $Script:AgentStates[$AgentName]
    if (-not $state) { return $null }
    
    $exitFile = "$($state.LogFile).exit"
    
    if (Test-Path $exitFile) {
        try {
            $exitCode = [int](Get-Content $exitFile -Raw).Trim()
            return $exitCode
        } catch {
            return $null
        }
    }
    
    return $null
}

function Get-AgentLastError {
    param([string]$AgentName)
    
    $state = $Script:AgentStates[$AgentName]
    if (-not $state) { return $null }
    
    $logFile = $state.LogFile
    
    if (Test-Path $logFile) {
        try {
            # Get last 10 lines and look for ERROR
            $lines = Get-Content $logFile -Tail 10 -ErrorAction SilentlyContinue
            $errorLines = $lines | Where-Object { $_ -match 'ERROR|error|Error|Exception|FATAL' }
            if ($errorLines) {
                return ($errorLines | Select-Object -Last 1)
            }
        } catch {}
    }
    
    return $null
}

# ============================================================================
# DASHBOARD
# ============================================================================

function Show-Dashboard {
    $width = 80
    $border = "=" * $width
    
    Clear-Host
    Write-Host $border -ForegroundColor Cyan
    Write-Host "  RALPH WATCHDOG - Process & Activity Monitor" -ForegroundColor Cyan
    Write-Host $border -ForegroundColor Cyan
    Write-Host ""
    
    # Uptime
    $uptime = ([DateTime]::UtcNow - $Script:WatchdogStartTime)
    $uptimeStr = "{0:hh\:mm\:ss}" -f $uptime
    Write-Host "  Uptime: $uptimeStr  |  Check #$($Script:TotalIterations)" -ForegroundColor White
    Write-Host ""
    
    # Agent status table
    Write-Host "  AGENT STATUS" -ForegroundColor Yellow
    Write-Host "  $("-" * 74)"
    Write-Host ("  {0,-12} {1,-8} {2,-10} {3,-12} {4,-15} {5,-8}" -f "Agent", "PID", "Status", "Idle", "Running", "Restarts") -ForegroundColor Gray
    Write-Host "  $("-" * 74)"
    
    foreach ($agentName in $Agents) {
        $state = $Script:AgentStates[$agentName]
        
        $pidStr = "-"
        $status = "not started"
        $statusColor = "Gray"
        $idleStr = "-"
        $runningFor = "-"
        $restarts = "0"
        
        if ($state) {
            $restarts = $state.RestartCount.ToString()
            
            if ($state.Process) {
                $pidStr = $state.Process.Id.ToString()
                
                if ($state.Process.HasExited) {
                    $status = "EXITED"
                    $statusColor = "Red"
                } else {
                    # Check activity from log file
                    $idleSeconds = Get-AgentIdleSeconds -AgentName $agentName
                    
                    if ($idleSeconds -lt 60) {
                        $idleStr = "$([int]$idleSeconds)s"
                    } else {
                        $idleStr = "$([int]($idleSeconds / 60))m $([int]($idleSeconds % 60))s"
                    }
                    
                    # Determine status
                    if ($state.Status -eq "completed") {
                        $status = "COMPLETED"
                        $statusColor = "Green"
                    } elseif (Test-AgentInGracePeriod -AgentName $agentName) {
                        $status = "starting"
                        $statusColor = "Cyan"
                    } elseif ($state.IsWaitingForInput) {
                        $status = "WAITING"
                        $statusColor = "Magenta"
                        $state.Status = "stuck"
                    } elseif (Test-AgentMaxIterationsReached -AgentName $agentName) {
                        $status = "COMPLETED"
                        $statusColor = "Green"
                        $state.Status = "completed"
                    } elseif ($idleSeconds -gt $IdleTimeoutSeconds) {
                        $status = "IDLE"
                        $statusColor = "Yellow"
                        $state.Status = "idle"
                    } else {
                        $status = "running"
                        $statusColor = "Green"
                        $state.Status = "running"
                    }
                    
                    # Calculate running time
                    if ($state.StartTime) {
                        $running = ([DateTime]::UtcNow - $state.StartTime)
                        if ($running.TotalSeconds -lt 60) {
                            $runningFor = "$([int]$running.TotalSeconds)s"
                        } elseif ($running.TotalMinutes -lt 60) {
                            $runningFor = "$([int]$running.TotalMinutes)m $([int]($running.Seconds))s"
                        } else {
                            $runningFor = "$([int]$running.TotalHours)h $([int]$running.Minutes)m"
                        }
                    }
                }
            }
            
            if ($state.Status -eq "error") {
                $status = "ERROR"
                $statusColor = "Red"
            }
        }
        
        Write-Host ("  {0,-12} " -f $agentName) -NoNewline
        Write-Host ("{0,-8} " -f $pidStr) -NoNewline -ForegroundColor White
        Write-Host ("{0,-10} " -f $status) -NoNewline -ForegroundColor $statusColor
        Write-Host ("{0,-12} " -f $idleStr) -NoNewline
        Write-Host ("{0,-15} " -f $runningFor) -NoNewline
        Write-Host ("{0,-8}" -f $restarts)
    }
    
    Write-Host "  $("-" * 74)"
    Write-Host ""
    
    # Show any errors detected
    $hasErrors = $false
    foreach ($agentName in $Agents) {
        $lastError = Get-AgentLastError -AgentName $agentName
        $exitCode = Get-AgentExitCode -AgentName $agentName
        if ($lastError -or ($exitCode -and $exitCode -ne 0)) {
            if (-not $hasErrors) {
                Write-Host "  ERRORS DETECTED" -ForegroundColor Red
                $hasErrors = $true
            }
            if ($exitCode -and $exitCode -ne 0) {
                Write-Host "  [$agentName] Exit code: $exitCode" -ForegroundColor Red
            }
            if ($lastError) {
                Write-Host "  [$agentName] $lastError" -ForegroundColor Red
            }
        }
    }
    if ($hasErrors) { Write-Host "" }
    
    # Settings
    Write-Host "  SETTINGS" -ForegroundColor Yellow
    Write-Host "  Idle Timeout: ${IdleTimeoutSeconds}s  |  Grace: ${StartupGraceSeconds}s  |  Auto-Restart: $(if (-not $NoAutoRestart) { 'ON' } else { 'OFF' })  |  Max: $MaxRestarts"
    Write-Host ""
    
    # Log locations
    Write-Host "  LOGS" -ForegroundColor Yellow
    Write-Host "  $Script:LogDir"
    Write-Host ""
    
    Write-Host $border -ForegroundColor Cyan
    Write-Host "  Press Ctrl+C to stop watchdog (agent windows stay open)" -ForegroundColor DarkGray
    Write-Host $border -ForegroundColor Cyan
}

# ============================================================================
# MAIN LOOP
# ============================================================================

function Start-Watchdog {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  RALPH WATCHDOG" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Project: $ProjectRoot"
    Write-Host "Agents: $($Agents -join ', ')"
    Write-Host "Idle Timeout: ${IdleTimeoutSeconds}s"
    Write-Host "Startup Grace: ${StartupGraceSeconds}s"
    Write-Host "Auto-Restart: $(if (-not $NoAutoRestart) { 'ENABLED' } else { 'DISABLED' })"
    Write-Host "Log Dir: $Script:LogDir"
    Write-Host ""
    
    # Start all agents in separate windows
    foreach ($agentName in $Agents) {
        Start-AgentProcess -AgentName $agentName
        Start-Sleep -Seconds 3  # Stagger starts
    }
    
    Write-Host ""
    Write-Host "[WATCHDOG] All agents started. Monitoring via log files..." -ForegroundColor Green
    Write-Host ""
    
    # Main monitoring loop
    try {
        while ($true) {
            $Script:TotalIterations++
            
            # Check each agent
            foreach ($agentName in $Agents) {
                $state = $Script:AgentStates[$agentName]
                if (-not $state -or -not $state.Process) { continue }
                
                # Skip if in error state (max restarts exceeded)
                if ($state.Status -eq "error") { continue }
                
                # Check if process exited
                if ($state.Process.HasExited) {
                    $exitCode = $state.Process.ExitCode
                    Write-Host "[WATCHDOG] $agentName exited (code: $exitCode)" -ForegroundColor Yellow
                    
                    if (-not $NoAutoRestart) {
                        Restart-AgentProcess -AgentName $agentName -Reason "process_exited (code: $exitCode)"
                    } else {
                        $state.Status = "exited"
                    }
                    continue
                }
                
                # Skip idle check if in grace period
                if (Test-AgentInGracePeriod -AgentName $agentName) { continue }
                
                # Check if agent reached max iterations (completed successfully)
                if (Test-AgentMaxIterationsReached -AgentName $agentName) {
                    if ($state.Status -ne "completed") {
                        Write-Host "[WATCHDOG] $agentName has reached max iterations - marking as completed" -ForegroundColor Green
                        $state.Status = "completed"
                    }
                    # Don't restart - agent finished its work
                    continue
                }
                
                # Check if agent is waiting for user input (stuck)
                if (Test-AgentWaitingForInput -AgentName $agentName) {
                    Write-Host "[WATCHDOG] $agentName is waiting for user input - restarting" -ForegroundColor Yellow
                    $state.Status = "stuck"
                    
                    if (-not $NoAutoRestart) {
                        Restart-AgentProcess -AgentName $agentName -Reason "waiting_for_input"
                    }
                    continue
                }
                
                # Check for idle (no log activity for timeout period)
                $idleSeconds = Get-AgentIdleSeconds -AgentName $agentName
                
                if ($idleSeconds -gt $IdleTimeoutSeconds) {
                    Write-Host "[WATCHDOG] $agentName idle for $([int]$idleSeconds)s (threshold: ${IdleTimeoutSeconds}s)" -ForegroundColor Yellow
                    
                    if (-not $NoAutoRestart) {
                        Restart-AgentProcess -AgentName $agentName -Reason "idle_timeout ($([int]$idleSeconds)s)"
                    } else {
                        $state.Status = "idle"
                    }
                }
            }
            
            # Update dashboard
            if (-not $NoDashboard) {
                Show-Dashboard
            }
            
            # Check if all agents are in terminal state (completed or error)
            $allTerminal = $true
            $allCompleted = $true
            $completedCount = 0
            $errorCount = 0
            
            foreach ($agentName in $Agents) {
                $state = $Script:AgentStates[$agentName]
                if ($state) {
                    if ($state.Status -eq "completed") {
                        $completedCount++
                    } elseif ($state.Status -eq "error") {
                        $errorCount++
                        $allCompleted = $false
                    } else {
                        $allTerminal = $false
                        $allCompleted = $false
                    }
                } else {
                    $allTerminal = $false
                    $allCompleted = $false
                }
            }
            
            if ($allTerminal -and $Script:AgentStates.Count -gt 0) {
                Write-Host ""
                if ($allCompleted) {
                    Write-Host "[WATCHDOG] All agents completed successfully!" -ForegroundColor Green
                } else {
                    Write-Host "[WATCHDOG] All agents finished. Completed: $completedCount, Errors: $errorCount" -ForegroundColor Yellow
                }
                Write-WatchdogSummary
                break
            }
            
            Start-Sleep -Milliseconds $CheckIntervalMs
        }
    }
    finally {
        Write-Host ""
        Write-Host "[WATCHDOG] Watchdog stopped." -ForegroundColor Cyan
        Write-Host "[WATCHDOG] Agent windows are still open - close them manually." -ForegroundColor Yellow
        
        # Write final summary if not already written
        Write-WatchdogSummary
    }
}

function Write-WatchdogSummary {
    # Prevent duplicate writes
    if ($Script:SummaryWritten) { return }
    $Script:SummaryWritten = $true
    
    $summaryFile = Join-Path $Script:LogDir "watchdog-summary.log"
    $uptime = ([DateTime]::UtcNow - $Script:WatchdogStartTime)
    
    $summary = @"
================================================================================
RALPH WATCHDOG SESSION SUMMARY
================================================================================
Start Time:    $($Script:WatchdogStartTime.ToString('yyyy-MM-dd HH:mm:ss')) UTC
End Time:      $([DateTime]::UtcNow.ToString('yyyy-MM-dd HH:mm:ss')) UTC
Total Uptime:  $("{0:hh\:mm\:ss}" -f $uptime)
Iterations:    $Script:TotalIterations

--------------------------------------------------------------------------------
AGENT FINAL STATUS
--------------------------------------------------------------------------------
"@
    
    foreach ($agentName in $Agents) {
        $state = $Script:AgentStates[$agentName]
        if ($state) {
            $status = $state.Status.ToUpper()
            $restarts = $state.RestartCount
            $runTime = "N/A"
            if ($state.StartTime) {
                $rt = ([DateTime]::UtcNow - $state.StartTime)
                $runTime = "{0:hh\:mm\:ss}" -f $rt
            }
            $summary += "`n  $($agentName.PadRight(12)) Status: $($status.PadRight(12)) Restarts: $restarts  RunTime: $runTime"
        } else {
            $summary += "`n  $($agentName.PadRight(12)) Status: NOT_STARTED"
        }
    }
    
    $summary += @"


--------------------------------------------------------------------------------
LOG FILES
--------------------------------------------------------------------------------
"@
    
    foreach ($agentName in $Agents) {
        $logFile = Join-Path $Script:LogDir "$agentName.log"
        if (Test-Path $logFile) {
            $size = (Get-Item $logFile).Length
            $sizeKB = [math]::Round($size / 1024, 2)
            $summary += "`n  $agentName : $logFile ($sizeKB KB)"
        }
    }
    
    $summary += @"


================================================================================
END OF SUMMARY
================================================================================
"@
    
    # Write to file
    $summary | Out-File -FilePath $summaryFile -Encoding UTF8
    
    Write-Host ""
    Write-Host "[WATCHDOG] Summary written to: $summaryFile" -ForegroundColor Cyan
}

# ============================================================================
# ENTRY POINT
# ============================================================================

try {
    Start-Watchdog
} catch {
    Write-Host "[WATCHDOG] Fatal error: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkRed
    exit 1
}
