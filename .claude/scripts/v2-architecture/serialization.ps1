# Ralph Serialization Module (PowerShell 5.1 Compatible)
# High-performance message serialization for <10ms latency targets
#
# Design Goals:
# - <1ms serialization/deserialization for typical messages
# - Zero-copy forwarding when possible
# - Compact binary representation for reduced I/O
# - Compatibility with existing JSON message protocol
#
# PowerShell 5.1 Compatibility Notes:
# - Uses ConvertTo-Json/ConvertFrom-Json (no System.Text.Json)
# - Uses PS 5.1 compatible syntax (no ??, no ?. operators)

# Load required assembly for BinaryWriter/Reader
Add-Type -AssemblyName System.Web.Extensions

# ============================================================================
# CLASSES
# ============================================================================

class MessageSerializer {
    # JSON serializer using PowerShell's ConvertTo-Json/ConvertFrom-Json
    # Simple and compatible with PS 5.1

    hidden [System.Text.Encoding]$Utf8

    MessageSerializer() {
        $this.Utf8 = [System.Text.Encoding]::UTF8
    }

    # Serialize to byte array
    [byte[]] Serialize([object]$message) {
        $json = $message | ConvertTo-Json -Compress -Depth 10
        return $this.Utf8.GetBytes($json)
    }

    # Serialize to string
    [string] SerializeToString([object]$message) {
        return $message | ConvertTo-Json -Compress -Depth 10
    }

    # Serialize with newline for pipe transmission
    [byte[]] SerializeWithNewline([object]$message) {
        $json = $message | ConvertTo-Json -Compress -Depth 10
        $jsonWithNewline = $json + "`n"
        return $this.Utf8.GetBytes($jsonWithNewline)
    }

    # Deserialize from byte array
    [object] Deserialize([byte[]]$bytes) {
        $json = $this.Utf8.GetString($bytes)
        return $json | ConvertFrom-Json
    }

    # Deserialize from string
    [object] DeserializeString([string]$json) {
        return $json | ConvertFrom-Json
    }

    # Deserialize to specific type (returns PSCustomObject)
    [object] DeserializeTo([byte[]]$bytes, [type]$targetType) {
        $json = $this.Utf8.GetString($bytes)
        $obj = $json | ConvertFrom-Json
        return $obj
    }

    # Get serialization statistics
    [hashtable] GetStats() {
        return @{
            encoding = $this.Utf8.EncodingName
        }
    }
}

class MessagePool {
    # Object pool for reducing GC pressure
    # Reuses message objects to minimize allocations

    hidden [System.Collections.Queue]$Pool
    hidden [int]$PoolSize
    hidden [long]$Allocated
    hidden [long]$Reused

    MessagePool([int]$initialSize) {
        $this.Pool = [System.Collections.Queue]::new()
        $this.PoolSize = $initialSize
        $this.Allocated = 0
        $this.Reused = 0

        # Pre-allocate pool
        for ($i = 0; $i -lt $initialSize; $i++) {
            $this.Pool.Enqueue(@{})
        }
    }

    [object] Acquire() {
        if ($this.Pool.Count -gt 0) {
            $this.Reused++
            $obj = $this.Pool.Dequeue()
            # Clear the object
            if ($obj -is [hashtable]) {
                $obj.Clear()
            }
            return $obj
        }
        $this.Allocated++
        return @{}
    }

    [void] Release([object]$obj) {
        if ($null -eq $obj) { return }
        $this.Pool.Enqueue($obj)
    }

    [hashtable] GetStats() {
        return @{
            Allocated = $this.Allocated
            Reused = $this.Reused
            ReuseRate = if ($this.Allocated -gt 0) {
                $this.Reused / [double]$this.Allocated
            } else { 0 }
        }
    }
}

class BinaryProtocol {
    # Binary serialization for maximum performance
    # Uses compact binary format for frequently used messages

    hidden [System.IO.BinaryWriter]$Writer
    hidden [System.IO.BinaryReader]$Reader
    hidden [System.IO.MemoryStream]$Stream
    hidden [System.Text.Encoding]$Utf8

