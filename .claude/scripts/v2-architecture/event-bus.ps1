# Ralph Event Bus - Bidirectional Pipe Transport
#
# Design Patterns Applied:
# - Actor Model: Named pipes as actor addresses
# - Single Message Channel: One bidirectional pipe per agent
# - At-Least-Once Delivery: Undelivered queue for fallback
#
# Key Features:
# - Bidirectional named pipes for fast messaging
# - Undelivered queue for fallback delivery
# - Non-blocking message reads
#
# - Non-blocking reads for event-driven operation
# - Automatic fallback to undelivered queue on failure

$Script:EventBusPipes = @{}
$Script:EventBusSessionDir = $null

# ============================================================================
# INITIALIZATION
# ============================================================================

function Initialize-EventBus {
    <#
    .SYNOPSIS
    Initialize the event bus for a Ralph session.

    .PARAMETER SessionDir
    The session directory path.

    .RETURNS
    $true on success.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$SessionDir
    )

    $Script:EventBusSessionDir = $SessionDir

    # Create pipes directory
    $pipeDir = Join-Path $SessionDir "pipes"
    if (-not (Test-Path $pipeDir)) {
        New-Item -ItemType Directory -Path $pipeDir -Force | Out-Null
    }

    return $true
}

# ============================================================================
# PIPE CREATION
# ============================================================================

function New-BidirectionalPipe {
    <#
    .SYNOPSIS
    Create a new bidirectional named pipe for an agent.

    .DESCRIPTION
    Creates a duplex named pipe server that can both read from
    and write to an agent process. This replaces the old one-way
    pipe system and file-based message queues.

    .PARAMETER AgentName
    The name of the agent (pm, developer, qa, etc.).

    .RETURNS
    A pipe context hashtable with Pipe, Reader, Writer properties.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$AgentName
    )

    $pipeName = "ralph-$AgentName-main"
    $pipeDir = Join-Path $Script:EventBusSessionDir "pipes"

    # Ensure directory exists
    if (-not (Test-Path $pipeDir)) {
        New-Item -ItemType Directory -Path $pipeDir -Force | Out-Null
    }

    # Create duplex pipe server (bidirectional)
    # InOut direction allows two-way communication on a single pipe
    $pipe = [System.IO.Pipes.NamedPipeServerStream]::new(
        $pipeName,
        [System.IO.Pipes.PipeDirection]::InOut,
        1,  # MaxServerInstances - only one connection allowed
        [System.IO.Pipes.PipeTransmissionMode]::Message,
        [System.IO.Pipes.PipeOptions]::Asynchronous
    )

    $pipeContext = @{
        Name = $pipeName
        Pipe = $pipe
        Reader = $null
        Writer = $null
        Connected = $false
        AgentName = $AgentName
        MessagesSent = 0
        MessagesReceived = 0
        CreatedAt = [DateTime]::UtcNow
    }

    $Script:EventBusPipes[$AgentName] = $pipeContext

    Write-Host "[EventBus] Created pipe: $pipeName" -ForegroundColor DarkGray

    return $pipeContext
}

# ============================================================================
# PIPE CONNECTION
# ============================================================================

function Wait-PipeConnection {
    <#
    .SYNOPSIS
    Wait for an agent to connect to its named pipe.

    .PARAMETER AgentName
    The agent name to wait for.

    .PARAMETER TimeoutMs
    Maximum time to wait in milliseconds (default: 30000).

    .RETURNS
    $true if connected, $false if timeout.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$AgentName,

        [Parameter(Mandatory=$false)]
        [int]$TimeoutMs = 30000
    )

    $ctx = $Script:EventBusPipes[$AgentName]
    if (-not $ctx) {
        Write-Warning "[EventBus] No pipe found for agent: $AgentName"
        return $false
    }

    if ($ctx.Connected) {
        return $true
    }

    try {
        $connected = $ctx.Pipe.WaitForConnection($TimeoutMs)

        if ($connected) {
            # Create reader and writer streams
            $ctx.Reader = [System.IO.StreamReader]::new($ctx.Pipe)
            $ctx.Writer = [System.IO.StreamWriter]::new($ctx.Pipe)
            $ctx.Writer.AutoFlush = $true
            $ctx.Connected = $true

            Write-Host "[EventBus] $AgentName connected" -ForegroundColor DarkGray
        } else {
            Write-Warning "[EventBus] $AgentName connection timeout after ${TimeoutMs}ms"
        }

        return $connected
    } catch {
        Write-Warning "[EventBus] Error waiting for $AgentName connection: $_"
        return $false
    }
}

