# Safe File I/O Module for Ralph Watchdog
# Provides timeout-protected file operations to prevent watchdog freezing
# All file reads have configurable timeouts with fallback values

# ============================================================================
# CONFIGURATION
# ============================================================================

$Script:FileReadTimeoutMs = 500   # Default timeout for file reads
$Script:FileEnumTimeoutMs = 2000  # Default timeout for directory enumeration (increased for reliability)
$Script:LogTimeouts = $false      # Log timeout events for debugging

# ============================================================================
# TIMEOUT-PROTECTED FILE CONTENT READING
# ============================================================================

function Get-FileContentWithTimeout {
    <#
    .SYNOPSIS
    Read file content with timeout protection to prevent blocking.

    .DESCRIPTION
    Uses a background job to read file content. If the read takes longer
    than the specified timeout, returns the default value instead.
    This prevents the watchdog from freezing on slow file I/O.

    .PARAMETER Path
    The file path to read.

    .PARAMETER TimeoutMs
    Maximum time to wait for the read to complete (default: 500ms).

    .PARAMETER DefaultValue
    Value to return if timeout occurs (default: $null).

    .PARAMETER Raw
    If specified, reads raw content; otherwise reads as string.

    .EXAMPLE
    $content = Get-FileContentWithTimeout -Path "file.json" -TimeoutMs 500 -DefaultValue "{}"
    # Returns file content or "{}" if read times out
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,

        [int]$TimeoutMs = $Script:FileReadTimeoutMs,

        $DefaultValue = $null,

        [switch]$Raw = $false
    )

    # Fast path: if file doesn't exist, return default immediately
    if (-not (Test-Path $Path)) {
        return $DefaultValue
    }

    # Try direct read first with error handling (faster than job for normal case)
    try {
        # Use a quick read attempt - if it fails, fall back to job-based approach
        $null = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        # File is accessible, try reading
        $content = Get-Content $Path -Raw -ErrorAction Stop
        if (-not [string]::IsNullOrWhiteSpace($content)) {
            return $content
        }
    } catch {
        # Fall through to job-based timeout approach
    }

    # Job-based approach for timeout protection
    $job = $null
    try {
        $job = Start-Job -ScriptBlock {
            param($p)
            try {
                Get-Content $p -Raw -ErrorAction SilentlyContinue
            } catch {
                $null
            }
        } -ArgumentList $path -ErrorAction SilentlyContinue

        if (-not $job) {
            if ($Script:LogTimeouts) {
                Write-Warning "[Safe-File-I/O] Failed to create job for $Path"
            }
            return $DefaultValue
        }

        # Wait for job completion with timeout
        $timeoutSeconds = $TimeoutMs / 1000
        $completed = $job | Wait-Job -Timeout $timeoutSeconds -ErrorAction SilentlyContinue

        if ($completed) {
            $result = $job | Receive-Job -ErrorAction SilentlyContinue
            Stop-Job $job -ErrorAction SilentlyContinue
            Remove-Job $job -Force -ErrorAction SilentlyContinue

            if (-not [string]::IsNullOrWhiteSpace($result)) {
                return $result
            }
            return $DefaultValue
        } else {
            # Timeout occurred
            if ($Script:LogTimeouts) {
                Write-Warning "[Safe-File-I/O] Timeout reading $Path (${TimeoutMs}ms)"
            }
            Stop-Job $job -ErrorAction SilentlyContinue
            Remove-Job $job -Force -ErrorAction SilentlyContinue
            return $DefaultValue
        }
    } finally {
        # Always clean up the job
        if ($job) {
            try {
                Stop-Job $job -ErrorAction SilentlyContinue 2>$null
                Remove-Job $job -Force -ErrorAction SilentlyContinue 2>$null
            } catch {
                # Job already cleaned up
            }
        }
    }
}

