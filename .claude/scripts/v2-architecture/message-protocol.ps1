# Ralph Message Protocol - Simplified (v2)
# Consolidates 47+ message types into 12 core types
#
# Design Principle: One message type per semantic category
# Reduces complexity while maintaining all necessary functionality

# ============================================================================
# MESSAGE TYPE CONSTANTS
# ============================================================================

# The 12 core message types (reduced from 47+)
$Script:MessageTypes = @(
    # Agent Lifecycle (2 types: agent_ready, status_update)
    "AgentStatus",

    # Bootstrap (1 type: initial startup trigger for PM)
    "Bootstrap",

    # Work Management (4 types: task_assign, asset_assign, task_complete, etc.)
    "WorkAssign",
    "WorkComplete",
    "WorkAbandoned",
    "WorkBlocked",

    # Problem Reporting (3 types: bug_report, quality_concern, work_blocked)
    "ProblemReport",

    # Communication (2 types: question, answer, design_answer, etc.)
    "Query",
    "Response",

    # Quality & Validation (3 types: validation_request, test_plan_request, regression_request)
    "ValidationRequest",
    "ValidationResult",

    # Design (5 types: design_question, design_answer, gdd_ready, etc.)
    "DesignUpdate",

    # Retrospective (2 types: retrospective_initiate, retrospective_contribution)
    "Retrospective",

    # Planning (2 types: prd_reorganized, prd_update)
    "PlanUpdate",

    # Research (4 types: research_request, research_response, research_update)
    "ResearchUpdate",

    # System (2 types: shutdown, error)
    "System",

    # Playtesting (2 types: playtest_request, playtest_report)
    "Playtest",

    # CLI Process Management (2 types: CLI invoke request, CLI completion notification)
    "CLIInvoke",
    "CLIComplete"
)

# Map old message types to new types
$Script:MessageTypeMapping = @{
    # Agent Lifecycle
    "agent_ready" = "AgentStatus"
    "status_update" = "AgentStatus"

    # Work Assignment
    "task_assign" = "WorkAssign"
    "asset_assign" = "WorkAssign"
    "validation_request" = "WorkAssign"
    "test_plan_request" = "WorkAssign"
    "regression_request" = "WorkAssign"

    # Work Completion
    "task_complete" = "WorkComplete"
    "implementation_complete" = "WorkComplete"
    "work_complete" = "WorkComplete"
    "asset_ready" = "WorkComplete"

    # Work Issues
    "task_abandoned" = "WorkAbandoned"
    "work_blocked" = "WorkBlocked"

    # Problems
    "bug_report" = "ProblemReport"
    "quality_concern" = "ProblemReport"

    # Queries
    "question" = "Query"
    "asset_question" = "Query"
    "design_question" = "Query"
    "reference_request" = "Query"
    "research_request" = "ResearchUpdate"  # Separate category
    "skill_request" = "Query"

    # Responses
    "answer" = "Response"
    "design_answer" = "Response"
    "design_guidance" = "Response"
    "priority_response" = "Response"
    "research_response" = "Response"
    "skill_improvements" = "Response"

    # Design Updates
    "gdd_ready" = "DesignUpdate"
    "gdd_update" = "DesignUpdate"
    "mechanic_proposal" = "DesignUpdate"

    # Retrospective
    "retrospective_initiate" = "Retrospective"
    "retrospective_contribution" = "Retrospective"

    # Planning
    "prd_reorganized" = "PlanUpdate"
    "prd_update" = "PlanUpdate"

    # Research
    "research_update" = "ResearchUpdate"

    # Validation
    "test_plan_contribution" = "ValidationResult"

    # System
    "shutdown" = "System"
    "error" = "System"

    # Playtesting
    "playtest_request" = "Playtest"
    "playtest_report" = "Playtest"
}

# ============================================================================
# MESSAGE CREATION
# ============================================================================

