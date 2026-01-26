# Ralph Actor Model Implementation
# True Erlang/OTP-style Actor Model for PowerShell
#
# Design Patterns Applied:
# - Actor Model: Isolated state, message mailbox, selective receive
# - Supervisor Pattern: Hierarchical restart strategies
# - Let It Crash: Fault isolation through process boundaries
#
# References:
# - https://www.erlang.org/doc/reference_manual/processes
# - https://www.erlang.org/doc/design_principles/sup_princ.html
# - https://github.com/akkadotnet/akka-dotnet

using namespace System.Threading
using namespace System.Collections.Concurrent

# ============================================================================
# ENUMS
# ============================================================================

enum ActorState {
    Created     # Actor created but not started
    Starting    # PreStart hook executing
    Idle        # Running, waiting for messages
    Processing  # Currently processing a message
    Restarting  # Being restarted by supervisor
    Stopping    # PostStop hook executing
    Stopped     # Gracefully terminated
    Crashed     # Terminated due to exception
}

enum RestartStrategy {
    OneForOne    # Restart only crashed child
    OneForAll    # Restart all children if one crashes
    RestForOne   # Restart crashed child and those started after it
}

enum RestartType {
    Permanent   # Always restart
    Transient    # Restart only on abnormal exit
    Temporary    # Never restart
}

# ============================================================================
# ACTOR MESSAGE
# ============================================================================

class ActorMessage {
    # Unique message identifier for tracking
    [string] $Id

    # Message type for routing and filtering
    [string] $Type

    # Message payload (can be any object)
    [object] $Payload

    # When message was created
    [DateTime] $Timestamp

    # Sender actor reference (null for system messages)
    [string] $Sender

    # Higher values = processed first (0 = normal priority)
    [int] $Priority

    # Optional correlation ID for request/response patterns
    [string] $CorrelationId

    # Optional reply-to destination
    [string] $ReplyTo

    ActorMessage() {
        $this.Id = [Guid]::NewGuid().ToString("N")
        $this.Timestamp = [DateTime]::UtcNow
        $this.Priority = 0
    }

    ActorMessage([string]$type, [object]$payload) : this() {
        $this.Type = $type
        $this.Payload = $payload
    }

    # Create a response message for this message
    [ActorMessage] CreateResponse([object]$responsePayload) {
        $response = [ActorMessage]::new("Response", $responsePayload)
        $response.CorrelationId = $this.Id
        if ($this.ReplyTo) {
            $response.ReplyTo = $this.ReplyTo
        } else {
            $response.ReplyTo = $this.Sender
        }
        return $response
    }

    # Check if this message is a response to the specified message
    [bool] IsResponseTo([ActorMessage]$originalMessage) {
        return $this.CorrelationId -eq $originalMessage.Id
    }
}

# System message types for actor lifecycle
class SystemMessage {
    static [string] $Stop = "System.Stop"
    static [string] $Kill = "System.Kill"
    static [string] $Ping = "System.Ping"
    static [string] $Pong = "System.Pong"
    static [string] $Terminate = "System.Terminate"
}

# ============================================================================
# ACTOR MAILBOX
# ============================================================================

class ActorMailbox {
    # Priority queue for high-priority messages
    hidden [System.Collections.Generic.List[ActorMessage]]$PriorityQueue

    # Normal queue for regular messages
    hidden [ConcurrentQueue[ActorMessage]]$NormalQueue

    # Event signal for message arrival (enables non-blocking waits)
    hidden [ManualResetEventSlim]$Signal

    # Maximum mailbox size before backpressure kicks in
    [int]$MaxSize

    # Current total message count
    [int]$Count

    # Messages dropped due to full mailbox
    hidden [long]$DroppedCount

    ActorMailbox([int]$maxSize) {
        $this.PriorityQueue = [System.Collections.Generic.List[ActorMessage]]::new()
        $this.NormalQueue = [ConcurrentQueue[ActorMessage]]::new()
        $this.Signal = [ManualResetEventSlim]::new($false)
        $this.MaxSize = $maxSize
        $this.Count = 0
        $this.DroppedCount = 0
    }