function Get-FileContentAsJsonWithTimeout {
    <#
    .SYNOPSIS
    Read and parse JSON file content with timeout protection.

    .DESCRIPTION
    Reads a file and parses it as JSON. Returns the parsed object
    or the default value if timeout or parse error occurs.

    .PARAMETER Path
    The JSON file path to read.

    .PARAMETER TimeoutMs
    Maximum time to wait (default: 500ms).

    .PARAMETER DefaultValue
    Object to return if timeout or parse error occurs.

    .EXAMPLE
    $mode = Get-FileContentAsJsonWithTimeout -Path "consolidation-mode.json" -DefaultValue @{mode="normal"}
    # Returns parsed JSON or default value if timeout/parse error
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,

        [int]$TimeoutMs = $Script:FileReadTimeoutMs,

        $DefaultValue = $null
    )

    $content = Get-FileContentWithTimeout -Path $Path -TimeoutMs $TimeoutMs -DefaultValue $null

    if ([string]::IsNullOrWhiteSpace($content)) {
        return $DefaultValue
    }

    try {
        return $content | ConvertFrom-Json -ErrorAction Stop
    } catch {
        if ($Script:LogTimeouts) {
            $err = $_.Exception.Message
            $pathStr = $Path
            Write-Warning "[Safe-File-I/O] Failed to parse JSON from ${pathStr}: ${err}"
        }
        return $DefaultValue
    }
}

# ============================================================================
# TIMEOUT-PROTECTED DIRECTORY ENUMERATION
# ============================================================================

function Get-ChildItemWithTimeout {
    <#
    .SYNOPSIS
    Enumerate directory contents with timeout protection.

    .DESCRIPTION
    Returns child items from a directory with timeout protection.
    Uses job-based approach to prevent blocking on slow directory scans.

    .PARAMETER Path
    The directory path to enumerate.

    .PARAMETER Filter
    Filter pattern for files (default: *).

    .PARAMETER TimeoutMs
    Maximum time to wait (default: 300ms).

    .PARAMETER DefaultValue
    Array to return if timeout occurs (default: @()).

    .EXAMPLE
    $files = Get-ChildItemWithTimeout -Path ".claude/session/messages/pm" -Filter "*.json"
    # Returns file list or empty array if timeout
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,

        [string]$Filter = "*",

        [int]$TimeoutMs = $Script:FileEnumTimeoutMs,

        [array]$DefaultValue = @()
    )

    # Fast path: if directory doesn't exist, return empty immediately
    if (-not (Test-Path $Path -PathType Container)) {
        return $DefaultValue
    }

    $job = $null
    try {
        $job = Start-Job -ScriptBlock {
            param($p, $f)
            try {
                Get-ChildItem -Path $p -Filter $f -ErrorAction SilentlyContinue
            } catch {
                @()
            }
        } -ArgumentList $Path, $Filter -ErrorAction SilentlyContinue

        if (-not $job) {
            if ($Script:LogTimeouts) {
                Write-Warning "[Safe-File-I/O] Failed to create job for Get-ChildItem $Path"
            }
            return $DefaultValue
        }

        $timeoutSeconds = $TimeoutMs / 1000
        $completed = $job | Wait-Job -Timeout $timeoutSeconds -ErrorAction SilentlyContinue

        if ($completed) {
            $result = $job | Receive-Job -ErrorAction SilentlyContinue
            Stop-Job $job -ErrorAction SilentlyContinue
            Remove-Job $job -Force -ErrorAction SilentlyContinue

            if ($result) {
                return $result
            }
            return $DefaultValue
        } else {
            # Timeout occurred
            if ($Script:LogTimeouts) {
                Write-Warning "[Safe-File-I/O] Timeout enumerating $Path (${TimeoutMs}ms)"
            }
            Stop-Job $job -ErrorAction SilentlyContinue
            Remove-Job $job -Force -ErrorAction SilentlyContinue
            return $DefaultValue
        }
    } finally {
        if ($job) {
            try {
                Stop-Job $job -ErrorAction SilentlyContinue 2>$null
                Remove-Job $job -Force -ErrorAction SilentlyContinue 2>$null
            } catch {
                # Job already cleaned up
            }
        }
    }
}

