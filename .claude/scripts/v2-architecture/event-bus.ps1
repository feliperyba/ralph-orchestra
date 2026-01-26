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

    # CRITICAL: Clear any stale PowerShell processes that might be holding pipes
    # This prevents "All pipe instances are busy" errors
    Clear-StalePowerShellProcesses

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

function Remove-StalePipe {
    <#
    .SYNOPSIS
    Remove a stale pipe for an agent if it exists.

    .PARAMETER AgentName
    The agent whose pipe should be cleaned up.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$AgentName
    )

    # Try to disconnect existing pipe if in cache (FIRST - before trying to kill processes)
    if ($Script:EventBusPipes.ContainsKey($AgentName)) {
        $ctx = $Script:EventBusPipes[$AgentName]
        try {
            if ($ctx.Writer) {
                $ctx.Writer.Dispose()
            }
            if ($ctx.Reader) {
                $ctx.Reader.Dispose()
            }
            if ($ctx.Pipe) {
                $ctx.Pipe.Dispose()
            }
        } catch {
            # Ignore disposal errors
        }
        $Script:EventBusPipes.Remove($AgentName)
    }

    # Only attempt process cleanup if we have a session PID (safer approach)
    $pipeName = "ralph-$AgentName-main"

    # Get session PID to avoid killing current session processes
    $sessionPid = $null
    $sessionMarkerFile = Join-Path $Script:EventBusSessionDir "session-pid.txt"
    if (Test-Path $sessionMarkerFile) {
        try {
            $sessionData = Get-Content $sessionMarkerFile | ConvertFrom-Json
            $sessionPid = $sessionData.SessionPid
        } catch {
            # Invalid marker file
        }
    }

    # If no session tracking, skip process killing for safety
    if (-not $sessionPid) {
        return
    }

    try {
        # Find PowerShell processes that might be holding the pipe
        $powershellProcesses = Get-Process -Name "pwsh", "powershell" -ErrorAction SilentlyContinue
        foreach ($psProc in $powershellProcesses) {
            try {
                # Never kill the session process itself
                if ($psProc.Id -eq $sessionPid) { continue }

                # Check if this process is actually holding our pipe via command line check
                $cmdLine = (Get-WmiObject Win32_Process -Filter "ProcessId = $($psProc.Id)" -ErrorAction SilentlyContinue).CommandLine

                # Only kill processes that are clearly for this specific pipe
                if ($cmdLine -and $cmdLine.Contains($pipeName)) {
                    # Verify it's not in our current session tree
                    $isCurrentSession = $false
                    $ancestorPid = $psProc.Parent.Id
                    $maxDepth = 5
                    $depth = 0
                    while ($ancestorPid -and $depth -lt $maxDepth) {
                        if ($ancestorPid -eq $sessionPid) {
                            $isCurrentSession = $true
                            break
                        }
                        try {
                            $ancestorProc = Get-Process -Id $ancestorPid -ErrorAction SilentlyContinue
                            if ($ancestorProc) {
                                $ancestorPid = $ancestorProc.Parent.Id
                            } else {
                                break
                            }
                        } catch {
                            break
                        }
                        $depth++
                    }

                    if (-not $isCurrentSession) {
                        Write-Host "[EventBus] Killing process holding pipe $pipeName (PID: $($psProc.Id))" -ForegroundColor Yellow
                        $psProc.Kill()
                        Start-Sleep -Milliseconds 200
                    }
                }
            } catch {
                # Continue checking other processes
            }
        }
    } catch {
        # Ignore errors in process enumeration
    }
}

