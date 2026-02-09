# Ralph Configuration Module (PowerShell)
# Centralized configuration for all Ralph scripts
# Source this file in other scripts: . "$PSScriptRoot\ralph-config.ps1"

# ============================================================================
# VALID STATUS VALUES (Standardized across all scripts)
# ============================================================================

$Script:ValidAgentStatuses = @(
    "stopped",      # Process not running
    "starting",     # Process booting up, not ready for interruption
    "idle",         # Running but not actively working
    "working",      # Actively processing a task
    "waiting",      # Waiting for input/response
    "ready",        # Ready to accept new work
    "completed",    # Finished all work
    "terminated",   # Intentionally stopped
    "error"         # Error state
)

$Script:ValidProcessStates = @(
    "stopped",      # Process not running
    "running"       # Process is running
)

function Test-ValidAgentStatus {
    <#
    .SYNOPSIS
    Validates that a status string is a known valid status.
    Returns $true if valid, $false otherwise.
    #>
    param([string]$Status)
    return $Status -in $Script:ValidAgentStatuses
}

function Get-ValidAgentStatuses {
    return $Script:ValidAgentStatuses
}

# ============================================================================
# ENVIRONMENT CONFIGURATION
# ============================================================================
# These can be overridden via environment variables

# Safe environment variable parsing helpers
function Get-EnvInt {
    param([string]$Name, [int]$Default, [int]$Min = 0, [int]$Max = [int]::MaxValue)
    $val = [Environment]::GetEnvironmentVariable($Name)
    if ([string]::IsNullOrWhiteSpace($val)) { return $Default }
    $parsed = 0
    if ([int]::TryParse($val, [ref]$parsed)) {
        # Clamp to valid range
        return [Math]::Max($Min, [Math]::Min($Max, $parsed))
    }
    return $Default
}

function Get-EnvString {
    param([string]$Name, [string]$Default)
    $val = [Environment]::GetEnvironmentVariable($Name)
    if ([string]::IsNullOrWhiteSpace($val)) { return $Default }
    return $val
}

# ============================================================================
# SECURITY: CREDENTIAL REDACTION
# ============================================================================

function Remove-SensitiveData {
    <#
    .SYNOPSIS
    Redacts potentially sensitive data from strings before logging.
    
    .DESCRIPTION
    Removes or masks patterns that look like credentials, tokens, API keys,
    passwords, and other sensitive data from log output.
    
    .PARAMETER Text
    The text to redact sensitive data from.
    
    .EXAMPLE
    $safeOutput = Remove-SensitiveData -Text $commandOutput
    Write-Host $safeOutput
    #>
    param(
        [Parameter(Mandatory=$true)]
        [AllowEmptyString()]
        [string]$Text
    )
    
    if ([string]::IsNullOrEmpty($Text)) { return $Text }
    
    # Patterns to redact (order matters - more specific first)
    # Note: Using simpler patterns to avoid PowerShell quote parsing issues
    $patterns = @(
        # Bearer tokens
        @{ Pattern = '(Bearer\s+)[A-Za-z0-9\-_\.]+'; Replace = '`$1[REDACTED]' }
        # API Keys (common patterns) - match key=value or key:value formats
        @{ Pattern = '(api[_-]?key\s*[:=]\s*)[A-Za-z0-9\-_]{20,}'; Replace = '`$1[REDACTED]' }
        @{ Pattern = '(apikey\s*[:=]\s*)[A-Za-z0-9\-_]{20,}'; Replace = '`$1[REDACTED]' }
        # Tokens
        @{ Pattern = '(token\s*[:=]\s*)[A-Za-z0-9\-_\.]{20,}'; Replace = '`$1[REDACTED]' }
        @{ Pattern = '(access_token\s*[:=]\s*)[A-Za-z0-9\-_\.]+'; Replace = '`$1[REDACTED]' }
        # Passwords
        @{ Pattern = '(password\s*[:=]\s*)\S+'; Replace = '`$1[REDACTED]' }
        @{ Pattern = '(passwd\s*[:=]\s*)\S+'; Replace = '`$1[REDACTED]' }
        @{ Pattern = '(pwd\s*[:=]\s*)\S+'; Replace = '`$1[REDACTED]' }
        # Secrets
        @{ Pattern = '(secret\s*[:=]\s*)\S+'; Replace = '`$1[REDACTED]' }
        @{ Pattern = '(client_secret\s*[:=]\s*)\S+'; Replace = '`$1[REDACTED]' }
        # Connection strings
        @{ Pattern = '(connectionstring\s*[:=]\s*)\S+'; Replace = '`$1[REDACTED]' }
        # GitHub tokens
        @{ Pattern = 'ghp_[A-Za-z0-9]{36}'; Replace = '[GITHUB_TOKEN_REDACTED]' }
        @{ Pattern = 'gho_[A-Za-z0-9]{36}'; Replace = '[GITHUB_OAUTH_REDACTED]' }
        # AWS keys
        @{ Pattern = 'AKIA[A-Z0-9]{16}'; Replace = '[AWS_KEY_REDACTED]' }
        # Azure keys (base64 pattern) - escaped forward slash for safety
        @{ Pattern = '[A-Za-z0-9\/+]{86}=='; Replace = '[AZURE_KEY_REDACTED]' }
    )
    
    $result = $Text
    foreach ($p in $patterns) {
        $result = $result -replace $p.Pattern, $p.Replace
    }
    
    return $result
}

