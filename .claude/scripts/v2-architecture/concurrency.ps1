# Ralph Concurrency Primitives Module
# Thread-safe synchronization for multi-process orchestration
#
# Design Patterns Applied:
# - Mutex: Cross-process mutual exclusion
# - Event: Signal-based coordination
# - Atomic Counter: Thread-safe incrementing
# - Sequence Generator: Protected unique number allocation
#
# References:
# - https://docs.microsoft.com/en-us/dotnet/standard/threading/mutexes
# - https://docs.microsoft.com/en-us/dotnet/standard/threading/event-wait-handles

# ============================================================================
# CLASSES
# ============================================================================

class GlobalMutex {
    # Cross-process mutex using Windows kernel mutex objects
    # Provides safe mutual exclusion across PowerShell processes

    hidden [System.Threading.Mutex]$Mutex
    [string]$Name
    [bool]$IsOwned
    [int]$OwnerId

    GlobalMutex([string]$name) {
        $this.Mutex = [System.Threading.Mutex]::new($false, "Global\Ralph_$name")
        $this.Name = $name
        $this.IsOwned = $false
        $this.OwnerId = 0
    }

    GlobalMutex([string]$name, [string]$sessionId) {
        # Include session ID for isolation between Ralph sessions
        $mutexName = "Global\Ralph_${sessionId}_$name"
        $this.Mutex = [System.Threading.Mutex]::new($false, $mutexName)
        $this.Name = $name
        $this.IsOwned = $false
        $this.OwnerId = 0
    }

    [bool] TryEnter([int]$timeoutMs) {
        $result = $this.Mutex.WaitOne($timeoutMs)
        if ($result) {
            $this.IsOwned = $true
            $this.OwnerId = [System.Threading.Thread]::CurrentThread.ManagedThreadId
        }
        return $result
    }

    [void] Enter() {
        $this.Mutex.WaitOne()
        $this.IsOwned = $true
        $this.OwnerId = [System.Threading.Thread]::CurrentThread.ManagedThreadId
    }

    [void] Leave() {
        if ($this.IsOwned) {
            $this.Mutex.ReleaseMutex()
            $this.IsOwned = $false
            $this.OwnerId = 0
        }
    }

    [bool] TryEnter([int]$timeoutMs, [ref]$lockCookie) {
        $result = $this.Mutex.WaitOne($timeoutMs)
        if ($result) {
            $this.IsOwned = $true
            $this.OwnerId = [System.Threading.Thread]::CurrentThread.ManagedThreadId
            $lockCookie.Value = [Guid]::NewGuid()
        }
        return $result
    }

    [void] Dispose() {
        if ($this.IsOwned) {
            $this.Leave()
        }
        $this.Mutex.Dispose()
    }
}

class AsyncEvent {
    # Manual reset event for signal-based coordination
    # More efficient than polling for inter-process communication

    hidden [System.Threading.ManualResetEvent]$Event
    [string]$Name
    [bool]$Signaled

    AsyncEvent([string]$name, [bool]$initialState) {
        $this.Event = [System.Threading.ManualResetEvent]::new($initialState)
        $this.Name = $name
        $this.Signaled = $initialState
    }

    [void] Set() {
        $this.Event.Set()
        $this.Signaled = $true
    }

    [void] Reset() {
        $this.Event.Reset()
        $this.Signaled = $false
    }

    [bool] Wait([int]$timeoutMs) {
        return $this.Event.WaitOne($timeoutMs)
    }

    [bool] IsSet() {
        return $this.Event.WaitOne(0)
    }

    [void] Dispose() {
        $this.Event.Dispose()
    }
}

class AutoResetSignal {
    # Auto-reset event that automatically clears after one waiter released
    # Useful for coordinating single-consumer scenarios

    hidden [System.Threading.AutoResetEvent]$Event
    [string]$Name

    AutoResetSignal([string]$name, [bool]$initialState) {
        $this.Event = [System.Threading.AutoResetEvent]::new($initialState)
        $this.Name = $name
    }

