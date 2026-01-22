# Ralph Message Queue System
# Event-driven communication between agents
# All messages go through this queue, watchdog routes them

# ============================================================================
# DEPENDENCIES
# ============================================================================

# Source safe-file-io module for timeout-protected file I/O
$safeIoModule = Join-Path $PSScriptRoot "safe-file-io.ps1"
if (Test-Path $safeIoModule) {
    . $safeIoModule
}

# Source message-state-manager for idempotency tracking
$stateManagerModule = Join-Path $PSScriptRoot "message-state-manager.ps1"
if (Test-Path $stateManagerModule) {
    . $stateManagerModule
}

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
    foreach ($agent in @("pm", "developer", "qa", "gamedesigner", "techartist", "watchdog")) {
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
        [ValidateSet("pm", "developer", "qa", "gamedesigner", "techartist", "watchdog")]
        [string]$From,

        [Parameter(Mandatory=$true)]
        [ValidateSet("pm", "developer", "qa", "gamedesigner", "techartist", "watchdog")]
        [string]$To,
        
        [Parameter(Mandatory=$true)]
        [ValidateSet(
            "task_assign", "validation_request", "bug_report", "task_complete",
            "question", "answer", "research_update", "regression_request",
            "prd_update", "status_update", "priority_review", "agent_ready",
            "work_complete", "error", "shutdown",
            "implementation_complete", "work_blocked", "task_abandoned", "quality_concern",
            "retrospective_initiate", "retrospective_contribution", "research_request", "research_response",
            "prd_reorganized", "skill_improvements", "priority_response", "skill_request",
            "gdd_ready", "gdd_update", "design_question", "design_answer",
            "playtest_request", "playtest_report", "mechanic_proposal", "design_guidance",
            "design_guidance_request", "test_plan_request", "test_plan_contribution",
            "asset_assign", "asset_ready", "asset_question", "shader_request", "reference_request"
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
    Get all pending messages for an agent with timeout protection.

    .PARAMETER Agent
    Agent name to get messages for

    .PARAMETER Type
    Optional filter by message type

    .PARAMETER Priority
    Optional filter by priority (returns this and higher)

    .PARAMETER TimeoutMs
    Maximum time to spend processing messages (default: 300ms).
    After timeout, returns whatever messages were processed.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("pm", "developer", "qa", "gamedesigner", "techartist", "watchdog")]
        [string]$Agent,

        [string]$Type = $null,

        [ValidateSet("low", "normal", "high", "urgent")]
        [string]$MinPriority = "low",

        [int]$TimeoutMs = 300
    )

    if (-not $Script:MessageQueueDir) {
        throw "Message queue not initialized."
    }

    $inbox = Join-Path $Script:MessageQueueDir $Agent
    if (-not (Test-Path $inbox)) { return @() }

    # RESILIENCE FIX: Use timeout-protected file enumeration if available
    # This prevents watchdog freeze when message directories are large
    # FIXED: Use Get-Command to check if function exists (Test-Path function: is unreliable)
    if (Get-Command Get-ChildItemWithTimeout -ErrorAction SilentlyContinue) {
        $allFiles = Get-ChildItemWithTimeout -Path $inbox -Filter "*.json" -TimeoutMs 2000 -DefaultValue @()
    } else {
        $allFiles = Get-ChildItem -Path $inbox -Filter "*.json" -ErrorAction SilentlyContinue
    }

    # Start timeout stopwatch
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    # Migration: cleanup any orphaned .tmp files from failed atomic writes
    # Only do this occasionally (every 10th call) to reduce overhead
    if ($Agent -eq "pm" -or (Get-Random -Maximum 10) -eq 0) {
        $allFiles | Where-Object { $_.Name -match '\.tmp$' } | ForEach-Object {
            $age = ([DateTime]::UtcNow - $_.LastWriteTimeUtc).TotalSeconds
            if ($age -gt 30) {
                Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
            }
        }
    }

    $priorityOrder = @{ "low" = 0; "normal" = 1; "high" = 2; "urgent" = 3 }
    $minPriorityValue = $priorityOrder[$MinPriority]

    $messages = @()
    $corruptFiles = @()

    # Process files with timeout protection
    foreach ($fileInfo in $allFiles) {
        # TIMEOUT CHECK: Abort if we've exceeded our time budget
        if ($stopwatch.ElapsedMilliseconds -gt $TimeoutMs) {
            # Return what we have rather than blocking watchdog
            break
        }

        # Skip temp files (shouldn't match *.json but be safe)
        if ($fileInfo.Name -match '\.tmp$') { continue }

        try {
            # Read with retry for race condition safety - but with timeout check
            $retries = 3
            $content = $null
            for ($i = 0; $i -lt $retries; $i++) {
                # Check timeout inside retry loop too
                if ($stopwatch.ElapsedMilliseconds -gt $TimeoutMs) {
                    break
                }

                try {
                    $rawContent = Get-Content $fileInfo.FullName -Raw -ErrorAction Stop
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
                $corruptFiles += $fileInfo.FullName
                continue
            }

            # Filter by status
            if ($content.status -ne "pending") { continue }

            # Filter by type if specified
            if ($Type -and $content.type -ne $Type) { continue }

            # Filter by priority
            $msgPriority = $priorityOrder[$content.priority]
            if ($msgPriority -lt $minPriorityValue) { continue }

            # Add file path for acknowledgment
            $content | Add-Member -NotePropertyName "_filePath" -NotePropertyValue $fileInfo.FullName -Force

            $messages += $content
        } catch {
            $corruptFiles += $fileInfo.FullName
        }
    }

    $stopwatch.Stop()

    # Move corrupt files to quarantine for debugging (async to not block)
    if ($corruptFiles.Count -gt 0) {
        $quarantine = Join-Path $Script:MessageQueueDir "quarantine"
        if (-not (Test-Path $quarantine)) {
            New-Item -ItemType Directory -Path $quarantine -Force | Out-Null
        }

        # Use async job for quarantine to avoid blocking
        Start-Job -ScriptBlock {
            param($files, $quarantine)
            foreach ($file in $files) {
                $dest = Join-Path $quarantine (Split-Path $file -Leaf)
                Move-Item -Path $file -Destination $dest -Force -ErrorAction SilentlyContinue
            }
        } -ArgumentList $corruptFiles, $quarantine -ErrorAction SilentlyContinue | Out-Null
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

# ============================================================================
# SAFE MESSAGE FUNCTIONS (WITH IDEMPOTENCY)
# ============================================================================

function Send-AgentMessageSafe {
    <#
    .SYNOPSIS
    Send a message with idempotency checks.
    Returns $null if message/task was already processed, preventing duplicates.

    .PARAMETER From
    Sender agent name (pm, developer, qa)

    .PARAMETER To
    Recipient agent name (pm, developer, qa, watchdog)

    .PARAMETER Type
    Message type

    .PARAMETER Payload
    Hashtable with message-specific data

    .PARAMETER Priority
    Message priority (default: normal)

    .PARAMETER ReplyTo
    Optional message ID this is replying to

    .RETURNS
    Message ID if sent, $null if skipped (already processed)
    #>
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("pm", "developer", "qa", "gamedesigner", "techartist", "watchdog")]
        [string]$From,

        [Parameter(Mandatory=$true)]
        [ValidateSet("pm", "developer", "qa", "gamedesigner", "techartist", "watchdog")]
        [string]$To,

        [Parameter(Mandatory=$true)]
        [ValidateSet(
            "task_assign", "validation_request", "bug_report", "task_complete",
            "question", "answer", "research_update", "regression_request",
            "prd_update", "status_update", "priority_review", "agent_ready",
            "work_complete", "error", "shutdown",
            "implementation_complete", "work_blocked", "task_abandoned", "quality_concern",
            "retrospective_initiate", "retrospective_contribution", "research_request", "research_response",
            "prd_reorganized", "skill_improvements", "priority_response", "skill_request",
            "gdd_ready", "gdd_update", "design_question", "design_answer",
            "playtest_request", "playtest_report", "mechanic_proposal", "design_guidance",
            "design_guidance_request", "test_plan_request", "test_plan_contribution",
            "asset_assign", "asset_ready", "asset_question", "shader_request", "reference_request"
        )]
        [string]$Type,

        [Parameter(Mandatory=$true)]
        [hashtable]$Payload,

        [ValidateSet("low", "normal", "high", "urgent")]
        [string]$Priority = "normal",

        [string]$ReplyTo = $null
    )

    # Check if this exact message was already processed (reply-to deduplication)
    if ($ReplyTo -and (Get-Command Test-MessageProcessed -ErrorAction SilentlyContinue)) {
        # For reply messages, check if we already replied to this message
        $existingReply = Get-ProcessedMessage -MessageId $ReplyTo
        if ($existingReply -and $existingReply.result -and $existingReply.result.replied) {
            # Already replied to this message - skip
            return $null
        }
    }

    # Check if PM already sent this message type to this agent for this task (deadlock prevention)
    if ($From -eq "pm" -and (Get-Command Test-SentMessageToAgent -ErrorAction SilentlyContinue)) {
        $alreadySent = Test-SentMessageToAgent -To $To -MessageType $Type -TaskId $Payload.taskId
        if ($alreadySent) {
            # PM already sent this message - skip to prevent duplicate
            if (-not $Script:MessageQueueSilent) {
                Write-Host "[Send-AgentMessageSafe] Skipping duplicate: $Type to $to (taskId: $($Payload.taskId))" -ForegroundColor Yellow
            }
            return $null
        }
    }

    # Check if task is already completed (task deduplication)
    $taskId = $Payload.taskId
    if ($taskId -and (Get-Command Test-TaskCompleted -ErrorAction SilentlyContinue)) {
        $taskCompleted = Test-TaskCompleted -TaskId $taskId
        if ($taskCompleted) {
            # Task already completed - skip sending this message
            # Unless this is a bug_report or quality_concern (which can happen after completion)
            if ($Type -notin @("bug_report", "quality_concern", "question")) {
                return $null
            }
        }
    }

    # Send the message
    $actualMessageId = Send-AgentMessage -From $From -To $To -Type $Type -Payload $Payload -Priority $Priority -ReplyTo $ReplyTo

    # Record that PM sent this message (for deduplication on restart)
    if ($actualMessageId -and $From -eq "pm" -and (Get-Command Set-SentMessageToAgent -ErrorAction SilentlyContinue)) {
        Set-SentMessageToAgent -To $To -MessageId $actualMessageId -MessageType $Type -TaskId $Payload.taskId | Out-Null
    }

    return $actualMessageId
}

function Invoke-AcknowledgeMessageSafe {
    <#
    .SYNOPSIS
    Acknowledge a message and record in state (idempotent).
    Safe to call multiple times for the same message.

    .PARAMETER MessageId
    The message ID to acknowledge

    .PARAMETER Agent
    The agent acknowledging (optional)

    .PARAMETER Result
    Result data to attach

    .RETURNS
    $true if newly marked, $false if already existed
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$MessageId,

        [string]$Agent = $null,

        [hashtable]$Result = @{}
    )

    # Mark as processed in state first (idempotent)
    $newlyMarked = $false
    if (Get-Command Set-MessageProcessed -ErrorAction SilentlyContinue) {
        $newlyMarked = Set-MessageProcessed -MessageId $MessageId -Result $Result -FromAgent $Agent
    }

    # Delete the message file
    Invoke-AcknowledgeMessage -MessageId $MessageId -Agent $Agent -Result $Result | Out-Null

    return $newlyMarked
}