$Script:RalphConfig = @{
    # Core settings
    MaxIterations        = Get-EnvInt -Name "RALPH_MAX_ITERATIONS" -Default 200 -Min 1 -Max 10000
    CompletionPromise    = Get-EnvString -Name "RALPH_COMPLETION_PROMISE" -Default "RALPH_COMPLETE"
    ContextResetPromise  = Get-EnvString -Name "RALPH_CONTEXT_RESET_PROMISE" -Default "CONTEXT_RESET"
    
    # AFK Mode / Idle Detection
    IdleTimeoutSeconds   = Get-EnvInt -Name "RALPH_IDLE_TIMEOUT" -Default 60 -Min 10 -Max 3600
    HeartbeatInterval    = Get-EnvInt -Name "RALPH_HEARTBEAT_INTERVAL" -Default 30 -Min 5 -Max 300
    StaleAgentThreshold  = Get-EnvInt -Name "RALPH_STALE_THRESHOLD" -Default 90 -Min 30 -Max 600
    
    # Context Management
    ContextResetThreshold = Get-EnvInt -Name "RALPH_CONTEXT_THRESHOLD" -Default 70 -Min 50 -Max 95
    
    # Timing
    PollIntervalMs       = Get-EnvInt -Name "RALPH_POLL_INTERVAL_MS" -Default 500 -Min 100 -Max 10000
    
    # Restart behavior
    RestartDelaySeconds  = Get-EnvInt -Name "RALPH_RESTART_DELAY" -Default 2 -Min 1 -Max 30
    MaxRestartAttempts   = Get-EnvInt -Name "RALPH_MAX_RESTART_ATTEMPTS" -Default 3 -Min 1 -Max 10
    
    # File locking (Phase 2)
    LockTimeoutMs        = Get-EnvInt -Name "RALPH_LOCK_TIMEOUT_MS" -Default 5000 -Min 1000 -Max 30000
    LockRetryDelayMs     = Get-EnvInt -Name "RALPH_LOCK_RETRY_MS" -Default 100 -Min 10 -Max 1000
    
    # Resource limits
    MaxLogSizeMB         = Get-EnvInt -Name "RALPH_MAX_LOG_SIZE_MB" -Default 50 -Min 10 -Max 500
    MaxArchiveAgeHours   = Get-EnvInt -Name "RALPH_MAX_ARCHIVE_AGE_HOURS" -Default 24 -Min 1 -Max 168
    MaxMessageQueueSize  = Get-EnvInt -Name "RALPH_MAX_MESSAGE_QUEUE_SIZE" -Default 1000 -Min 100 -Max 10000

    # Timing constants (centralized from hardcoded values)
    WindowCloseDelaySeconds    = Get-EnvInt -Name "RALPH_WINDOW_CLOSE_DELAY" -Default 30 -Min 5 -Max 120
    ProcessStartGraceSeconds   = Get-EnvInt -Name "RALPH_PROCESS_START_GRACE" -Default 5 -Min 1 -Max 30
    AgentStaggerDelaySeconds   = Get-EnvInt -Name "RALPH_AGENT_STAGGER_DELAY" -Default 3 -Min 1 -Max 10
    DeliveryGraceSeconds       = Get-EnvInt -Name "RALPH_DELIVERY_GRACE" -Default 10 -Min 5 -Max 60

    # Consolidation mode (PM reviews pending messages on startup/restart)
    ConsolidationTimeoutSeconds = Get-EnvInt -Name "RALPH_CONSOLIDATION_TIMEOUT" -Default 300 -Min 60 -Max 900

    # Timeout configuration (prevents watchdog freeze on slow I/O)
    FileReadTimeoutMs              = Get-EnvInt -Name "RALPH_FILE_READ_TIMEOUT" -Default 500 -Min 100 -Max 5000
    FileEnumTimeoutMs              = Get-EnvInt -Name "RALPH_FILE_ENUM_TIMEOUT" -Default 300 -Min 100 -Max 5000

    # RESILIENCE: Circuit breaker configuration
    CircuitBreakerEnabled          = Get-EnvString -Name "RALPH_CIRCUIT_BREAKER_ENABLED" -Default "true"
    CircuitBreakerMaxFailures      = Get-EnvInt -Name "RALPH_CIRCUIT_BREAKER_MAX_FAILURES" -Default 3 -Min 1 -Max 10
    CircuitBreakerCooldownSeconds   = Get-EnvInt -Name "RALPH_CIRCUIT_BREAKER_COOLDOWN" -Default 60 -Min 10 -Max 600

    # Message processing timeout (prevents watchdog freeze on large queues)
    MessageProcessingTimeoutMs      = Get-EnvInt -Name "RALPH_MESSAGE_PROCESSING_TIMEOUT" -Default 300 -Min 100 -Max 5000

    # Auxiliary script cleanup (for session scripts created by agents)
    TempScriptMaxAgeHours = Get-EnvInt -Name "RALPH_TEMP_SCRIPT_MAX_AGE_HOURS" -Default 1 -Min 1 -Max 24
}

