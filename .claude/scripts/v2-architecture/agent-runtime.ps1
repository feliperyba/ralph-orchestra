# Ralph Agent Runtime Library (V2)
# Standard library for all Ralph agents
#
# Provides:
# - Connection to watchdog via bidirectional named pipe
# - Message sending and receiving
# - Agent lifecycle management

# Source required modules
$Script:AgentRuntimeModuleDir = Split-Path -Parent $MyInvocation.MyCommand.Path

$eventBusModule = Join-Path $Script:AgentRuntimeModuleDir "event-bus.ps1"
if (Test-Path $eventBusModule) {
    . $eventBusModule
} else {
    Write-Warning "[AgentRuntime] event-bus.ps1 not found at $eventBusModule"
}

$messageProtocolModule = Join-Path $Script:AgentRuntimeModuleDir "message-protocol.ps1"
if (Test-Path $messageProtocolModule) {
    . $messageProtocolModule
} else {
    Write-Warning "[AgentRuntime] message-protocol.ps1 not found at $messageProtocolModule"
}

# ============================================================================
# AGENT CONTEXT
# ============================================================================

$Script:AgentRuntime = @{
    AgentName = $null
    Pipe = $null
    Reader = $null
    Writer = $null
    Connected = $false
    SessionDir = $null
}

# ============================================================================
# CONNECTION
# ============================================================================

function Connect-ToWatchdog {
    <#
    .SYNOPSIS
    Connect to the watchdog as an agent.

    .DESCRIPTION
    Establishes a bidirectional pipe connection to the watchdog.
    This should be called first when an agent starts.

    .PARAMETER AgentName
    The name of this agent (pm, developer, qa, etc.).

    .PARAMETER SessionDir
    The session directory path (optional, auto-detected if not provided).

    .RETURNS
    $true if connection successful, $false otherwise.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$AgentName,

        [Parameter(Mandatory=$false)]
        [string]$SessionDir = ""
    )

    # Auto-detect session directory if not provided
    if (-not $SessionDir) {
        # Try to find session directory relative to project root
        $possibleDirs = @(
            ".\.claude\session",
            "C:\Users\Felip\Projects\gamedev\projects\ralph-orchestra\.claude\session"
        )

        foreach ($dir in $possibleDirs) {
            if (Test-Path $dir) {
                $SessionDir = Resolve-Path $dir
                break
            }
        }

        if (-not $SessionDir) {
            throw "Session directory not found. Please provide SessionDir parameter."
        }
    }

    $Script:AgentRuntime.SessionDir = $SessionDir
    $Script:AgentRuntime.AgentName = $AgentName

    # Initialize event bus for this session
    Initialize-EventBus -SessionDir $SessionDir

    # Get or create pipe for this agent
    $pipeName = "ralph-$AgentName-main"

    # Connect as a client to the watchdog's server pipe
    $pipe = [System.IO.Pipes.NamedPipeClientStream]::new(
        ".",  # Server name (local machine)
        $pipeName,
        [System.IO.Pipes.PipeDirection]::InOut
    )

    # Try to connect with timeout
    $connected = $false
    $timeoutMs = 30000  # 30 seconds
    $startTime = [DateTime]::UtcNow

    try {
        Write-Host "[$AgentName] Connecting to watchdog pipe $pipeName..." -ForegroundColor Cyan

        while (-not $connected) {
            try {
                $pipe.Connect(1000)  # Try 1 second at a time
                $connected = $true
                break
            } catch {
                $elapsedMs = ([DateTime]::UtcNow - $startTime).TotalMilliseconds
                if ($elapsedMs -ge $timeoutMs) {
                    Write-Warning "[$AgentName] Connection timeout after ${elapsedMs}ms"
                    break
                }
            }

            if (-not $connected) {
                Start-Sleep -Milliseconds 500
            }
        }
    } catch {
        Write-Warning "[$AgentName] Error connecting to watchdog: $_"
        return $false
    }

    if (-not $connected) {
        return $false
    }

    # Create reader and writer
    $Script:AgentRuntime.Pipe = $pipe
    $Script:AgentRuntime.Reader = [System.IO.StreamReader]::new($pipe)
    $Script:AgentRuntime.Writer = [System.IO.StreamWriter]::new($pipe)
    $Script:AgentRuntime.Writer.AutoFlush = $true
    $Script:AgentRuntime.Connected = $true

    Write-Host "[$AgentName] Connected to watchdog" -ForegroundColor Green

    # Send ready signal
    Send-AgentStatus -Status "ready"

    return $true
}

