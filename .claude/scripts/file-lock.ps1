# Ralph File Lock Utility (PowerShell)
# Provides atomic file locking for session state files
# Prevents race conditions between agents accessing shared files
#
# Usage:
#   . "$PSScriptRoot\file-lock.ps1"
#   $lock = Lock-SessionFile -FilePath $path
#   try { ... modify file ... } finally { Unlock-SessionFile -Lock $lock }

# Source configuration if not already loaded
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not (Get-Command "Get-RalphConfig" -ErrorAction SilentlyContinue)) {
    . "$scriptDir\ralph-config.ps1"
}

# ============================================================================
# FILE LOCKING FUNCTIONS
# ============================================================================

function Get-LockFilePath {
    param([string]$FilePath)
    return "$FilePath.lock"
}

function Lock-SessionFile {
    <#
    .SYNOPSIS
    Acquires an exclusive lock on a session file.
    
    .DESCRIPTION
    Creates a .lock file to prevent other agents from modifying the file.
    Will retry for LockTimeoutMs before failing.
    
    .PARAMETER FilePath
    The path to the file to lock.
    
    .PARAMETER TimeoutMs
    Maximum time to wait for lock acquisition (default: from config).
    
    .PARAMETER AgentName
    Name of the agent acquiring the lock (for debugging).
    
    .RETURNS
    Lock object to pass to Unlock-SessionFile, or $null if lock failed.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath,
        
        [int]$TimeoutMs = 0,
        [string]$AgentName = "unknown"
    )
    
    $config = Get-RalphConfig
    if ($TimeoutMs -eq 0) { $TimeoutMs = $config.LockTimeoutMs }
    $retryDelayMs = $config.LockRetryDelayMs
    
    $lockPath = Get-LockFilePath -FilePath $FilePath
    $startTime = [DateTime]::UtcNow
    $lockAcquired = $false
    
    while (-not $lockAcquired) {
        $elapsed = ([DateTime]::UtcNow - $startTime).TotalMilliseconds
        
        if ($elapsed -gt $TimeoutMs) {
            Write-RalphLog "Lock timeout on $FilePath after ${TimeoutMs}ms" -Level "WARN" -Agent $AgentName -Color Yellow
            return $null
        }
        
        # Check if lock file exists
        if (Test-Path $lockPath) {
            # Check if lock is stale (older than 30 seconds = likely dead process)
            try {
                $lockInfo = Get-Content $lockPath -Raw | ConvertFrom-Json
                $lockAge = ([DateTime]::UtcNow - [DateTime]::Parse($lockInfo.acquiredAt)).TotalSeconds
                
                if ($lockAge -gt 30) {
                    # Stale lock - remove it
                    Write-RalphLog "Removing stale lock on $FilePath (age: ${lockAge}s)" -Level "WARN" -Agent $AgentName -Color Yellow
                    Remove-Item $lockPath -Force -ErrorAction SilentlyContinue
                } else {
                    # Active lock - wait and retry
                    Start-Sleep -Milliseconds $retryDelayMs
                    continue
                }
            } catch {
                # Can't parse lock file - remove it
                Remove-Item $lockPath -Force -ErrorAction SilentlyContinue
            }
        }
        
        # Try to create lock file
        try {
            $lockInfo = @{
                agent = $AgentName
                pid = $PID
                acquiredAt = Get-Timestamp
                filePath = $FilePath
            }
            
            # Use exclusive file mode to prevent race conditions
            $lockJson = $lockInfo | ConvertTo-Json -Compress
            
            # Try atomic creation - this will fail if file already exists
            $stream = $null
            $writer = $null
            try {
                $stream = [System.IO.File]::Open(
                    $lockPath,
                    [System.IO.FileMode]::CreateNew,
                    [System.IO.FileAccess]::Write,
                    [System.IO.FileShare]::None
                )
                
                $writer = New-Object System.IO.StreamWriter($stream)
                $writer.Write($lockJson)
                $writer.Flush()
            } finally {
                # Always dispose writer and stream to prevent handle leaks
                if ($writer) { try { $writer.Dispose() } catch {} }
                if ($stream) { try { $stream.Dispose() } catch {} }
            }
            
            $lockAcquired = $true
            
            return @{
                FilePath = $FilePath
                LockPath = $lockPath
                Agent = $AgentName
                AcquiredAt = $lockInfo.acquiredAt
            }
        } catch [System.IO.IOException] {
            # File already exists (another process grabbed it) - retry
            Start-Sleep -Milliseconds $retryDelayMs
        } catch {
            Write-RalphLog "Lock error on $FilePath : $_" -Level "ERROR" -Agent $AgentName -Color Red
            return $null
        }
    }
    
    return $null
}

