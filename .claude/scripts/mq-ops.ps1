# Message Queue Operations Script
# Bash-safe interface to message queue functions
# Usage: powershell.exe -File mq-ops.ps1 -Operation <op> [params]
#
# Operations:
#   get-pending  - Get pending messages for an agent
#   send        - Send a message to an agent
#   remove      - Remove a processed message
#   global-state- Get all messages across all agents
#   list        - List message filenames for an agent
#   cleanup     - Clean stale messages and dead letter queue
#   dlq-count   - Get dead letter queue count

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("get-pending", "send", "remove", "global-state", "list", "cleanup", "dlq-count")]
    [string]$Operation,

    [string]$Agent = "",
    [string]$MessageId = "",
    [string]$From = "",
    [string]$To = "",
    [string]$Type = "",
    [string]$PayloadJson = "",
    [string]$OutputFile = "",
    [int]$MaxAgeMinutes = 60
)

$ErrorActionPreference = "Stop"

# ============================================================================
# Find project root by searching for .claude directory
# ============================================================================
function Find-ProjectRoot {
    $currentDir = $PWD
    while ($currentDir -and -not (Test-Path "$currentDir\.claude")) {
        $currentDir = Split-Path $currentDir -Parent
    }
    if (-not $currentDir) {
        throw "Project root not found (couldn't find .claude directory)"
    }
    return $currentDir
}

try {
    # Find project root
    $projectRoot = Find-ProjectRoot

    # Load message queue
    $mqScript = Join-Path $projectRoot ".claude\scripts\message-queue.ps1"
    if (-not (Test-Path $mqScript)) {
        throw "Message queue script not found at: $mqScript"
    }

    . $mqScript

    # Initialize message queue
    $sessionDir = Join-Path $projectRoot ".claude\session"
    Initialize-MessageQueue -SessionDir $sessionDir | Out-Null

    # Execute operation
    $result = switch ($Operation) {
        "get-pending" {
            if (-not $Agent) { throw "-Agent parameter required for get-pending operation" }
            Get-PendingMessages -Agent $Agent
        }
        "send" {
            if (-not $From) { throw "-From parameter required for send operation" }
            if (-not $To) { throw "-To parameter required for send operation" }
            if (-not $Type) { throw "-Type parameter required for send operation" }

            # Parse payload JSON if provided
            $payload = if ($PayloadJson) {
                try {
                    $PayloadJson | ConvertFrom-Json
                } catch {
                    throw "Invalid JSON in -PayloadJson: $_"
                }
            } else {
                @{ timestamp = (Get-Date).ToUniversalTime().ToString("o") }
            }

            $msgId = Send-AgentMessage -From $From -To $To -Type $Type -Payload $payload -Priority "normal"
            @{ messageId = $msgId; success = $true }
        }
        "remove" {
            if (-not $Agent) { throw "-Agent parameter required for remove operation" }
            if (-not $MessageId) { throw "-MessageId parameter required for remove operation" }
            Remove-AgentMessage -Agent $Agent -MessageId $MessageId
            @{ success = $true }
        }
        "global-state" {
            Get-GlobalMessageState
        }
        "list" {
            if (-not $Agent) { throw "-Agent parameter required for list operation" }

            # Use the MessageQueueDir that was set during initialization
            $inbox = Join-Path $Script:MessageQueueDir $Agent
            if (Test-Path $inbox) {
                Get-ChildItem $inbox "msg-*.json" -ErrorAction SilentlyContinue |
                    Select-Object -ExpandProperty Name
            } else {
                @()
            }
        }
        default {
            throw "Unknown operation: $Operation"
        }
    }

    # Output result
    $jsonOutput = $result | ConvertTo-Json -Depth 10 -Compress:$false

    if ($OutputFile) {
        # Ensure output directory exists
        $outputDir = Split-Path $OutputFile -Parent
        if (-not (Test-Path $outputDir)) {
            New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
        }
        $jsonOutput | Out-File -FilePath $OutputFile -Encoding UTF8 -Force
        Write-Host "Output written to: $OutputFile"
    } else {
        # Write to stdout (will be captured by caller)
        Write-Output $jsonOutput
    }

} catch {
    # Write error as JSON for consistent parsing
    $errorOutput = @{
        error = $true
        message = $_.Exception.Message
        operation = $Operation
    } | ConvertTo-Json -Depth 10

    if ($OutputFile) {
        $errorOutput | Out-File -FilePath $OutputFile -Encoding UTF8 -Force
    } else {
        Write-Error $errorOutput
    }
    exit 1
}