    [void] Signal() {
        $this.Event.Set()
    }

    [bool] Wait([int]$timeoutMs) {
        return $this.Event.WaitOne($timeoutMs)
    }

    [void] Dispose() {
        $this.Event.Dispose()
    }
}

class AtomicCounter {
    # Thread-safe counter using Monitor.Enter/Exit
    # PowerShell 5.1 doesn't support lock statement in classes

    hidden [long]$value
    hidden [object]$lockObj

    AtomicCounter([long]$initialValue) {
        $this.value = $initialValue
        $this.lockObj = [object]::new()
    }

    [long] Increment() {
        [System.Threading.Monitor]::Enter($this.lockObj)
        try {
            $this.value = $this.value + 1
            return $this.value
        } finally {
            [System.Threading.Monitor]::Exit($this.lockObj)
        }
    }

    [long] Decrement() {
        [System.Threading.Monitor]::Enter($this.lockObj)
        try {
            $this.value = $this.value - 1
            return $this.value
        } finally {
            [System.Threading.Monitor]::Exit($this.lockObj)
        }
    }

    [long] Add([long]$delta) {
        [System.Threading.Monitor]::Enter($this.lockObj)
        try {
            $this.value = $this.value + $delta
            return $this.value
        } finally {
            [System.Threading.Monitor]::Exit($this.lockObj)
        }
    }

    [long] Get() {
        [System.Threading.Monitor]::Enter($this.lockObj)
        try {
            return $this.value
        } finally {
            [System.Threading.Monitor]::Exit($this.lockObj)
        }
    }

    [long] Set([long]$newValue) {
        [System.Threading.Monitor]::Enter($this.lockObj)
        try {
            $old = $this.value
            $this.value = $newValue
            return $old
        } finally {
            [System.Threading.Monitor]::Exit($this.lockObj)
        }
    }

    [bool] CompareAndExchange([long]$expected, [long]$newValue) {
        [System.Threading.Monitor]::Enter($this.lockObj)
        try {
            if ($this.value -eq $expected) {
                $this.value = $newValue
                return $true
            }
            return $false
        } finally {
            [System.Threading.Monitor]::Exit($this.lockObj)
        }
    }

    [void] Reset() {
        [System.Threading.Monitor]::Enter($this.lockObj)
        try {
            $this.value = 0
        } finally {
            [System.Threading.Monitor]::Exit($this.lockObj)
        }
    }
}

class LockScope {
    # RAII-style lock scope using IDisposable
    # Ensures mutex is always released

    hidden [GlobalMutex]$Mutex
    hidden [bool]$Owned

    LockScope([GlobalMutex]$mutex) {
        $this.Mutex = $mutex
        $this.Owned = $false
    }

    [bool] TryAcquire([int]$timeoutMs) {
        $this.Owned = $this.Mutex.TryEnter($timeoutMs)
        return $this.Owned
    }

    [void] Acquire() {
        $this.Mutex.Enter()
        $this.Owned = $true
    }

    [void] Dispose() {
        if ($this.Owned) {
            $this.Mutex.Leave()
            $this.Owned = $false
        }
    }
}

class ReadWriteLock {
    # Reader-writer lock for multiple readers, exclusive writer
    # Optimizes for read-heavy workloads

    hidden [System.Threading.ReaderWriterLockSlim]$Lock
    [string]$Name

    ReadWriteLock([string]$name) {
        $this.Lock = [System.Threading.ReaderWriterLockSlim]::new(
            [System.Threading.LockRecursionPolicy]::NoRecursion
        )
        $this.Name = $name
    }

    [void] EnterReadLock() {
        $this.Lock.EnterReadLock()
    }

    [void] ExitReadLock() {
        $this.Lock.ExitReadLock()
    }

    [void] EnterWriteLock() {
        $this.Lock.EnterWriteLock()
    }

    [void] ExitWriteLock() {
        $this.Lock.ExitWriteLock()
    }

