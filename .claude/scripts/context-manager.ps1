# Ralph Context Manager (PowerShell)
# Provides context window estimation and reset management
# Uses token counting approximation for better accuracy than file size
#
# Usage:
#   . "$PSScriptRoot\context-manager.ps1"
#   $usage = Get-ContextUsage -AgentName "developer"
#   if ($usage.percent -gt 70) { Request-ContextReset -AgentName "developer" }

# Source configuration if not already loaded
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not (Get-Command "Get-RalphConfig" -ErrorAction SilentlyContinue)) {
    . "$scriptDir\ralph-config.ps1"
}

# ============================================================================
# CONTEXT ESTIMATION
# ============================================================================

# Approximate tokens based on character count
# Average English: ~4 chars per token, code: ~3.5 chars per token
$Script:CharsPerToken = 3.5

# Claude's context window (approximate)
$Script:MaxContextTokens = 200000

function Get-TokenEstimate {
    <#
    .SYNOPSIS
    Estimates token count from text or file.
    #>
    param(
        [string]$Text = "",
        [string]$FilePath = ""
    )
    
    if ($FilePath -and (Test-Path $FilePath)) {
        $Text = Get-Content $FilePath -Raw -ErrorAction SilentlyContinue
    }
    
    if (-not $Text) { return 0 }
    
    return [int]($Text.Length / $Script:CharsPerToken)
}

function Get-ContextUsage {
    <#
    .SYNOPSIS
    Estimates current context window usage for an agent.
    
    .DESCRIPTION
    Tracks cumulative token usage by counting:
    - Session state files
    - Progress logs
    - Agent-specific output
    - Iteration count (proxy for conversation length)
    
    .PARAMETER AgentName
    The agent to check context for.
    
    .PARAMETER ProjectRoot
    Project root directory.
    
    .RETURNS
    Object with: tokens (estimated), percent (of max), isHigh (>threshold)
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$AgentName,
        [string]$ProjectRoot = (Get-Location).Path
    )
    
    $config = Get-RalphConfig
    $paths = Get-RalphPaths -ProjectRoot $ProjectRoot
    
    $totalTokens = 0
    
    # Count tokens in session files
    $sessionFiles = @(
        $paths.CoordinatorState,
        $paths.CurrentTask,
        $paths.HandoffLog,
        (Join-Path $paths.SessionDir "agent-$AgentName.json"),
        (Join-Path $paths.SessionDir "$AgentName-last-promise.txt")
    )
    
    foreach ($file in $sessionFiles) {
        if (Test-Path $file) {
            $totalTokens += Get-TokenEstimate -FilePath $file
        }
    }
    
    # Count progress log tokens
    $progressFile = Join-Path $paths.SessionDir "coordinator-progress.txt"
    if (Test-Path $progressFile) {
        $totalTokens += Get-TokenEstimate -FilePath $progressFile
    }
    
    # Get iteration count from state
    $state = Get-CoordinatorState -ProjectRoot $ProjectRoot
    $iteration = if ($state -and $state.iteration) { $state.iteration } else { 1 }
    
    # Estimate conversation tokens based on iteration
    # Each iteration adds approximately 2000-5000 tokens of conversation
    $conversationTokensPerIteration = 3500
    $estimatedConversationTokens = $iteration * $conversationTokensPerIteration
    
    $totalTokens += $estimatedConversationTokens
    
    # Calculate percentage
    $percent = [int](($totalTokens / $Script:MaxContextTokens) * 100)
    $percent = [Math]::Min(100, $percent)
    
    return @{
        tokens = $totalTokens
        maxTokens = $Script:MaxContextTokens
        percent = $percent
        iteration = $iteration
        isHigh = ($percent -ge $config.ContextResetThreshold)
        threshold = $config.ContextResetThreshold
    }
}

# ============================================================================
# CONTEXT TRACKING
# ============================================================================

function Get-ContextTrackingFile {
    param(
        [string]$AgentName,
        [string]$ProjectRoot = (Get-Location).Path
    )
    
    $paths = Get-RalphPaths -ProjectRoot $ProjectRoot
    return Join-Path $paths.SessionDir "$AgentName-context-tracking.json"
}

function Initialize-ContextTracking {
    <#
    .SYNOPSIS
    Initializes context tracking for an agent.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$AgentName,
        [string]$ProjectRoot = (Get-Location).Path
    )
    
    $trackingFile = Get-ContextTrackingFile -AgentName $AgentName -ProjectRoot $ProjectRoot
    
    $tracking = @{
        agent = $AgentName
        startedAt = Get-Timestamp
        iteration = 0
        resetCount = 0
        cumulativeTokens = 0
        lastResetAt = $null
    }
    
    $tracking | ConvertTo-Json -Depth 5 | Out-File -FilePath $trackingFile -Encoding utf8
    
    return $tracking
}

function Update-ContextTracking {
    <#
    .SYNOPSIS
    Updates context tracking after each iteration.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$AgentName,
        [int]$TokensUsed = 0,
        [string]$ProjectRoot = (Get-Location).Path
    )
    
    $trackingFile = Get-ContextTrackingFile -AgentName $AgentName -ProjectRoot $ProjectRoot
    
    $tracking = $null
    if (Test-Path $trackingFile) {
        try {
            $tracking = Get-Content $trackingFile -Raw | ConvertFrom-Json
        } catch {}
    }
    
    if (-not $tracking) {
        $tracking = Initialize-ContextTracking -AgentName $AgentName -ProjectRoot $ProjectRoot
    }
    
    # Update tracking
    $tracking.iteration++
    $tracking.cumulativeTokens += $TokensUsed
    $tracking.lastUpdated = Get-Timestamp
    
    $tracking | ConvertTo-Json -Depth 5 | Out-File -FilePath $trackingFile -Encoding utf8
    
    return $tracking
}

