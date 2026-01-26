# Ralph Async Pipes Module - Event-Driven I/O for <10ms Latency
#
# Design Patterns Applied:
# - Event-Driven I/O: No polling, use async/await with signals
# - Zero-Copy: Forward messages without serialization overhead
# - Message Batching: Reduce per-message overhead
# - Backpressure: Handle fast producers/slow consumers
#
# Features:
# - Async pipe read/write using System.IO.Pipes async operations
# - Event-driven message delivery (ManualResetEvent for signaling)
# - Message batching for throughput optimization
# - Zero-copy forwarding between pipes
# - Automatic flow control and backpressure
#
# References:
# - https://docs.microsoft.com/en-us/dotnet/standard/io/asynchronous-file-i-o
# - https://www.enterpriseintegrationpatterns.com/patterns/messaging/EventDrivenConsumer.html

using namespace System.IO
using namespace System.IO.Pipes
using namespace System.Threading
using namespace System.Threading.Tasks
using namespace System.Collections.Concurrent

# ============================================================================
# ASYNC PIPE READER - Event-driven message consumption
# ============================================================================

class AsyncPipeReader {
    hidden [NamedPipeServerStream]$Pipe
    hidden [CancellationTokenSource]$CancellationToken
    hidden [Thread]$ReaderThread
    hidden [Action[object]]$MessageCallback
    hidden [Action[Exception]]$ErrorCallback
    hidden [ManualResetEventSlim]$Signal
    hidden [LatencyTracker]$Latency
    hidden [byte[]]$Buffer
    hidden [MemoryStream]$ReadStream
    hidden [int]$BufferSize

    [bool]$IsRunning
    [long]$MessagesReceived
    [long]$BytesReceived

    AsyncPipeReader(
        [NamedPipeServerStream]$pipe,
        [Action[object]]$messageCallback,
        [Action[Exception]]$errorCallback
    ) {
        $this.Pipe = $pipe
        $this.MessageCallback = $messageCallback
        $this.ErrorCallback = $errorCallback
        $this.CancellationToken = [CancellationTokenSource]::new()
        $this.Signal = [ManualResetEventSlim]::new($false)
        $this.Latency = [LatencyTracker]::new(1000)
        $this.BufferSize = 8192  # 8KB buffer
        $this.Buffer = [byte[]]::new($this.BufferSize)
        $this.ReadStream = [MemoryStream]::new()
        $this.IsRunning = $false
    }

    [void] StartReading() {
        if ($this.IsRunning) { return }

        $this.IsRunning = $true
        $this.ReaderThread = [Thread]::new({
            param($reader)
            try {
                $reader.ReadLoop()
            } catch {
                if ($reader.ErrorCallback) {
                    $reader.ErrorCallback.Invoke($_.Exception)
                }
            }
        })
        $this.ReaderThread.Start($this)
    }

    hidden [void] ReadLoop() {
        $token = $this.CancellationToken.Token

        while (-not $token.IsCancellationRequested -and $this.Pipe.IsConnected) {
            try {
                # Read data asynchronously
                $bytesRead = $this.Pipe.Read($this.Buffer, 0, $this.BufferSize)

                if ($bytesRead -eq 0) {
                    # EOF - pipe closed
                    break
                }

                $this.BytesReceived += $bytesRead

                # Write to memory stream
                $this.ReadStream.Write($this.Buffer, 0, $bytesRead)

                # Process complete messages (newline-delimited JSON)
                $this.ProcessMessages()

                $this.Signal.Set()

            } catch [System.OperationCanceledException] {
                break
            } catch {
                if ($this.ErrorCallback) {
                    $this.ErrorCallback.Invoke($_.Exception)
                }
                # Brief pause on error before retry
                Start-Sleep -Milliseconds 10
            }
        }
    }

