# Ralph Message Queue System
# Event-driven communication between agents
# All messages go through this queue, watchdog routes them

# ============================================================================
# MESSAGE TYPES
# ============================================================================
# task_assign        - PM assigns task to Developer
# validation_request - Developer requests QA validation
# bug_report         - QA reports bugs to Developer (via PM for priority)
# task_complete      - QA confirms task passed
# question           - Any agent asks another for clarification
# answer             - Response to a question
# research_update    - PM shares research findings
# regression_request - PM requests QA regression testing
# prd_update         - PM updates PRD/specs
# status_update      - Agent reports current status
# priority_review    - Request PM to prioritize something

# ============================================================================
# CONFIGURATION
# ============================================================================

$Script:MessageQueueDir = $null
$Script:MessageQueueSilent = $false  # Set to $true to suppress console output

function Set-MessageQueueSilent {
    param([bool]$Silent = $true)
    $Script:MessageQueueSilent = $Silent
}

function Initialize-MessageQueue {
    param(
        [Parameter(Mandatory=$true)]
        [string]$SessionDir
    )

    $Script:MessageQueueDir = Join-Path $SessionDir "messages"

    # Create base directory
    if (-not (Test-Path $Script:MessageQueueDir)) {
        New-Item -ItemType Directory -Path $Script:MessageQueueDir -Force | Out-Null
    }

    # Create inbox folders for each agent
    foreach ($agent in @("pm", "developer", "qa", "watchdog")) {
        $inbox = Join-Path $Script:MessageQueueDir $agent
        if (-not (Test-Path $inbox)) {
            New-Item -ItemType Directory -Path $inbox -Force | Out-Null
        }
    }

    # Initialize consolidation mode
    Initialize-ConsolidationMode -SessionDir $SessionDir

    # Silent - no console output
}

# ============================================================================
# MESSAGE FUNCTIONS
# ============================================================================

function New-MessageId {
    return "msg-$(Get-Date -Format 'yyyyMMdd-HHmmss')-$([guid]::NewGuid().ToString().Substring(0,8))"
}

function Send-AgentMessage {
    <#
    .SYNOPSIS
    Send a message to another agent's inbox
    
    .PARAMETER From
    Sender agent name (pm, developer, qa)
    
    .PARAMETER To
    Recipient agent name (pm, developer, qa, watchdog)
    
    .PARAMETER Type
    Message type (task_assign, validation_request, bug_report, etc.)
    
    .PARAMETER Payload
    Hashtable with message-specific data
    
    .PARAMETER Priority
    Message priority (low, normal, high, urgent)
    
    .PARAMETER ReplyTo
    Optional message ID this is replying to
    #>
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("pm", "developer", "qa", "watchdog")]
        [string]$From,
        
        [Parameter(Mandatory=$true)]
        [ValidateSet("pm", "developer", "qa", "watchdog")]
        [string]$To,
        
        [Parameter(Mandatory=$true)]
        [ValidateSet(
            "task_assign", "validation_request", "bug_report", "task_complete",
            "question", "answer", "research_update", "regression_request",
            "prd_update", "status_update", "priority_review", "agent_ready",
            "work_complete", "error", "shutdown"
        )]
        [string]$Type,
        
        [Parameter(Mandatory=$true)]
        [hashtable]$Payload,
        
        [ValidateSet("low", "normal", "high", "urgent")]
        [string]$Priority = "normal",
        
        [string]$ReplyTo = $null
    )
    
    if (-not $Script:MessageQueueDir) {
        throw "Message queue not initialized. Call Initialize-MessageQueue first."
    }
    
    $messageId = New-MessageId
    
    $message = @{
        id = $messageId
        from = $From
        to = $To
        type = $Type
        priority = $Priority
        payload = $Payload
        timestamp = [DateTime]::UtcNow.ToString("o")
        status = "pending"
        replyTo = $ReplyTo
    }
    
    # Write to recipient's inbox using atomic write pattern (write to .tmp, then rename)
    # This prevents partial reads by other processes during write
    $inbox = Join-Path $Script:MessageQueueDir $To
    $filePath = Join-Path $inbox "$messageId.json"
    $tempPath = Join-Path $inbox "$messageId.json.tmp"
    
    try {
        $message | ConvertTo-Json -Depth 10 | Out-File -FilePath $tempPath -Encoding UTF8
        Move-Item -Path $tempPath -Destination $filePath -Force
    } catch {
        # Cleanup temp file on failure
        if (Test-Path $tempPath) { Remove-Item $tempPath -Force -ErrorAction SilentlyContinue }
        throw
    }
    
    # Silent - logging handled by caller
    
    return $messageId
}