    [bool] TryEnterReadLock([int]$timeoutMs) {
        return $this.Lock.TryEnterReadLock($timeoutMs)
    }

    [bool] TryEnterWriteLock([int]$timeoutMs) {
        return $this.Lock.TryEnterWriteLock($timeoutMs)
    }

    [void] Dispose() {
        $this.Lock.Dispose()
    }
}

class SemaphoreGuard {
    # Counting semaphore to limit concurrent access
    # Useful for throttling resource usage

    hidden [System.Threading.Semaphore]$Semaphore
    [string]$Name
    [int]$MaxCount

    SemaphoreGuard([string]$name, [int]$maxCount) {
        $this.Semaphore = [System.Threading.Semaphore]::new($maxCount, $maxCount, "Global\Ralph_$name")
        $this.Name = $name
        $this.MaxCount = $maxCount
    }

    [bool] TryAcquire([int]$timeoutMs) {
        return $this.Semaphore.WaitOne($timeoutMs)
    }

    [void] Acquire() {
        $this.Semaphore.WaitOne()
    }

    [void] Release() {
        $this.Semaphore.Release()
    }

    [void] Release([int]$count) {
        $this.Semaphore.Release($count)
    }

    [int] AvailableCount() {
        return $this.Semaphore.AvailableWaitHandle.ToString()
    }

    [void] Dispose() {
        $this.Semaphore.Dispose()
    }
}

# ============================================================================
# GLOBAL STATE
# ============================================================================

$Script:SequenceMutex = $null
$Script:SequenceCounter = $null
$Script:IsInitialized = $false

# ============================================================================
# SEQUENCE GENERATOR
# ============================================================================

function Initialize-SequenceGenerator {
    <#
    .SYNOPSIS
    Initialize the global sequence generator with mutex protection.

    .DESCRIPTION
    Creates a cross-process mutex for sequence number allocation.
    Must be called before Get-NextSequence.

    .PARAMETER SessionId
    Optional session ID for isolation between Ralph instances.
    #>
    param(
        [Parameter(Mandatory=$false)]
        [string]$SessionId = ""
    )

    if ($Script:IsInitialized) {
        return
    }

    if ($SessionId) {
        $mutexName = "Ralph_${SessionId}_EventSeq"
        $Script:SequenceMutex = [System.Threading.Mutex]::new($false, "Global\$mutexName")
    } else {
        $Script:SequenceMutex = [System.Threading.Mutex]::new($false, "Global\RalphEventSeq")
    }

    $Script:SequenceCounter = [AtomicCounter]::new(0)
    $Script:IsInitialized = $true
}

function Get-NextSequence {
    <#
    .SYNOPSIS
    Get next sequence number with mutex protection.

    .DESCRIPTION
    Atomically increments and returns the next sequence number.
    Safe to call from multiple processes concurrently.

    .RETURNS
    The next sequence number.

    .EXAMPLE
    $seq = Get-NextSequence  # Returns 1, 2, 3, ...
    #>
    if (-not $Script:IsInitialized) {
        throw "Sequence generator not initialized. Call Initialize-SequenceGenerator first."
    }

    # Acquire mutex for the operation
    $acquired = $Script:SequenceMutex.WaitOne(5000)
    if (-not $acquired) {
        throw "Failed to acquire sequence mutex within timeout"
    }

    try {
        return $Script:SequenceCounter.Increment()
    } finally {
        $Script:SequenceMutex.ReleaseMutex()
    }
}

function Get-CurrentSequence {
    <#
    .SYNOPSIS
    Get current sequence number without incrementing.

    .RETURNS
    The current sequence number.
    #>
    if (-not $Script:IsInitialized) {
        throw "Sequence generator not initialized. Call Initialize-SequenceGenerator first."
    }

    return $Script:SequenceCounter.Get()
}