    # Try to enqueue a message (returns false if mailbox is full)
    [bool] TryEnqueue([ActorMessage]$message) {
        if ($null -eq $message) {
            return $false
        }

        # Check if mailbox is full
        if ($this.Count -ge $this.MaxSize) {
            [Interlocked]::Increment([ref]$this.DroppedCount)
            return $false
        }

        # Add to appropriate queue based on priority
        if ($message.Priority -gt 0) {
            lock($this.PriorityQueue) {
                $this.PriorityQueue.Add($message)
                # Sort by priority (descending)
                $this.PriorityQueue.Sort({ $args[1].Priority - $args[0].Priority })
                $this.Count = $this.PriorityQueue.Count + $this.NormalQueue.Count
            }
        } else {
            $this.NormalQueue.Enqueue($message)
            $this.Count = $this.PriorityQueue.Count + $this.NormalQueue.Count
        }

        # Signal that a message is available
        $this.Signal.Set()
        return $true
    }

    # Dequeue a message with timeout (checks priority queue first)
    [ActorMessage] Dequeue([int]$timeoutMs) {
        $deadline = [DateTime]::UtcNow.AddMilliseconds($timeoutMs)

        while ([DateTime]::UtcNow -lt $deadline) {
            # Check priority queue first (lock-protected)
            lock($this.PriorityQueue) {
                if ($this.PriorityQueue.Count -gt 0) {
                    $msg = $this.PriorityQueue[0]
                    $this.PriorityQueue.RemoveAt(0)
                    $this.Count = $this.PriorityQueue.Count + $this.NormalQueue.Count

                    # Reset signal if no more messages
                    if ($this.Count -eq 0) {
                        $this.Signal.Reset()
                    }

                    return $msg
                }
            }

            # Try normal queue
            $msg = $null
            if ($this.NormalQueue.TryDequeue([ref]$msg)) {
                $this.Count = $this.PriorityQueue.Count + $this.NormalQueue.Count

                # Reset signal if no more messages
                if ($this.Count -eq 0) {
                    $this.Signal.Reset()
                }

                return $msg
            }

            # No messages available - wait for signal
            $remainingMs = [math]::Max(0, ($deadline - [DateTime]::UtcNow).TotalMilliseconds)
            if ($this.Signal.Wait([int]$remainingMs)) {
                $this.Signal.Reset()
                # Signal was set - loop again to check queues
                continue
            }

            # Timeout reached
            break
        }

        return $null
    }

    # Get all messages (for mailbox inspection/debugging)
    [ActorMessage[]] GetAllMessages() {
        $messages = [System.Collections.Generic.List[ActorMessage]]::new()

        lock($this.PriorityQueue) {
            foreach ($msg in $this.PriorityQueue) {
                $messages.Add($msg)
            }
        }

        while ($this.NormalQueue.TryDequeue([ref]$msg)) {
            $messages.Add($msg)
        }

        return $messages.ToArray()
    }

    # Clear all messages
    [void] Clear() {
        lock($this.PriorityQueue) {
            $this.PriorityQueue.Clear()
        }

        while ($this.NormalQueue.TryDequeue([ref]$null)) {}

        $this.Count = 0
        $this.Signal.Reset()
    }

    # Get mailbox statistics
    [hashtable] GetStats() {
        return @{
            Count = $this.Count
            PriorityCount = $this.PriorityQueue.Count
            NormalCount = $this.NormalQueue.Count
            Dropped = $this.DroppedCount
            MaxSize = $this.MaxSize
            Utilization = [math]::Round($this.Count / [double]$this.MaxSize * 100, 2)
        }
    }
}

# ============================================================================
# ACTOR CONTEXT
# ============================================================================

class ActorContext {
    [RalphActor]$Self
    [System.Collections.Generic.Dictionary[string,RalphActor]]$Actors
    [string]$Parent