# ============================================================================
# MESSAGING - SEND
# ============================================================================

function Send-MessageToAgent {
    <#
    .SYNOPSIS
    Send a message to an agent via named pipe.

    .DESCRIPTION
    Sends a JSON message to an agent. If the pipe is not connected,
    falls back to the undelivered queue for retry later.

    .PARAMETER AgentName
    The recipient agent name.

    .PARAMETER Message
    The message hashtable or object to send.

    .RETURNS
    $true if sent successfully, $false otherwise (queued for retry).
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$AgentName,

        [Parameter(Mandatory=$true)]
        [object]$Message
    )

    $ctx = $Script:EventBusPipes[$AgentName]

    if (-not $ctx) {
        Write-Warning "[EventBus] No pipe found for agent: $AgentName"
        Write-Undelivered -AgentName $AgentName -Message $Message
        return $false
    }

    if (-not $ctx.Connected) {
        Write-Debug "[EventBus] $AgentName not connected, queuing message"
        Write-Undelivered -AgentName $AgentName -Message $Message
        return $false
    }

    try {
        # Check if pipe is still connected
        if (-not $ctx.Pipe.IsConnected) {
            $ctx.Connected = $false
            Write-Undelivered -AgentName $AgentName -Message $Message
            return $false
        }

        $json = $Message | ConvertTo-Json -Compress -Depth 10
        $ctx.Writer.WriteLine($json)

        $ctx.MessagesSent++
        return $true
    } catch {
        Write-Warning "[EventBus] Error sending to $AgentName`: $_"
        $ctx.Connected = $false
        Write-Undelivered -AgentName $AgentName -Message $Message
        return $false
    }
}

function Send-MessageToAgents {
    <#
    .SYNOPSIS
    Send a message to multiple agents.

    .PARAMETER AgentNames
    Array of agent names to send to.

    .PARAMETER Message
    The message to send.

    .RETURNS
    Number of agents successfully sent to.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$AgentNames,

        [Parameter(Mandatory=$true)]
        [object]$Message
    )

    $sent = 0
    foreach ($agentName in $AgentNames) {
        if (Send-MessageToAgent -AgentName $agentName -Message $Message) {
            $sent++
        }
    }
    return $sent
}

function Broadcast-Message {
    <#
    .SYNOPSIS
    Send a message to all connected agents.

    .PARAMETER Message
    The message to broadcast.

    .PARAMETER ExcludeAgent
    Optional agent name to exclude from broadcast.

    .RETURNS
    Number of agents successfully sent to.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [object]$Message,

        [Parameter(Mandatory=$false)]
        [string]$ExcludeAgent = ""
    )

    $agents = @($Script:EventBusPipes.Keys | Where-Object { $_ -ne $ExcludeAgent })
    return Send-MessageToAgents -AgentNames $agents -Message $Message
}

# ============================================================================
# MESSAGING - RECEIVE
# ============================================================================

function Receive-MessageFromAgent {
    <#
    .SYNOPSIS
    Receive a message from an agent (non-blocking).

    .DESCRIPTION
    Reads a message from an agent's pipe if one is available.
    Returns $null immediately if no message is waiting (non-blocking).

    .PARAMETER AgentName
    The agent name to receive from.

    .RETURNS
    The message object, or $null if no message available.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$AgentName
    )

    $ctx = $Script:EventBusPipes[$AgentName]

    if (-not $ctx -or -not $ctx.Connected) {
        return $null
    }

    try {
        $pipe = $ctx.Pipe

        # Check if still connected
        if (-not $pipe.IsConnected) {
            $ctx.Connected = $false
            return $null
        }

        # Non-blocking check using Peek
        if ($ctx.Reader.Peek() -gt 0) {
            $line = $ctx.Reader.ReadLine()

            if ($line -and $line -match '\S') {
                $ctx.MessagesReceived++
                return $line | ConvertFrom-Json
            }
        }

        return $null
    } catch {
        Write-Warning "[EventBus] Error receiving from $AgentName`: $_"
        $ctx.Connected = $false
        return $null
    }
}

