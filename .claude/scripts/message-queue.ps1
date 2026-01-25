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

# Source consolidation-mode module for PM consolidation behavior
$consolidationModule = Join-Path $PSScriptRoot "Consolidation-Mode.ps1"
if (Test-Path $consolidationModule) {
    . $consolidationModule
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
$Script:MessageSequenceCache = @{}  # Track message sequences to prevent collisions
$Script:MaxMessagesPerInbox = 50  # Circuit breaker: max messages before rejecting new ones

function Set-MessageQueueSilent {
    param([bool]$Silent = $true)
    $Script:MessageQueueSilent = $Silent
}

function Initialize-MessageQueue {
    param(
        [Parameter(Mandatory=$true)]
        [string]$SessionDir
    )

    # CRITICAL: If in a worktree, resolve to master session directory
    # All agents must use the SAME message queue for coordination
    $configModule = Join-Path $PSScriptRoot "ralph-config.ps1"
    $masterSessionPath = $SessionDir  # Default to current session directory

    if (Test-Path $configModule) {
        . $configModule
        # Get-MasterSessionPath expects a project root, but we receive a session directory
        # Extract project root from session directory if needed
        $projectRoot = $SessionDir
        if ($SessionDir -match '^(.+)\.claude[\\/]session$') {
            $projectRoot = $matches[1]
        }
        $masterSessionPath = Get-MasterSessionPath -CurrentPath $projectRoot
        $Script:MessageQueueDir = Join-Path $masterSessionPath "messages"
    } else {
        # Fallback if ralph-config not available (shouldn't happen in normal operation)
        $Script:MessageQueueDir = Join-Path $SessionDir "messages"
    }

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

    # Initialize consolidation mode (also uses master path)
    Initialize-ConsolidationMode -SessionDir $masterSessionPath

    # Silent - no console output
}

# ============================================================================
# MESSAGE FUNCTIONS
# ============================================================================

function New-MessageId {
    <#
    .SYNOPSIS
    Generate a unique message ID with standardized naming format.

    .PARAMETER RecipientAgent
    The agent receiving this message (included in filename for clarity).

    .RETURNS
    Message ID in format: msg-{recipient_agent}-{timestamp}-{sequence}
    Example: msg-developer-20250123-120000-001
    #>
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("pm", "developer", "qa", "gamedesigner", "techartist", "watchdog")]
        [string]$RecipientAgent
    )

    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $seq = Get-NextMessageSequence -Agent $RecipientAgent -Timestamp $timestamp
    return "msg-$RecipientAgent-$timestamp-$('{0:D3}' -f $seq)"
}

function Get-NextMessageSequence {
    <#
    .SYNOPSIS
    Get the next sequence number for a given agent and timestamp.
    Prevents filename collisions when multiple messages are created within the same second.

    .PARAMETER Agent
    The recipient agent name.

    .PARAMETER Timestamp
    The timestamp for this batch of messages.

    .RETURNS
    The next sequence number (1-based).
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Agent,

        [Parameter(Mandatory=$true)]
        [string]$Timestamp
    )

    $key = "$Agent-$Timestamp"
    if (-not $Script:MessageSequenceCache.ContainsKey($key)) {
        $Script:MessageSequenceCache[$key] = 0
    }
    $Script:MessageSequenceCache[$key]++
    return $Script:MessageSequenceCache[$key]
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
            "success_criteria", "success_criteria_request",
            "gdd_ready", "gdd_update", "design_question", "design_answer",
            "playtest_request", "playtest_report", "mechanic_proposal", "design_guidance",
            "design_guidance_request", "test_plan_request", "test_plan_contribution", "visual_reference",
            "asset_assign", "asset_ready", "asset_question", "shader_request", "reference_request",
            "retrospective_complete",
            "context_checkpoint",
            "env_ready"
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

    $messageId = New-MessageId -RecipientAgent $To
    
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

    # CIRCUIT BREAKER: Check inbox size before sending
    $currentCount = @(Get-ChildItem -Path $inbox -Filter "msg-*.json" -ErrorAction SilentlyContinue).Count
    if ($currentCount -ge $Script:MaxMessagesPerInbox) {
        throw "Inbox full: $To has $currentCount messages (max: $Script:MaxMessagesPerInbox). Clear messages before sending more."
    }

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

# ============================================================================
# PENDING MESSAGE HELPER FUNCTIONS
# ============================================================================