function Get-PendingMessages {
    <#
    .SYNOPSIS
    Get all pending messages for an agent
    
    .PARAMETER Agent
    Agent name to get messages for
    
    .PARAMETER Type
    Optional filter by message type
    
    .PARAMETER Priority
    Optional filter by priority (returns this and higher)
    #>
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("pm", "developer", "qa", "watchdog")]
        [string]$Agent,
        
        [string]$Type = $null,
        
        [ValidateSet("low", "normal", "high", "urgent")]
        [string]$MinPriority = "low"
    )
    
    if (-not $Script:MessageQueueDir) {
        throw "Message queue not initialized."
    }
    
    $inbox = Join-Path $Script:MessageQueueDir $Agent
    if (-not (Test-Path $inbox)) { return @() }
    
    # Migration: cleanup any orphaned .tmp files from failed atomic writes
    Get-ChildItem -Path $inbox -Filter "*.json.tmp" -ErrorAction SilentlyContinue | ForEach-Object {
        $age = ([DateTime]::UtcNow - $_.LastWriteTimeUtc).TotalSeconds
        if ($age -gt 30) {
            # Stale temp file - remove it
            Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
        }
    }
    
    $priorityOrder = @{ "low" = 0; "normal" = 1; "high" = 2; "urgent" = 3 }
    $minPriorityValue = $priorityOrder[$MinPriority]
    
    $messages = @()
    $corruptFiles = @()
    
    Get-ChildItem -Path $inbox -Filter "*.json" -ErrorAction SilentlyContinue | ForEach-Object {
        # Skip temp files (shouldn't match *.json but be safe)
        if ($_.Name -match '\.tmp$') { return }
        
        try {
            # Read with retry for race condition safety
            $retries = 3
            $content = $null
            for ($i = 0; $i -lt $retries; $i++) {
                try {
                    $rawContent = Get-Content $_.FullName -Raw -ErrorAction Stop
                    if ([string]::IsNullOrWhiteSpace($rawContent)) {
                        # File may be in middle of write - wait and retry
                        Start-Sleep -Milliseconds 50
                        continue
                    }
                    $content = $rawContent | ConvertFrom-Json -ErrorAction Stop
                    break
                } catch {
                    if ($i -lt $retries - 1) { Start-Sleep -Milliseconds 50 }
                }
            }
            
            if (-not $content) {
                $corruptFiles += $_.FullName
                return
            }
            
            # Filter by status
            if ($content.status -ne "pending") { return }
            
            # Filter by type if specified
            if ($Type -and $content.type -ne $Type) { return }
            
            # Filter by priority
            $msgPriority = $priorityOrder[$content.priority]
            if ($msgPriority -lt $minPriorityValue) { return }
            
            # Add file path for acknowledgment
            $content | Add-Member -NotePropertyName "_filePath" -NotePropertyValue $_.FullName -Force
            
            $messages += $content
        } catch {
            $corruptFiles += $_.FullName
        }
    }
    
    # Move corrupt files to quarantine for debugging
    if ($corruptFiles.Count -gt 0) {
        $quarantine = Join-Path $Script:MessageQueueDir "quarantine"
        if (-not (Test-Path $quarantine)) {
            New-Item -ItemType Directory -Path $quarantine -Force | Out-Null
        }
        foreach ($file in $corruptFiles) {
            $dest = Join-Path $quarantine (Split-Path $file -Leaf)
            Move-Item -Path $file -Destination $dest -Force -ErrorAction SilentlyContinue
        }
    }
    
    # Sort by priority (highest first), then by timestamp (oldest first)
    $messages = $messages | Sort-Object -Property @(
        @{ Expression = { $priorityOrder[$_.priority] }; Descending = $true },
        @{ Expression = { $_.timestamp }; Descending = $false }
    )
    
    return $messages
}