function New-Message {
    <#
    .SYNOPSIS
    Create a new standardized message.

    .PARAMETER Type
    The message type (one of the 12 core types).

    .PARAMETER From
    The sender agent name.

    .PARAMETER To
    The recipient agent name.

    .PARAMETER Payload
    The message payload (hashtable).

    .PARAMETER InReplyTo
    Optional message ID this is replying to.

    .RETURNS
    A hashtable representing the message.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("AgentStatus", "Bootstrap", "WorkAssign", "WorkComplete", "WorkAbandoned", "WorkBlocked", "ProblemReport", "Query", "Response", "ValidationRequest", "ValidationResult", "DesignUpdate", "Retrospective", "PlanUpdate", "ResearchUpdate", "System", "Playtest", "CLIInvoke", "CLIComplete")]
        [string]$Type,

        [Parameter(Mandatory=$true)]
        [string]$From,

        [Parameter(Mandatory=$true)]
        [string]$To,

        [Parameter(Mandatory=$false)]
        [hashtable]$Payload = @{},

        [Parameter(Mandatory=$false)]
        [string]$InReplyTo = $null
    )

    $messageId = "msg-$(Get-Date -Format 'yyyyMMdd-HHmmss')-$(Get-Random -Minimum 1000 -Maximum 9999)"

    $message = @{
        id = $messageId
        type = $Type
        from = $From
        to = $To
        timestamp = [DateTime]::UtcNow.ToString("o")
        payload = $Payload
    }

    if ($InReplyTo) {
        $message.inReplyTo = $InReplyTo
    }

    return $message
}

function Convert-LegacyMessageType {
    <#
    .SYNOPSIS
    Convert a legacy message type to its new simplified type.

    .PARAMETER LegacyType
    The old message type name.

    .RETURNS
    The new message type name, or the original if no mapping exists.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$LegacyType
    )

    if ($Script:MessageTypeMapping.ContainsKey($LegacyType)) {
        return $Script:MessageTypeMapping[$LegacyType]
    }

    # Already a new type or unknown
    return $LegacyType
}

# ============================================================================
# CONVENIENCE FUNCTIONS FOR COMMON MESSAGES
# ============================================================================

function New-WorkAssignMessage {
    <#
    .SYNOPSIS
    Create a WorkAssign message.

    .PARAMETER From
    Sender agent.

    .PARAMETER To
    Recipient agent.

    .PARAMETER TaskId
    The task ID being assigned.

    .PARAMETER WorkType
    Type of work (implementation, validation, design, etc.).

    .PARAMETER Title
    Task title.

    .PARAMETER Description
    Task description.

    .PARAMETER AcceptanceCriteria
    Array of acceptance criteria.

    .RETURNS
    WorkAssign message hashtable.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$From,

        [Parameter(Mandatory=$true)]
        [string]$To,

        [Parameter(Mandatory=$true)]
        [string]$TaskId,

        [Parameter(Mandatory=$true)]
        [string]$WorkType,

        [Parameter(Mandatory=$true)]
        [string]$Title,

        [Parameter(Mandatory=$false)]
        [string]$Description = "",

        [Parameter(Mandatory=$false)]
        [string[]]$AcceptanceCriteria = @()
    )

    $payload = @{
        taskId = $TaskId
        workType = $WorkType
        title = $Title
        description = $Description
        acceptanceCriteria = $AcceptanceCriteria
    }

    return New-Message -Type "WorkAssign" -From $From -To $To -Payload $payload
}

function New-WorkCompleteMessage {
    <#
    .SYNOPSIS
    Create a WorkComplete message.

    .PARAMETER From
    Sender agent.

    .PARAMETER To
    Recipient agent (usually pm).

    .PARAMETER TaskId
    The completed task ID.

    .PARAMETER Result
    Result of the work (success, failed, etc.).

    .PARAMETER Notes
    Optional notes about the completion.

    .RETURNS
    WorkComplete message hashtable.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$From,

        [Parameter(Mandatory=$true)]
        [string]$To,

        [Parameter(Mandatory=$true)]
        [string]$TaskId,

        [Parameter(Mandatory=$false)]
        [string]$Result = "success",

        [Parameter(Mandatory=$false)]
        [string]$Notes = ""
    )

    $payload = @{
        taskId = $TaskId
        result = $Result
        notes = $Notes
    }

    return New-Message -Type "WorkComplete" -From $From -To $To -Payload $payload
}

function New-QueryMessage {
    <#
    .SYNOPSIS
    Create a Query message.

    .PARAMETER From
    Sender agent.

    .PARAMETER To
    Recipient agent.

    .PARAMETER Question
    The question being asked.

    .PARAMETER Context
    Optional context for the question.

    .RETURNS
    Query message hashtable.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$From,

        [Parameter(Mandatory=$true)]
        [string]$To,

        [Parameter(Mandatory=$true)]
        [string]$Question,

        [Parameter(Mandatory=$false)]
        [hashtable]$Context = @{}
    )

    $payload = @{
        question = $Question
        context = $Context
    }

    return New-Message -Type "Query" -From $From -To $To -Payload $payload
}