function Unlock-SessionFile {
    <#
    .SYNOPSIS
    Releases a lock acquired with Lock-SessionFile.
    
    .PARAMETER Lock
    The lock object returned by Lock-SessionFile.
    #>
    param(
        [Parameter(Mandatory=$true)]
        $Lock
    )
    
    if (-not $Lock -or -not $Lock.LockPath) {
        return
    }
    
    if (Test-Path $Lock.LockPath) {
        try {
            Remove-Item $Lock.LockPath -Force
        } catch {
            # Ignore unlock errors - lock will expire anyway
        }
    }
}

function Invoke-WithFileLock {
    <#
    .SYNOPSIS
    Executes a script block while holding an exclusive lock on a file.
    
    .DESCRIPTION
    Acquires lock, executes script block, releases lock.
    Ensures lock is released even if script block throws.
    
    .PARAMETER FilePath
    The path to the file to lock.
    
    .PARAMETER ScriptBlock
    The code to execute while holding the lock.
    
    .PARAMETER AgentName
    Name of the agent for logging.
    
    .EXAMPLE
    Invoke-WithFileLock -FilePath $statePath -AgentName "developer" -ScriptBlock {
        $state = Get-Content $statePath | ConvertFrom-Json
        $state.iteration++
        $state | ConvertTo-Json | Set-Content $statePath
    }
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath,
        
        [Parameter(Mandatory=$true)]
        [scriptblock]$ScriptBlock,
        
        [string]$AgentName = "unknown"
    )
    
    $lock = Lock-SessionFile -FilePath $FilePath -AgentName $AgentName
    
    if (-not $lock) {
        throw "Failed to acquire lock on $FilePath"
    }
    
    try {
        & $ScriptBlock
    } finally {
        Unlock-SessionFile -Lock $lock
    }
}

# ============================================================================
# ATOMIC FILE OPERATIONS
# ============================================================================

function Write-AtomicJson {
    <#
    .SYNOPSIS
    Writes JSON to a file atomically (write to temp, then move).
    
    .PARAMETER FilePath
    The target file path.
    
    .PARAMETER Data
    The object to serialize as JSON.
    
    .PARAMETER Depth
    JSON serialization depth (default: 10).
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath,
        
        [Parameter(Mandatory=$true)]
        $Data,
        
        [int]$Depth = 10
    )
    
    $tempPath = "$FilePath.tmp"
    
    try {
        $Data | ConvertTo-Json -Depth $Depth | Out-File -FilePath $tempPath -Encoding utf8
        Move-Item -Path $tempPath -Destination $FilePath -Force
        return $true
    } catch {
        if (Test-Path $tempPath) { Remove-Item $tempPath -Force }
        throw
    }
}

function Read-JsonSafe {
    <#
    .SYNOPSIS
    Reads JSON from a file with error handling.
    
    .PARAMETER FilePath
    The file to read.
    
    .RETURNS
    Parsed JSON object, or $null if file doesn't exist or is invalid.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath
    )
    
    if (-not (Test-Path $FilePath)) {
        return $null
    }
    
    try {
        return Get-Content $FilePath -Raw | ConvertFrom-Json
    } catch {
        return $null
    }
}