function Remove-OrphanedTempFiles {
    <#
    .SYNOPSIS
    Removes orphaned .tmp files from message queue directories.

    .DESCRIPTION
    Cleans up temporary files from failed atomic writes that are older than 30 seconds.
    Only runs occasionally (random 1 in 10 chance) to reduce overhead.

    .PARAMETER Files
    The file list to process (from Get-ChildItem).

    .PARAMETER AlwaysRun
    If true, always run cleanup regardless of random check.
    #>
    param(
        [object[]]$Files,
        [switch]$AlwaysRun
    )

    $thresholdSeconds = 30

    foreach ($file in $Files | Where-Object { $_.Name -match '\.tmp$' }) {
        $age = ([DateTime]::UtcNow - $file.LastWriteTimeUtc).TotalSeconds
        if ($age -gt $thresholdSeconds) {
            Remove-Item $file.FullName -Force -ErrorAction SilentlyContinue
        }
    }
}

function Read-MessageFileWithRetry {
    <#
    .SYNOPSIS
    Reads and parses a message file with retry logic.

    .DESCRIPTION
    Attempts to read a JSON message file up to 3 times with 50ms delays between retries.
    Handles empty files (in-progress writes) and JSON parse errors.

    .PARAMETER FilePath
    The full path to the message file.

    .PARAMETER TimeoutMs
    Maximum time to spend retrying before giving up.

    .RETURNS
    The parsed message object, or $null if all retries fail.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath,

        [int]$TimeoutMs = 150
    )

    $retries = 3
    $retryDelayMs = 50
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    for ($i = 0; $i -lt $retries; $i++) {
        # Check timeout
        if ($stopwatch.ElapsedMilliseconds -gt $TimeoutMs) {
            break
        }

        try {
            $rawContent = Get-Content $FilePath -Raw -ErrorAction Stop
            if ([string]::IsNullOrWhiteSpace($rawContent)) {
                # File may be in middle of write - wait and retry
                Start-Sleep -Milliseconds $retryDelayMs
                continue
            }
            $content = $rawContent | ConvertFrom-Json -ErrorAction Stop
            $stopwatch.Stop()
            return $content
        } catch {
            if ($i -lt $retries - 1) { Start-Sleep -Milliseconds $retryDelayMs }
        }
    }

    $stopwatch.Stop()
    return $null
}

function Move-CorruptFilesToQuarantine {
    <#
    .SYNOPSIS
    Moves corrupt message files to quarantine directory.

    .DESCRIPTION
    Uses async job to avoid blocking the main thread.

    .PARAMETER CorruptFiles
    List of file paths that failed to parse.

    .PARAMETER MessageQueueDir
    The message queue directory containing the quarantine folder.
    #>
    param(
        [string[]]$CorruptFiles = @(),

        [Parameter(Mandatory=$true)]
        [string]$MessageQueueDir
    )

    if ($CorruptFiles.Count -eq 0) {
        return
    }

    $quarantine = Join-Path $MessageQueueDir "quarantine"
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
    } -ArgumentList $CorruptFiles, $quarantine -ErrorAction SilentlyContinue | Out-Null
}

# ============================================================================
# DEAD LETTER QUEUE - Unprocessable message handling
# ============================================================================

function Move-ToDeadLetterQueue {
    <#
    .SYNOPSIS
    Moves unprocessable message files to dead letter queue with metadata.

    .DESCRIPTION
    When a message cannot be processed (invalid format, unknown type, etc.),
    move it to the dead letter queue for later analysis instead of leaving it
    to clog the inbox.

    .PARAMETER MessagePath
    Path to the message file to move.

    .PARAMETER Reason
    Why the message couldn't be processed.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$MessagePath,

        [Parameter(Mandatory=$true)]
        [string]$Reason
    )

    if (-not (Test-Path $MessagePath)) {
        return
    }

    $deadLetterDir = Join-Path $Script:MessageQueueDir "deadletter"
    if (-not (Test-Path $deadLetterDir)) {
        New-Item -ItemType Directory -Path $deadLetterDir -Force | Out-Null
    }

    $filename = [System.IO.Path]::GetFileName($MessagePath)
    $timestamp = [DateTime]::UtcNow.ToString("yyyyMMdd-HHmmss")
    $destFilename = "${timestamp}_${filename}"
    $destPath = Join-Path $deadLetterDir $destFilename

    # Create metadata file with reason
    $metadataPath = "${destPath}.meta.json"
    $metadata = @{
        originalPath = $MessagePath
        movedAt = [DateTime]::UtcNow.ToString("o")
        reason = $Reason
    } | ConvertTo-Json -Depth 3

    try {
        Move-Item -Path $MessagePath -Destination $destPath -Force -ErrorAction Stop
        $metadata | Out-File -FilePath $metadataPath -Encoding UTF8 -Force
        if (-not $Script:MessageQueueSilent) {
            Write-Host "  [DLQ] Moved to dead letter: $filename - Reason: $Reason" -ForegroundColor DarkYellow
        }
    } catch {
        if (-not $Script:MessageQueueSilent) {
            Write-Host "  [DLQ] Failed to move to dead letter: $_" -ForegroundColor Red
        }
    }
}