function Get-MessageById {
    param(
        [Parameter(Mandatory=$true)]
        [string]$MessageId,
        
        [string]$Agent = $null
    )
    
    if (-not $Script:MessageQueueDir) {
        throw "Message queue not initialized."
    }
    
    # Search in specific agent's inbox or all inboxes
    $searchPaths = @()
    if ($Agent) {
        $searchPaths += Join-Path $Script:MessageQueueDir $Agent
    } else {
        $searchPaths += Get-ChildItem -Path $Script:MessageQueueDir -Directory | Select-Object -ExpandProperty FullName
    }
    
    foreach ($path in $searchPaths) {
        $filePath = Join-Path $path "$MessageId.json"
        if (Test-Path $filePath) {
            $content = Get-Content $filePath -Raw | ConvertFrom-Json
            $content | Add-Member -NotePropertyName "_filePath" -NotePropertyValue $filePath -Force
            return $content
        }
    }

    return $null
}

function Set-MessageStatus {
    <#
    .SYNOPSIS
    Update a message's status
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$MessageId,

        [Parameter(Mandatory=$true)]
        [ValidateSet("pending", "processing", "completed", "failed")]
        [string]$Status,

        [string]$Agent = $null
    )

    $message = Get-MessageById -MessageId $MessageId -Agent $Agent
    if (-not $message) {
        # Silent - message not found
        return $false
    }

    $message.status = $Status

    if ($Status -eq "completed") {
        # Delete immediately - no archiving
        if ($message._filePath -and (Test-Path $message._filePath)) {
            Remove-Item $message._filePath -Force
        }
    } else {
        # Update in place
        if ($message._filePath -and (Test-Path $message._filePath)) {
            $message.PSObject.Properties.Remove('_filePath')
            $message | ConvertTo-Json -Depth 10 | Out-File -FilePath $message._filePath -Encoding UTF8
        }
    }

    return $true
}

function Invoke-AcknowledgeMessage {
    <#
    .SYNOPSIS
    Mark a message as processed (completed) and delete it

    .PARAMETER MessageId
    The ID of the message to acknowledge

    .PARAMETER Agent
    The agent to search for the message (optional)

    .PARAMETER Result
    Optional result data to attach to the message

    .RETURNS
    $true if acknowledged successfully, $false otherwise
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$MessageId,

        [string]$Agent = $null,

        [hashtable]$Result = @{}
    )

    $message = Get-MessageById -MessageId $MessageId -Agent $Agent
    if (-not $message) {
        return $false
    }

    # Store file path for deletion
    $filePath = $message._filePath

    # Add result and completion timestamp
    $message | Add-Member -NotePropertyName "result" -NotePropertyValue $Result -Force
    $message | Add-Member -NotePropertyName "completedAt" -NotePropertyValue ([DateTime]::UtcNow.ToString("o")) -Force
    $message.status = "completed"

    # Log to session messages.log before deletion (optional audit trail)
    $sessionDir = Split-Path $Script:MessageQueueDir -Parent
    $messageLogFile = Join-Path $sessionDir "messages.log"
    $logEntry = @{
        timestamp = [DateTime]::UtcNow.ToString("o")
        messageId = $message.id
        type = $message.type
        from = $message.from
        to = $message.to
        completedAt = $message.completedAt
    } | ConvertTo-Json -Compress
    $logEntry | Out-File -FilePath $messageLogFile -Append -Encoding utf8 -ErrorAction SilentlyContinue

    # Delete immediately - message is processed
    # Use retry logic to handle file locks
    if ($filePath -and (Test-Path $filePath)) {
        $deleted = $false
        for ($i = 0; $i -lt 3; $i++) {
            try {
                Remove-Item $filePath -Force -ErrorAction Stop
                $deleted = $true
                break
            } catch {
                if ($i -lt 2) {
                    Start-Sleep -Milliseconds 100
                }
            }
        }
        if (-not $deleted) {
            # Failed to delete - rename to .failed for cleanup
            try {
                $failedPath = $filePath + ".failed"
                Move-Item -Path $filePath -Destination $failedPath -Force -ErrorAction SilentlyContinue
            } catch {
                # Last resort - leave the file but it won't be picked up again due to status change
            }
        }
    }

    # Silent - acknowledgment logged by caller
    return $true
}

