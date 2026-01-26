# Ralph Test Helpers - Utility Functions for Integration Testing
# Provides isolated test environments, test data generation, and assertions

# ============================================================================
# TEST ENVIRONMENT MANAGEMENT
# ============================================================================

$Script:TestEnvironments = @{}
$Script:CurrentTestName = $null
$Script:TestStats = @{
    Passed = 0
    Failed = 0
    Skipped = 0
    Total = 0
}

function New-TestEnvironment {
    <#
    .SYNOPSIS
    Create an isolated test environment with session directory structure.

    .DESCRIPTION
    Creates a temporary directory with the Ralph session structure:
    - messages/ (for message queues)
    - state/ (for state files)
    - logs/ (for test logs)

    Returns a cleanup scriptblock that should be called after the test.

    .PARAMETER TestName
    Name of the test (used for directory naming).

    .RETURNS
    Hashtable with:
    - Path: Full path to test directory
    - SessionDir: Path to session subdirectory
    - MessagesDir: Path to messages subdirectory
    - StateDir: Path to state subdirectory
    - LogsDir: Path to logs subdirectory
    - Cleanup: Scriptblock to clean up the test environment

    .EXAMPLE
    $env = New-TestEnvironment -TestName "crash-recovery"
    # ... run test ...
    & $env.Cleanup
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$TestName
    )

    $safeName = $TestName -replace '[^a-zA-Z0-9-]', '_'
    $testPath = Join-Path $env:TEMP "ralph-test-$safeName-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

    # Create directory structure
    $null = New-Item -ItemType Directory -Path $testPath -Force -ErrorAction Stop
    $sessionDir = Join-Path $testPath "session"
    $null = New-Item -ItemType Directory -Path $sessionDir -Force -ErrorAction Stop

    $messagesDir = Join-Path $sessionDir "messages"
    $null = New-Item -ItemType Directory -Path $messagesDir -Force -ErrorAction Stop

    $stateDir = Join-Path $sessionDir "state"
    $null = New-Item -ItemType Directory -Path $stateDir -Force -ErrorAction Stop

    $logsDir = Join-Path $testPath "logs"
    $null = New-Item -ItemType Directory -Path $logsDir -Force -ErrorAction Stop

    # Create agent-specific message directories
    $agents = @("pm", "developer", "qa", "gamedesigner", "techartist")
    foreach ($agent in $agents) {
        $agentDir = Join-Path $messagesDir $agent
        $null = New-Item -ItemType Directory -Path $agentDir -Force -ErrorAction Stop
    }

    # Cleanup scriptblock - captures testPath directly using a closure
    $capturedPath = $testPath
    $cleanupScriptBlock = {
        param($Path = $capturedPath)
        if ($Path -and (Test-Path $Path)) {
            try {
                Remove-Item $Path -Recurse -Force -ErrorAction Stop
            } catch {
                Write-Warning "Failed to cleanup test environment: $_"
            }
        }
    }.GetNewClosure()

    $env = @{
        Path = $testPath
        SessionDir = $sessionDir
        MessagesDir = $messagesDir
        StateDir = $stateDir
        LogsDir = $logsDir
        Cleanup = $cleanupScriptBlock
    }

    # Register for cleanup on exit
    $Script:TestEnvironments[$safeName] = $env

    return $env
}

function Remove-TestEnvironment {
    <#
    .SYNOPSIS
    Remove a test environment by name.

    .PARAMETER TestName
    Name of the test environment to remove.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$TestName
    )

    $safeName = $TestName -replace '[^a-zA-Z0-9-]', '_'

    if ($Script:TestEnvironments.ContainsKey($safeName)) {
        $env = $Script:TestEnvironments[$safeName]
        & $env.Cleanup
        $Script:TestEnvironments.Remove($safeName)
    }
}

function Remove-AllTestEnvironments {
    <#
    .SYNOPSIS
    Remove all registered test environments.
    #>
    param()

    # Iterate over a copy of keys to avoid modification during enumeration
    $keys = @($Script:TestEnvironments.Keys)
    foreach ($name in $keys) {
        Remove-TestEnvironment -TestName $name
    }
}