function Receive-MessageFromAnyAgent {
    <#
    .SYNOPSIS
    Receive a message from any agent that has one available.

    .RETURNS
    Hashtable with AgentName and Message, or $null if no messages.
    #>

    foreach ($agentName in $Script:EventBusPipes.Keys) {
        $msg = Receive-MessageFromAgent -AgentName $agentName
        if ($msg) {
            return @{
                AgentName = $agentName
                Message = $msg
            }
        }
    }

    return $null
}

function Receive-AllPendingMessages {
    <#
    .SYNOPSIS
    Receive all pending messages from all agents.

    .RETURNS
    Array of hashtables with AgentName and Message.
    #>
    $messages = @()

    foreach ($agentName in $Script:EventBusPipes.Keys) {
        while ($msg = Receive-MessageFromAgent -AgentName $agentName) {
            $messages += @{
                AgentName = $agentName
                Message = $msg
            }
        }
    }

    return $messages
}

# ============================================================================
# UNDELIVERED QUEUE (Fallback)
# ============================================================================

function Get-UndeliveredFilePath {
    <#
    .SYNOPSIS
    Get the path to the undelivered messages file.
    #>
    return Join-Path $Script:EventBusSessionDir "undelivered.jsonl"
}

function Write-Undelivered {
    <#
    .SYNOPSIS
    Write a failed message to the undelivered queue.

    .PARAMETER AgentName
    The intended recipient agent name.

    .PARAMETER Message
    The message that failed to deliver.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$AgentName,

        [Parameter(Mandatory=$true)]
        [object]$Message
    )

    $undeliveredFile = Get-UndeliveredFilePath

    $entry = @{
        agent = $AgentName
        message = $Message
        timestamp = [DateTime]::UtcNow.ToString("o")
    } | ConvertTo-Json -Compress -Depth 10

    try {
        Add-Content -Path $undeliveredFile -Value $entry -Encoding UTF8
    } catch {
        # Create directory if it doesn't exist
        $dir = Split-Path -Parent $undeliveredFile
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Add-Content -Path $undeliveredFile -Value $entry -Encoding UTF8
        }
    }
}

function Get-UndeliveredMessages {
    <#
    .SYNOPSIS
    Get all undelivered messages for an agent.

    .PARAMETER AgentName
    The agent name to filter by.

    .RETURNS
    Array of undelivered message entries (always returns an array).
    #>
    param(
        [Parameter(Mandatory=$false)]
        [string]$AgentName = ""
    )

    $undeliveredFile = Get-UndeliveredFilePath

    if (-not (Test-Path $undeliveredFile)) {
        return @()
    }

    $entryList = [System.Collections.Generic.List[object]]::new()
    try {
        Get-Content $undeliveredFile -ErrorAction SilentlyContinue | ForEach-Object {
            if ($_ -match '\S') {
                $entry = $_ | ConvertFrom-Json
                if (-not $AgentName -or $entry.agent -eq $AgentName) {
                    [void]$entryList.Add($entry)
                }
            }
        }
    } catch {
        # Return empty on error
    }

    # Always return an array
    return ,@($entryList.ToArray())
}

function Retry-Undelivered {
    <#
    .SYNOPSIS
    Retry sending undelivered messages for an agent.

    .PARAMETER AgentName
    The agent name to retry for.

    .RETURNS
    Number of messages successfully delivered.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$AgentName
    )

    $entries = Get-UndeliveredMessages -AgentName $AgentName

    if ($entries.Count -eq 0) {
        return 0
    }

    $delivered = 0
    $remaining = @()

    foreach ($entry in $entries) {
        $sent = Send-MessageToAgent -AgentName $AgentName -Message $entry.message
        if ($sent) {
            $delivered++
        } else {
            $remaining += $entry
        }
    }

    # Update undelivered file with remaining entries
    $undeliveredFile = Get-UndeliveredFilePath

    if ($remaining.Count -eq 0) {
        # All delivered, remove entries for this agent
        $allEntries = Get-UndeliveredMessages
        $otherEntries = $allEntries | Where-Object { $_.agent -ne $AgentName }
        $otherEntries | ForEach-Object {
            $_.ToString() | ConvertTo-Json -Compress | Out-File -FilePath $undeliveredFile -Append -Encoding UTF8
        }
    } else {
        # Write back remaining entries
        $remaining | ForEach-Object {
            $_.ToString() | ConvertTo-Json -Compress | Out-File -FilePath $undeliveredFile -Append -Encoding UTF8
        }
    }

    if ($delivered -gt 0) {
        Write-Host "[EventBus] Delivered $delivered pending message(s) to $AgentName" -ForegroundColor Cyan
    }

    return $delivered
}