function Reset-SequenceGenerator {
    <#
    .SYNOPSIS
    Reset the sequence counter to zero.

    .DESCRIPTION
    Use with caution - only for testing or session initialization.
    #>
    if (-not $Script:IsInitialized) {
        throw "Sequence generator not initialized. Call Initialize-SequenceGenerator first."
    }

    $acquired = $Script:SequenceMutex.WaitOne(5000)
    if (-not $acquired) {
        throw "Failed to acquire sequence mutex within timeout"
    }

    try {
        $Script:SequenceCounter.Reset()
    } finally {
        $Script:SequenceMutex.ReleaseMutex()
    }
}

# ============================================================================
# LOCK SCOPE HELPERS
# ============================================================================

function Use-GlobalLock {
    <#
    .SYNOPSIS
    Execute a scriptblock under global mutex protection.

    .PARAMETER MutexName
    Name of the mutex to acquire.

    .PARAMETER ScriptBlock
    Scriptblock to execute while holding the lock.

    .PARAMETER TimeoutMs
    Timeout in milliseconds. Default is 5000.

    .EXAMPLE
    Use-GlobalLock "EventLog" {
        # Safe concurrent write
        Add-Content "log.txt" "message"
    }
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$MutexName,

        [Parameter(Mandatory=$true)]
        [scriptblock]$ScriptBlock,

        [Parameter(Mandatory=$false)]
        [int]$TimeoutMs = 5000,

        [Parameter(Mandatory=$false)]
        [string]$SessionId = ""
    )

    $mutex = $null
    try {
        if ($SessionId) {
            $mutex = [GlobalMutex]::new($MutexName, $SessionId)
        } else {
            $mutex = [GlobalMutex]::new($MutexName)
        }

        if (-not $mutex.TryEnter($TimeoutMs)) {
            throw "Failed to acquire mutex '$MutexName' within ${TimeoutMs}ms"
        }

        try {
            & $ScriptBlock
        } finally {
            $mutex.Leave()
        }
    } finally {
        if ($mutex) {
            $mutex.Dispose()
        }
    }
}

function Use-ReadWriteLock {
    <#
    .SYNOPSIS
    Execute scriptblock with reader-writer lock protection.

    .PARAMETER LockName
    Name of the lock.

    .PARAMETER ScriptBlock
    Scriptblock to execute.

    .PARAMETER Write
    Whether to acquire write lock (exclusive). Default is read lock.

    .EXAMPLE
    # Read operation - shared lock
    $data = Use-ReadWriteLock "Cache" { Get-Content "cache.json" }

    # Write operation - exclusive lock
    Use-ReadWriteLock "Cache" -Write { Set-Content "cache.json" $newData }
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$LockName,

        [Parameter(Mandatory=$true)]
        [scriptblock]$ScriptBlock,

        [Parameter(Mandatory=$false)]
        [switch]$Write,

        [Parameter(Mandatory=$false)]
        [int]$TimeoutMs = 5000
    )

    $lock = [ReadWriteLock]::new($LockName)
    try {
        if ($Write) {
            if (-not $lock.TryEnterWriteLock($TimeoutMs)) {
                throw "Failed to acquire write lock '$LockName' within ${TimeoutMs}ms"
            }
            try {
                & $ScriptBlock
            } finally {
                $lock.ExitWriteLock()
            }
        } else {
            if (-not $lock.TryEnterReadLock($TimeoutMs)) {
                throw "Failed to acquire read lock '$LockName' within ${TimeoutMs}ms"
            }
            try {
                & $ScriptBlock
            } finally {
                $lock.ExitReadLock()
            }
        }
    } finally {
        $lock.Dispose()
    }
}

# ============================================================================
# EXPORTS
# ============================================================================

try {
    Export-ModuleMember -Function @(
        # Sequence generator
        'Initialize-SequenceGenerator',
        'Get-NextSequence',
        'Get-CurrentSequence',
        'Reset-SequenceGenerator',

        # Lock helpers
        'Use-GlobalLock',
        'Use-ReadWriteLock'
    )

    Export-ModuleMember -Variable @(
        'Script:SequenceMutex',
        'Script:SequenceCounter',
        'Script:IsInitialized'
    )
} catch {
    # Not running as a module
}