# ============================================================================
# MESSAGING - SEND
# ============================================================================

function Send-Message {
    <#
    .SYNOPSIS
    Send a message to another agent via the watchdog.

    .PARAMETER To
    The recipient agent name.

    .PARAMETER Type
    The message type.

    .PARAMETER Payload
    The message payload data.

    .PARAMETER InReplyTo
    Optional message ID this is replying to.

    .RETURNS
    The message ID if sent successfully, $null otherwise.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$To,

        [Parameter(Mandatory=$true)]
        [string]$Type,

        [Parameter(Mandatory=$false)]
        [hashtable]$Payload = @{},

        [Parameter(Mandatory=$false)]
        [string]$InReplyTo = $null
    )

    if (-not $Script:AgentRuntime.Connected) {
        Write-Warning "[$($Script:AgentRuntime.AgentName)] Not connected to watchdog"
        return $null
    }

    $message = New-Message `
        -Type $Type `
        -From $Script:AgentRuntime.AgentName `
        -To $To `
        -Payload $Payload `
        -InReplyTo $InReplyTo

    try {
        $json = $message | ConvertTo-Json -Compress -Depth 10
        $Script:AgentRuntime.Writer.WriteLine($json)

        Write-Debug "[$($Script:AgentRuntime.AgentName)] Sent to $To`: $Type"
        return $message.id
    } catch {
        Write-Warning "[$($Script:AgentRuntime.AgentName)] Failed to send message: $_"
        return $null
    }
}

function Send-AgentStatus {
    <#
    .SYNOPSIS
    Send an AgentStatus message to the watchdog.

    .PARAMETER Status
    The agent's current status (ready, working, waiting, etc.).

    .PARAMETER CurrentTask
    Optional task ID the agent is working on.

    .PARAMETER Notes
    Optional notes about the agent's state.
    #>
    param(
        [Parameter(Mandatory=$false)]
        [string]$Status = "idle",

        [Parameter(Mandatory=$false)]
        [string]$CurrentTask = $null,

        [Parameter(Mandatory=$false)]
        [string]$Notes = ""
    )

    $payload = @{
        status = $Status
    }

    if ($CurrentTask) {
        $payload.currentTask = $CurrentTask
    }

    if ($Notes) {
        $payload.notes = $Notes
    }

    Send-Message -To "watchdog" -Type "AgentStatus" -Payload $payload
}

function Send-WorkComplete {
    <#
    .SYNOPSIS
    Send a WorkComplete message to PM.

    .PARAMETER TaskId
    The completed task ID.

    .PARAMETER Result
    Result of the work (success, failed, etc.).

    .PARAMETER Notes
    Optional notes about the completion.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$TaskId,

        [Parameter(Mandatory=$false)]
        [string]$Result = "success",

        [Parameter(Mandatory=$false)]
        [string]$Notes = ""
    )

    Send-Message -To "pm" -Type "WorkComplete" -Payload @{
        taskId = $TaskId
        result = $Result
        notes = $Notes
    }
}