function Retry-AllUndelivered {
    <#
    .SYNOPSIS
    Retry sending all undelivered messages to their respective agents.

    .RETURNS
    Total number of messages successfully delivered.
    #>
    $totalDelivered = 0

    # Get unique agent names from undelivered queue
    $agents = (Get-UndeliveredMessages | Select-Object -ExpandProperty agent | Sort-Object -Unique)

    foreach ($agentName in $agents) {
        $totalDelivered += Retry-Undelivered -AgentName $agentName
    }

    return $totalDelivered
}

# ============================================================================
# PIPE MANAGEMENT
# ============================================================================

function Close-Pipe {
    <#
    .SYNOPSIS
    Close an agent's pipe connection gracefully.

    .PARAMETER AgentName
    The agent whose pipe should be closed.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$AgentName
    )

    $ctx = $Script:EventBusPipes[$AgentName]

    if ($ctx) {
        try {
            if ($ctx.Writer) {
                $ctx.Writer.Close()
                $ctx.Writer.Dispose()
            }
            if ($ctx.Reader) {
                $ctx.Reader.Close()
                $ctx.Reader.Dispose()
            }
            if ($ctx.Pipe) {
                if ($ctx.Pipe.IsConnected) {
                    $ctx.Pipe.Flush()
                    $ctx.Pipe.Close()
                }
                $ctx.Pipe.Dispose()
            }
        } catch {
            # Ignore cleanup errors
        }

        $ctx.Connected = $false
        Write-Host "[EventBus] Closed pipe for $AgentName" -ForegroundColor DarkGray
    }
}

function Remove-Pipe {
    <#
    .SYNOPSIS
    Remove an agent's pipe from the bus.

    .PARAMETER AgentName
    The agent whose pipe should be removed.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$AgentName
    )

    Close-Pipe -AgentName $AgentName
    $Script:EventBusPipes.Remove($AgentName)
}

function Close-AllPipes {
    <#
    .SYNOPSIS
    Close all pipe connections gracefully.
    #>

    foreach ($agentName in @($Script:EventBusPipes.Keys)) {
        Close-Pipe -AgentName $agentName
    }
}

# ============================================================================
# STATUS AND DIAGNOSTICS
# ============================================================================

function Get-PipeStatus {
    <#
    .SYNOPSIS
    Get status of all agent pipes.

    .RETURNS
    Hashtable mapping agent names to their pipe status.
    #>
    $status = @{}

    foreach ($kv in $Script:EventBusPipes.GetEnumerator()) {
        $ctx = $kv.Value
        $status[$kv.Key] = @{
            Name = $ctx.Name
            Connected = $ctx.Connected
            MessagesSent = $ctx.MessagesSent
            MessagesReceived = $ctx.MessagesReceived
            CreatedAt = $ctx.CreatedAt
            IsConnected = if ($ctx.Pipe) { $ctx.Pipe.IsConnected } else { $false }
        }
    }

    return $status
}

function Get-ConnectedAgents {
    <#
    .SYNOPSIS
    Get list of agents with connected pipes.

    .RETURNS
    Array of connected agent names.
    #>
    return @($Script:EventBusPipes.GetEnumerator() |
        Where-Object { $_.Value.Connected -and $_.Value.Pipe.IsConnected } |
        ForEach-Object { $_.Key })
}

# ============================================================================
# EXPORTS
# ============================================================================

# Only export if running as a module (not when sourced directly)
try {
    Export-ModuleMember -Function @(
        # Initialization
        'Initialize-EventBus',

        # Pipe creation
        'New-BidirectionalPipe',

        # Pipe connection
        'Wait-PipeConnection',

        # Messaging - Send
        'Send-MessageToAgent',
        'Send-MessageToAgents',
        'Broadcast-Message',

        # Messaging - Receive
        'Receive-MessageFromAgent',
        'Receive-MessageFromAnyAgent',
        'Receive-AllPendingMessages',

        # Undelivered queue
        'Get-UndeliveredFilePath',
        'Write-Undelivered',
        'Get-UndeliveredMessages',
        'Retry-Undelivered',
        'Retry-AllUndelivered',

        # Pipe management
        'Close-Pipe',
        'Remove-Pipe',
        'Close-AllPipes',

        # Status and diagnostics
        'Get-PipeStatus',
        'Get-ConnectedAgents'
    )
} catch {
    # Not running as a module - ignore export error
}