    ActorContext([RalphActor]$self) {
        $this.Self = $self
        $this.Actors = [System.Collections.Generic.Dictionary[string,RalphActor]]::new()
    }

    # Send a message to another actor (fire-and-forget)
    [void] Send([string]$targetActor, [ActorMessage]$message) {
        if ($this.Actors.ContainsKey($targetActor)) {
            $actor = $this.Actors[$targetActor]
            $message.Sender = $this.Self.Name
            $actor.Tell($message)
        }
    }

    # Send a message to another actor (with reply-to set)
    [void] SendWithReplyTo([string]$targetActor, [ActorMessage]$message) {
        $message.ReplyTo = $this.Self.Name
        $this.Send($targetActor, $message)
    }

    # Request a message and wait for response (request-response pattern)
    [ActorMessage] Request([string]$targetActor, [ActorMessage]$message, [int]$timeoutMs) {
        $message.ReplyTo = $this.Self.Name
        $response = $null

        # Create a temporary mailbox filter for the response
        $filter = {
            param([ActorMessage]$msg)
            return $msg.Type -eq "Response" -and $msg.CorrelationId -eq $message.Id
        }

        # Send request
        $this.Send($targetActor, $message)

        # Wait for response with selective receive
        $response = $this.Self.Receive($filter, $timeoutMs)

        return $response
    }

    # Forward a message to another actor (preserving original sender)
    [void] Forward([string]$targetActor, [ActorMessage]$message) {
        if ($this.Actors.ContainsKey($targetActor)) {
            $actor = $this.Actors[$targetActor]
            $actor.Tell($message)
        }
    }

    # Spawn a new child actor
    [RalphActor] Spawn([string]$name, [scriptblock]$receiveHandler) {
        $child = [RalphActor]::new($name)
        $child.ReceiveHandler = $receiveHandler
        $child.Parent = $this.Self.Name

        $this.Actors[$name] = $child
        $child.Start()

        return $child
    }

    # Get a reference to another actor
    [RalphActor] Actor([string]$name) {
        if ($this.Actors.ContainsKey($name)) {
            return $this.Actors[$name]
        }
        return $null
    }

    # Stop a child actor
    [void] StopChild([string]$name) {
        if ($this.Actors.ContainsKey($name)) {
            $this.Actors[$name].Stop()
            $this.Actors.Remove($name)
        }
    }
}

# ============================================================================
# RALPH ACTOR
# ============================================================================

class RalphActor {
    # Identity
    [string]$Id
    [string]$Name

    # State
    [ActorState]$State
    [hashtable]$StateData

    # Mailbox
    [ActorMailbox]$Mailbox

    # Lifecycle
    [DateTime]$StartedAt
    [DateTime]$StoppedAt
    [int]$RestartCount
    [string]$Parent

    # Supervision
    [RestartType]$RestartType
    [int]$MaxRestarts
    [timespan]$RestartWindow

    # Processing
    hidden [CancellationTokenSource]$CancellationToken
    hidden [Thread]$ProcessingThread
    hidden [int]$ReceiveTimeoutMs

    # Behavior hooks (scriptblocks set by actor implementer)
    [scriptblock]$ReceiveHandler
    [scriptblock]$PreStartHandler
    [scriptblock]$PostStopHandler
    [scriptblock]$PreRestartHandler
    [scriptblock]$PostRestartHandler

    # Context for message handling
    hidden [ActorContext]$Context

    # Statistics
    [long]$MessagesProcessed
    [long]$MessagesDropped
    hidden [DateTime]$LastMessageTime

    # Configuration
    [hashtable]$Config

    # Default constructor
    RalphActor([string]$name) {
        $this.Initialize($name, @{})
    }

    # Constructor with configuration
    RalphActor([string]$name, [hashtable]$config) {
        $this.Initialize($name, $config)
    }