function Record-ContextReset {
    <#
    .SYNOPSIS
    Records that a context reset occurred.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$AgentName,
        [string]$Reason = "threshold",
        [string]$ProjectRoot = (Get-Location).Path
    )
    
    $trackingFile = Get-ContextTrackingFile -AgentName $AgentName -ProjectRoot $ProjectRoot
    $paths = Get-RalphPaths -ProjectRoot $ProjectRoot
    
    $tracking = $null
    if (Test-Path $trackingFile) {
        try {
            $tracking = Get-Content $trackingFile -Raw | ConvertFrom-Json
        } catch {}
    }
    
    if (-not $tracking) {
        $tracking = Initialize-ContextTracking -AgentName $AgentName -ProjectRoot $ProjectRoot
    }
    
    $tracking.resetCount++
    $tracking.lastResetAt = Get-Timestamp
    $tracking.lastResetReason = $Reason
    $tracking.iteration = 0  # Reset iteration counter
    $tracking.cumulativeTokens = 0
    
    $tracking | ConvertTo-Json -Depth 5 | Out-File -FilePath $trackingFile -Encoding utf8
    
    # Also update the reset count file for backward compatibility
    $resetCountFile = Join-Path $paths.SessionDir "$AgentName-reset-count.txt"
    "$($tracking.resetCount)" | Out-File -FilePath $resetCountFile -Encoding utf8
    
    Write-RalphLog "Context reset recorded for $AgentName (reset #$($tracking.resetCount), reason: $Reason)" -Level "INFO" -Agent $AgentName -Color Cyan
    
    return $tracking
}

# ============================================================================
# CONTEXT RESET REQUEST
# ============================================================================

function Request-ContextReset {
    <#
    .SYNOPSIS
    Signals that a context reset should occur.
    
    .DESCRIPTION
    Creates a reset request file that the agent loop will detect.
    The agent should save state and emit <promise>CONTEXT_RESET</promise>.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$AgentName,
        [string]$Reason = "threshold_reached",
        [string]$ProjectRoot = (Get-Location).Path
    )
    
    $paths = Get-RalphPaths -ProjectRoot $ProjectRoot
    $resetRequestFile = Join-Path $paths.SessionDir "$AgentName-reset-request.json"
    
    $request = @{
        agent = $AgentName
        requestedAt = Get-Timestamp
        reason = $Reason
    }
    
    $request | ConvertTo-Json -Depth 5 | Out-File -FilePath $resetRequestFile -Encoding utf8
    
    Write-RalphLog "Context reset requested for $AgentName (reason: $Reason)" -Level "WARN" -Agent "CONTEXT" -Color Yellow
    
    return $request
}

function Test-ContextResetRequested {
    <#
    .SYNOPSIS
    Checks if a context reset has been requested for an agent.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$AgentName,
        [string]$ProjectRoot = (Get-Location).Path
    )
    
    $paths = Get-RalphPaths -ProjectRoot $ProjectRoot
    $resetRequestFile = Join-Path $paths.SessionDir "$AgentName-reset-request.json"
    
    return Test-Path $resetRequestFile
}

function Clear-ContextResetRequest {
    <#
    .SYNOPSIS
    Clears a pending context reset request.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$AgentName,
        [string]$ProjectRoot = (Get-Location).Path
    )
    
    $paths = Get-RalphPaths -ProjectRoot $ProjectRoot
    $resetRequestFile = Join-Path $paths.SessionDir "$AgentName-reset-request.json"
    
    if (Test-Path $resetRequestFile) {
        Remove-Item $resetRequestFile -Force
    }
}

# ============================================================================
# PROACTIVE CONTEXT MANAGEMENT
# ============================================================================

function Test-ShouldResetContext {
    <#
    .SYNOPSIS
    Determines if context should be reset based on usage.
    
    .DESCRIPTION
    Checks if context usage exceeds threshold.
    Called by agent loop to decide when to trigger reset.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$AgentName,
        [string]$ProjectRoot = (Get-Location).Path
    )
    
    $usage = Get-ContextUsage -AgentName $AgentName -ProjectRoot $ProjectRoot
    
    if ($usage.isHigh) {
        Write-RalphLog "Context at $($usage.percent)% (threshold: $($usage.threshold)%) - reset recommended" -Level "WARN" -Agent $AgentName -Color Yellow
        return $true
    }
    
    return $false
}

function Get-ContextSummary {
    <#
    .SYNOPSIS
    Gets a human-readable summary of context status for all agents.
    #>
    param([string]$ProjectRoot = (Get-Location).Path)
    
    $summary = @{}
    
    foreach ($agentName in @("pm", "developer", "qa")) {
        $usage = Get-ContextUsage -AgentName $agentName -ProjectRoot $ProjectRoot
        $tracking = $null
        
        $trackingFile = Get-ContextTrackingFile -AgentName $agentName -ProjectRoot $ProjectRoot
        if (Test-Path $trackingFile) {
            try {
                $tracking = Get-Content $trackingFile -Raw | ConvertFrom-Json
            } catch {}
        }
        
        $summary[$agentName] = @{
            usage = $usage
            tracking = $tracking
            resetRequested = Test-ContextResetRequested -AgentName $agentName -ProjectRoot $ProjectRoot
        }
    }
    
    return $summary
}