# ============================================================================
# AUXILIARY SCRIPT CLASSIFICATION
# ============================================================================
# Scripts created in session folder are classified as temporary or reusable
# Temporary scripts are auto-deleted after TempScriptMaxAgeHours
# Reusable scripts should be documented in AGENT.md files

$Script:AuxiliaryScripts = @{
    # Temporary scripts - auto-deleted after use
    # These patterns match scripts that are created for one-time use
    Temporary = @(
        "*-runner.ps1",           # Agent runner scripts (created by watchdog)
        "pending-messages-*.json", # Message delivery files
        "*.exit",                 # Agent exit status files
        "restart-flag-*.json",    # Restart signal files
        "*.tmp",                  # Temporary files
        "*-temp.ps1"              # Any temp PowerShell scripts
    )
    # Reusable scripts - persist and should be documented in AGENT.md
    # Add scripts here that provide value across multiple sessions
    Reusable = @(
        # Currently none - add future reusable scripts here with descriptive names
        # Example: "qa-browser-test-helper.ps1" - Would be documented in QA AGENT.md
    )
}

function Get-ScriptType {
    <#
    .SYNOPSIS
    Classifies a script file as Temporary, Reusable, or Unknown based on its filename.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$FileName
    )

    foreach ($pattern in $Script:AuxiliaryScripts.Temporary) {
        if ($FileName -like $pattern) { return "Temporary" }
    }
    foreach ($pattern in $Script:AuxiliaryScripts.Reusable) {
        if ($FileName -like $pattern) { return "Reusable" }
    }
    return "Unknown"
}

function Invoke-TempScriptCleanup {
    <#
    .SYNOPSIS
    Removes temporary scripts from the session directory that are older than the configured threshold.
    #>
    param(
        [string]$SessionDir = (Join-Path (Get-Location).Path ".claude/session"),
        [int]$MaxAgeHours = 0
    )

    if (-not (Test-Path $SessionDir)) { return 0 }

    if ($MaxAgeHours -le 0) {
        $MaxAgeHours = $Script:RalphConfig.TempScriptMaxAgeHours
    }

    $cutoff = [DateTime]::UtcNow.AddHours(-$MaxAgeHours)
    $removed = 0

    Get-ChildItem -Path $SessionDir -File -ErrorAction SilentlyContinue | ForEach-Object {
        $scriptType = Get-ScriptType -FileName $_.Name
        if ($scriptType -eq "Temporary") {
            if ($_.LastWriteTimeUtc -lt $cutoff) {
                try {
                    Remove-Item $_.FullName -Force
                    $removed++
                } catch {
                    Write-RalphLog "Failed to remove temp script $($_.Name): $_" -Level "WARN" -Color Yellow
                }
            }
        }
    }

    return $removed
}

