# Ralph Dashboard (PowerShell)
# Real-time status display for Ralph multi-agent system
#
# Usage:
#   .\.claude\scripts\dashboard.ps1
#   .\.claude\scripts\dashboard.ps1 -RefreshSeconds 5 -Continuous

param(
    [int]$RefreshSeconds = 3,
    [switch]$Continuous = $true,
    [switch]$Compact = $false,
    [string]$ProjectRoot = ""
)

$ErrorActionPreference = "SilentlyContinue"

# Determine project root
if (-not $ProjectRoot) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $ProjectRoot = (Get-Item $scriptDir).Parent.Parent.FullName
}

# Source utilities
. "$ProjectRoot\.claude\scripts\ralph-config.ps1"
. "$ProjectRoot\.claude\scripts\context-manager.ps1"
. "$ProjectRoot\.claude\scripts\metrics.ps1"

$paths = Get-RalphPaths -ProjectRoot $ProjectRoot
$config = Get-RalphConfig

# ============================================================================
# DISPLAY HELPERS
# ============================================================================

function Write-Header {
    param([string]$Text, [ConsoleColor]$Color = [ConsoleColor]::Cyan)
    
    $width = 74
    $border = "═" * $width
    
    Write-Host ""
    Write-Host "╔$border╗" -ForegroundColor $Color
    Write-Host ("║ {0,-72} ║" -f $Text) -ForegroundColor $Color
    Write-Host "╚$border╝" -ForegroundColor $Color
}

function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-Host "  ─── $Title ───" -ForegroundColor Yellow
}

function Get-StatusColor {
    param([string]$Status)
    
    switch ($Status) {
        "running" { return "Green" }
        "completed" { return "Cyan" }
        "terminated" { return "Yellow" }
        "working" { return "Cyan" }
        "idle" { return "Green" }
        "waiting" { return "Yellow" }
        "stale" { return "Red" }
        "passed" { return "Green" }
        "failed" { return "Red" }
        "in_progress" { return "Cyan" }
        default { return "Gray" }
    }
}

function Format-Duration {
    param([int]$Seconds)
    
    if ($Seconds -lt 60) { return "${Seconds}s" }
    if ($Seconds -lt 3600) { return "$([int]($Seconds / 60))m $($Seconds % 60)s" }
    return "$([int]($Seconds / 3600))h $([int](($Seconds % 3600) / 60))m"
}

# ============================================================================
# DATA COLLECTION
# ============================================================================

function Get-DashboardData {
    $data = @{
        timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        state = $null
        agents = @{}
        currentTask = $null
        prd = $null
        metrics = $null
        contextSummary = @{}
    }
    
    # Get coordinator state
    if (Test-Path $paths.CoordinatorState) {
        try {
            $data.state = Get-Content $paths.CoordinatorState -Raw | ConvertFrom-Json
        } catch {}
    }
    
    # Get agent status from per-agent files
    foreach ($agentName in @("pm", "developer", "qa")) {
        $agentFile = Join-Path $paths.SessionDir "agent-$agentName.json"
        
        if (Test-Path $agentFile) {
            try {
                $agentData = Get-Content $agentFile -Raw | ConvertFrom-Json
                
                # Calculate time since last seen
                $lastSeen = $null
                $elapsed = 9999
                
                if ($agentData.lastSeen) {
                    try {
                        $lastSeen = [DateTime]::Parse($agentData.lastSeen)
                        $elapsed = ([DateTime]::UtcNow - $lastSeen).TotalSeconds
                    } catch {}
                }
                
                $health = "UNKNOWN"
                if ($elapsed -lt $config.HeartbeatInterval * 2) {
                    $health = "HEALTHY"
                } elseif ($elapsed -lt $config.StaleAgentThreshold) {
                    $health = "WARNING"
                } else {
                    $health = "STALE"
                }
                
                $data.agents[$agentName] = @{
                    status = $agentData.status
                    lastSeen = $agentData.lastSeen
                    elapsed = $elapsed
                    health = $health
                    iteration = $agentData.iteration
                    pid = $agentData.pid
                }
            } catch {}
        } else {
            $data.agents[$agentName] = @{
                status = "offline"
                health = "OFFLINE"
                elapsed = 9999
            }
        }
    }
    
    # Get current task
    if (Test-Path $paths.CurrentTask) {
        try {
            $data.currentTask = Get-Content $paths.CurrentTask -Raw | ConvertFrom-Json
        } catch {}
    }
    
    # Get PRD summary
    if (Test-Path $paths.PrdFile) {
        try {
            $prd = Get-Content $paths.PrdFile -Raw | ConvertFrom-Json
            $items = if ($prd.items) { $prd.items } elseif ($prd -is [array]) { $prd } else { @() }
            
            $data.prd = @{
                total = $items.Count
                passed = ($items | Where-Object { $_.passes -eq $true }).Count
                pending = ($items | Where-Object { $_.passes -ne $true }).Count
            }
        } catch {}
    }
    
    # Get metrics
    $data.metrics = Get-Metrics -ProjectRoot $ProjectRoot
    
    # Get context summary
    foreach ($agentName in @("pm", "developer", "qa")) {
        $usage = Get-ContextUsage -AgentName $agentName -ProjectRoot $ProjectRoot
        $data.contextSummary[$agentName] = $usage
    }
    
    return $data
}