function New-ResponseMessage {
    <#
    .SYNOPSIS
    Create a Response message.

    .PARAMETER From
    Sender agent.

    .PARAMETER To
    Recipient agent.

    .PARAMETER Answer
    The answer content.

    .PARAMETER InReplyTo
    The original message ID being replied to.

    .RETURNS
    Response message hashtable.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$From,

        [Parameter(Mandatory=$true)]
        [string]$To,

        [Parameter(Mandatory=$true)]
        [string]$Answer,

        [Parameter(Mandatory=$false)]
        [string]$InReplyTo = $null
    )

    $payload = @{
        answer = $Answer
    }

    return New-Message -Type "Response" -From $From -To $To -Payload $payload -InReplyTo $InReplyTo
}

function New-ProblemReportMessage {
    <#
    .SYNOPSIS
    Create a ProblemReport message.

    .PARAMETER From
    Sender agent.

    .PARAMETER To
    Recipient agent (usually pm).

    .PARAMETER TaskId
    The related task ID.

    .PARAMETER ProblemType
    Type of problem (bug, quality_concern, blocker).

    .PARAMETER Description
    Description of the problem.

    .PARAMETER Severity
    Severity level (low, medium, high, critical).

    .RETURNS
    ProblemReport message hashtable.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$From,

        [Parameter(Mandatory=$true)]
        [string]$To,

        [Parameter(Mandatory=$true)]
        [string]$TaskId,

        [Parameter(Mandatory=$true)]
        [string]$ProblemType,

        [Parameter(Mandatory=$true)]
        [string]$Description,

        [Parameter(Mandatory=$false)]
        [ValidateSet("low", "medium", "high", "critical")]
        [string]$Severity = "medium"
    )

    $payload = @{
        taskId = $TaskId
        problemType = $ProblemType
        description = $Description
        severity = $Severity
    }

    return New-Message -Type "ProblemReport" -From $From -To $To -Payload $payload
}

function New-ValidationRequestMessage {
    <#
    .SYNOPSIS
    Create a ValidationRequest message.

    .PARAMETER From
    Sender agent (usually developer).

    .PARAMETER To
    Recipient agent (usually qa).

    .PARAMETER TaskId
    The task to validate.

    .PARAMETER ValidationType
    Type of validation (code_review, browser_test, etc.).

    .RETURNS
    ValidationRequest message hashtable.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$From,

        [Parameter(Mandatory=$true)]
        [string]$To,

        [Parameter(Mandatory=$true)]
        [string]$TaskId,

        [Parameter(Mandatory=$false)]
        [string]$ValidationType = "full"
    )

    $payload = @{
        taskId = $TaskId
        validationType = $ValidationType
    }

    return New-Message -Type "ValidationRequest" -From $From -To $To -Payload $payload
}

function New-SystemMessage {
    <#
    .SYNOPSIS
    Create a System message (shutdown, error, etc.).

    .PARAMETER From
    Sender agent (usually watchdog).

    .PARAMETER To
    Recipient agent or "*" for broadcast.

    .PARAMETER SystemEventType
    Type of system event (shutdown, error, warning).

    .PARAMETER Message
    The system message content.

    .RETURNS
    System message hashtable.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$From,

        [Parameter(Mandatory=$true)]
        [string]$To,

        [Parameter(Mandatory=$true)]
        [ValidateSet("shutdown", "error", "warning", "info")]
        [string]$SystemEventType,

        [Parameter(Mandatory=$true)]
        [string]$Message
    )

    $payload = @{
        systemEvent = $SystemEventType
        message = $Message
    }

    return New-Message -Type "System" -From $From -To $To -Payload $payload
}