function Get-MessageCount {
    <#
    .SYNOPSIS
    Get count of pending messages per agent with timeout protection.
    #>
    param()

    if (-not $Script:MessageQueueDir) { return @{} }

    $counts = @{}
    $useTimeoutProtection = Get-Command Get-FileCountWithTimeout -ErrorAction SilentlyContinue

    foreach ($agent in @("pm", "developer", "qa", "gamedesigner", "techartist", "watchdog")) {
        $inbox = Join-Path $Script:MessageQueueDir $agent

        if (-not (Test-Path $inbox)) {
            $counts[$agent] = 0
            continue
        }

        # Use timeout-protected enumeration if available (prevents watchdog freeze)
        if ($useTimeoutProtection) {
            $counts[$agent] = Get-FileCountWithTimeout -Path $inbox -Filter "*.json" -TimeoutMs 2000 -DefaultValue 0
        } else {
            # Fallback to synchronous count
            $counts[$agent] = (Get-ChildItem -Path $inbox -Filter "*.json" -ErrorAction SilentlyContinue | Measure-Object).Count
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

    foreach ($agent in @("pm", "developer", "qa", "gamedesigner", "techartist", "watchdog")) {
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
# NEW MESSAGE TYPES - Event-Driven Coordination
# ============================================================================

function Send-ImplementationComplete {
    <#
    .SYNOPSIS
    Developer sends this to QA when implementation is complete and ready for validation.

    .PARAMETER TaskId
    The PRD task ID

    .PARAMETER Commit
    The git commit hash of the implementation

    .PARAMETER Summary
    Brief summary of changes
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$TaskId,

        [Parameter(Mandatory=$true)]
        [string]$Commit,

        [string]$Summary = ""
    )

    $payload = @{
        taskId = $TaskId
        commit = $Commit
        summary = $Summary
    }

    return Send-AgentMessage -From "developer" -To "qa" -Type "implementation_complete" -Payload $payload -Priority "high"
}

function Send-WorkBlocked {
    <#
    .SYNOPSIS
    Send when work cannot proceed due to blocker.

    .PARAMETER TaskId
    The PRD task ID

    .PARAMETER Blocker
    Description of what's blocking progress

    .PARAMETER Details
    Additional context about the blocker
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$TaskId,

        [Parameter(Mandatory=$true)]
        [string]$Blocker,

        [string]$Details = ""
    )

    $payload = @{
        taskId = $TaskId
        blocker = $Blocker
        details = $Details
        timestamp = [DateTime]::UtcNow.ToString("o")
    }

    return Send-AgentMessage -From "developer" -To "pm" -Type "work_blocked" -Payload $payload -Priority "urgent"
}

function Send-TaskAbandoned {
    <#
    .SYNOPSIS
    Send when giving up on a task after multiple attempts.

    .PARAMETER TaskId
    The PRD task ID

    .PARAMETER Reason
    Why the task is being abandoned
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$TaskId,

        [Parameter(Mandatory=$true)]
        [string]$Reason
    )

    $payload = @{
        taskId = $TaskId
        reason = $Reason
    }

    return Send-AgentMessage -From "developer" -To "pm" -Type "task_abandoned" -Payload $payload -Priority "urgent"
}

function Send-QualityConcern {
    <#
    .SYNOPSIS
    QA sends this to PM for non-blocking quality concerns.

    .PARAMETER TaskId
    The PRD task ID

    .PARAMETER Concern
    Description of the quality concern

    .PARAMETER Severity
    Severity level (low, medium, high)
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$TaskId,

        [Parameter(Mandatory=$true)]
        [string]$Concern,

        [ValidateSet("low", "medium", "high")]
        [string]$Severity = "medium"
    )

    $payload = @{
        taskId = $TaskId
        concern = $Concern
        severity = $Severity
    }

    return Send-AgentMessage -From "qa" -To "pm" -Type "quality_concern" -Payload $payload -Priority "normal"
}