function Get-TestTempPath {
    <#
    .SYNOPSIS
    Get a temporary path for test files.

    .PARAMETER SubPath
    Optional subpath within the temp directory.

    .RETURNS
    Full path to a temporary location.
    #>
    param(
        [string]$SubPath = ""
    )

    $basePath = Join-Path $env:TEMP "ralph-test"
    if (-not (Test-Path $basePath)) {
        $null = New-Item -ItemType Directory -Path $basePath -Force -ErrorAction SilentlyContinue
    }

    if ($SubPath) {
        return Join-Path $basePath $SubPath
    }
    return $basePath
}

# ============================================================================
# TEST DATA GENERATION
# ============================================================================

function New-TestMessage {
    <#
    .SYNOPSIS
    Generate a valid test message with all required fields.

    .DESCRIPTION
    Creates a message hashtable with properly formatted fields
    for testing the message queue system.

    .PARAMETER From
    Sender agent name (default: "pm").

    .PARAMETER To
    Recipient agent name (default: "developer").

    .PARAMETER Type
    Message type (default: "task_assign").

    .PARAMETER Payload
    Message payload hashtable (default: @{ taskId = "test-001" }).

    .PARAMETER Priority
    Message priority (default: "normal").

    .PARAMETER Id
    Custom message ID (auto-generated if not provided).

    .RETURNS
    Hashtable representing a valid message.
    #>
    param(
        [string]$From = "pm",
        [string]$To = "developer",
        [string]$Type = "task_assign",
        [hashtable]$Payload = @{ taskId = "test-001" },
        [string]$Priority = "normal",
        [string]$Id = $null
    )

    if (-not $Id) {
        $Id = "msg-$(Get-Date -Format 'yyyyMMdd-HHmmss')-$([guid]::NewGuid().ToString().Substring(0,8))"
    }

    return @{
        id = $Id
        from = $From
        to = $To
        type = $Type
        priority = $Priority
        payload = $Payload
        timestamp = [DateTime]::UtcNow.ToString("o")
        status = "pending"
    }
}

function New-CorruptStateFile {
    <#
    .SYNOPSIS
    Create a corrupted state file for testing recovery.

    .DESCRIPTION
    Creates a file with intentionally corrupted JSON content
    to test state recovery and error handling.

    .PARAMETER Path
    Path where the corrupted file should be created.

    .PARAMETER CorruptionType
    Type of corruption:
    - "invalid": Invalid JSON syntax
    - "truncated": Truncated JSON
    - "empty": Empty file
    - "binary": Binary garbage data

    .RETURNS
    Full path to the created corrupted file.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,

        [ValidateSet("invalid", "truncated", "empty", "binary")]
        [string]$CorruptionType = "invalid"
    )

    $parentDir = Split-Path $Path -Parent
    if (-not (Test-Path $parentDir)) {
        $null = New-Item -ItemType Directory -Path $parentDir -Force -ErrorAction Stop
    }

    switch ($CorruptionType) {
        "invalid" {
            # Invalid JSON - missing closing brace
            Set-Content -Path $Path -Value '{ "valid": "json", "broken": true' -NoNewline -ErrorAction Stop
        }
        "truncated" {
            # Truncated mid-string
            Set-Content -Path $Path -Value '{ "test": "value that gets cu' -NoNewline -ErrorAction Stop
        }
        "empty" {
            # Empty file
            Set-Content -Path $Path -Value '' -NoNewline -ErrorAction Stop
        }
        "binary" {
            # Binary garbage
            $bytes = [byte[]]@(0xFF, 0xFE, 0xFD, 0xFC, 0xFB, 0xF0, 0x00, 0x01)
            [System.IO.File]::WriteAllBytes($Path, $bytes)
        }
    }

    return $Path
}

function New-TestAgentState {
    <#
    .SYNOPSIS
    Generate a valid agent state for testing.

    .PARAMETER AgentName
    Name of the agent.

    .PARAMETER Status
    Agent status (default: "idle").

    .PARAMETER LastHeartbeat
    Last heartbeat time (default: now).

    .RETURNS
    Hashtable representing agent state.
    #>
    param(
        [string]$AgentName = "developer",
        [string]$Status = "idle",
        [DateTime]$LastHeartbeat = [DateTime]::UtcNow
    )

    return @{
        name = $AgentName
        status = $Status
        lastHeartbeat = $LastHeartbeat.ToString("o")
        pid = $PID
        contextResets = 0
        tasksCompleted = 0
    }
}

