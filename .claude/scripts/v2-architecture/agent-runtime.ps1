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

    # Helpers
    'Get-AgentName',
    'Get-SessionDir',
    'IsConnected'
)