# ============================================================================
# DISPLAY FUNCTIONS
# ============================================================================

function Show-Dashboard {
    param($Data)
    
    Clear-Host
    
    # Header
    Write-Header "RALPH WIGGUM - Multi-Agent Development System"
    
    Write-Host "  Updated: $($Data.timestamp)" -ForegroundColor DarkGray
    
    # Session Status
    if ($Data.state) {
        $status = $Data.state.status ?? "unknown"
        $statusColor = Get-StatusColor -Status $status
        $iteration = $Data.state.iteration ?? 0
        $maxIter = $Data.state.maxIterations ?? 200
        
        Write-Host ""
        Write-Host "  Session: " -NoNewline
        Write-Host $($Data.state.sessionId ?? "N/A") -ForegroundColor White
        Write-Host "  Status:  " -NoNewline
        Write-Host $status.ToUpper() -ForegroundColor $statusColor
        Write-Host "  Progress: $iteration / $maxIter iterations"
    } else {
        Write-Host ""
        Write-Host "  No active session" -ForegroundColor DarkGray
    }
    
    # Agent Status Table
    Write-Section "AGENTS"
    
    Write-Host ""
    Write-Host ("  {0,-12} {1,-10} {2,-12} {3,-10} {4,-8} {5,-10}" -f "Agent", "Status", "Last Seen", "Health", "Iter", "PID") -ForegroundColor Gray
    Write-Host "  " + ("─" * 62)
    
    foreach ($agentName in @("pm", "developer", "qa")) {
        $agent = $Data.agents[$agentName]
        
        if (-not $agent) {
            Write-Host ("  {0,-12} {1,-10}" -f $agentName, "N/A") -ForegroundColor DarkGray
            continue
        }
        
        $statusColor = Get-StatusColor -Status $agent.status
        
        $healthColor = switch ($agent.health) {
            "HEALTHY" { "Green" }
            "WARNING" { "Yellow" }
            "STALE" { "Red" }
            "OFFLINE" { "DarkGray" }
            default { "Gray" }
        }
        
        $lastSeenDisplay = if ($agent.elapsed -lt 60) {
            "$([int]$agent.elapsed)s ago"
        } elseif ($agent.elapsed -lt 3600) {
            "$([int]($agent.elapsed / 60))m ago"
        } elseif ($agent.elapsed -lt 9999) {
            "$([int]($agent.elapsed / 3600))h ago"
        } else {
            "Never"
        }
        
        $iterDisplay = if ($agent.iteration) { $agent.iteration } else { "-" }
        $pidDisplay = if ($agent.pid) { $agent.pid } else { "-" }
        
        Write-Host ("  {0,-12} " -f $agentName) -NoNewline
        Write-Host ("{0,-10} " -f ($agent.status ?? "offline")) -NoNewline -ForegroundColor $statusColor
        Write-Host ("{0,-12} " -f $lastSeenDisplay) -NoNewline
        Write-Host ("{0,-10} " -f $agent.health) -NoNewline -ForegroundColor $healthColor
        Write-Host ("{0,-8} " -f $iterDisplay) -NoNewline
        Write-Host ("{0,-10}" -f $pidDisplay)
    }
    
    # Current Task
    if ($Data.currentTask) {
        Write-Section "CURRENT TASK"
        
        $task = $Data.currentTask
        $taskStatus = $task.status ?? "unknown"
        $taskStatusColor = Get-StatusColor -Status $taskStatus
        
        Write-Host ""
        Write-Host "  ID:       $($task.prdId ?? $task.id ?? 'N/A')"
        Write-Host "  Title:    $($task.title ?? 'N/A')"
        Write-Host "  Assigned: $($task.assignedTo ?? 'N/A')"
        Write-Host "  Status:   " -NoNewline
        Write-Host $taskStatus -ForegroundColor $taskStatusColor
    }
    
    # PRD Progress
    if ($Data.prd) {
        Write-Section "PRD PROGRESS"
        
        $prd = $Data.prd
        $progressPct = if ($prd.total -gt 0) { [int](($prd.passed / $prd.total) * 100) } else { 0 }
        $barWidth = 40
        $filledWidth = [int](($progressPct / 100) * $barWidth)
        $emptyWidth = $barWidth - $filledWidth
        
        $progressBar = "[" + ("█" * $filledWidth) + ("░" * $emptyWidth) + "]"
        
        Write-Host ""
        Write-Host "  $progressBar $progressPct%"
        Write-Host "  Passed: $($prd.passed) / $($prd.total)  |  Pending: $($prd.pending)"
    }
    
    # Context Usage
    if (-not $Compact) {
        Write-Section "CONTEXT USAGE"
        
        Write-Host ""
        foreach ($agentName in @("pm", "developer", "qa")) {
            $ctx = $Data.contextSummary[$agentName]
            if ($ctx) {
                $pct = $ctx.percent ?? 0
                $barWidth = 20
                $filledWidth = [int](($pct / 100) * $barWidth)
                $emptyWidth = $barWidth - $filledWidth
                
                $barColor = if ($pct -ge 70) { "Red" } elseif ($pct -ge 50) { "Yellow" } else { "Green" }
                
                $bar = "[" + ("█" * $filledWidth) + ("░" * $emptyWidth) + "]"
                
                Write-Host ("  {0,-12} " -f $agentName) -NoNewline
                Write-Host $bar -NoNewline -ForegroundColor $barColor
                Write-Host " $pct%"
            }
        }
    }
    
    # Metrics Summary
    if ($Data.metrics -and -not $Compact) {
        Write-Section "METRICS"
        
        $m = $Data.metrics.aggregates
        
        Write-Host ""
        Write-Host "  Tasks: $($m.completedTasks)/$($m.totalTasks) completed  |  Failed: $($m.failedTasks)  |  Pass Rate: $([int]($m.validationPassRate * 100))%"
        Write-Host "  Iterations: $($m.totalIterations)  |  Context Resets: $($m.totalResets)  |  Avg Task Time: $(Format-Duration -Seconds $m.avgTaskTimeSeconds)"
    }
    
    # Footer
    Write-Host ""
    Write-Host "  ─────────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "  Press Ctrl+C to exit  |  Refreshing every ${RefreshSeconds}s" -ForegroundColor DarkGray
}

# ============================================================================
# MAIN LOOP
# ============================================================================

Write-Host "Starting Ralph Dashboard..." -ForegroundColor Cyan
Write-Host "Project: $ProjectRoot"
Write-Host ""

if ($Continuous) {
    while ($true) {
        $data = Get-DashboardData
        Show-Dashboard -Data $data
        Start-Sleep -Seconds $RefreshSeconds
    }
} else {
    $data = Get-DashboardData
    Show-Dashboard -Data $data
}