    BinaryProtocol() {
        $this.Stream = [System.IO.MemoryStream]::new()
        $this.Writer = [System.IO.BinaryWriter]::new($this.Stream)
        $this.Reader = [System.IO.BinaryReader]::new($this.Stream)
        $this.Utf8 = [System.Text.Encoding]::UTF8
    }

    [byte[]] EncodeMessage([hashtable]$message) {
        $this.Stream.SetLength(0)
        $this.Stream.Position = 0

        # Write message type (2 bytes)
        $type = if ($message.type) { $message.type } else { "unknown" }
        $typeBytes = $this.Utf8.GetBytes($type)
        $this.Writer.Write([uint16]$typeBytes.Length)
        $this.Writer.Write($typeBytes)

        # Write from (2 bytes + length)
        if ($message.from) {
            $fromBytes = $this.Utf8.GetBytes($message.from)
            $this.Writer.Write([uint16]$fromBytes.Length)
            $this.Writer.Write($fromBytes)
        } else {
            $this.Writer.Write([uint16]0)
        }

        # Write to (2 bytes + length)
        if ($message.to) {
            $toBytes = $this.Utf8.GetBytes($message.to)
            $this.Writer.Write([uint16]$toBytes.Length)
            $this.Writer.Write($toBytes)
        } else {
            $this.Writer.Write([uint16]0)
        }

        # Write payload length + payload
        if ($message.payload) {
            $serializer = [MessageSerializer]::new()
            $payloadJson = $serializer.SerializeToString($message.payload)
            $payloadBytes = $this.Utf8.GetBytes($payloadJson)
            $this.Writer.Write([uint32]$payloadBytes.Length)
            $this.Writer.Write($payloadBytes)
        } else {
            $this.Writer.Write([uint32]0)
        }

        # Return bytes
        $this.Stream.Flush()
        $result = [byte[]]::new($this.Stream.Position)
        [Array]::Copy($this.Stream.GetBuffer(), 0, $result, 0, $this.Stream.Position)
        return $result
    }

    [hashtable] DecodeMessage([byte[]]$bytes) {
        $this.Stream.SetLength(0)
        $this.Stream.Write($bytes, 0, $bytes.Length)
        $this.Stream.Position = 0

        $result = @{}

        # Read type
        $typeLength = $this.Reader.ReadUInt16()
        if ($typeLength -gt 0) {
            $typeBytes = $this.Reader.ReadBytes($typeLength)
            $result.type = $this.Utf8.GetString($typeBytes)
        }

        # Read from
        $fromLength = $this.Reader.ReadUInt16()
        if ($fromLength -gt 0) {
            $fromBytes = $this.Reader.ReadBytes($fromLength)
            $result.from = $this.Utf8.GetString($fromBytes)
        }

        # Read to
        $toLength = $this.Reader.ReadUInt16()
        if ($toLength -gt 0) {
            $toBytes = $this.Reader.ReadBytes($toLength)
            $result.to = $this.Utf8.GetString($toBytes)
        }

        # Read payload
        $payloadLength = $this.Reader.ReadUInt32()
        if ($payloadLength -gt 0) {
            $payloadBytes = $this.Reader.ReadBytes($payloadLength)
            $payloadJson = $this.Utf8.GetString($payloadBytes)
            $serializer = [MessageSerializer]::new()
            $result.payload = $serializer.DeserializeString($payloadJson)
        }

        return $result
    }

    [void] Dispose() {
        if ($this.Writer -ne $null) { $this.Writer.Dispose() }
        if ($this.Reader -ne $null) { $this.Reader.Dispose() }
        if ($this.Stream -ne $null) { $this.Stream.Dispose() }
    }
}

# ============================================================================
# MESSAGE STREAMING
# ============================================================================

class MessageStream {
    # Streaming serialization for batch operations
    # Reduces per-message overhead

    hidden [System.IO.Stream]$OutputStream
    hidden [MessageSerializer]$Serializer
    hidden [System.IO.StreamWriter]$Writer
    hidden [int]$MessagesWritten

    MessageStream([System.IO.Stream]$stream) {
        $this.OutputStream = $stream
        $this.Serializer = [MessageSerializer]::new()
        $this.Writer = [System.IO.StreamWriter]::new($stream, [System.Text.Encoding]::UTF8)
        $this.MessagesWritten = 0
    }