# ============================================================================
# PATH CONFIGURATION
# ============================================================================

function Get-RalphPaths {
    param(
        [string]$ProjectRoot = (Get-Location).Path
    )
    
    return @{
        SessionDir           = Join-Path $ProjectRoot ".claude/session"
        ScriptsDir           = Join-Path $ProjectRoot ".claude/scripts"
        HooksDir             = Join-Path $ProjectRoot ".claude/hooks"
        SkillsDir            = Join-Path $ProjectRoot ".claude/skills"
        
        # State files
        CoordinatorState     = Join-Path $ProjectRoot ".claude/session/coordinator-state.json"
        CurrentTask          = Join-Path $ProjectRoot ".claude/session/current-task.json"
        HandoffLog           = Join-Path $ProjectRoot ".claude/session/handoff-log.json"
        ContinueFlag         = Join-Path $ProjectRoot ".claude/session/continue-loop.flag"
        
        # Per-agent state files (Phase 2 - separated for reduced contention)
        AgentStatePM         = Join-Path $ProjectRoot ".claude/session/agent-pm.json"
        AgentStateDeveloper  = Join-Path $ProjectRoot ".claude/session/agent-developer.json"
        AgentStateQA         = Join-Path $ProjectRoot ".claude/session/agent-qa.json"
        
        # Progress files
        ProgressLog          = Join-Path $ProjectRoot ".claude/session/progress.txt"
        EventsLog            = Join-Path $ProjectRoot ".claude/session/events.jsonl"
        MetricsFile          = Join-Path $ProjectRoot ".claude/session/metrics.json"
        
        # Work-in-progress (for graceful restart)
        WorkInProgress       = Join-Path $ProjectRoot ".claude/session/work-in-progress.json"
        
        # PRD
        PrdFile              = Join-Path $ProjectRoot "prd.json"
    }
}

# ============================================================================
# AGENT CONFIGURATION
# ============================================================================

$Script:AgentConfig = @{
    "pm" = @{
        Type = "coordinator"
        Command = "/ralph-coordinator-event"
        DisplayName = "PM (Coordinator)"
        Color = "Magenta"
    }
    "developer" = @{
        Type = "worker"
        Command = "/ralph-worker-event --agent developer"
        DisplayName = "Developer"
        Color = "Cyan"
    }
    "techartist" = @{
        Type = "worker"
        Command = "/ralph-worker-event --agent techartist"
        DisplayName = "Tech Artist"
        Color = "Green"
    }
    "qa" = @{
        Type = "worker"
        Command = "/ralph-worker-event --agent qa"
        DisplayName = "QA"
        Color = "Yellow"
    }
    "gamedesigner" = @{
        Type = "worker"
        Command = "/ralph-worker-event --agent gamedesigner"
        DisplayName = "Game Designer"
        Color = "Blue"
    }
}

function Get-AgentConfig {
    param([string]$AgentName)
    return $Script:AgentConfig[$AgentName]
}

