# Debug test 7 - check if Get-ChildItemWithTimeout is being used
$ErrorActionPreference = "Stop"

. "$PSScriptRoot\test-helpers.ps1"
. "$PSScriptRoot\safe-file-io.ps1"
. "$PSScriptRoot\message-queue.ps1"

Write-Host "=== Debug Message Queue Test 7 (Function Check) ===" -ForegroundColor Cyan

$env = New-TestEnvironment -TestName "debug-queue7"
Initialize-MessageQueue -SessionDir $env.SessionDir

# Check if the function exists
Write-Host "Get-ChildItemWithTimeout exists: $(Get-Command Get-ChildItemWithTimeout -ErrorAction SilentlyContinue | Measure-Object).Count" -ForegroundColor Gray

# Send a message
$msgId = Send-AgentMessage -From "pm" -To "developer" -Type "task_assign" -Payload @{ test = "debug" }
Write-Host "Message ID: $msgId" -ForegroundColor Green

# Check cache before call
$inbox = Join-Path $Script:MessageQueueDir "developer"
$cacheKey = "$inbox|*.json"
Write-Host "`nCache check:" -ForegroundColor Gray
Write-Host "  Cache key: $cacheKey" -ForegroundColor DarkGray
Write-Host "  Cache has key: $($Script:DirectoryEnumCache.ContainsKey($cacheKey))" -ForegroundColor DarkGray
if ($Script:DirectoryEnumCache.ContainsKey($cacheKey)) {
    $cached = $Script:DirectoryEnumCache[$cacheKey]
    Write-Host "  Cached files: $($cached.Files.Count)" -ForegroundColor DarkGray
}

# Now call Get-PendingMessages
Write-Host "`nCalling Get-PendingMessages..." -ForegroundColor Gray
$pending = Get-PendingMessages -Agent "developer"
Write-Host "Result: $($pending.Count) messages" -ForegroundColor $(if ($pending.Count -gt 0) { "Green" } else { "Red" })

# Check cache after call
Write-Host "`nCache after call:" -ForegroundColor Gray
Write-Host "  Cache has key: $($Script:DirectoryEnumCache.ContainsKey($cacheKey))" -ForegroundColor DarkGray
if ($Script:DirectoryEnumCache.ContainsKey($cacheKey)) {
    $cached = $Script:DirectoryEnumCache[$cacheKey]
    Write-Host "  Cached files: $($cached.Files.Count)" -ForegroundColor DarkGray
}

# Cleanup
& $env.Cleanup
Write-Host "`n[OK] Debug 7 complete" -ForegroundColor Green
