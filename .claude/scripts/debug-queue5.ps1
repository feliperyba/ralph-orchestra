# Debug test 5 - bypass cache
$ErrorActionPreference = "Stop"

. "$PSScriptRoot\test-helpers.ps1"
. "$PSScriptRoot\safe-file-io.ps1"
. "$PSScriptRoot\message-queue.ps1"

Write-Host "=== Debug Message Queue Test 5 (Bypass Cache) ===" -ForegroundColor Cyan

$env = New-TestEnvironment -TestName "debug-queue5"
Initialize-MessageQueue -SessionDir $env.SessionDir

# Clear the cache
$Script:DirectoryEnumCache.Clear()
Write-Host "Cache cleared" -ForegroundColor Gray

# Send a message
$msgId = Send-AgentMessage -From "pm" -To "developer" -Type "task_assign" -Payload @{ test = "debug" }
Write-Host "Message ID: $msgId" -ForegroundColor Green

# Wait a bit
Start-Sleep -Milliseconds 100

# Clear cache again before reading
$Script:DirectoryEnumCache.Clear()
Write-Host "Cache cleared again" -ForegroundColor Gray

# Now try Get-PendingMessages
Write-Host "`nGet-PendingMessages after cache clear:" -ForegroundColor Gray
$pending = Get-PendingMessages -Agent "developer"
Write-Host "Result: $($pending.Count) messages" -ForegroundColor $(if ($pending.Count -gt 0) { "Green" } else { "Red" })

# Try using the timeout directly
Write-Host "`nGet-PendingMessages with 5s timeout:" -ForegroundColor Gray
$pending2 = Get-PendingMessages -Agent "developer" -TimeoutMs 5000
Write-Host "Result: $($pending2.Count) messages" -ForegroundColor $(if ($pending2.Count -gt 0) { "Green" } else { "Red" })

# Cleanup
& $env.Cleanup
Write-Host "`n[OK] Debug 5 complete" -ForegroundColor Green