# ============================================================================
# TEST FRAMEWORK
# ============================================================================

function Invoke-Test {
    <#
    .SYNOPSIS
    Execute a test with logging and error handling.

    .DESCRIPTION
    Runs a test scriptblock, logs results, and updates test statistics.
    Automatically handles setup/teardown and provides colored output.

    .PARAMETER Name
    Test name (displayed in output).

    .PARAMETER ScriptBlock
    Test script to execute.

    .PARAMETER Skip
    If set, marks the test as skipped.

    .RETURNS
    $true if test passed, $false if failed, $null if skipped.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,

        [Parameter(Mandatory=$true)]
        [scriptblock]$ScriptBlock,

        [switch]$Skip
    )

    $Script:CurrentTestName = $Name
    $Script:TestStats.Total++

    if ($Skip) {
        Write-Host "  [SKIP] $Name" -ForegroundColor DarkYellow
        $Script:TestStats.Skipped++
        return $null
    }

    Write-Host "  [TEST] $Name" -ForegroundColor Cyan

    try {
        $result = & $ScriptBlock

        if ($result -eq $false) {
            Write-Host "    FAIL" -ForegroundColor Red
            $Script:TestStats.Failed++
            return $false
        }

        Write-Host "    PASS" -ForegroundColor Green
        $Script:TestStats.Passed++
        return $true
    } catch {
        Write-Host "    FAIL: $($_.Exception.Message)" -ForegroundColor Red
        if ($_.ScriptStackTrace) {
            Write-Host "    at $($_.ScriptStackTrace.Split("`n")[0])" -ForegroundColor DarkRed
        }
        $Script:TestStats.Failed++
        return $false
    } finally {
        $Script:CurrentTestName = $null
    }
}

function Assert-TestCondition {
    <#
    .SYNOPSIS
    Assert a condition is true, throwing if not.

    .DESCRIPTION
    Test assertion helper. Throws an error with a descriptive
    message if the condition is false.

    .PARAMETER Condition
    Condition to test.

    .PARAMETER Message
    Error message if condition is false.

    .PARAMETER Actual
    Actual value (for error reporting).

    .PARAMETER Expected
    Expected value (for error reporting).

    .EXAMPLE
    Assert-TestCondition -Condition ($result -eq $expected) -Message "Result should equal expected"
    #>
    param(
        [Parameter(Mandatory=$true)]
        [bool]$Condition,

        [Parameter(Mandatory=$true)]
        [string]$Message,

        [object]$Actual = $null,
        [object]$Expected = $null
    )

    if (-not $Condition) {
        $errorDetail = $Message
        if ($null -ne $Actual -or $null -ne $Expected) {
            $errorDetail += " [Expected: $Expected, Actual: $Actual]"
        }
        throw $errorDetail
    }
}

function Assert-TestEqual {
    <#
    .SYNOPSIS
    Assert two values are equal.

    .PARAMETER Actual
    Actual value.

    .PARAMETER Expected
    Expected value.

    .PARAMETER Message
    Optional error message.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [object]$Actual,

        [Parameter(Mandatory=$true)]
        [object]$Expected,

        [string]$Message = "Values should be equal"
    )

    if ($Actual -ne $Expected) {
        throw "$Message [Expected: '$Expected', Actual: '$Actual']"
    }
}

function Assert-TestThrows {
    <#
    .SYNOPSIS
    Assert a scriptblock throws an exception.

    .PARAMETER ScriptBlock
    Scriptblock that should throw.

    .PARAMETER ExceptionType
    Specific exception type (optional).

    .PARAMETER Message
    Error message if no exception is thrown.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [scriptblock]$ScriptBlock,

        [type]$ExceptionType = $null,
        [string]$Message = "Scriptblock should throw"
    )

    $threw = $false
    $actualException = $null

    try {
        & $ScriptBlock | Out-Null
    } catch {
        $threw = $true
        $actualException = $_.Exception
    }

    if (-not $threw) {
        throw "$Message (no exception was thrown)"
    }

    if ($ExceptionType -and $actualException -isnot $ExceptionType) {
        throw "$Message (expected $($ExceptionType.Name), got $($actualException.GetType().Name))"
    }
}

# ============================================================================
# TEST RESULT REPORTING
# ============================================================================

function Get-TestStats {
    <#
    .SYNOPSIS
    Get current test statistics.

    .RETURNS
    Hashtable with test counts.
    #>
    param()

    return $Script:TestStats.Clone()
}

function Show-TestResults {
    <#
    .SYNOPSIS
    Display test results summary.
    #>
    param()

    $stats = Get-TestStats
    $total = $stats.Total
    $passed = $stats.Passed
    $failed = $stats.Failed
    $skipped = $stats.Skipped

    Write-Host "`n=== Test Results ===" -ForegroundColor Cyan
    Write-Host "  Total:   $total" -ForegroundColor White
    Write-Host "  Passed:  $passed" -ForegroundColor Green
    Write-Host "  Failed:  $failed" -ForegroundColor $(if ($failed -gt 0) { "Red" } else { "Green" })
    Write-Host "  Skipped: $skipped" -ForegroundColor Yellow

    $successRate = if ($total -gt 0) { [math]::Round(($passed / $total) * 100, 1) } else { 0 }
    $statusColor = if ($failed -eq 0) { "Green" } elseif ($failed -le $total * 0.1) { "Yellow" } else { "Red" }
    Write-Host "  Success: $successRate%" -ForegroundColor $statusColor
    Write-Host "====================`n" -ForegroundColor Cyan

    return ($failed -eq 0)
}

function Reset-TestStats {
    <#
    .SYNOPSIS
    Reset test statistics.
    #>
    param()

    $Script:TestStats = @{
        Passed = 0
        Failed = 0
        Skipped = 0
        Total = 0
    }
}

# ============================================================================
# TEST TIMING HELPERS
# ============================================================================

function Measure-TestExecution {
    <#
    .SYNOPSIS
    Measure test execution time with detailed output.

    .PARAMETER ScriptBlock
    Scriptblock to measure.

    .PARAMETER Label
    Label for the measurement.

    .RETURNS
    TimeSpan of execution duration.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [scriptblock]$ScriptBlock,

        [string]$Label = "Execution"
    )

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        & $ScriptBlock | Out-Null
    } finally {
        $sw.Stop()
    }

    $ms = $sw.ElapsedMilliseconds
    $color = if ($ms -lt 10) { "Green" } elseif ($ms -lt 100) { "Yellow" } else { "Red" }
    Write-Host "    ${Label}: " -NoNewline -ForegroundColor Gray
    Write-Host "$ms ms" -ForegroundColor $color

    return $sw.Elapsed
}