function Get-FileCountWithTimeout {
    <#
    .SYNOPSIS
    Count files in a directory with timeout protection.

    .DESCRIPTION
    Returns the count of files matching a filter in a directory.
    Optimized to return count only, not full file list.

    .PARAMETER Path
    The directory path to count files in.

    .PARAMETER Filter
    Filter pattern for files (default: *).

    .PARAMETER TimeoutMs
    Maximum time to wait (default: 300ms).

    .PARAMETER DefaultValue
    Value to return if timeout occurs (default: 0).

    .EXAMPLE
    $count = Get-FileCountWithTimeout -Path ".claude/session/messages/pm" -Filter "*.json"
    # Returns file count or 0 if timeout
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,

        [string]$Filter = "*",

        [int]$TimeoutMs = $Script:FileEnumTimeoutMs,

        [int]$DefaultValue = 0
    )

    $files = Get-ChildItemWithTimeout -Path $Path -Filter $Filter -TimeoutMs $TimeoutMs -DefaultValue @()

    if ($files) {
        return @($files).Count
    }
    return $DefaultValue
}

# ============================================================================
# TIMEOUT-PROTECTED FILE EXISTENCE CHECK
# ============================================================================

function Test-FileExistsWithTimeout {
    <#
    .SYNOPSIS
    Check if a file exists with timeout protection.

    .DESCRIPTION
    Checks file existence with minimal blocking. Returns quickly
    even if the file system is slow.

    .PARAMETER Path
    The file path to check.

    .PARAMETER TimeoutMs
    Maximum time to wait (default: 100ms).

    .EXAMPLE
    $exists = Test-FileExistsWithTimeout -Path "consolidation-mode.json"
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,

        [int]$TimeoutMs = 100
    )

    $job = $null
    try {
        $job = Start-Job -ScriptBlock {
            param($p)
            Test-Path $p -PathType Leaf -ErrorAction SilentlyContinue
        } -ArgumentList $Path -ErrorAction SilentlyContinue

        if (-not $job) {
            return $false
        }

        $timeoutSeconds = $TimeoutMs / 1000
        $completed = $job | Wait-Job -Timeout $timeoutSeconds -ErrorAction SilentlyContinue

        if ($completed) {
            $result = $job | Receive-Job -ErrorAction SilentlyContinue
            Stop-Job $job -ErrorAction SilentlyContinue
            Remove-Job $job -Force -ErrorAction SilentlyContinue
            return $result -eq $true
        }

        # Timeout - assume doesn't exist for safety
        Stop-Job $job -ErrorAction SilentlyContinue
        Remove-Job $job -Force -ErrorAction SilentlyContinue
        return $false
    } finally {
        if ($job) {
            try {
                Stop-Job $job -ErrorAction SilentlyContinue 2>$null
                Remove-Job $job -Force -ErrorAction SilentlyContinue 2>$null
            } catch {
                # Job already cleaned up
            }
        }
    }
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

function Set-SafeFileTimeouts {
    <#
    .SYNOPSIS
    Configure timeout values for safe file operations.

    .PARAMETER FileReadTimeoutMs
    Timeout for file read operations.

    .PARAMETER FileEnumTimeoutMs
    Timeout for directory enumeration operations.

    .PARAMETER LogTimeouts
    Enable/disable timeout logging.
    #>
    param(
        [int]$FileReadTimeoutMs = 500,
        [int]$FileEnumTimeoutMs = 300,
        [bool]$LogTimeouts = $false
    )

    $Script:FileReadTimeoutMs = $FileReadTimeoutMs
    $Script:FileEnumTimeoutMs = $FileEnumTimeoutMs
    $Script:LogTimeouts = $LogTimeouts
}

function Get-SafeFileTimeouts {
    return @{
        FileReadTimeoutMs = $Script:FileReadTimeoutMs
        FileEnumTimeoutMs = $Script:FileEnumTimeoutMs
        LogTimeouts = $Script:LogTimeouts
    }
}