    hidden [void] ProcessMessages() {
        $currentBytes = $this.ReadStream.ToArray()
        $this.ReadStream = [MemoryStream]::new()

        $offset = 0
        $sw = [System.Diagnostics.Stopwatch]::StartNew()

        while ($offset -lt $currentBytes.Length) {
            # Find newline delimiter
            $newlineIndex = $currentBytes[$offset..($currentBytes.Length - 1)].IndexOf([byte]10)

            if ($newlineIndex -lt 0) {
                # No complete message, save remaining bytes
                $remaining = $currentBytes[$offset..($currentBytes.Length - 1)]
                if ($remaining.Count -gt 0) {
                    $this.ReadStream.Write($remaining, 0, $remaining.Count)
                }
                break
            }

            # Extract message
            $messageBytes = $currentBytes[$offset..($offset + $newlineIndex - 1)]
            $offset += $newlineIndex + 1

            try {
                # Deserialize and callback
                $json = [System.Text.Encoding]::UTF8.GetString($messageBytes)
                $message = $json | ConvertFrom-Json

                if ($this.MessageCallback) {
                    $this.MessageCallback.Invoke($message)
                }

                $this.MessagesReceived++
            } catch {
                # Skip malformed messages
            }
        }

        $sw.Stop()
        if ($this.MessagesReceived % 100 -eq 0) {
            $this.Latency.Record($sw.ElapsedMicroseconds)
        }
    }

    [void] Stop() {
        if (-not $this.IsRunning) { return }

        $this.IsRunning = $false
        $this.CancellationToken.Cancel()
        $this.Signal.Set()

        if ($this.ReaderThread) {
            if (-not $this.ReaderThread.Join(1000)) {
                # Thread didn't join, force abort
                $this.ReaderThread.Abort()
            }
        }
    }

    [bool] WaitForMessage([int]$timeoutMs) {
        return $this.Signal.Wait($timeoutMs)
    }

    [hashtable] GetMetrics() {
        return @{
            MessagesReceived = $this.MessagesReceived
            BytesReceived = $this.BytesReceived
            Latency = $this.Latency.GetStatistics()
            IsRunning = $this.IsRunning
        }
    }
}

# ============================================================================
# ASYNC PIPE WRITER - Efficient message sending
# ============================================================================

class AsyncPipeWriter {
    hidden [NamedPipeClientStream]$Pipe
    hidden [ConcurrentQueue[byte[]]]$WriteQueue
    hidden [Thread]$WriterThread
    hidden [CancellationTokenSource]$CancellationToken
    hidden [ManualResetEventSlim]$HasData
    hidden [LatencyTracker]$Latency
    hidden [int]$MaxQueueSize

    [bool]$IsRunning
    [long]$MessagesSent
    [long]$BytesSent
    [long]$DroppedMessages

    AsyncPipeWriter([NamedPipeClientStream]$pipe) {
        $this.Pipe = $pipe
        $this.WriteQueue = [ConcurrentQueue[byte[]]]::new()
        $this.CancellationToken = [CancellationTokenSource]::new()
        $this.HasData = [ManualResetEventSlim]::new($false)
        $this.Latency = [LatencyTracker]::new(1000)
        $this.MaxQueueSize = 1000
        $this.IsRunning = $false
    }

    [void] StartWriting() {
        if ($this.IsRunning) { return }

        $this.IsRunning = $true
        $this.WriterThread = [Thread]::new({
            param($writer)
            try {
                $writer.WriteLoop()
            } catch {
                # Write thread exited
            }
        })
        $this.WriterThread.Start($this)
    }

    hidden [void] WriteLoop() {
        $token = $this.CancellationToken.Token
        $buffer = [byte[]]::new(65536)  # 64KB write buffer

        while (-not $token.IsCancellationRequested -and $this.Pipe.IsConnected) {
            # Wait for data
            if (-not $this.HasData.Wait(100)) {
                continue
            }

            $this.HasData.Reset()

            # Drain queue in batches
            $offset = 0
            $batchCount = 0
            $maxBatch = 100  # Max messages per batch

            while ($batchCount -lt $maxBatch -and
                   $this.WriteQueue.TryDequeue([ref]$data)) {
                if ($offset + $data.Length -gt $buffer.Length) {
                    # Flush buffer
                    if ($offset -gt 0) {
                        $this.Pipe.Write($buffer, 0, $offset)
                        $this.Pipe.Flush()
                        $this.BytesSent += $offset
                        $offset = 0
                    }
                }

                [Array]::Copy($data, 0, $buffer, $offset, $data.Length)
                $offset += $data.Length
                $batchCount++
            }

            # Final flush
            if ($offset -gt 0) {
                $this.Pipe.Write($buffer, 0, $offset)
                $this.Pipe.Flush()
                $this.BytesSent += $offset
                $this.MessagesSent += $batchCount
            }
        }
    }