function Get-MessageCount {
    <#
    .SYNOPSIS
    Get count of pending messages per agent
    #>
    param()
    
    if (-not $Script:MessageQueueDir) { return @{} }
    
    $counts = @{}
    
    foreach ($agent in @("pm", "developer", "qa", "watchdog")) {
        $inbox = Join-Path $Script:MessageQueueDir $agent
        if (Test-Path $inbox) {
            $counts[$agent] = (Get-ChildItem -Path $inbox -Filter "*.json" -ErrorAction SilentlyContinue | Measure-Object).Count
        } else {
            $counts[$agent] = 0
        }
    }
    
    return $counts
}

function Clear-MessageQueue {
    <#
    .SYNOPSIS
    Clear all messages (for testing/reset)
    #>
    param()

    if (-not $Script:MessageQueueDir) { return }

    foreach ($agent in @("pm", "developer", "qa", "watchdog")) {
        $inbox = Join-Path $Script:MessageQueueDir $agent
        if (Test-Path $inbox) {
            Get-ChildItem -Path $inbox -Filter "*.json" | Remove-Item -Force
        }
    }

    # Silent - clear logged by caller
}

# ============================================================================
# CONVENIENCE FUNCTIONS FOR COMMON MESSAGE TYPES
# ============================================================================

function Send-TaskAssignment {
    param(
        [Parameter(Mandatory=$true)]
        [string]$TaskId,
        
        [Parameter(Mandatory=$true)]
        [string]$Title,
        
        [Parameter(Mandatory=$true)]
        [string]$Description,
        
        [string[]]$AcceptanceCriteria = @(),
        
        [string]$Worktree = $null,
        
        [string]$Priority = "normal"
    )
    
    $payload = @{
        taskId = $TaskId
        title = $Title
        description = $Description
        acceptanceCriteria = $AcceptanceCriteria
        worktree = $Worktree
    }
    
    return Send-AgentMessage -From "pm" -To "developer" -Type "task_assign" -Payload $payload -Priority $Priority
}

function Send-ValidationRequest {
    param(
        [Parameter(Mandatory=$true)]
        [string]$TaskId,
        
        [Parameter(Mandatory=$true)]
        [string]$Description,
        
        [string]$Branch = $null,
        
        [string]$Worktree = $null,
        
        [string]$Priority = "normal"
    )
    
    $payload = @{
        taskId = $TaskId
        description = $Description
        branch = $Branch
        worktree = $Worktree
    }
    
    return Send-AgentMessage -From "developer" -To "qa" -Type "validation_request" -Payload $payload -Priority $Priority
}

function Send-BugReport {
    param(
        [Parameter(Mandatory=$true)]
        [string]$TaskId,
        
        [Parameter(Mandatory=$true)]
        [string[]]$Bugs,
        
        [string]$Severity = "normal"
    )
    
    # Bug reports go to PM for priority decision
    $payload = @{
        taskId = $TaskId
        bugs = $Bugs
        severity = $Severity
        recommendedAction = "fix_required"
    }
    
    return Send-AgentMessage -From "qa" -To "pm" -Type "bug_report" -Payload $payload -Priority $Severity
}

function Send-TaskComplete {
    param(
        [Parameter(Mandatory=$true)]
        [string]$TaskId,
        
        [string]$Summary = ""
    )
    
    $payload = @{
        taskId = $TaskId
        summary = $Summary
        validationPassed = $true
    }
    
    return Send-AgentMessage -From "qa" -To "pm" -Type "task_complete" -Payload $payload -Priority "normal"
}