    # Common initialization
    hidden [void] Initialize([string]$name, [hashtable]$config) {
        $this.Id = "actor-$name-$([Guid]::NewGuid().ToString('N').Substring(0, 8))"
        $this.Name = $name
        $this.State = [ActorState]::Created
        $this.StateData = @{}
        $this.Config = $config

        # Mailbox configuration
        $maxMailboxSize = if ($config.MaxMailboxSize) { $config.MaxMailboxSize } else { 10000 }
        $this.Mailbox = [ActorMailbox]::new($maxMailboxSize)

        # Supervision configuration
        $this.RestartType = if ($config.RestartType) {
            [RestartType]$config.RestartType
        } else {
            [RestartType]::Permanent
        }
        $this.MaxRestarts = if ($config.MaxRestarts) { $config.MaxRestarts } else { 5 }
        $this.RestartWindow = if ($config.RestartWindow) {
            $config.RestartWindow
        } else {
            [timespan]::FromMinutes(1)
        }

        # Processing configuration
        $this.ReceiveTimeoutMs = if ($config.ReceiveTimeoutMs) { $config.ReceiveTimeoutMs } else { 5000 }

        # Initialize cancellation token
        $this.CancellationToken = [CancellationTokenSource]::new()

        # Statistics
        $this.MessagesProcessed = 0
        $this.MessagesDropped = 0
        $this.RestartCount = 0

        # Create context (will be set during Start)
        $this.Context = $null
    }

    # Start the actor
    [void] Start() {
        if ($this.State -ne [ActorState]::Created -and $this.State -ne [ActorState]::Stopped) {
            Write-Warning "[$($this.Name)] Actor cannot be started from state: $($this.State)"
            return
        }

        $this.State = [ActorState]::Starting
        $this.StartedAt = [DateTime]::UtcNow

        # Create context for this actor
        $this.Context = [ActorContext]::new($this)

        # Call PreStart hook if defined
        if ($this.PreStartHandler) {
            try {
                & $this.PreStartHandler $this.Context
            } catch {
                Write-Warning "[$($this.Name)] PreStart hook failed: $_"
            }
        }

        # Start processing thread
        $this.CancellationToken = [CancellationTokenSource]::new()
        $this.ProcessingThread = [Thread]::new({
            param($actor)
            try {
                $actor.ProcessLoop()
            } catch {
                Write-Warning "[$($actor.Name)] Processing loop error: $_"
            }
        })
        $this.ProcessingThread.Name = "Actor-$($this.Name)"
        $this.ProcessingThread.IsBackground = $false
        $this.ProcessingThread.Start($this)

        $this.State = [ActorState]::Idle
    }

    # Main message processing loop
    hidden [void] ProcessLoop() {
        while (-not $this.CancellationToken.Token.IsCancellationRequested) {
            # Dequeue next message with timeout
            $message = $this.Mailbox.Dequeue($this.ReceiveTimeoutMs)

            if ($null -eq $message) {
                # Timeout - continue loop
                continue
            }

            # Update statistics
            $this.LastMessageTime = [DateTime]::UtcNow

            # Process message
            $this.ProcessMessage($message)
        }
    }

    # Process a single message
    hidden [void] ProcessMessage([ActorMessage]$message) {
        # Handle system messages
        if ($this.HandleSystemMessage($message)) {
            return
        }

        $this.State = [ActorState]::Processing

        try {
            # Call user-defined receive handler
            if ($this.ReceiveHandler) {
                & $this.ReceiveHandler $this.Context $message
            } else {
                # Default behavior: log and ignore
                Write-Host "[$($this.Name)] Received: $($message.Type)" -ForegroundColor DarkGray
            }

            $this.MessagesProcessed++
        } catch {
            Write-Warning "[$($this.Name)] Error processing message: $_"

            # Actor should crash on exception
            $this.Crash($_)
        } finally {
            if ($this.State -eq [ActorState]::Processing) {
                $this.State = [ActorState]::Idle
            }
        }
    }