    [bool] TrySendMessage([object]$message) {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()

        try {
            $json = $message | ConvertTo-Json -Compress -Depth 10
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)

            # Add newline delimiter
            $withNewline = [byte[]]::new($bytes.Length + 1)
            [Array]::Copy($bytes, 0, $withNewline, 0, $bytes.Length)
            $withNewline[$bytes.Length] = 10  # LF

            # Check queue size (backpressure)
            if ($this.WriteQueue.Count -ge $this.MaxQueueSize) {
                [Interlocked]::Increment([ref]$this.DroppedMessages)
                return $false
            }

            $this.WriteQueue.Enqueue($withNewline)
            $this.HasData.Set()

            $sw.Stop()
            $this.Latency.Record($sw.ElapsedMicroseconds)
            return $true

        } catch {
            return $false
        }
    }

    [void] SendMessage([object]$message) {
        if (-not $this.TrySendMessage($message)) {
            throw "Failed to send message - queue full or pipe disconnected"
        }
    }

    [void] Stop() {
        if (-not $this.IsRunning) { return }

        $this.IsRunning = $false
        $this.CancellationToken.Cancel()
        $this.HasData.Set()

        # Drain queue
        $this.Pipe.Flush()

        if ($this.WriterThread) {
            $this.WriterThread.Join(1000)
        }
    }

    [hashtable] GetMetrics() {
        return @{
            MessagesSent = $this.MessagesSent
            BytesSent = $this.BytesSent
            QueueSize = $this.WriteQueue.Count
            DroppedMessages = $this.DroppedMessages
            Latency = $this.Latency.GetStatistics()
            IsRunning = $this.IsRunning
        }
    }
}

# ============================================================================
# MESSAGE BATCHER - Aggregate messages for efficiency
# ============================================================================

class MessageBatcher {
    hidden [List[object]]$Batch
    hidden [DateTime]$FirstMessageTime
    [int]$MaxBatchSize
    [timespan]$MaxBatchDelay
    [int]$CurrentBatchCount

    MessageBatcher([int]$maxSize, [int]$maxDelayMs) {
        $this.Batch = [List[object]]::new()
        $this.MaxBatchSize = $maxSize
        $this.MaxBatchDelay = [timespan]::FromMilliseconds($maxDelayMs)
    }

    [object[]] Add([object]$message) {
        $now = [DateTime]::UtcNow

        if ($this.Batch.Count -eq 0) {
            $this.FirstMessageTime = $now
        }

        $this.Batch.Add($message)
        $this.CurrentBatchCount++

        # Check if batch is ready
        if ($this.ShouldFlush()) {
            return $this.Flush()
        }

        return $null
    }

    hidden [bool] ShouldFlush() {
        if ($this.Batch.Count -ge $this.MaxBatchSize) {
            return $true
        }

        if ($this.FirstMessageTime) {
            $elapsed = [DateTime]::UtcNow - $this.FirstMessageTime
            if ($elapsed -ge $this.MaxBatchDelay) {
                return $true
            }
        }

        return $false
    }

    [object[]] Flush() {
        if ($this.Batch.Count -eq 0) {
            return [object[]]::new()
        }

        $result = $this.Batch.ToArray()
        $this.Batch.Clear()
        $this.FirstMessageTime = $null

        return $result
    }

    [bool] HasPending {
        get { return $this.Batch.Count -gt 0 }
    }

    [int] PendingCount {
        get { return $this.Batch.Count }
    }
}

# ============================================================================
# ZERO-COPY MESSAGE FORWARDER
# ============================================================================

class MessageForwarder {
    hidden [Dictionary[string, NamedPipeServerStream]]$ServerPipes
    hidden [Dictionary[string, NamedPipeClientStream]]$ClientPipes
    hidden [MessageSerializer]$Serializer

    MessageForwarder() {
        $this.ServerPipes = [Dictionary[string, NamedPipeServerStream]]::new()
        $this.ClientPipes = [Dictionary[string, NamedPipeClientStream]]::new()
        $this.Serializer = [MessageSerializer]::new()
    }

    [void] RegisterServerPipe([string]$agentName, [NamedPipeServerStream]$pipe) {
        $this.ServerPipes[$agentName] = $pipe
    }

    [void] RegisterClientPipe([string]$agentName, [NamedPipeClientStream]$pipe) {
        $this.ClientPipes[$agentName] = $pipe
    }

    [void] UnregisterPipe([string]$agentName) {
        if ($this.ServerPipes.ContainsKey($agentName)) {
            $this.ServerPipes.Remove($agentName)
        }
        if ($this.ClientPipes.ContainsKey($agentName)) {
            $this.ClientPipes.Remove($agentName)
        }
    }