function Send-ProblemReport {
    <#
    .SYNOPSIS
    Send a ProblemReport message to PM.

    .PARAMETER TaskId
    The related task ID.

    .PARAMETER ProblemType
    Type of problem (bug, quality_concern, blocker).

    .PARAMETER Description
    Description of the problem.

    .PARAMETER Severity
    Severity level (low, medium, high, critical).
    #>
    param(
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

    Send-Message -To "pm" -Type "ProblemReport" -Payload @{
        taskId = $TaskId
        problemType = $ProblemType
        description = $Description
        severity = $Severity
    }
}

# ============================================================================
# MESSAGING - RECEIVE
# ============================================================================

function Receive-Message {
    <#
    .SYNOPSIS
    Receive a message from the watchdog (blocking with timeout).

    .PARAMETER TimeoutMs
        Timeout in milliseconds (default: 1000).

    .RETURNS
    The message object, or $null if timeout.
    #>
    param(
        [Parameter(Mandatory=$false)]
        [int]$TimeoutMs = 1000
    )

    if (-not $Script:AgentRuntime.Connected) {
        return $null
    }

    $deadline = [DateTime]::UtcNow.AddMilliseconds($TimeoutMs)

    while ([DateTime]::UtcNow -lt $deadline) {
        try {
            $pipe = $Script:AgentRuntime.Pipe

            # Check if still connected
            if (-not $pipe.IsConnected) {
                Write-Warning "[$($Script:AgentRuntime.AgentName)] Pipe disconnected"
                $Script:AgentRuntime.Connected = $false
                return $null
            }

            # Non-blocking check
            if ($Script:AgentRuntime.Reader.Peek() -gt 0) {
                $line = $Script:AgentRuntime.Reader.ReadLine()

                if ($line -and $line -match '\S') {
                    $msg = $line | ConvertFrom-Json

                    # Convert legacy message types if needed
                    if ($msg.type -notin $Script:MessageTypes) {
                        $msg.type = Convert-LegacyMessageType -LegacyType $msg.type
                    }

                    Write-Debug "[$($Script:AgentRuntime.AgentName)] Received from $($msg.from): $($msg.type)"
                    return $msg
                }
            }
        } catch {
            Write-Warning "[$($Script:AgentRuntime.AgentName)] Error receiving: $_"
            $Script:AgentRuntime.Connected = $false
            return $null
        }

        if ([DateTime]::UtcNow -lt $deadline) {
            Start-Sleep -Milliseconds 50
        }
    }

    return $null
}

# ============================================================================
# AGENT LOOP
# ============================================================================

function Enter-AgentLoop {
    <#
    .SYNOPSIS
    Enter the main agent message processing loop.

    .DESCRIPTION
    This function blocks and processes messages from the watchdog
    until a shutdown message is received. This is the main loop for agents.

    .PARAMETER MessageHandler
    A scriptblock that processes each received message.
    The scriptblock receives parameters: $Message, $Response

    .PARAMETER TimeoutMs
        Timeout for message receive in each iteration (default: 1000ms).

    .RETURNS
    $true when loop exits normally (shutdown received).
    #>
    param(
        [Parameter(Mandatory=$true)]
        [scriptblock]$MessageHandler,

        [Parameter(Mandatory=$false)]
        [int]$TimeoutMs = 1000
    )

    if (-not $Script:AgentRuntime.Connected) {
        Write-Error "[$($Script:AgentRuntime.AgentName)] Not connected to watchdog. Call Connect-ToWatchdog first."
        return $false
    }

    Write-Host "[$($Script:AgentRuntime.AgentName)] Entering agent loop..." -ForegroundColor Green

    try {
        while ($true) {
            $msg = Receive-Message -TimeoutMs $TimeoutMs

            if ($msg) {
                # Handle shutdown
                if ($msg.type -eq "System" -and $msg.payload.systemEvent -eq "shutdown") {
                    Write-Host "[$($Script:AgentRuntime.AgentName)] Received shutdown signal" -ForegroundColor Yellow
                    break
                }

                # Call the message handler
                try {
                    $handlerResult = & $MessageHandler -Message $msg

                    # If handler returns a response, send it
                    if ($handlerResult) {
                        if ($handlerResult -is [hashtable] -and $handlerResult.type) {
                            Send-Message -To $msg.from @handlerResult
                        }
                    }
                } catch {
                    Write-Error "[$($Script:AgentRuntime.AgentName)] Error in message handler: $_"
                    # Send error back
                    try {
                        Send-Message -To "watchdog" -Type "System" -Payload @{
                            systemEvent = "error"
                            message = "Agent error: $_"
                        }
                    } catch {
                        # Can't send error, just log it
                    }
                }
            }
        }

        # Brief heartbeat to indicate we're alive
        Send-AgentStatus -Status "working" -CurrentTask $Script:AgentRuntime.CurrentTask
    }
    finally {
        Write-Host "[$($Script:AgentRuntime.AgentName)] Exiting agent loop" -ForegroundColor Yellow

        # Clean up connection
        if ($Script:AgentRuntime.Connected) {
            try {
                $Script:AgentRuntime.Writer.Close()
                $Script:AgentRuntime.Reader.Close()
                $Script:AgentRuntime.Pipe.Close()
                $Script:AgentRuntime.Connected = $false
            } catch {
                # Ignore cleanup errors
            }
        }
    }

    return $true
}

# ============================================================================
# HELPERS
# ============================================================================

function Get-AgentName {
    <#
    .SYNOPSIS
    Get the current agent name.
    #>
    return $Script:AgentRuntime.AgentName
}

function Get-SessionDir {
    <#
    .SYNOPSIS
    Get the current session directory.
    #>
    return $Script:AgentRuntime.SessionDir
}

function IsConnected {
    <#
    .SYNOPSIS
    Check if the agent is connected to the watchdog.
    #>
    return $Script:AgentRuntime.Connected
}

# ============================================================================
# CONVENIENCE FUNCTIONS
# ============================================================================

function Start-AgentLoop {
    <#
    .SYNOPSIS
    Connect to watchdog and enter the message processing loop.

    .DESCRIPTION
    Convenience function that combines Connect-ToWatchdog and Enter-AgentLoop.
    Uses a default message handler that logs messages and takes no action.

    .PARAMETER AgentName
    The name of this agent (pm, developer, qa, etc.).

    .PARAMETER SessionDir
    The session directory path (optional, auto-detected if not provided).

    .PARAMETER TimeoutMs
    Timeout for message receive in each iteration (default: 5000ms).

    .RETURNS
    $true if connection successful and loop exited normally.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$AgentName,

        [Parameter(Mandatory=$false)]
        [string]$SessionDir = "",

        [Parameter(Mandatory=$false)]
        [int]$TimeoutMs = 5000
    )

    # Connect first
    $connected = Connect-ToWatchdog -AgentName $AgentName -SessionDir $SessionDir
    if (-not $connected) {
        Write-Error "[$AgentName] Failed to connect to watchdog"
        return $false
    }

    # ============================================================================
    # PM BOOTSTRAP: PM agent needs an initial message to start the development cycle
    # ============================================================================
    if ($AgentName -eq "pm") {
        # PM needs to bootstrap - create a self-message to start the cycle
        $contextDir = Join-Path $SessionDir "agents\pm"
        if (-not (Test-Path $contextDir)) {
            New-Item -ItemType Directory -Path $contextDir -Force | Out-Null
        }

        # Only create bootstrap if no pending message exists
        $pendingMessageFile = Join-Path $contextDir "pending-message.json"
        if (-not (Test-Path $pendingMessageFile)) {
            $bootstrapMsg = @{
                id = "bootstrap-$(Get-Date -Format 'yyyyMMdd-HHmmss')-$(Get-Random -Minimum 1000 -Maximum 9999)"
                from = "watchdog"
                to = "pm"
                type = "Bootstrap"
                payload = @{
                    action = "StartDevelopmentCycle"
                    reason = "Initial startup"
                }
                timestamp = [DateTime]::UtcNow.ToString("o")
            }

            $bootstrapMsg | ConvertTo-Json -Depth 10 | Out-File -FilePath $pendingMessageFile -Encoding utf8
            Write-Host "[PM] Bootstrap message created - invoking CLI immediately" -ForegroundColor Green

            # Immediately invoke CLI to process the bootstrap message
            # This is the PM's first action - start the development cycle
            $responseFile = Join-Path $contextDir "response.json"

            $invokeMsg = @{
                id = "invoke-bootstrap-$(Get-Date -Format 'yyyyMMdd-HHmmss')-$(Get-Random -Minimum 1000 -Maximum 9999)"
                type = "CLIInvoke"
                from = "pm"
                to = "watchdog"
                payload = @{
                    agentName = "pm"
                    messageFile = $pendingMessageFile
                    responseFile = $responseFile
                    requestedAt = [DateTime]::UtcNow.ToString("o")
                }
                timestamp = [DateTime]::UtcNow.ToString("o")
            }

            try {
                $json = $invokeMsg | ConvertTo-Json -Compress -Depth 10
                $Script:AgentRuntime.Writer.WriteLine($json)
                Write-Host "[PM] Waiting for CLI to complete bootstrap..." -ForegroundColor DarkGray
            } catch {
                Write-Error "[PM] Failed to send CLIInvoke for bootstrap: $_"
                return $false
            }

            # Wait for CLIComplete message after bootstrap
            $timeoutMs = 330000  # 5.5 minutes
            $startTime = [DateTime]::UtcNow
            $cliComplete = $false

            while (([DateTime]::UtcNow - $startTime).TotalMilliseconds -lt $timeoutMs) {
                try {
                    if ($Script:AgentRuntime.Reader.Peek() -gt 0) {
                        $line = $Script:AgentRuntime.Reader.ReadLine()
                        if ($line -and $line -match '\S') {
                            $msg = $line | ConvertFrom-Json

                            if ($msg.type -in $Script:MessageTypes) {
                                # It's a new-style message
                            } else {
                                $msg.type = Convert-LegacyMessageType -LegacyType $msg.type
                            }

                            if ($msg.type -eq "CLIComplete" -and $msg.payload.agentName -eq "pm") {
                                $cliComplete = $true
                                Write-Host "[PM] Bootstrap CLI completed: $($msg.payload.success)" -ForegroundColor Green
                                break
                            }
                        }
                    }
                } catch {
                    # Continue waiting
                }
                Start-Sleep -Milliseconds 100
            }

            if (-not $cliComplete) {
                Write-Warning "[PM] Timeout waiting for bootstrap CLI completion"
            }

            # Clean up bootstrap message file
            if (Test-Path $pendingMessageFile) {
                Remove-Item $pendingMessageFile -Force
            }
        }
    }

    # Default message handler - request CLI invocation from supervisor
    # Capture variables in closure using GetNewClosure()
    $defaultHandler = {
        param($Message)

        # Get the agent name from the script scope
        $agentName = $Script:AgentRuntime.AgentName
        $sessionDir = $Script:AgentRuntime.SessionDir

        Write-Host "[$agentName] Processing message: $($Message.type) from $($Message.from)" -ForegroundColor Cyan

        # Skip CLIInvoke messages (these are our own requests echoing back)
        if ($Message.type -eq "CLIInvoke") {
            return $null
        }

        # Handle CLIComplete messages (supervisor's response)
        if ($Message.type -eq "CLIComplete") {
            Write-Host "[$agentName] CLI completed: $($Message.payload.success)" -ForegroundColor Green
            return $null
        }

        # Save message to temp file for CLI context
        $contextDir = Join-Path $sessionDir "agents\$agentName"
        if (-not (Test-Path $contextDir)) {
            New-Item -ItemType Directory -Path $contextDir -Force | Out-Null
        }
        $messageFile = Join-Path $contextDir "pending-message.json"
        $responseFile = Join-Path $contextDir "response.json"
        $Message | ConvertTo-Json -Depth 10 | Out-File -FilePath $messageFile -Encoding utf8

        # Request supervisor to spawn CLI (instead of spawning ourselves)
        Write-Host "[$agentName] Requesting CLI invocation from supervisor" -ForegroundColor DarkGray

        $invokeMsg = @{
            id = "invoke-$(Get-Date -Format 'yyyyMMdd-HHmmss')-$(Get-Random -Minimum 1000 -Maximum 9999)"
            type = "CLIInvoke"
            from = $agentName
            to = "watchdog"
            payload = @{
                agentName = $agentName
                messageFile = $messageFile
                responseFile = $responseFile
                requestedAt = [DateTime]::UtcNow.ToString("o")
            }
            timestamp = [DateTime]::UtcNow.ToString("o")
        }

        try {
            $json = $invokeMsg | ConvertTo-Json -Compress -Depth 10
            $Script:AgentRuntime.Writer.WriteLine($json)
        } catch {
            Write-Error "[$agentName] Failed to send CLIInvoke: $_"
            # Clean up message file
            if (Test-Path $messageFile) {
                Remove-Item $messageFile -Force
            }
            return $null
        }

        # Wait for CLIComplete message from supervisor
        Write-Host "[$agentName] Waiting for CLI to complete..." -ForegroundColor DarkGray
        $timeoutMs = 330000  # 5.5 minutes (slightly longer than supervisor timeout)
        $startTime = [DateTime]::UtcNow
        $cliComplete = $false

        while (([DateTime]::UtcNow - $startTime).TotalMilliseconds -lt $timeoutMs) {
            # Check for message (non-blocking poll)
            try {
                if ($Script:AgentRuntime.Reader.Peek() -gt 0) {
                    $line = $Script:AgentRuntime.Reader.ReadLine()
                    if ($line -and $line -match '\S') {
                        $msg = $line | ConvertFrom-Json

                        # Convert legacy message types if needed
                        if ($msg.type -notin $Script:MessageTypes) {
                            $msg.type = Convert-LegacyMessageType -LegacyType $msg.type
                        }

                        if ($msg.type -eq "CLIComplete" -and $msg.payload.agentName -eq $agentName) {
                            $cliComplete = $true
                            Write-Host "[$agentName] CLI completed: $($msg.payload.success)" -ForegroundColor Green
                            break
                        }

                        # Not our CLIComplete - could be another message, queue it for next loop
                        # For now, just log and continue waiting
                        Write-Warning "[$agentName] Received unexpected message while waiting for CLI: $($msg.type)"
                    }
                }
            } catch {
                Write-Warning "[$agentName] Error reading message while waiting for CLI: $_"
            }

            Start-Sleep -Milliseconds 100
        }

        if (-not $cliComplete) {
            Write-Warning "[$agentName] Timeout waiting for CLI completion"
            # Clean up message file
            if (Test-Path $messageFile) {
                Remove-Item $messageFile -Force
            }
            return $null
        }

        # Check for response file
        if (Test-Path $responseFile) {
            $response = Get-Content $responseFile | ConvertFrom-Json
            Remove-Item $responseFile -Force
            Write-Host "[$agentName] CLI returned response" -ForegroundColor Green
            return $response
        }

        Write-Warning "[$agentName] CLI did not produce response file"
        return $null
    }.GetNewClosure()

    # Enter the loop
    return Enter-AgentLoop -MessageHandler $defaultHandler -TimeoutMs $TimeoutMs
}

# ============================================================================
# EXPORTS
# ============================================================================

Export-ModuleMember -Function @(
    # Connection
    'Connect-ToWatchdog',

    # Messaging - Send
    'Send-Message',
    'Send-AgentStatus',
    'Send-WorkComplete',
    'Send-ProblemReport',

    # Messaging - Receive
    'Receive-Message',

    # Agent Loop
    'Enter-AgentLoop',
    'Start-AgentLoop',

    # Helpers
    'Get-AgentName',
    'Get-SessionDir',
    'IsConnected'
)