    # Handle system messages (returns true if message was handled)
    hidden [bool] HandleSystemMessage([ActorMessage]$message) {
        switch ($message.Type) {
            [SystemMessage]::Stop {
                $this.Stop()
                return $true
            }
            [SystemMessage]::Kill {
                $this.Crash("Kill signal received")
                return $true
            }
            [SystemMessage]::Ping {
                # Send pong response
                if ($message.ReplyTo) {
                    $pong = [ActorMessage]::new([SystemMessage]::Pong, $null)
                    $pong.Sender = $this.Name
                    # TODO: Send to reply-to destination
                }
                return $true
            }
            default {
                return $false
            }
        }
    }

    # Send a message to this actor (Tell pattern)
    [void] Tell([ActorMessage]$message) {
        if ($null -eq $message) {
            return
        }

        if ($this.State -eq [ActorState]::Stopped -or $this.State -eq [ActorState]::Crashed) {
            [Interlocked]::Increment([ref]$this.MessagesDropped)
            return
        }

        if (-not $this.Mailbox.TryEnqueue($message)) {
            [Interlocked]::Increment([ref]$this.MessagesDropped)
            Write-Warning "[$($this.Name)] Mailbox full, message dropped"
        }
    }

    # Send a typed message to this actor
    [void] Tell([string]$type, [object]$payload) {
        $msg = [ActorMessage]::new($type, $payload)
        $this.Tell($msg)
    }

    # Receive next message with timeout
    [ActorMessage] Receive([int]$timeoutMs) {
        return $this.Mailbox.Dequeue($timeoutMs)
    }

    # Receive next message matching a predicate (selective receive)
    [ActorMessage] Receive([scriptblock]$predicate, [int]$timeoutMs) {
        $deadline = [DateTime]::UtcNow.AddMilliseconds($timeoutMs)

        while (-not $this.CancellationToken.Token.IsCancellationRequested -and
               [DateTime]::UtcNow -lt $deadline) {

            $remainingMs = [math]::Max(0, ($deadline - [DateTime]::UtcNow).TotalMilliseconds)
            $msg = $this.Mailbox.Dequeue([int]$remainingMs)

            if ($null -eq $msg) {
                continue
            }

            # Check predicate
            try {
                if ($predicate) {
                    $match = & $predicate $msg
                    if ($match) {
                        return $msg
                    }
                } else {
                    # No predicate = accept all
                    return $msg
                }
            } catch {
                # Predicate error - reject message
                Write-Warning "[$($this.Name)] Predicate error: $_"
            }

            # Message doesn't match - requeue with lower priority
            $msg.Priority = -1
            $this.Mailbox.TryEnqueue($msg)
        }

        return $null
    }

    # Stop the actor gracefully
    [void] Stop() {
        if ($this.State -eq [ActorState]::Stopped) {
            return
        }

        $this.State = [ActorState]::Stopping

        # Cancel processing loop
        $this.CancellationToken.Cancel()

        # Wait for processing thread to finish
        if ($this.ProcessingThread -and -not $this.ProcessingThread.Join(5000)) {
            # Thread didn't finish - force abort
            Write-Warning "[$($this.Name)] Processing thread did not stop gracefully"
        }

        # Call PostStop hook if defined
        if ($this.PostStopHandler) {
            try {
                & $this.PostStopHandler $this.Context
            } catch {
                Write-Warning "[$($this.Name)] PostStop hook failed: $_"
            }
        }

        $this.State = [ActorState]::Stopped
        $this.StoppedAt = [DateTime]::UtcNow
    }

    # Crash the actor (for supervisor to handle)
    hidden [void] Crash([object]$reason) {
        $this.State = [ActorState]::Crashed
        $this.StoppedAt = [DateTime]::UtcNow

        # Supervisor will handle restart
    }