function Send-Question {
    param(
        [Parameter(Mandatory=$true)]
        [string]$From,
        
        [Parameter(Mandatory=$true)]
        [string]$To,
        
        [Parameter(Mandatory=$true)]
        [string]$Question,
        
        [string]$Context = "",
        
        [string]$TaskId = $null
    )
    
    $payload = @{
        question = $Question
        context = $Context
        taskId = $TaskId
    }
    
    return Send-AgentMessage -From $From -To $To -Type "question" -Payload $payload -Priority "high"
}

function Send-Answer {
    param(
        [Parameter(Mandatory=$true)]
        [string]$From,
        
        [Parameter(Mandatory=$true)]
        [string]$To,
        
        [Parameter(Mandatory=$true)]
        [string]$Answer,
        
        [Parameter(Mandatory=$true)]
        [string]$ReplyTo
    )
    
    $payload = @{
        answer = $Answer
    }
    
    return Send-AgentMessage -From $From -To $To -Type "answer" -Payload $payload -Priority "high" -ReplyTo $ReplyTo
}

function Send-StatusUpdate {
    param(
        [Parameter(Mandatory=$true)]
        [string]$From,
        
        [Parameter(Mandatory=$true)]
        [ValidateSet("idle", "working", "waiting", "error", "completed")]
        [string]$Status,
        
        [string]$CurrentTask = $null,
        
        [string]$Details = ""
    )
    
    $payload = @{
        status = $Status
        currentTask = $CurrentTask
        details = $Details
    }
    
    return Send-AgentMessage -From $From -To "watchdog" -Type "status_update" -Payload $payload -Priority "low"
}

# ============================================================================
# CONSOLIDATION MODE
# ============================================================================
# Consolidation mode allows PM to review all pending messages on startup/restart
# before any workers begin processing. This ensures PM is the source of truth.

$Script:ConsolidationModeFile = $null

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

function Save-ConsolidationState {
    <#
    .SYNOPSIS
    Save consolidation mode state to a persistent location for context reset recovery.
    This ensures consolidation mode survives context resets.

    .PARAMETER SessionDir
    The session directory path.

    .RETURNS
    $true if saved successfully, $false otherwise.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$SessionDir
    )

    $consolidationModeFile = Join-Path $SessionDir "consolidation-mode.json"
    if (-not (Test-Path $consolidationModeFile)) {
        return $false
    }

    try {
        $mode = Get-Content $consolidationModeFile -Raw | ConvertFrom-Json

        # Save to a location that survives context resets
        $persistentStateDir = Join-Path $SessionDir "persistent-state"
        if (-not (Test-Path $persistentStateDir)) {
            New-Item -ItemType Directory -Path $persistentStateDir -Force | Out-Null
        }

        $persistentFile = Join-Path $persistentStateDir "consolidation-mode.json"
        $mode | ConvertTo-Json -Depth 10 | Out-File -FilePath $persistentFile -Encoding UTF8

        return $true
    } catch {
        return $false
    }
}

function Restore-ConsolidationState {
    <#
    .SYNOPSIS
    Restore consolidation mode state from persistent storage after context reset.
    This is called when PM agent restarts after a context reset.

    .PARAMETER SessionDir
    The session directory path.

    .RETURNS
    $true if restored successfully, $false otherwise.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$SessionDir
    )

    $persistentStateDir = Join-Path $SessionDir "persistent-state"
    $persistentFile = Join-Path $persistentStateDir "consolidation-mode.json"

    if (-not (Test-Path $persistentFile)) {
        return $false
    }

    try {
        $mode = Get-Content $persistentFile -Raw | ConvertFrom-Json

        # Only restore if we're not already in a different mode
        $currentMode = Get-ConsolidationMode
        if (-not $currentMode -or $currentMode.mode -eq "normal") {
            # Current mode is normal or doesn't exist, safe to restore
            $consolidationModeFile = Join-Path $SessionDir "consolidation-mode.json"
            $mode | ConvertTo-Json -Depth 10 | Out-File -FilePath $consolidationModeFile -Encoding UTF8
            return $true
        }

        return $false
    } catch {
        return $false
    }
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

    # AUTOMATIC PERSISTENCE: Also save to persistent state location for context reset recovery
    # This ensures consolidation mode survives PM agent context resets
    try {
        $sessionDir = Split-Path $Script:ConsolidationModeFile -Parent
        $persistentStateDir = Join-Path $sessionDir "persistent-state"
        if (-not (Test-Path $persistentStateDir)) {
            New-Item -ItemType Directory -Path $persistentStateDir -Force | Out-Null
        }
        $persistentFile = Join-Path $persistentStateDir "consolidation-mode.json"
        $state | ConvertTo-Json -Depth 10 | Out-File -FilePath $persistentFile -Encoding UTF8
    } catch {
        # Log but don't fail - main file was written successfully
    }
}