function Clear-DeadLetterQueue {
    <#
    .SYNOPSIS
    Clears all messages from the dead letter queue.

    .DESCRIPTION
    Removes all files from the dead letter queue directory.
    Use with caution - this permanently deletes unprocessable messages.
    #>
    param()

    $deadLetterDir = Join-Path $Script:MessageQueueDir "deadletter"
    if (-not (Test-Path $deadLetterDir)) {
        return 0
    }

    $count = 0
    try {
        $files = Get-ChildItem -Path $deadLetterDir -File
        $count = $files.Count
        Remove-Item -Path $deadLetterDir -Recurse -Force -ErrorAction Stop
        New-Item -ItemType Directory -Path $deadLetterDir -Force | Out-Null
        if (-not $Script:MessageQueueSilent -and $count -gt 0) {
            Write-Host "  [DLQ] Cleared $count messages from dead letter queue" -ForegroundColor Cyan
        }
    } catch {
        if (-not $Script:MessageQueueSilent) {
            Write-Host "  [DLQ] Failed to clear dead letter queue: $_" -ForegroundColor Red
        }
    }
    return $count
}

function Get-DeadLetterQueueCount {
    <#
    .SYNOPSIS
    Returns the number of messages in the dead letter queue.
    #>
    $deadLetterDir = Join-Path $Script:MessageQueueDir "deadletter"
    if (-not (Test-Path $deadLetterDir)) {
        return 0
    }

    return @(Get-ChildItem -Path $deadLetterDir -Filter "msg-*.json" -ErrorAction SilentlyContinue).Count
}