function Get-RalphConfig {
    return $Script:RalphConfig
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

function Write-RalphLog {
    param(
        [string]$Message,
        [string]$Level = "INFO",
        [string]$Agent = "",
        [ConsoleColor]$Color = [ConsoleColor]::White
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $prefix = if ($Agent) { "[$timestamp] [$Agent] [$Level]" } else { "[$timestamp] [$Level]" }
    
    Write-Host "$prefix $Message" -ForegroundColor $Color
}

function Get-Timestamp {
    return (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
}

function Get-TimestampLocal {
    return Get-Date -Format "yyyy-MM-dd HH:mm:ss"
}

function Write-SessionLog {
    <#
    .SYNOPSIS
    Write to unified session log file with agent identification.

    .DESCRIPTION
    Writes log entries to the unified session.log file in the session directory.
    This consolidates logging from all agents into a single file instead of
    scattered progress files.

    .PARAMETER Message
    The log message.

    .PARAMETER Agent
    The agent writing the log (pm, developer, qa, watchdog).

    .PARAMETER Level
    Log level (INFO, WARNING, ERROR, DEBUG).

    .PARAMETER ProjectRoot
    Project root path. Defaults to current location.

    .EXAMPLE
    Write-SessionLog -Agent "qa" -Level "INFO" -Message "Validation passed for feat-001"
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,

        [Parameter(Mandatory=$true)]
        [ValidateSet("pm", "developer", "techartist", "qa", "gamedesigner", "watchdog")]
        [string]$Agent,

        [ValidateSet("INFO", "WARNING", "ERROR", "DEBUG")]
        [string]$Level = "INFO",

        [string]$ProjectRoot = (Get-Location).Path
    )

    $paths = Get-RalphPaths -ProjectRoot $ProjectRoot
    $logFile = Join-Path $paths.SessionDir "session.log"

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Agent] [$Level] $Message"

    try {
        $logEntry | Out-File -FilePath $logFile -Append -Encoding utf8
    } catch {
        # Silently fail if log cannot be written
    }
}

# ============================================================================
# SESSION STATE HELPERS
# ============================================================================

function Initialize-SessionDirectory {
    param([string]$ProjectRoot = (Get-Location).Path)
    
    $paths = Get-RalphPaths -ProjectRoot $ProjectRoot
    
    if (-not (Test-Path $paths.SessionDir)) {
        New-Item -ItemType Directory -Path $paths.SessionDir -Force | Out-Null
        Write-RalphLog "Created session directory: $($paths.SessionDir)" -Level "DEBUG"
    }
}

function Get-CoordinatorState {
    param([string]$ProjectRoot = (Get-Location).Path)
    
    $paths = Get-RalphPaths -ProjectRoot $ProjectRoot
    
    if (Test-Path $paths.CoordinatorState) {
        try {
            return Get-Content $paths.CoordinatorState -Raw | ConvertFrom-Json
        } catch {
            Write-RalphLog "Failed to parse coordinator state: $_" -Level "ERROR" -Color Red
            return $null
        }
    }
    return $null
}

function Save-CoordinatorState {
    param(
        [Parameter(Mandatory=$true)]
        $State,
        [string]$ProjectRoot = (Get-Location).Path
    )
    
    $paths = Get-RalphPaths -ProjectRoot $ProjectRoot
    $tempFile = "$($paths.CoordinatorState).tmp"
    
    try {
        $State | ConvertTo-Json -Depth 10 | Out-File -FilePath $tempFile -Encoding utf8
        Move-Item -Path $tempFile -Destination $paths.CoordinatorState -Force
        return $true
    } catch {
        Write-RalphLog "Failed to save coordinator state: $_" -Level "ERROR" -Color Red
        if (Test-Path $tempFile) { Remove-Item $tempFile -Force }
        return $false
    }
}

function Get-AgentHeartbeat {
    param(
        [string]$AgentName,
        [string]$ProjectRoot = (Get-Location).Path
    )
    
    $paths = Get-RalphPaths -ProjectRoot $ProjectRoot
    
    # First, try per-agent heartbeat file (more reliable - single writer)
    $agentFile = Join-Path $paths.SessionDir "agent-$AgentName.json"
    if (Test-Path $agentFile) {
        try {
            $heartbeat = Get-Content $agentFile -Raw | ConvertFrom-Json
            if ($heartbeat -and $heartbeat.lastSeen) {
                return $heartbeat
            }
        } catch {}
    }
    
    # Fallback to coordinator state
    $state = Get-CoordinatorState -ProjectRoot $ProjectRoot
    if ($state -and $state.agents -and $state.agents.$AgentName) {
        return $state.agents.$AgentName
    }
    return $null
}

function Update-AgentHeartbeat {
    param(
        [Parameter(Mandatory=$true)]
        [string]$AgentName,
        [string]$Status = "idle",
        [string]$ProjectRoot = (Get-Location).Path,
        [switch]$UseLocking = $false
    )
    
    $paths = Get-RalphPaths -ProjectRoot $ProjectRoot
    
    # First, update per-agent heartbeat file (no locking needed - single writer)
    $agentFile = Join-Path $paths.SessionDir "agent-$AgentName.json"
    $heartbeat = @{
        agent = $AgentName
        status = $Status
        lastSeen = Get-Timestamp
        pid = $PID
    }
    try {
        $heartbeat | ConvertTo-Json -Depth 5 | Out-File -FilePath $agentFile -Encoding utf8
    } catch {}
    
    # Then, update coordinator state (with optional locking for critical sections)
    if ($UseLocking) {
        # Source file-lock.ps1 if not already loaded
        $lockScript = Join-Path $paths.ScriptsDir "file-lock.ps1"
        if (Test-Path $lockScript) {
            . $lockScript
            
            try {
                Update-JsonFile -FilePath $paths.CoordinatorState -AgentName $AgentName -CreateIfMissing -UpdateScript {
                    param($state)
                    if (-not $state) { return $null }
                    if (-not $state.agents) {
                        $state | Add-Member -NotePropertyName "agents" -NotePropertyValue @{} -Force
                    }
                    $state.agents.$AgentName = @{
                        status = $Status
                        lastSeen = Get-Timestamp
                    }
                    return $state
                }
                return $true
            } catch {
                Write-RalphLog "Failed to update heartbeat with locking: $_" -Level "WARN" -Color Yellow
            }
        }
    }
    
    # Fallback: simple update without locking (for heartbeats, eventual consistency is OK)
    $state = Get-CoordinatorState -ProjectRoot $ProjectRoot
    if (-not $state) {
        return $false
    }
    
    if (-not $state.agents) {
        $state | Add-Member -NotePropertyName "agents" -NotePropertyValue @{} -Force
    }
    
    $state.agents.$AgentName = @{
        status = $Status
        lastSeen = Get-Timestamp
    }
    
    return Save-CoordinatorState -State $state -ProjectRoot $ProjectRoot
}

function Test-AgentStale {
    param(
        [Parameter(Mandatory=$true)]
        [string]$AgentName,
        [int]$ThresholdSeconds = $Script:RalphConfig.StaleAgentThreshold,
        [string]$ProjectRoot = (Get-Location).Path,
        [switch]$IgnoreMissing  # If true, missing heartbeat is NOT stale (for initial startup)
    )
    
    $heartbeat = Get-AgentHeartbeat -AgentName $AgentName -ProjectRoot $ProjectRoot
    
    if (-not $heartbeat -or -not $heartbeat.lastSeen) {
        # No heartbeat - check if we should consider this stale or not
        if ($IgnoreMissing) {
            return $false  # Don't restart agents that haven't started yet
        }
        return $true  # No heartbeat = stale
    }
    
    try {
        $lastSeen = [DateTime]::Parse($heartbeat.lastSeen)
        $elapsed = ([DateTime]::UtcNow - $lastSeen).TotalSeconds
        return $elapsed -gt $ThresholdSeconds
    } catch {
        return $true  # Can't parse = stale
    }
}

# ============================================================================
# WORK-IN-PROGRESS HELPERS
# ============================================================================

function Save-WorkInProgress {
    param(
        [Parameter(Mandatory=$true)]
        [string]$AgentName,
        [hashtable]$TaskState,
        [string]$Reason = "restart",
        [string]$ProjectRoot = (Get-Location).Path
    )
    
    $paths = Get-RalphPaths -ProjectRoot $ProjectRoot
    
    $wip = @{
        savedAt = Get-Timestamp
        agent = $AgentName
        reason = $Reason
        taskState = $TaskState
    }
    
    try {
        $wip | ConvertTo-Json -Depth 10 | Out-File -FilePath $paths.WorkInProgress -Encoding utf8
        Write-RalphLog "Saved work-in-progress for $AgentName" -Level "INFO" -Agent $AgentName
        return $true
    } catch {
        Write-RalphLog "Failed to save work-in-progress: $_" -Level "ERROR" -Color Red
        return $false
    }
}

function Get-WorkInProgress {
    param([string]$ProjectRoot = (Get-Location).Path)
    
    $paths = Get-RalphPaths -ProjectRoot $ProjectRoot
    
    if (Test-Path $paths.WorkInProgress) {
        try {
            return Get-Content $paths.WorkInProgress -Raw | ConvertFrom-Json
        } catch {
            return $null
        }
    }
    return $null
}

function Clear-WorkInProgress {
    param([string]$ProjectRoot = (Get-Location).Path)
    
    $paths = Get-RalphPaths -ProjectRoot $ProjectRoot
    
    if (Test-Path $paths.WorkInProgress) {
        Remove-Item $paths.WorkInProgress -Force
    }
}
