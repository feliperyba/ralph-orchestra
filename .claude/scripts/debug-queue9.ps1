# Debug test 9 - check Get-ChildItemWithTimeout in isolation
$ErrorActionPreference = "Stop"

Write-Host "=== Debug Message Queue Test 9 (Isolation) ===" -ForegroundColor Cyan

. "$PSScriptRoot\test-helpers.ps1"
. "$PSScriptRoot\message-queue.ps1"

$env = New-TestEnvironment -TestName "debug-queue9"
Initialize-MessageQueue -SessionDir $env.SessionDir

# Send a message
$msgId = Send-AgentMessage -From "pm" -To "developer" -Type "task_assign" -Payload @{ test = "debug" }
Write-Host "Message ID: $msgId" -ForegroundColor Green

# Check the function directly
$inbox = Join-Path $Script:MessageQueueDir "developer"

# First, verify files exist
Write-Host "`nFile check:" -ForegroundColor Gray
$filesDirect = Get-ChildItem -Path $inbox -Filter "*.json"
Write-Host "  Get-ChildItem found: $($filesDirect.Count) files" -ForegroundColor Cyan

# Now call Get-ChildItemWithTimeout (the one used by message-queue.ps1)
Write-Host "`nGet-ChildItemWithTimeout check:" -ForegroundColor Gray
$func = Get-Command Get-ChildItemWithTimeout -ErrorAction SilentlyContinue
Write-Host "  Function source: $($func.Source)" -ForegroundColor DarkGray
Write-Host "  Function exists: $($null -ne $func)" -ForegroundColor DarkGray

if ($func) {
    # Call with very long timeout
    $filesTimeout = Get-ChildItemWithTimeout -Path $inbox -Filter "*.json" -TimeoutMs 10000 -DefaultValue @()
    Write-Host "  Get-ChildItemWithTimeout found: $($filesTimeout.Count) files" -ForegroundColor $(if ($filesTimeout.Count -gt 0) { "Green" } else { "Red" })
}

# Now try Get-PendingMessages
Write-Host "`nGet-PendingMessages check:" -ForegroundColor Gray
$pending = Get-PendingMessages -Agent "developer" -TimeoutMs 10000
Write-Host "  Get-PendingMessages found: $($pending.Count) messages" -ForegroundColor $(if ($pending.Count -gt 0) { "Green" } else { "Red" })

# Cleanup
& $env.Cleanup
Write-Host "`n[OK] Debug 9 complete" -ForegroundColor Green