function Sort-MessagesByPriority {
    <#
    .SYNOPSIS
    Sorts messages by priority (highest first), then by timestamp (oldest first).

    .PARAMETER Messages
    The message collection to sort.

    .RETURNS
    Sorted message collection (always an array, even for single messages).
    #>
    param(
        [object[]]$Messages = @()
    )

    # Ensure empty input returns empty array (not $null)
    if ($null -eq $Messages -or $Messages.Count -eq 0) {
        return @()  # Explicitly return empty array
    }

    $priorityOrder = @{ "low" = 0; "normal" = 1; "high" = 2; "urgent" = 3 }

    # Use array subexpression @() and ensure result is always an array
    $sorted = $Messages | Sort-Object -Property @(
        @{ Expression = { $priorityOrder[$_.priority] }; Descending = $true },
        @{ Expression = { $_.timestamp }; Descending = $false }
    )

    # Ensure we always return an array (even for single messages)
    # Use Write-Output -NoEnumerate or array construction to prevent unrolling
    if ($null -eq $sorted) {
        return @()
    } elseif ($sorted -is [array]) {
        return ,$sorted  # Comma operator prevents unrolling single-element arrays
    } else {
        # Single item - use array literal to wrap it
        ,@($sorted)
    }
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

    # Get file list with timeout protection
    if (Get-Command Get-ChildItemWithTimeout -ErrorAction SilentlyContinue) {
        $allFiles = Get-ChildItemWithTimeout -Path $inbox -Filter "*.json" -TimeoutMs 2000 -DefaultValue @()
    } else {
        $allFiles = Get-ChildItem -Path $inbox -Filter "*.json" -ErrorAction SilentlyContinue
    }

    # Cleanup orphaned temp files occasionally
    if ($Agent -eq "pm" -or (Get-Random -Maximum 10) -eq 0) {
        Remove-OrphanedTempFiles -Files @($allFiles) -AlwaysRun
    }

    $priorityOrder = @{ "low" = 0; "normal" = 1; "high" = 2; "urgent" = 3 }
    $minPriorityValue = $priorityOrder[$MinPriority]
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $messages = @()
    $corruptFiles = @()

    # Process files with timeout protection
    foreach ($fileInfo in $allFiles) {
        # Timeout check
        if ($stopwatch.ElapsedMilliseconds -gt $TimeoutMs) {
            break
        }

        # Skip temp files
        if ($fileInfo.Name -match '\.tmp$') { continue }

        # Read message file with retry
        $remainingTimeout = $TimeoutMs - $stopwatch.ElapsedMilliseconds
        $content = Read-MessageFileWithRetry -FilePath $fileInfo.FullName -TimeoutMs $remainingTimeout

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
    }

    $stopwatch.Stop()

    # Move corrupt files to quarantine
    Move-CorruptFilesToQuarantine -CorruptFiles $corruptFiles -MessageQueueDir $Script:MessageQueueDir

    # Sort and return messages
    return Sort-MessagesByPriority -Messages $messages
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
            "success_criteria", "success_criteria_request",
            "gdd_ready", "gdd_update", "design_question", "design_answer",
            "playtest_request", "playtest_report", "mechanic_proposal", "design_guidance",
            "design_guidance_request", "test_plan_request", "test_plan_contribution", "visual_reference",
            "asset_assign", "asset_ready", "asset_question", "shader_request", "reference_request",
            "retrospective_complete",
            "context_checkpoint",
            "env_ready"
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

function Send-EnvReady {
    <#
    .SYNOPSIS
    PM sends this to watchdog after consolidating messages on startup.
    Signals that PM is ready for normal operations and workers can receive messages.

    This message exits watchdog's startup mode, allowing workers to be spawned.
    #>
    param()

    $payload = @{
        timestamp = [DateTime]::UtcNow.ToString("o")
    }

    return Send-AgentMessage -From "pm" -To "watchdog" -Type "env_ready" -Payload $payload -Priority "high"
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
# CONSOLIDATION MODE HELPERS
# ============================================================================
# Consolidation mode functions are now in Consolidation-Mode.ps1
# These helper functions remain here as they use message queue internals

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

function Invoke-ConsolidateAndClearAllMessages {
    <#
    .SYNOPSIS
    PM consolidation function: Read all messages from all agents, consolidate them,
    and delete all messages after processing. This ensures PM has complete picture
    on startup and messages don't pile up across restarts.

    .RETURNS
    Hashtable with consolidated state for PM decision making.
    #>
    param()

    if (-not $Script:MessageQueueDir) {
        throw "Message queue not initialized. Call Initialize-MessageQueue first."
    }

    # Get global message state (all messages across all agents)
    $globalState = Get-GlobalMessageState

    $consolidated = @{
        totalMessages = $globalState.totalMessages
        byAgent = @{}
        byType = @{}
        allMessages = $globalState.allMessages
        consolidatedAt = [DateTime]::UtcNow.ToString("o")
    }

    # Group by agent and by type for PM analysis
    foreach ($agent in @("pm", "developer", "qa", "gamedesigner", "techartist")) {
        $consolidated.byAgent[$agent] = @($globalState.byAgent[$agent])
    }

    # Group by message type
    foreach ($msg in $globalState.allMessages) {
        $type = $msg.type
        if (-not $consolidated.byType[$type]) {
            $consolidated.byType[$type] = @()
        }
        $consolidated.byType[$type] += $msg
    }

    # Delete ALL messages after consolidation (they've been processed)
    # This is the key: PM has read everything, messages are now redundant
    $deletedCount = 0
    foreach ($agent in @("pm", "developer", "qa", "gamedesigner", "techartist", "watchdog")) {
        $inbox = Join-Path $Script:MessageQueueDir $agent
        if (Test-Path $inbox) {
            $messages = Get-ChildItem -Path $inbox -Filter "*.json" -ErrorAction SilentlyContinue
            foreach ($msgFile in $messages) {
                try {
                    Remove-Item $msgFile.FullName -Force -ErrorAction Stop
                    $deletedCount++
                } catch {
                    # Log but continue - message may have been deleted by another process
                }
            }
        }
    }

    # Add deletion count to consolidated state
    $consolidated.messagesDeleted = $deletedCount

    return $consolidated
}

# ============================================================================
# EXPORT
# ============================================================================

# Export functions for dot-sourcing
# Usage: . "$PSScriptRoot\message-queue.ps1"