function Clear-StalePowerShellProcesses {
    <#
    .SYNOPSIS
    Clear all stale PowerShell processes that might be holding Ralph pipes.

    .DESCRIPTION
    Finds and kills orphaned PowerShell processes that were likely created
    by Ralph agents but didn't clean up properly. These processes can hold
    named pipes and cause "All pipe instances are busy" errors.

    SAFETY: Only kills processes that are clearly orphaned Ralph agents:
    - Must have no main window (background process)
    - Must be older than 5 minutes (truly stale)
    - Must contain Ralph-specific patterns in command line
    - Must NOT be part of the current session tree
    #>
    try {
        # Get session PID to avoid killing current session processes
        $sessionPid = $null
        $sessionMarkerFile = Join-Path $Script:EventBusSessionDir "session-pid.txt"
        if (Test-Path $sessionMarkerFile) {
            try {
                $sessionData = Get-Content $sessionMarkerFile | ConvertFrom-Json
                $sessionPid = $sessionData.SessionPid
            } catch {
                # Invalid marker file
            }
        }

        # Get all PowerShell processes
        $powershellProcesses = Get-Process -Name "pwsh", "powershell" -ErrorAction SilentlyContinue

        $killedCount = 0
        foreach ($psProc in $powershellProcesses) {
            try {
                # Never kill the session process itself
                if ($sessionPid -and $psProc.Id -eq $sessionPid) { continue }

                $processAge = [DateTime]::UtcNow - $psProc.StartTime.ToUniversalTime()

                # Check if this is likely a Ralph agent PowerShell:
                # - No main window title (running in background)
                # - Older than 5 minutes (truly orphaned - increased from 2 for safety)
                $hasMainWindow = -not [string]::IsNullOrEmpty($psProc.MainWindowTitle)

                if (-not $hasMainWindow -and $processAge.TotalMinutes -gt 5) {
                    # Additional safety check: verify it's a Ralph process via command line
                    try {
                        $cmdLine = (Get-WmiObject Win32_Process -Filter "ProcessId = $($psProc.Id)" -ErrorAction SilentlyContinue).CommandLine

                        # Only kill if it contains Ralph-specific patterns
                        if ($cmdLine -and ($cmdLine.Contains("ralph-") -or $cmdLine.Contains("Start-AgentLoop") -or $cmdLine.Contains("agent-runtime.ps1"))) {
                            # Final safety check: verify it's not in current session tree
                            $isCurrentSession = $false
                            if ($sessionPid) {
                                $ancestorPid = $psProc.Parent.Id
                                $maxDepth = 5
                                $depth = 0
                                while ($ancestorPid -and $depth -lt $maxDepth) {
                                    if ($ancestorPid -eq $sessionPid) {
                                        $isCurrentSession = $true
                                        break
                                    }
                                    try {
                                        $ancestorProc = Get-Process -Id $ancestorPid -ErrorAction SilentlyContinue
                                        if ($ancestorProc) {
                                            $ancestorPid = $ancestorProc.Parent.Id
                                        } else {
                                            break
                                        }
                                    } catch {
                                        break
                                    }
                                    $depth++
                                }
                            }

                            if (-not $isCurrentSession) {
                                Write-Host "[EventBus] Killing stale Ralph PowerShell (PID: $($psProc.Id), Age: $([int]$processAge.TotalMinutes)m)" -ForegroundColor DarkGray
                                $psProc.Kill()
                                $killedCount++
                            }
                        }
                    } catch {
                        # WMI failed - skip this process to be safe
                    }
                }
            } catch {
                # Process already exited or access denied
            }
        }

        if ($killedCount -gt 0) {
            Write-Host "[EventBus] Killed $killedCount stale Ralph PowerShell process(es)" -ForegroundColor Yellow
            Start-Sleep -Milliseconds 500  # Give OS time to release pipes
        }
    } catch {
        # Ignore errors in cleanup
    }
}

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

    # Clean up any existing pipe for this agent first (in-memory cache)
    Remove-StalePipe -AgentName $AgentName

    # AGGRESSIVE CLEANUP: Try multiple approaches to clear stale pipes
    # Approach 1: Try to connect as client to force disconnect any stale server
    $attempts = 0
    $maxAttempts = 5
    while ($attempts -lt $maxAttempts) {
        try {
            $testPipe = [System.IO.Pipes.NamedPipeClientStream]::new(".", $pipeName, [System.IO.Pipes.PipeDirection]::InOut)
            if ($testPipe.TryConnect(500)) {
                # Pipe exists - connect and immediately disconnect to clear it
                $testPipe.Close()
                $testPipe.Dispose()
                Write-Host "[EventBus] Cleared stale pipe: $pipeName (attempt $($attempts + 1))" -ForegroundColor DarkGray
                Start-Sleep -Milliseconds 200
                $attempts++
                # Try again to make sure it's really gone
                continue
            }
            $testPipe.Dispose()
            break
        } catch {
            # Pipe doesn't exist - this is what we want
            $testPipe.Dispose()
            break
        }
    }

    # Approach 2: Force kill any PowerShell processes holding our specific pipes
    try {
        $powershellProcesses = Get-Process -Name "pwsh", "powershell" -ErrorAction SilentlyContinue
        foreach ($psProc in $powershellProcesses) {
            try {
                # Check command line arguments for our pipe name
                $cmdLine = (Get-WmiObject Win32_Process -Filter "ProcessId = $($psProc.Id)" -ErrorAction SilentlyContinue).CommandLine
                if ($cmdLine -and $cmdLine.Contains($pipeName)) {
                    Write-Host "[EventBus] Killing process holding pipe $pipeName (PID: $($psProc.Id))" -ForegroundColor Yellow
                    $psProc.Kill()
                    Start-Sleep -Milliseconds 200
                }
            } catch {
                # Continue checking other processes
            }
        }
    } catch {
        # Ignore WMI errors
    }

    # Final attempt to clear by trying to connect one more time
    try {
        $finalCheckPipe = [System.IO.Pipes.NamedPipeClientStream]::new(".", $pipeName, [System.IO.Pipes.PipeDirection]::InOut)
        if ($finalCheckPipe.TryConnect(100)) {
            $finalCheckPipe.Close()
            $finalCheckPipe.Dispose()
            Start-Sleep -Milliseconds 500
        } else {
            $finalCheckPipe.Dispose()
        }
    } catch {
        # Pipe doesn't exist - good
    }

    # Create duplex pipe server (bidirectional)
    # InOut direction allows two-way communication on a single pipe
    try {
        $pipe = [System.IO.Pipes.NamedPipeServerStream]::new(
            $pipeName,
            [System.IO.Pipes.PipeDirection]::InOut,
            1,  # MaxServerInstances - only one connection allowed
            [System.IO.Pipes.PipeTransmissionMode]::Message,
            [System.IO.Pipes.PipeOptions]::Asynchronous
        )
    } catch {
        Write-Error "Failed to create pipe for $AgentName`: $_"
        Write-Host ""
        Write-Host "This usually means a pipe from a previous session is still active." -ForegroundColor Yellow
        Write-Host "Try stopping any running Claude processes and run again." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Or manually cleanup with:" -ForegroundColor Gray
        Write-Host "  Get-Process | Where-Object {$_.ProcessName -like '*claude*' -or $_.ProcessName -like '*powershell*'} | Stop-Process -Force" -ForegroundColor DarkGray
        throw
    }

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
        # WaitForConnectionAsync() is parameterless - timeout handled by Task.Wait()
        $task = $ctx.Pipe.WaitForConnectionAsync()
        $timeout = [TimeSpan]::FromMilliseconds($TimeoutMs)
        $completed = $task.Wait($timeout)

        if ($completed) {
            # Create reader and writer streams
            $ctx.Reader = [System.IO.StreamReader]::new($ctx.Pipe)
            $ctx.Writer = [System.IO.StreamWriter]::new($ctx.Pipe)
            $ctx.Writer.AutoFlush = $true
            $ctx.Connected = $true

            Write-Host "[EventBus] $AgentName connected" -ForegroundColor DarkGray
            return $true
        } else {
            Write-Warning "[EventBus] $AgentName connection timeout after ${TimeoutMs}ms"
            return $false
        }
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
    Write a failed message to the undelivered queue with TTL.

    .DESCRIPTION
    CRITICAL FIX: Added TTL (time-to-live) to prevent unbounded queue growth.
    Messages expire after 1 hour and are cleaned up automatically.

    .PARAMETER AgentName
    The intended recipient agent name.

    .PARAMETER Message
    The message that failed to deliver.

    .PARAMETER TTLHours
    Time-to-live in hours. Default is 1 hour.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$AgentName,

        [Parameter(Mandatory=$true)]
        [object]$Message,

        [Parameter(Mandatory=$false)]
        [int]$TTLHours = 1
    )

    $undeliveredFile = Get-UndeliveredFilePath

    $entry = @{
        agent = $AgentName
        message = $Message
        timestamp = [DateTime]::UtcNow.ToString("o")
        expiresAt = ([DateTime]::UtcNow.AddHours($TTLHours)).ToString("o")
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
    Get all undelivered messages for an agent, excluding expired ones.

    .DESCRIPTION
    CRITICAL FIX: Filters out expired messages to prevent processing stale data.

    .PARAMETER AgentName
    The agent name to filter by.

    .PARAMETER CleanExpired
    If true, removes expired entries from the file.

    .RETURNS
    Array of undelivered message entries (always returns an array).
    #>
    param(
        [Parameter(Mandatory=$false)]
        [string]$AgentName = "",

        [Parameter(Mandatory=$false)]
        [switch]$CleanExpired
    )

    $undeliveredFile = Get-UndeliveredFilePath

    if (-not (Test-Path $undeliveredFile)) {
        return @()
    }

    $entryList = [System.Collections.Generic.List[object]]::new()
    $validEntries = [System.Collections.Generic.List[string]]::new()
    $now = [DateTime]::UtcNow

    try {
        Get-Content $undeliveredFile -ErrorAction SilentlyContinue | ForEach-Object {
            if ($_ -match '\S') {
                try {
                    $entry = $_ | ConvertFrom-Json

                    # Check if expired (only if expiresAt field exists)
                    $isExpired = if ($entry.expiresAt) {
                        try {
                            $expiresAt = [DateTime]::Parse($entry.expiresAt)
                            $now -gt $expiresAt
                        } catch {
                            $false  # If parse fails, treat as not expired
                        }
                    } else {
                        $false  # Old entries without expiresAt are kept
                    }

                    if (-not $isExpired) {
                        if (-not $AgentName -or $entry.agent -eq $AgentName) {
                            [void]$entryList.Add($entry)
                        }
                        if ($CleanExpired) {
                            [void]$validEntries.Add($_)
                        }
                    }
                } catch {
                    # Skip malformed entries
                }
            }
        }
    } catch {
        # Return empty on error
    }

    # If cleaning, rewrite the file with only valid entries
    if ($CleanExpired -and $validEntries.Count -gt 0) {
        try {
            $validEntries | Out-File -FilePath $undeliveredFile -Encoding UTF8
        } catch {
            # Ignore cleanup errors
        }
    }

    # Always return an array
    return ,@($entryList.ToArray())
}