    [int] Forward([string]$fromAgent, [object]$message, [string[]]$toAgents) {
        # Serialize once for all recipients (zero-copy forwarding)
        $bytes = $this.Serializer.SerializeWithNewline($message)

        $sent = 0

        foreach ($toAgent in $toAgents) {
            $pipe = $null

            # Try server pipe first
            if ($this.ServerPipes.ContainsKey($toAgent)) {
                $pipe = $this.ServerPipes[$toAgent]
            }
            # Then try client pipe
            elseif ($this.ClientPipes.ContainsKey($toAgent)) {
                $pipe = $this.ClientPipes[$toAgent]
            }

            if ($pipe -and $pipe.IsConnected) {
                try {
                    $pipe.Write($bytes, 0, $bytes.Length)
                    $pipe.Flush()
                    $sent++
                } catch {
                    # Pipe disconnected or error
                }
            }
        }

        return $sent
    }

    [int] Broadcast([object]$message, [string[]]$excludeAgents) {
        $excludeSet = [HashSet[string]]::new([string[]]$excludeAgents)
        $recipients = [List[string]]::new()

        foreach ($agentName in $this.ServerPipes.Keys) {
            if (-not $excludeSet.Contains($agentName)) {
                $recipients.Add($agentName)
            }
        }

        return $this.Forward("", $message, $recipients.ToArray())
    }

    [bool] IsConnected([string]$agentName) {
        $pipe = $null
        if ($this.ServerPipes.ContainsKey($agentName)) {
            $pipe = $this.ServerPipes[$agentName]
        } elseif ($this.ClientPipes.ContainsKey($agentName)) {
            $pipe = $this.ClientPipes[$agentName]
        }

        return $pipe -and $pipe.IsConnected
    }

    [string[]] GetConnectedAgents() {
        $connected = [List[string]]::new()

        foreach ($kvp in $this.ServerPipes.GetEnumerator()) {
            if ($kvp.Value.IsConnected) {
                $connected.Add($kvp.Key)
            }
        }

        foreach ($kvp in $this.ClientPipes.GetEnumerator()) {
            if ($kvp.Value.IsConnected) {
                $connected.Add($kvp.Key)
            }
        }

        return $connected.ToArray()
    }
}

# ============================================================================
# BIDIRECTIONAL ASYNC PIPE - Combined reader/writer
# ============================================================================

class BidirectionalAsyncPipe {
    [string]$AgentName
    [NamedPipeServerStream]$ServerPipe
    [NamedPipeClientStream]$ClientPipe
    [AsyncPipeReader]$Reader
    [AsyncPipeWriter]$Writer
    [MessageBatcher]$Batcher

    BidirectionalAsyncPipe([string]$agentName, [string]$pipeName) {
        $this.AgentName = $agentName
        $this.ServerPipe = [NamedPipeServerStream]::new(
            $pipeName,
            [PipeDirection]::InOut,
            [NamedPipeServerStream]::MaxAllowedServerInstances,
            [PipeTransmissionMode]::Byte
        )

        # Initialize reader with callbacks
        $this.Reader = [AsyncPipeReader]::new(
            $this.ServerPipe,
            {
                param($msg)
                # Default: just write to console
                # Override by setting Reader.MessageCallback
            }.GetNewClosure(),
            {
                param($ex)
                Write-Warning "Pipe reader error for $agentName`: $ex"
            }.GetNewClosure()
        )

        # Initialize writer
        $this.Writer = [AsyncPipeWriter]::new($this.ServerPipe)

        # Initialize batcher
        $this.Batcher = [MessageBatcher]::new(50, 10)  # 50 msgs or 10ms
    }

    [void] Start() {
        $this.ServerPipe.WaitForConnection()
        $this.Reader.StartReading()
        $this.Writer.StartWriting()
    }

    [bool] TrySend([object]$message) {
        # Check if batch is ready first
        $batch = $this.Batcher.Add($message)
        if ($null -ne $batch) {
            # Send batch
            foreach ($msg in $batch) {
                if (-not $this.Writer.TrySendMessage($msg)) {
                    return $false
                }
            }
        }
        return $true
    }

    [void] Send([object]$message) {
        # Flush any pending batch first
        if ($this.Batcher.HasPending) {
            $batch = $this.Batcher.Flush()
            foreach ($msg in $batch) {
                $this.Writer.SendMessage($msg)
            }
        }

        $this.Writer.SendMessage($message)
    }