function New-CLIInvokeMessage {
    <#
    .SYNOPSIS
    Create a CLIInvoke message to request supervisor to spawn CLI.

    .PARAMETER From
    Sender agent (the agent requesting CLI invocation).

    .PARAMETER AgentName
    The agent this CLI is for (pm, developer, qa, etc.).

    .PARAMETER MessageFile
    Path to the pending-message.json file.

    .PARAMETER ResponseFile
    Path where response should be written.

    .RETURNS
    CLIInvoke message hashtable.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$From,

        [Parameter(Mandatory=$true)]
        [string]$AgentName,

        [Parameter(Mandatory=$true)]
        [string]$MessageFile,

        [Parameter(Mandatory=$false)]
        [string]$ResponseFile = ""
    )

    if (-not $ResponseFile) {
        # Derive response file from message file path
        $ResponseFile = $MessageFile -replace "pending-message\.json$", "response.json"
    }

    $payload = @{
        agentName = $AgentName
        messageFile = $MessageFile
        responseFile = $ResponseFile
        requestedAt = [DateTime]::UtcNow.ToString("o")
    }

    return New-Message -Type "CLIInvoke" -From $From -To "watchdog" -Payload $payload
}

function New-BootstrapMessage {
    <#
    .SYNOPSIS
    Create a Bootstrap message for PM startup.

    .PARAMETER From
    Sender agent (usually watchdog).

    .PARAMETER To
    Recipient agent (usually pm).

    .PARAMETER Action
    The bootstrap action (StartDevelopmentCycle).

    .PARAMETER Reason
    Reason for bootstrap (Initial startup, Restart, etc.).

    .RETURNS
    Bootstrap message hashtable.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$From,

        [Parameter(Mandatory=$true)]
        [string]$To,

        [Parameter(Mandatory=$true)]
        [string]$Action,

        [Parameter(Mandatory=$false)]
        [string]$Reason = ""
    )

    $payload = @{
        action = $Action
        reason = $Reason
    }

    return New-Message -Type "Bootstrap" -From $From -To $To -Payload $payload
}

function New-CLICompleteMessage {
    <#
    .SYNOPSIS
    Create a CLIComplete message to notify broker CLI finished.

    .PARAMETER To
    Recipient agent name.

    .PARAMETER AgentName
    The agent that invoked the CLI.

    .PARAMETER ExitCode
    The CLI process exit code.

    .PARAMETER Success
    Whether the CLI completed successfully.

    .PARAMETER Error
    Error message if CLI failed.

    .RETURNS
    CLIComplete message hashtable.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$To,

        [Parameter(Mandatory=$true)]
        [string]$AgentName,

        [Parameter(Mandatory=$false)]
        [int]$ExitCode = 0,

        [Parameter(Mandatory=$false)]
        [bool]$Success = $true,

        [Parameter(Mandatory=$false)]
        [string]$Error = ""
    )

    $payload = @{
        agentName = $AgentName
        exitCode = $ExitCode
        success = $Success
        completedAt = [DateTime]::UtcNow.ToString("o")
    }

    if ($Error) {
        $payload.error = $Error
    }

    return New-Message -Type "CLIComplete" -From "watchdog" -To $To -Payload $payload
}

# ============================================================================
# MESSAGE VALIDATION
# ============================================================================

function Test-Message {
    <#
    .SYNOPSIS
    Validate a message has all required fields.

    .PARAMETER Message
    The message hashtable to validate.

    .RETURNS
    $true if valid, $false otherwise.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Message
    )

    # Required fields for all messages
    $required = @("id", "type", "from", "to", "timestamp", "payload")

    foreach ($field in $required) {
        if (-not $Message.ContainsKey($field)) {
            Write-Warning "[Message] Missing required field: $field"
            return $false
        }
    }

    # Validate type is one of the core types
    if ($Message.type -notin $Script:MessageTypes) {
        Write-Warning "[Message] Unknown message type: $($Message.type)"
        return $false
    }

    return $true
}

# ============================================================================
# EXPORTS
# ============================================================================

# Only export if running as a module (not when sourced directly)
try {
    Export-ModuleMember -Function @(
        # Message creation
        'New-Message',
        'New-WorkAssignMessage',
        'New-WorkCompleteMessage',
        'New-QueryMessage',
        'New-ResponseMessage',
        'New-ProblemReportMessage',
        'New-ValidationRequestMessage',
        'New-SystemMessage',
        'New-BootstrapMessage',
        'New-CLIInvokeMessage',
        'New-CLICompleteMessage',

        # Legacy support
        'Convert-LegacyMessageType',

        # Validation
        'Test-Message'
    )
} catch {
    # Not running as a module - ignore export error
}