# ============================================================================
# INITIALIZATION
# ============================================================================

# Clean up any orphaned test directories older than 24 hours on module load
function Initialize-TestHelpers {
    <#
    .SYNOPSIS
    Initialize test helpers and clean up old test directories.
    #>
    param()

    try {
        $tempBase = Join-Path $env:TEMP "ralph-test-"
        $oldDirs = Get-Item -Path "$tempBase*" -ErrorAction SilentlyContinue |
                   Where-Object { $_.CreationTime -lt (Get-Date).AddHours(-24) }

        foreach ($dir in $oldDirs) {
            try {
                Remove-Item $dir.FullName -Recurse -Force -ErrorAction Stop
            } catch {
                # Ignore cleanup failures
            }
        }
    } catch {
        # Ignore initialization errors
    }
}

# Auto-initialize on import
Initialize-TestHelpers

# Export module info
$ExportFunctions = @(
    "New-TestEnvironment"
    "Remove-TestEnvironment"
    "Remove-AllTestEnvironments"
    "Get-TestTempPath"
    "New-TestMessage"
    "New-CorruptStateFile"
    "New-TestAgentState"
    "Invoke-Test"
    "Assert-TestCondition"
    "Assert-TestEqual"
    "Assert-TestThrows"
    "Get-TestStats"
    "Show-TestResults"
    "Reset-TestStats"
    "Measure-TestExecution"
)