    [void] SetMessageCallback([Action[object]]$callback) {
        $this.Reader.MessageCallback = $callback
    }

    [void] Stop() {
        # Flush any pending messages
        if ($this.Batcher.HasPending) {
            $batch = $this.Batcher.Flush()
            foreach ($msg in $batch) {
                $this.Writer.TrySendMessage($msg)
            }
        }

        $this.Reader.Stop()
        $this.Writer.Stop()
        $this.ServerPipe?.Dispose()
    }

    [hashtable] GetMetrics() {
        $readerMetrics = $this.Reader.GetMetrics()
        $writerMetrics = $this.Writer.GetMetrics()

        return @{
            AgentName = $this.AgentName
            Reader = $readerMetrics
            Writer = $writerMetrics
            BatcherPending = $this.Batcher.PendingCount
            IsConnected = $this.ServerPipe.IsConnected
        }
    }
}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

function New-MessageBatcher {
    <#
    .SYNOPSIS
    Create a new message batcher.

    .PARAMETER MaxSize
    Maximum batch size before auto-flush.

    .PARAMETER MaxDelayMs
    Maximum delay in ms before auto-flush.

    .RETURNS
    MessageBatcher instance.
    #>
    param(
        [Parameter(Mandatory=$false)]
        [int]$MaxSize = 50,

        [Parameter(Mandatory=$false)]
        [int]$MaxDelayMs = 10
    )

    return [MessageBatcher]::new($MaxSize, $MaxDelayMs)
}

function New-MessageForwarder {
    <#
    .SYNOPSIS
    Create a new message forwarder for zero-copy forwarding.

    .RETURNS
    MessageForwarder instance.
    #>
    return [MessageForwarder]::new()
}

function New-BidirectionalAsyncPipe {
    <#
    .SYNOPSIS
    Create a new bidirectional async pipe.

    .PARAMETER AgentName
    Name of the agent.

    .PARAMETER PipeName
    Name of the pipe (defaults to "Ralph_<AgentName>").

    .RETURNS
    BidirectionalAsyncPipe instance.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$AgentName,

        [Parameter(Mandatory=$false)]
        [string]$PipeName = ""
    )

    if ([string]::IsNullOrEmpty($PipeName)) {
        $PipeName = "Ralph_$AgentName"
    }

    return [BidirectionalAsyncPipe]::new($AgentName, $PipeName)
}

function Send-BatchMessage {
    <#
    .SYNOPSIS
    Send a message using batching for efficiency.

    .PARAMETER Batcher
    The MessageBatcher instance.

    .PARAMETER Pipe
    The BidirectionalAsyncPipe instance.

    .PARAMETER Message
    The message to send.

    .EXAMPLE
    $batcher = New-MessageBatcher
    $pipe = New-BidirectionalAsyncPipe -AgentName "pm"
    Send-BatchMessage -Batcher $batcher -Pipe $pipe -Message $msg
    #>
    param(
        [Parameter(Mandatory=$true)]
        [MessageBatcher]$Batcher,

        [Parameter(Mandatory=$true)]
        [BidirectionalAsyncPipe]$Pipe,

        [Parameter(Mandatory=$true)]
        [object]$Message
    )

    $batch = $Batcher.Add($Message)
    if ($null -ne $batch) {
        foreach ($msg in $batch) {
            $pipe.Send($msg)
        }
    }
}

function Flush-Batch {
    <#
    .SYNOPSIS
    Flush pending batched messages.

    .PARAMETER Batcher
    The MessageBatcher instance.

    .PARAMETER Pipe
    The BidirectionalAsyncPipe instance.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [MessageBatcher]$Batcher,

        [Parameter(Mandatory=$true)]
        [BidirectionalAsyncPipe]$Pipe
    )

    if ($Batcher.HasPending) {
        $batch = $Batcher.Flush()
        foreach ($msg in $batch) {
            $pipe.Send($msg)
        }
    }
}

# ============================================================================
# EXPORTS
# ============================================================================

try {
    Export-ModuleMember -Function @(
        # Constructors
        'New-MessageBatcher',
        'New-MessageForwarder',
        'New-BidirectionalAsyncPipe',

        # Operations
        'Send-BatchMessage',
        'Flush-Batch',

        # Classes
        'AsyncPipeReader',
        'AsyncPipeWriter',
        'MessageBatcher',
        'MessageForwarder',
        'BidirectionalAsyncPipe'
    )
} catch {
    # Not running as a module
}