    [void] Write([hashtable]$message) {
        $json = $this.Serializer.SerializeToString($message)
        $this.Writer.WriteLine($json)
        $this.MessagesWritten++
    }

    [void] WriteBatch([hashtable[]]$messages) {
        foreach ($msg in $messages) {
            $this.Write($msg)
        }
    }

    [void] Flush() {
        $this.Writer.Flush()
    }

    [void] Dispose() {
        if ($this.Writer -ne $null) { $this.Writer.Dispose() }
    }
}

# ============================================================================
# GLOBAL SINGLETON
# ============================================================================

$Script:MessageSerializer = $null
$Script:MessagePool = $null
$Script:IsInitialized = $false

function Initialize-Serialization {
    <#
    .SYNOPSIS
    Initialize the serialization module.

    .DESCRIPTION
    Creates singleton instances for high-performance serialization.
    #>
    param(
        [Parameter(Mandatory=$false)]
        [int]$PoolSize = 100
    )

    if ($Script:IsInitialized) {
        return
    }

    $Script:MessageSerializer = [MessageSerializer]::new()
    $Script:MessagePool = [MessagePool]::new($PoolSize)
    $Script:IsInitialized = $true
}

function ConvertTo-MessageBytes {
    <#
    .SYNOPSIS
    Serialize a message to byte array.

    .PARAMETER Message
    The message hashtable to serialize.

    .PARAMETER WithNewline
    Append newline for pipe transmission.

    .EXAMPLE
    $bytes = ConvertTo-MessageBytes @{ type = "Task"; data = $task }
    #>
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [hashtable]$Message,

        [Parameter(Mandatory=$false)]
        [switch]$WithNewline
    )

    if (-not $Script:IsInitialized) {
        Initialize-Serialization
    }

    if ($WithNewline) {
        return $Script:MessageSerializer.SerializeWithNewline($Message)
    }
    return $Script:MessageSerializer.Serialize($Message)
}

function ConvertFrom-MessageBytes {
    <#
    .SYNOPSIS
    Deserialize a message from byte array.

    .PARAMETER Bytes
    The byte array to deserialize.

    .EXAMPLE
    $msg = ConvertFrom-MessageBytes $bytes
    #>
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [byte[]]$Bytes
    )

    if (-not $Script:IsInitialized) {
        Initialize-Serialization
    }

    return $Script:MessageSerializer.Deserialize($Bytes)
}

# ============================================================================
# BATCH SERIALIZATION
# ============================================================================

function ConvertTo-MessageBatch {
    <#
    .SYNOPSIS
    Serialize multiple messages efficiently.

    .PARAMETER Messages
    Array of message hashtables.

    .OUTPUTS
    Byte array containing all serialized messages.

    .EXAMPLE
    $bytes = ConvertTo-MessageBatch $messages
    #>
    param(
        [Parameter(Mandatory=$true)]
        [hashtable[]]$Messages
    )

    if (-not $Script:IsInitialized) {
        Initialize-Serialization
    }

    $ms = [System.IO.MemoryStream]::new()
    try {
        foreach ($msg in $Messages) {
            $bytes = $Script:MessageSerializer.SerializeWithNewline($msg)
            $ms.Write($bytes, 0, $bytes.Length)
        }
        return $ms.ToArray()
    } finally {
        $ms.Dispose()
    }
}

function ConvertFrom-MessageBatch {
    <#
    .SYNOPSIS
    Deserialize multiple messages from a byte array.

    .PARAMETER Bytes
    Byte array containing newline-separated JSON messages.

    .OUTPUTS
    Array of deserialized message hashtables.

    .EXAMPLE
    $messages = ConvertFrom-MessageBatch $bytes
    #>
    param(
        [Parameter(Mandatory=$true)]
        [byte[]]$Bytes
    )

    if (-not $Script:IsInitialized) {
        Initialize-Serialization
    }

    $messages = [System.Collections.ArrayList]::new()
    $text = [System.Text.Encoding]::UTF8.GetString($Bytes)

    foreach ($line in $text -split "`n") {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        try {
            $msg = $Script:MessageSerializer.DeserializeString($line)
            [void]$messages.Add($msg)
        } catch {
            # Skip malformed messages
        }
    }

    return $messages.ToArray()
}