function Get-AgentMessages {
    <#
    .SYNOPSIS
    Alias for Get-PendingMessages for clarity in agent code.

    .PARAMETER Agent
    Agent name to get messages for

    .PARAMETER Type
    Optional filter by message type

    .PARAMETER MinPriority
    Minimum priority to return
    #>
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("pm", "developer", "qa", "gamedesigner", "techartist", "watchdog")]
        [string]$Agent,

        [string]$Type = $null,

        [ValidateSet("low", "normal", "high", "urgent")]
        [string]$MinPriority = "low"
    )

    return Get-PendingMessages -Agent $Agent -Type $Type -MinPriority $MinPriority
}

function Remove-AgentMessage {
    <#
    .SYNOPSIS
    Delete a processed message from agent's inbox.

    .PARAMETER Agent
    The agent whose inbox contains the message

    .PARAMETER MessageId
    The message ID to delete
    #>
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("pm", "developer", "qa", "gamedesigner", "techartist", "watchdog")]
        [string]$Agent,

        [Parameter(Mandatory=$true)]
        [string]$MessageId
    )

    if (-not $Script:MessageQueueDir) {
        throw "Message queue not initialized."
    }

    $inbox = Join-Path $Script:MessageQueueDir $Agent
    $filePath = Join-Path $inbox "$MessageId.json"

    if (Test-Path $filePath) {
        Remove-Item $filePath -Force -ErrorAction SilentlyContinue
    }
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

    # REMOVED: Persistent-state save functionality
    # Consolidation mode now only lives in memory. If watchdog crashes,
    # the stale state cleanup in watchdog-event.ps1 will clear the mode
    # and PM will re-consolidate on next startup.
    # This prevents getting stuck in consolidation mode from crashed sessions.
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
        gamedesigner = @()
        techartist = @()
        watchdog = @()
    }

    foreach ($agent in @("pm", "developer", "qa", "gamedesigner", "techartist", "watchdog")) {
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