function Update-JsonFile {
    <#
    .SYNOPSIS
    Reads, modifies, and writes a JSON file atomically with locking.
    
    .PARAMETER FilePath
    The JSON file to update.
    
    .PARAMETER UpdateScript
    Script block that receives the current data and returns the updated data.
    Receives $null if file doesn't exist.
    
    .PARAMETER AgentName
    Name of the agent for lock tracking.
    
    .PARAMETER CreateIfMissing
    If true, creates the file if it doesn't exist.
    
    .EXAMPLE
    Update-JsonFile -FilePath $statePath -AgentName "pm" -UpdateScript {
        param($state)
        if (-not $state) { $state = @{} }
        $state.iteration = ($state.iteration ?? 0) + 1
        return $state
    }
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath,
        
        [Parameter(Mandatory=$true)]
        [scriptblock]$UpdateScript,
        
        [string]$AgentName = "unknown",
        [switch]$CreateIfMissing
    )
    
    Invoke-WithFileLock -FilePath $FilePath -AgentName $AgentName -ScriptBlock {
        $currentData = Read-JsonSafe -FilePath $FilePath
        
        if (-not $currentData -and -not $CreateIfMissing) {
            throw "File not found and CreateIfMissing is false: $FilePath"
        }
        
        $updatedData = & $UpdateScript $currentData
        
        if ($updatedData) {
            Write-AtomicJson -FilePath $FilePath -Data $updatedData
        }
    }
}

# ============================================================================
# OPTIMISTIC LOCKING (Version-based)
# ============================================================================

function Get-FileVersion {
    <#
    .SYNOPSIS
    Gets the version field from a JSON state file.
    #>
    param([string]$FilePath)
    
    $data = Read-JsonSafe -FilePath $FilePath
    if ($data -and $data.version) {
        return [int]$data.version
    }
    return 0
}

function Update-JsonFileOptimistic {
    <#
    .SYNOPSIS
    Updates a JSON file using optimistic locking (version checking).
    
    .DESCRIPTION
    Reads the file, applies updates, increments version, and writes.
    Fails if version changed between read and write (another process modified it).
    
    .PARAMETER FilePath
    The JSON file to update.
    
    .PARAMETER UpdateScript
    Script block that receives current data and returns updated data.
    
    .PARAMETER MaxRetries
    Number of times to retry on version conflict (default: 3).
    
    .PARAMETER AgentName
    Name of the agent for logging.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath,
        
        [Parameter(Mandatory=$true)]
        [scriptblock]$UpdateScript,
        
        [int]$MaxRetries = 3,
        [string]$AgentName = "unknown"
    )
    
    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        # Read current state
        $currentData = Read-JsonSafe -FilePath $FilePath
        $currentVersion = if ($currentData -and $currentData.version) { [int]$currentData.version } else { 0 }
        
        # Apply updates
        $updatedData = & $UpdateScript $currentData
        
        if (-not $updatedData) {
            return  # Nothing to update
        }
        
        # Increment version
        $updatedData | Add-Member -NotePropertyName "version" -NotePropertyValue ($currentVersion + 1) -Force
        
        # Try to write with lock
        $lock = Lock-SessionFile -FilePath $FilePath -AgentName $AgentName -TimeoutMs 1000
        
        if (-not $lock) {
            Write-RalphLog "Optimistic update retry $attempt/$MaxRetries - lock contention" -Level "WARN" -Agent $AgentName -Color Yellow
            Start-Sleep -Milliseconds (100 * $attempt)
            continue
        }
        
        try {
            # Re-check version (it might have changed while waiting for lock)
            $recheckData = Read-JsonSafe -FilePath $FilePath
            $recheckVersion = if ($recheckData -and $recheckData.version) { [int]$recheckData.version } else { 0 }
            
            if ($recheckVersion -ne $currentVersion) {
                Write-RalphLog "Optimistic update retry $attempt/$MaxRetries - version conflict ($currentVersion -> $recheckVersion)" -Level "WARN" -Agent $AgentName -Color Yellow
                continue
            }
            
            # Version matches - safe to write
            Write-AtomicJson -FilePath $FilePath -Data $updatedData
            return
        } finally {
            Unlock-SessionFile -Lock $lock
        }
    }
    
    throw "Failed to update $FilePath after $MaxRetries retries due to version conflicts"
}