function Get-ConsolidationMode {
    <#
    .SYNOPSIS
    Get the current consolidation mode state.

    .RETURNS
    The consolidation mode object, or $null if file doesn't exist.
    #>
    param()

    if (-not $Script:ConsolidationModeFile -or -not (Test-Path $Script:ConsolidationModeFile)) {
        return $null
    }

    try {
        $mode = Get-Content $Script:ConsolidationModeFile -Raw | ConvertFrom-Json
        return $mode
    } catch {
        return $null
    }
}

function Get-GlobalMessageState {
    <#
    .SYNOPSIS
    Get a consolidated view of all pending messages across all agents.
    This is used by PM on startup to understand the global state.

    .RETURNS
    A hashtable with:
    - totalMessages: Total count of pending messages
    - byAgent: Messages grouped by recipient agent
    - allMessages: All messages sorted by priority (high to low), then timestamp (oldest first)
    #>
    param()

    if (-not $Script:MessageQueueDir) {
        throw "Message queue not initialized. Call Initialize-MessageQueue first."
    }

    $priorityOrder = @{ "low" = 0; "normal" = 1; "high" = 2; "urgent" = 3 }

    $allMessages = @()
    $byAgent = @{
        pm = @()
        developer = @()
        qa = @()
        watchdog = @()
    }

    foreach ($agent in @("pm", "developer", "qa", "watchdog")) {
        $inbox = Join-Path $Script:MessageQueueDir $agent
        if (-not (Test-Path $inbox)) { continue }

        Get-ChildItem -Path $inbox -Filter "*.json" -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                $content = Get-Content $_.FullName -Raw | ConvertFrom-Json
                if ($content.status -eq "pending") {
                    # Add file path for potential operations
                    $content | Add-Member -NotePropertyName "_filePath" -NotePropertyValue $_.FullName -Force

                    $allMessages += $content
                    $byAgent[$agent] += $content
                }
            } catch {
                # Skip corrupt messages
            }
        }
    }

    # Sort by priority (highest first), then by timestamp (oldest first)
    $allMessages = $allMessages | Sort-Object -Property @(
        @{ Expression = { $priorityOrder[$_.priority] }; Descending = $true },
        @{ Expression = { $_.timestamp }; Descending = $false }
    )

    return @{
        totalMessages = $allMessages.Count
        byAgent = $byAgent
        allMessages = $allMessages
    }
}

function Initialize-ConsolidationForStartup {
    <#
    .SYNOPSIS
    Initialize consolidation mode on watchdog startup if there are pending messages.
    This should be called by watchdog before starting any agents.

    .RETURNS
    $true if consolidation was initialized, $false if not needed.
    #>
    param()

    if (-not $Script:MessageQueueDir -or -not $Script:ConsolidationModeFile) {
        return $false
    }

    # Check if there are any pending messages
    $counts = Get-MessageCount
    $totalPending = ($counts.Values | Measure-Object -Sum).Sum

    if ($totalPending -eq 0) {
        # No pending messages, no consolidation needed
        Set-ConsolidationMode -Mode "normal" -Reason "no_pending_messages"
        return $false
    }

    # There are pending messages - set consolidation mode
    Set-ConsolidationMode -Mode "pending_consolidation" -Reason "startup" -Assignments @{
        messageCounts = $counts
    }

    return $true
}

# ============================================================================
# EXPORT
# ============================================================================

# Export functions for dot-sourcing
# Usage: . "$PSScriptRoot\message-queue.ps1"