    # Get actor statistics
    [hashtable] GetStats() {
        $uptime = if ($this.StartedAt -gt [DateTime]::MinValue) {
            if ($this.StoppedAt -gt $this.StartedAt) {
                ($this.StoppedAt - $this.StartedAt).TotalSeconds
            } else {
                ([DateTime]::UtcNow - $this.StartedAt).TotalSeconds
            }
        } else { 0 }

        return @{
            Id = $this.Id
            Name = $this.Name
            State = $this.State.ToString()
            UptimeSeconds = [math]::Round($uptime, 2)
            MessagesProcessed = $this.MessagesProcessed
            MessagesDropped = $this.MessagesDropped
            RestartCount = $this.RestartCount
            MailboxStats = $this.Mailbox.GetStats()
            StartedAt = $this.StartedAt.ToString("o")
            StoppedAt = if ($this.StoppedAt -gt [DateTime]::MinValue) { $this.StoppedAt.ToString("o") } else { $null }
            LastMessageTime = if ($this.LastMessageTime -gt [DateTime]::MinValue) { $this.LastMessageTime.ToString("o") } else { $null }
        }
    }
}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

# Create a new actor with default configuration
function New-Actor {
    <#
    .SYNOPSIS
    Create a new Ralph actor.

    .PARAMETER Name
    The unique name for this actor.

    .PARAMETER ReceiveHandler
    Scriptblock to handle incoming messages.

    .PARAMETER Config
    Optional configuration hashtable.

    .EXAMPLE
    $actor = New-Actor "MyActor" {
        param($ctx, $msg)
        Write-Host "Received: $($msg.Type)"
    }
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,

        [Parameter(Mandatory=$true)]
        [scriptblock]$ReceiveHandler,

        [Parameter(Mandatory=$false)]
        [hashtable]$Config = @{},

        [Parameter(Mandatory=$false)]
        [scriptblock]$PreStart,

        [Parameter(Mandatory=$false)]
        [scriptblock]$PostStop,

        [Parameter(Mandatory=$false)]
        [scriptblock]$PreRestart,

        [Parameter(Mandatory=$false)]
        [scriptblock]$PostRestart
    )

    $actor = [RalphActor]::new($Name, $Config)
    $actor.ReceiveHandler = $ReceiveHandler

    if ($PreStart) { $actor.PreStartHandler = $PreStart }
    if ($PostStop) { $actor.PostStopHandler = $PostStop }
    if ($PreRestart) { $actor.PreRestartHandler = $PreRestart }
    if ($PostRestart) { $actor.PostRestartHandler = $PostRestart }

    return $actor
}

# Start an actor
function Start-Actor {
    <#
    .SYNOPSIS
    Start an actor.

    .PARAMETER Actor
    The RalphActor to start.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [RalphActor]$Actor
    )

    $Actor.Start()
    return $Actor
}

# Stop an actor
function Stop-Actor {
    <#
    .SYNOPSIS
    Stop an actor gracefully.

    .PARAMETER Actor
    The RalphActor to stop.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [RalphActor]$Actor
    )

    $Actor.Stop()
}

# Send a message to an actor
function Send-ActorMessage {
    <#
    .SYNOPSIS
    Send a message to an actor.

    .PARAMETER Actor
    The target actor.

    .PARAMETER Type
    Message type.

    .PARAMETER Payload
    Message payload.

    .PARAMETER Priority
    Message priority (higher = processed first).
    #>
    param(
        [Parameter(Mandatory=$true)]
        [RalphActor]$Actor,

        [Parameter(Mandatory=$true)]
        [string]$Type,

        [Parameter(Mandatory=$false)]
        [object]$Payload,

        [Parameter(Mandatory=$false)]
        [int]$Priority = 0
    )

    $msg = [ActorMessage]::new($Type, $Payload)
    $msg.Priority = $Priority
    $Actor.Tell($msg)
}

# ============================================================================
# EXPORTS
# ============================================================================

try {
    Export-ModuleMember -Function @(
        'New-Actor',
        'Start-Actor',
        'Stop-Actor',
        'Send-ActorMessage'
    )

    Export-ModuleMember -Variable @(
        'Script:AllActors'
    )
} catch {
    # Not running as a module
}