function Retry-Undelivered {
    <#
    .SYNOPSIS
    Retry sending undelivered messages for an agent.

    .DESCRIPTION
    CRITICAL FIX: Automatically cleans expired messages during retry.

    .PARAMETER AgentName
    The agent name to retry for.

    .RETURNS
    Number of messages successfully delivered.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$AgentName
    )

    # Get non-expired messages and clean expired ones from file
    $entries = Get-UndeliveredMessages -AgentName $AgentName -CleanExpired

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
        $allEntries = Get-UndeliveredMessages -CleanExpired
        $otherEntries = $allEntries | Where-Object { $_.agent -ne $AgentName }
        $otherEntries | ForEach-Object {
            $_.ToString() | ConvertTo-Json -Compress -Depth 10 | Out-File -FilePath $undeliveredFile -Append -Encoding UTF8
        }
    } else {
        # Write back remaining entries
        $remaining | ForEach-Object {
            $_.ToString() | ConvertTo-Json -Compress -Depth 10 | Out-File -FilePath $undeliveredFile -Append -Encoding UTF8
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

    .DESCRIPTION
    Also cleans expired messages during processing.

    .RETURNS
    Total number of messages successfully delivered.
    #>
    $totalDelivered = 0

    # Get unique agent names from undelivered queue (non-expired only)
    $agents = (Get-UndeliveredMessages -CleanExpired | Select-Object -ExpandProperty agent | Sort-Object -Unique)

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
